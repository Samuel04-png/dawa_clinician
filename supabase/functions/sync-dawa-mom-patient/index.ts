import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
import { corsHeaders } from '../_shared/cors.ts';

const sourceProject = 'dawa_mom';
const sourceSchema = 'public';
const sourceTable = 'mothers';
const destinationTable = 'patients';

type JsonRecord = Record<string, unknown>;

type WebhookPayload = {
  type?: unknown;
  eventType?: unknown;
  event_type?: unknown;
  op?: unknown;
  schema?: unknown;
  table?: unknown;
  record?: JsonRecord | null;
  old_record?: JsonRecord | null;
  old?: JsonRecord | null;
};

type SyncEvent = 'INSERT' | 'UPDATE' | 'DELETE';

class PayloadError extends Error {}

export async function handleRequest(req: Request): Promise<Response> {
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405, {
      Allow: 'POST',
    });
  }

  const expectedSecret = Deno.env.get('DAWA_SYNC_SECRET') ?? '';
  const providedSecret = req.headers.get('x-dawa-sync-secret') ?? '';
  if (!expectedSecret) {
    return jsonResponse({ error: 'Sync secret is not configured.' }, 500);
  }
  if (!timingSafeEqual(providedSecret, expectedSecret)) {
    return jsonResponse({ error: 'Unauthorized.' }, 401);
  }

  let payload: WebhookPayload;
  try {
    payload = await req.json();
  } catch (_error) {
    return jsonResponse({ error: 'Invalid JSON payload.' }, 400);
  }

  let event: SyncEvent;
  let sourceRecord: JsonRecord;
  let sourceMotherId: string;
  try {
    assertSourceWebhook(payload);
    event = normalizeEvent(payload);
    sourceRecord = recordForEvent(payload, event);
    sourceMotherId = requiredText(sourceRecord.id);
  } catch (error) {
    if (error instanceof PayloadError) {
      return jsonResponse({ error: error.message }, 400);
    }
    return jsonResponse({ error: 'Invalid webhook payload.' }, 400);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: 'Supabase service credentials are missing.' }, 500);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  try {
    const existing = await findExistingPatient(supabase, sourceMotherId);
    const now = new Date().toISOString();

    if (event === 'DELETE') {
      if (!existing) {
        return jsonResponse({ ok: true, event, action: 'missing_noop' });
      }

      const archivePayload = metadataPayload(sourceRecord, sourceMotherId, now);
      archivePayload.source_deleted_at = now;

      await updatePatient(supabase, existing.id, archivePayload);
      return jsonResponse({ ok: true, event, action: 'archived' });
    }

    const demographicPayload = {
      ...metadataPayload(sourceRecord, sourceMotherId, now),
      ...demographicFields(sourceRecord),
      source_deleted_at: null,
    };

    if (existing) {
      await updatePatient(supabase, existing.id, demographicPayload);
      return jsonResponse({ ok: true, event, action: 'updated' });
    }

    const insertPayload = {
      id: destinationId(sourceMotherId),
      mother_id: preferredText(sourceRecord, ['mother_id', 'patient_id']) ??
        sourceMotherId,
      ...demographicPayload,
    };

    const inserted = await insertPatient(supabase, insertPayload);
    if (inserted) {
      return jsonResponse({ ok: true, event, action: 'inserted' });
    }

    const conflicted = await findExistingPatient(supabase, sourceMotherId);
    if (conflicted) {
      await updatePatient(supabase, conflicted.id, demographicPayload);
      return jsonResponse({ ok: true, event, action: 'updated_after_conflict' });
    }

    return jsonResponse({ error: 'Could not synchronize patient.' }, 500);
  } catch (_error) {
    console.error('[sync-dawa-mom-patient] Synchronization failed.');
    return jsonResponse({ error: 'Patient synchronization failed.' }, 500);
  }
}

serve(handleRequest);

function assertSourceWebhook(payload: WebhookPayload): void {
  const schemaName = optionalText(payload.schema);
  const rawTable = optionalText(payload.table);
  const normalizedTable = rawTable?.includes('.')
    ? rawTable.split('.').pop()
    : rawTable;
  const normalizedSchema = rawTable?.includes('.')
    ? rawTable.split('.').shift()
    : schemaName;

  if (normalizedSchema !== sourceSchema || normalizedTable !== sourceTable) {
    throw new PayloadError('Webhook must target public.mothers.');
  }
}

function normalizeEvent(payload: WebhookPayload): SyncEvent {
  const event = optionalText(
    payload.type ?? payload.eventType ?? payload.event_type ?? payload.op,
  )?.toUpperCase();
  if (event === 'INSERT' || event === 'UPDATE' || event === 'DELETE') {
    return event;
  }
  throw new PayloadError('Unsupported webhook event type.');
}

function recordForEvent(payload: WebhookPayload, event: SyncEvent): JsonRecord {
  const record = event === 'DELETE'
    ? payload.old_record ?? payload.old ?? payload.record
    : payload.record ?? payload.old_record ?? payload.old;
  if (!isRecord(record)) {
    throw new PayloadError('Webhook record is missing.');
  }
  return record;
}

function metadataPayload(
  sourceRecord: JsonRecord,
  sourceMotherId: string,
  syncedAt: string,
): JsonRecord {
  return {
    source_project: sourceProject,
    source_mother_id: sourceMotherId,
    source_user_id: preferredText(sourceRecord, ['user_id', 'auth_id']),
    registration_source: sourceProject,
    synced_at: syncedAt,
  };
}

function demographicFields(sourceRecord: JsonRecord): JsonRecord {
  const fields: JsonRecord = {};
  assignIfPresent(fields, 'name', textField(sourceRecord, ['full_name', 'name']));
  assignIfPresent(
    fields,
    'phone_number',
    textField(sourceRecord, ['mobile_number', 'phone_number', 'phone']),
  );
  assignIfPresent(fields, 'dateOfBirth', dateField(sourceRecord, [
    'date_of_birth',
    'dateOfBirth',
    'dob',
  ]));
  assignIfPresent(fields, 'address', textField(sourceRecord, ['address']));
  assignIfPresent(fields, 'occupation', textField(sourceRecord, ['occupation']));
  assignIfPresent(
    fields,
    'mother_id',
    textField(sourceRecord, ['mother_id', 'patient_id']),
  );
  return fields;
}

function assignIfPresent(
  fields: JsonRecord,
  destination: string,
  value: unknown,
): void {
  if (value !== undefined) {
    fields[destination] = value;
  }
}

async function findExistingPatient(
  supabase: ReturnType<typeof createClient>,
  sourceMotherId: string,
): Promise<{ id: string } | null> {
  const { data, error } = await supabase
    .from(destinationTable)
    .select('id')
    .eq('source_project', sourceProject)
    .eq('source_mother_id', sourceMotherId)
    .maybeSingle();

  if (error) {
    throw error;
  }
  return data as { id: string } | null;
}

async function insertPatient(
  supabase: ReturnType<typeof createClient>,
  payload: JsonRecord,
): Promise<boolean> {
  const { error } = await supabase
    .from(destinationTable)
    .insert(payload)
    .select('id')
    .single();

  if (!error) {
    return true;
  }
  if (error.code === '23505') {
    return false;
  }
  throw error;
}

async function updatePatient(
  supabase: ReturnType<typeof createClient>,
  patientId: string,
  payload: JsonRecord,
): Promise<void> {
  const { error } = await supabase
    .from(destinationTable)
    .update(payload)
    .eq('id', patientId);

  if (error) {
    throw error;
  }
}

function textField(sourceRecord: JsonRecord, keys: string[]): string | null | undefined {
  const picked = pickValue(sourceRecord, keys);
  if (!picked.found) {
    return undefined;
  }
  return optionalText(picked.value);
}

function dateField(sourceRecord: JsonRecord, keys: string[]): string | null | undefined {
  const picked = pickValue(sourceRecord, keys);
  if (!picked.found) {
    return undefined;
  }
  const value = optionalText(picked.value);
  if (!value) {
    return null;
  }
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? undefined : date.toISOString();
}

function preferredText(sourceRecord: JsonRecord, keys: string[]): string | null {
  return textField(sourceRecord, keys) ?? null;
}

function pickValue(
  sourceRecord: JsonRecord,
  keys: string[],
): { found: boolean; value: unknown } {
  for (const key of keys) {
    if (Object.prototype.hasOwnProperty.call(sourceRecord, key)) {
      return { found: true, value: sourceRecord[key] };
    }
  }
  return { found: false, value: undefined };
}

function optionalText(value: unknown): string | null {
  if (value === null || value === undefined) {
    return null;
  }
  const text = String(value).trim();
  return text.length === 0 ? null : text;
}

function requiredText(value: unknown): string {
  const text = optionalText(value);
  if (!text) {
    throw new PayloadError('Source mother ID is missing.');
  }
  return text;
}

function isRecord(value: unknown): value is JsonRecord {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function destinationId(sourceMotherId: string): string {
  return `dawa_mom_${base64Url(sourceMotherId)}`;
}

function base64Url(value: string): string {
  const bytes = new TextEncoder().encode(value);
  let binary = '';
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary)
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');
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
        'authorization, x-client-info, apikey, content-type, x-dawa-sync-secret',
      'Content-Type': 'application/json',
      ...extraHeaders,
    },
  });
}
