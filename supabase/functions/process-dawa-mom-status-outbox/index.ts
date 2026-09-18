import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
import { corsHeaders } from '../_shared/cors.ts';

type JsonRecord = Record<string, unknown>;
type OutboxJob = {
  id: string;
  event_id: string;
  payload: JsonRecord;
  attempt_count: number;
};

export async function handleRequest(req: Request): Promise<Response> {
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405, { Allow: 'POST' });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const callbackUrl = Deno.env.get('DAWA_MOM_STATUS_CALLBACK_URL');
  const callbackSecret = Deno.env.get('DAWA_MOM_SYNC_SECRET');
  if (!supabaseUrl || !serviceRoleKey || !callbackUrl || !callbackSecret) {
    return jsonResponse({ error: 'Status worker is not configured.' }, 500);
  }
  if (!isAuthorizedWorker(req, serviceRoleKey)) {
    return jsonResponse({ error: 'Unauthorized.' }, 401);
  }

  let requestedLimit = 10;
  try {
    const body = await req.json();
    const parsed = Number(body?.limit);
    if (Number.isFinite(parsed)) requestedLimit = Math.round(parsed);
  } catch {
    // Empty requests use the safe default.
  }
  const limit = Math.max(1, Math.min(requestedLimit, 25));
  const workerId = `dawa-clinician-${crypto.randomUUID()}`;
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data, error } = await supabase.rpc('claim_dawa_mom_status_events', {
    p_limit: limit,
    p_worker_id: workerId,
  });
  if (error) {
    console.error('[process-dawa-mom-status-outbox] Could not claim jobs.');
    return jsonResponse({ error: 'Status jobs could not be claimed.' }, 500);
  }

  const jobs = (data ?? []) as OutboxJob[];
  let completed = 0;
  let retrying = 0;
  let permanentlyFailed = 0;

  for (const job of jobs) {
    let success = false;
    let retryable = true;
    let errorCode: string | null = 'UPSTREAM_UNREACHABLE';
    try {
      const upstream = await fetch(callbackUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-dawa-sync-secret': callbackSecret,
        },
        body: JSON.stringify(job.payload),
      });
      let upstreamPayload: JsonRecord = {};
      try {
        const parsed = await upstream.json();
        if (isRecord(parsed)) upstreamPayload = parsed;
      } catch {
        // A safe HTTP-derived code is sufficient.
      }
      success = upstream.ok;
      errorCode = success
        ? null
        : (text(upstreamPayload.code) ?? `HTTP_${upstream.status}`).slice(0, 120);
      retryable = upstreamPayload.retryable === true || upstream.status === 408 ||
        upstream.status === 429 || upstream.status >= 500;
    } catch {
      // Keep the generic retryable network failure.
    }

    const permanent = !success && (!retryable || job.attempt_count >= 8);
    const retryAt = success || permanent
      ? null
      : new Date(Date.now() + retryDelayMs(job.attempt_count)).toISOString();
    const { error: completeError } = await supabase.rpc(
      'complete_dawa_mom_status_event',
      {
        p_job_id: job.id,
        p_worker_id: workerId,
        p_success: success,
        p_error_code: errorCode,
        p_retry_at: retryAt,
        p_permanent: permanent,
      },
    );

    if (completeError) {
      console.error('[process-dawa-mom-status-outbox] Could not complete a job.');
      retrying += 1;
    } else if (success) {
      completed += 1;
    } else if (permanent) {
      permanentlyFailed += 1;
    } else {
      retrying += 1;
    }
  }

  return jsonResponse({
    claimed: jobs.length,
    completed,
    retrying,
    permanently_failed: permanentlyFailed,
  });
}

if (import.meta.main) {
  serve(handleRequest);
}

function isAuthorizedWorker(req: Request, serviceRoleKey: string): boolean {
  const workerSecret = Deno.env.get('DAWA_CLINICIAN_WORKER_SECRET');
  const providedWorkerSecret = req.headers.get('x-dawa-worker-secret') ?? '';
  if (workerSecret && timingSafeEqual(providedWorkerSecret, workerSecret)) return true;
  const authorization = req.headers.get('Authorization') ?? '';
  const bearer = authorization.startsWith('Bearer ')
    ? authorization.slice('Bearer '.length)
    : '';
  return timingSafeEqual(bearer, serviceRoleKey);
}

function retryDelayMs(attemptCount: number): number {
  const exponent = Math.max(0, Math.min(attemptCount - 1, 6));
  const base = 60_000 * 2 ** exponent;
  return Math.min(base + Math.floor(Math.random() * 30_000), 60 * 60 * 1000);
}

function isRecord(value: unknown): value is JsonRecord {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function text(value: unknown): string | null {
  if (value === null || value === undefined) return null;
  const candidate = String(value).trim();
  return candidate.length === 0 ? null : candidate;
}

function timingSafeEqual(left: string, right: string): boolean {
  const encoder = new TextEncoder();
  const leftBytes = encoder.encode(left);
  const rightBytes = encoder.encode(right);
  const length = Math.max(leftBytes.length, rightBytes.length);
  let difference = leftBytes.length ^ rightBytes.length;
  for (let index = 0; index < length; index++) {
    difference |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  }
  return difference === 0;
}

function jsonResponse(
  body: JsonRecord,
  status = 200,
  extraHeaders: HeadersInit = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Access-Control-Allow-Headers':
        'authorization, x-client-info, apikey, content-type, x-dawa-worker-secret',
      'Content-Type': 'application/json',
      ...extraHeaders,
    },
  });
}
