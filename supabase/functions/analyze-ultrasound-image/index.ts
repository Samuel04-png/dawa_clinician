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
    return jsonResponse(buildFallbackResult(gestationalAgeWeeks));
  }

  try {
    const result = await analyzeWithGemini({
      apiKey,
      imageBase64: image.base64,
      mimeType: image.mimeType,
      gestationalAgeWeeks,
    });

    return jsonResponse(result);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({
      ...buildFallbackResult(gestationalAgeWeeks),
      error: message,
    });
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
}: {
  apiKey: string;
  imageBase64: string;
  mimeType: string;
  gestationalAgeWeeks?: number;
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

  return normalizeModelResult(parseJsonObject(text), gestationalAgeWeeks);
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
  gestationalAgeWeeks?: number,
): UltrasoundAnalysisResponse {
  const fallback = buildFallbackResult(gestationalAgeWeeks);
  const rawFindings = normalizeFindings(value.findings);
  const findings = rawFindings.length ? rawFindings : fallback.findings;
  const overallLevel = normalizeLevel(value.overallLevel) ?? deriveOverallLevel(findings);
  const measurements = normalizeMeasurements(value.measurements);
  const estimatedGestationalAge = normalizeGestationalAge(value.estimatedGestationalAge) ??
    gestationalAgeWeeks;

  return {
    findings,
    overallAssessment: normalizeText(value.overallAssessment) ||
      'AI-assisted ultrasound review completed. Confirm all findings clinically.',
    overallLevel,
    recommendation: normalizeText(value.recommendation) ||
      'Review the image quality and confirm findings with a qualified clinician.',
    ...(estimatedGestationalAge ? { estimatedGestationalAge } : {}),
    ...(measurements ? { measurements } : {}),
  };
}

function normalizeFindings(value: unknown): UltrasoundFinding[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.slice(0, 8).map((item) => {
    const finding = item && typeof item === 'object'
      ? item as Record<string, unknown>
      : {};

    return {
      category: normalizeText(finding.category) || 'Image Review',
      finding: normalizeText(finding.finding) || 'No specific finding returned.',
      level: normalizeLevel(finding.level) ?? 'monitor',
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

function buildFallbackResult(gestationalAgeWeeks?: number): UltrasoundAnalysisResponse {
  return {
    findings: [
      {
        category: 'Image Received',
        finding: 'Ultrasound image was received for AI-assisted review.',
        level: 'monitor',
        note: 'No vision model is configured, so this is a fallback response.',
      },
      {
        category: 'Clinical Confirmation',
        finding: 'Image interpretation should be confirmed by a trained clinician.',
        level: 'monitor',
        note: 'Configure GEMINI_API_KEY for model-assisted findings.',
      },
    ],
    overallAssessment:
      'Ultrasound analysis endpoint is available. Model-assisted interpretation is not configured in this environment.',
    overallLevel: 'monitor',
    recommendation:
      'Confirm findings manually and configure GEMINI_API_KEY to enable AI-assisted ultrasound image review.',
    ...(gestationalAgeWeeks ? { estimatedGestationalAge: gestationalAgeWeeks } : {}),
  };
}

function clamp(value: number, min: number, max: number) {
  return Math.min(Math.max(value, min), max);
}
