import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const smsApiUrl = Deno.env.get('SMS_API_URL');
  const smsApiToken = Deno.env.get('SMS_API_TOKEN');
  if (!smsApiUrl) {
    return jsonResponse({ error: 'SMS_API_URL is not configured.' }, 501);
  }

  const body = await req.json().catch(() => ({}));
  const response = await fetch(smsApiUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(smsApiToken ? { Authorization: `Bearer ${smsApiToken}` } : {}),
    },
    body: JSON.stringify(body),
  });

  const data = await response.json().catch(async () => ({ text: await response.text() }));
  return jsonResponse(data, response.status);
});
