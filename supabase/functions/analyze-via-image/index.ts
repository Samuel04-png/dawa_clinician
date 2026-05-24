import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const token = Deno.env.get('HUGGINGFACE_API_TOKEN');
  const model = Deno.env.get('HUGGINGFACE_VIA_MODEL');
  if (!token || !model) {
    return jsonResponse(
      { error: 'HUGGINGFACE_API_TOKEN and HUGGINGFACE_VIA_MODEL are required.' },
      501,
    );
  }

  const body = await req.json().catch(() => ({}));
  const imageBase64 = body.imageBase64;
  if (!imageBase64 || typeof imageBase64 !== 'string') {
    return jsonResponse({ error: 'imageBase64 is required.' }, 400);
  }

  const binary = Uint8Array.from(atob(imageBase64), (char) => char.charCodeAt(0));
  const response = await fetch(`https://api-inference.huggingface.co/models/${model}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/octet-stream',
    },
    body: binary,
  });

  const data = await response.json().catch(() => ({}));
  return jsonResponse(data, response.status);
});
