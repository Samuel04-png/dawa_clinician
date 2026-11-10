import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';

type FindingLevel = 'normal' | 'monitor' | 'urgent';

type UltrasoundFinding = {
  category: string;
  finding: string;
  level: FindingLevel;
  note?: string;
};

type UltrasoundAnalysisResponse = {
  analysisProvider: 'gemini' | 'unavailable';
  examinationId?: string;
  modelId?: string;
  modelVersion?: string;
  findings: UltrasoundFinding[];
  overallAssessment: string;
  overallLevel: FindingLevel;
  recommendation: string;
  estimatedGestationalAge?: number;
  measurements?: Record<string, string>;
  error?: string;
};

type AnalyzeUltrasoundBody = {
  imageBase64?: unknown;
  gestationalAgeWeeks?: unknown;
  mimeType?: unknown;
  examinationId?: unknown;
};

const validLevels = new Set<FindingLevel>(['normal', 'monitor', 'urgent']);

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'POST is required.' }, 405);
  }

  const body = (await req.json().catch(() => ({}))) as AnalyzeUltrasoundBody;
  if (!body.imageBase64 || typeof body.imageBase64 !== 'string') {
    return jsonResponse({ error: 'imageBase64 is required.' }, 400);
  }

  const gestationalAgeWeeks = normalizeGestationalAge(body.gestationalAgeWeeks);
  if (typeof body.examinationId !== 'string' || !body.examinationId.trim()) {
    return jsonResponse({ error: 'examinationId is required.' }, 400);
  }
  const examinationId = body.examinationId.trim();
  const image = parseImageBase64(
    body.imageBase64,
    typeof body.mimeType === 'string' ? body.mimeType : undefined,
  );

  if (!image.base64) {
    return jsonResponse({ error: 'imageBase64 is empty.' }, 400);
  }

  if (!isValidBase64(image.base64)) {
    return jsonResponse({ error: 'imageBase64 must be valid base64.' }, 400);
  }

  const apiKey = Deno.env.get('GEMINI_API_KEY');
  if (!apiKey) {
    return jsonResponse({
      analysisProvider: 'unavailable',
      examinationId,
      findings: [],
      error: 'The cloud ultrasound model is not configured.',
    }, 503);
  }

  try {
    const result = await analyzeWithGemini({
      apiKey,
      imageBase64: image.base64,
      mimeType: image.mimeType,
      gestationalAgeWeeks,
      examinationId,
    });

    return jsonResponse(result);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({
      analysisProvider: 'unavailable',
      examinationId,
      findings: [],
      error: message,
    }, 502);
  }
});

function parseImageBase64(imageBase64: string, fallbackMimeType?: string) {
  const trimmed = imageBase64.trim();
  const dataUrlMatch = trimmed.match(/^data:([^;]+);base64,(.*)$/s);

  if (dataUrlMatch) {
    return {
      mimeType: dataUrlMatch[1] || fallbackMimeType || 'image/jpeg',
      base64: dataUrlMatch[2].replace(/\s/g, ''),
    };
  }

  return {
    mimeType: fallbackMimeType || 'image/jpeg',
    base64: trimmed.replace(/\s/g, ''),
  };
}

function isValidBase64(value: string) {
  try {
    atob(value);
    return true;
  } catch {
    return false;
  }
}

function normalizeGestationalAge(value: unknown) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return clamp(Math.round(value), 4, 42);
  }

  if (typeof value === 'string' && value.trim()) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return clamp(Math.round(parsed), 4, 42);
    }
  }

  return undefined;
}

async function analyzeWithGemini({
  apiKey,
  imageBase64,
  mimeType,
  gestationalAgeWeeks,
  examinationId,
}: {
  apiKey: string;
  imageBase64: string;
  mimeType: string;
  gestationalAgeWeeks?: number;
  examinationId: string;
}): Promise<UltrasoundAnalysisResponse> {
  const model =
    Deno.env.get('GEMINI_ULTRASOUND_MODEL') ||
    Deno.env.get('GEMINI_MODEL') ||
    'gemini-1.5-flash';

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        generationConfig: {
          temperature: 0.2,
          responseMimeType: 'application/json',
        },
        contents: [
          {
            parts: [
              {
                text: buildPrompt(gestationalAgeWeeks),
              },
              {
                inline_data: {
                  mime_type: mimeType,
                  data: imageBase64,
                },
              },
            ],
          },
        ],
      }),
    },
  );

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error =
      typeof data.error?.message === 'string'
        ? data.error.message
        : `Gemini request failed with ${response.status}`;
    throw new Error(error);
  }

  const text =
    data.candidates?.[0]?.content?.parts
      ?.map((part: { text?: string }) => part.text ?? '')
      .join('') ?? '';

  return normalizeModelResult(
    parseJsonObject(text),
    examinationId,
    model,
  );
}

function buildPrompt(gestationalAgeWeeks?: number) {
  return [
    'You are an assistive obstetric ultrasound image reviewer for a clinician-facing app.',
    'Return JSON only. Do not include markdown.',
    'Do not diagnose beyond what is visible. If image quality is poor or a structure is not visible, say so.',
    'Use urgent only for obvious high-risk visual concerns. Otherwise prefer monitor when uncertain.',
    `Known gestational age: ${gestationalAgeWeeks ?? 'unknown'} weeks.`,
    'Schema:',
    '{',
    '  "findings": [{"category": string, "finding": string, "level": "normal|monitor|urgent", "note": string}],',
    '  "overallAssessment": string,',
    '  "overallLevel": "normal|monitor|urgent",',
    '  "recommendation": string,',
    '  "estimatedGestationalAge": number|null,',
    '  "measurements": {"BPD": string, "HC": string, "AC": string, "FL": string, "EFW": string}|null',
    '}',
  ].join('\n');
}

function parseJsonObject(text: string) {
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start === -1 || end === -1 || end <= start) {
    throw new Error('Model did not return a JSON object.');
  }

  return JSON.parse(text.slice(start, end + 1));
}

function normalizeModelResult(
  value: Record<string, unknown>,
  examinationId: string,
  modelId: string,
): UltrasoundAnalysisResponse {
  const findings = normalizeFindings(value.findings);
  const overallLevel = normalizeLevel(value.overallLevel) ?? deriveOverallLevel(findings);
  const measurements = normalizeMeasurements(value.measurements);
  const estimatedGestationalAge = normalizeGestationalAge(value.estimatedGestationalAge);
  const overallAssessment = normalizeText(value.overallAssessment);
  const recommendation = normalizeText(value.recommendation);
  if (!overallAssessment || !recommendation) {
    throw new Error('Model response omitted the assessment or recommendation.');
  }

  return {
    analysisProvider: 'gemini',
    examinationId,
    modelId,
    findings,
    overallAssessment,
    overallLevel,
    recommendation,
    ...(estimatedGestationalAge ? { estimatedGestationalAge } : {}),
    ...(measurements ? { measurements } : {}),
  };
}

function normalizeFindings(value: unknown): UltrasoundFinding[] {
  if (!Array.isArray(value) || value.length === 0) {
    throw new Error('Model response omitted structured findings.');
  }

  return value.slice(0, 8).map((item) => {
    if (!item || typeof item !== 'object') {
      throw new Error('Model response contained an invalid finding.');
    }
    const finding = item as Record<string, unknown>;
    const category = normalizeText(finding.category);
    const description = normalizeText(finding.finding);
    const level = normalizeLevel(finding.level);
    if (!category || !description || !level) {
      throw new Error('Model response contained an incomplete finding.');
    }
    return {
      category,
      finding: description,
      level,
      ...(normalizeText(finding.note) ? { note: normalizeText(finding.note) } : {}),
    };
  });
}

function normalizeMeasurements(value: unknown) {
  if (!value || typeof value !== 'object') {
    return undefined;
  }

  const allowedKeys = ['BPD', 'HC', 'AC', 'FL', 'EFW', 'CRL', 'NT', 'AFI'];
  const output: Record<string, string> = {};
  const record = value as Record<string, unknown>;

  for (const key of allowedKeys) {
    const text = normalizeText(record[key]);
    if (text) {
      output[key] = text;
    }
  }

  return Object.keys(output).length ? output : undefined;
}

function normalizeLevel(value: unknown): FindingLevel | undefined {
  if (typeof value !== 'string') {
    return undefined;
  }

  const level = value.trim().toLowerCase();
  return validLevels.has(level as FindingLevel) ? level as FindingLevel : undefined;
}

function deriveOverallLevel(findings: UltrasoundFinding[]): FindingLevel {
  if (findings.some((finding) => finding.level === 'urgent')) {
    return 'urgent';
  }

  if (findings.some((finding) => finding.level === 'monitor')) {
    return 'monitor';
  }

  return 'normal';
}

function normalizeText(value: unknown) {
  return typeof value === 'string' ? value.trim().slice(0, 500) : '';
}

function clamp(value: number, min: number, max: number) {
  return Math.min(Math.max(value, min), max);
}
