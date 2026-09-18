import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';

type GeminiBody = {
  action?: string;
  model?: string;
  prompt?: string;
  imageBase64?: string;
  mimeType?: string;
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const apiKey = Deno.env.get('GEMINI_API_KEY');
  if (!apiKey) {
    return jsonResponse({ error: 'GEMINI_API_KEY is not configured.' }, 500);
  }

  const body = (await req.json().catch(() => ({}))) as GeminiBody;
  const model = body.model || 'gemini-1.5-flash';
  const prompt = body.prompt || '';
  const parts: Record<string, unknown>[] = [{ text: prompt }];

  if (body.imageBase64) {
    parts.push({
      inline_data: {
        mime_type: body.mimeType || 'image/jpeg',
        data: body.imageBase64,
      },
    });
  }

  const method = body.action === 'countTokens' ? 'countTokens' : 'generateContent';
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:${method}?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ contents: [{ parts }] }),
    },
  );

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    return jsonResponse(data, response.status);
  }

  if (method === 'countTokens') {
    return jsonResponse({
      text: String(data.totalTokens ?? data.total_tokens ?? ''),
      raw: data,
    });
  }

  const text =
    data.candidates?.[0]?.content?.parts
      ?.map((part: { text?: string }) => part.text ?? '')
      .join('') ?? '';

  return jsonResponse({ text, raw: data });
});
