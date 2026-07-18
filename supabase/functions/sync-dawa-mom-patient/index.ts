import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import {
  createClient,
  type SupabaseClient,
} from 'https://esm.sh/@supabase/supabase-js@2.45.4';
import { corsHeaders } from '../_shared/cors.ts';

const sourceProject = 'dawa_mom';
const sourceSchema = 'public';
const sourceTable = 'mothers';
const destinationTable = 'patients';
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type JsonRecord = Record<string, unknown>;

type WebhookPayload = {
  event_id?: unknown;
  eventId?: unknown;
  event_type?: unknown;
  eventType?: unknown;
  type?: unknown;
  op?: unknown;
  schema?: unknown;
  table?: unknown;
  record?: JsonRecord | null;
  old_record?: JsonRecord | null;
  old?: JsonRecord | null;
};

type SyncEvent = 'INSERT' | 'UPDATE' | 'DELETE';

type SupabaseAdmin = SupabaseClient<any, 'public', any>;

class PayloadError extends Error {}

export async function handleRequest(req: Request): Promise<Response> {
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405, {
      Allow: 'POST',
    });
  }

  const expectedSecret = Deno.env.get('DAWA_CLINICIAN_SYNC_SECRET') ??
    Deno.env.get('DAWA_SYNC_SECRET') ?? '';
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
  } catch {
    return jsonResponse({ error: 'Invalid JSON payload.' }, 400);
  }

  let event: SyncEvent;
  let sourceRecord: JsonRecord;
  let sourceMotherId: string;
  let eventId: string;
  try {
    assertSourceWebhook(payload);
    event = normalizeEvent(payload);
    sourceRecord = recordForEvent(payload, event);
    sourceMotherId = requiredUuid(sourceRecord.id ?? sourceRecord.source_mother_id);
    eventId = await resolveEventId(payload, event, sourceRecord, sourceMotherId);
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
    auth: { autoRefreshToken: false, persistSession: false },
  });

  try {
    const replay = await findProcessedEvent(supabase, eventId);
    if (replay) {
      return jsonResponse({ ...replay, replayed: true });
    }

    const existing = await findExistingPatient(supabase, sourceMotherId);
    const now = new Date().toISOString();
    let patientId: string | null = existing?.id ?? null;
    let action: string;

    if (existing && isStaleSourceVersion(
      existing.source_updated_at,
      existing.source_deleted_at,
      event,
      sourceRecord,
    )) {
      patientId = existing.id;
      action = 'stale_noop';
    } else if (event === 'DELETE') {
      if (!existing) {
        action = 'missing_noop';
      } else {
        const archivePayload = metadataPayload(
          sourceRecord,
          sourceMotherId,
          eventId,
          now,
        );
        archivePayload.source_deleted_at = now;
        await updatePatient(supabase, existing.id, archivePayload);
        action = 'archived';
      }
    } else {
      const demographicPayload = {
        ...metadataPayload(sourceRecord, sourceMotherId, eventId, now),
        ...demographicFields(sourceRecord),
        source_deleted_at: null,
      };

      if (existing) {
        await updatePatient(supabase, existing.id, demographicPayload);
        patientId = existing.id;
        action = 'updated';
      } else {
        const insertPayload = {
          id: destinationId(sourceMotherId),
          mother_id: preferredText(sourceRecord, ['mother_id', 'patient_id']) ??
            sourceMotherId,
          ...demographicPayload,
        };
        patientId = await insertPatient(supabase, insertPayload);
        action = 'inserted';

        if (!patientId) {
          const conflicted = await findExistingPatient(supabase, sourceMotherId);
          if (!conflicted) {
            throw new Error('Patient mapping was not found after conflict.');
          }
          patientId = conflicted.id;
          if (isStaleSourceVersion(
            conflicted.source_updated_at,
            conflicted.source_deleted_at,
            event,
            sourceRecord,
          )) {
            action = 'stale_after_conflict_noop';
          } else {
            await updatePatient(supabase, conflicted.id, demographicPayload);
            action = 'updated_after_conflict';
          }
        }
      }
    }

    const result: JsonRecord = {
      ok: true,
      event_id: eventId,
      event,
      action,
      source_mother_id: sourceMotherId,
      patient_id: patientId,
      processed_at: now,
    };
    await recordProcessedEvent(
      supabase,
      eventId,
      event,
      sourceMotherId,
      patientId,
      result,
    );
    return jsonResponse(result);
  } catch {
    console.error('[sync-dawa-mom-patient] Synchronization failed.');
    return jsonResponse({
      error: 'Patient synchronization failed.',
      code: 'PATIENT_SYNC_FAILED',
      retryable: true,
    }, 500);
  }
}

if (import.meta.main) {
  serve(handleRequest);
}

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
  if (event === 'PATIENT.UPSERT' || event === 'UPSERT') {
    return 'UPDATE';
  }
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

async function resolveEventId(
  payload: WebhookPayload,
  event: SyncEvent,
  sourceRecord: JsonRecord,
  sourceMotherId: string,
): Promise<string> {
  const provided = optionalText(payload.event_id ?? payload.eventId);
  if (provided) {
    if (!uuidPattern.test(provided)) {
      throw new PayloadError('event_id must be a UUID.');
    }
    return provided.toLowerCase();
  }

  // Compatibility for the pre-outbox database webhook during rolling deploy.
  // The same source row version produces the same UUID and therefore remains
  // idempotent. New outbox calls always provide event_id explicitly.
  const version = preferredText(sourceRecord, [
    'source_updated_at',
    'updated_at',
    'created_at',
  ]) ?? 'unversioned';
  return uuidFromText(`${sourceProject}:${event}:${sourceMotherId}:${version}`);
}

function metadataPayload(
  sourceRecord: JsonRecord,
  sourceMotherId: string,
  eventId: string,
  syncedAt: string,
): JsonRecord {
  return {
    source_project: sourceProject,
    source_mother_id: sourceMotherId,
    source_user_id: preferredText(sourceRecord, [
      'source_user_id',
      'user_id',
      'auth_id',
      'profile_id',
    ]),
    source_event_id: eventId,
    source_updated_at: dateField(sourceRecord, [
      'source_updated_at',
      'updated_at',
    ]) ?? null,
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
  assignIfPresent(fields, 'email', textField(sourceRecord, ['email']));
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

async function findProcessedEvent(
  supabase: SupabaseAdmin,
  eventId: string,
): Promise<JsonRecord | null> {
  const { data, error } = await supabase
    .from('integration_processed_events')
    .select('result')
    .eq('source', sourceProject)
    .eq('event_id', eventId)
    .maybeSingle();
  if (error) throw error;
  return data?.result && isRecord(data.result) ? data.result : null;
}

async function recordProcessedEvent(
  supabase: SupabaseAdmin,
  eventId: string,
  event: SyncEvent,
  sourceMotherId: string,
  patientId: string | null,
  result: JsonRecord,
): Promise<void> {
  const { error } = await supabase.from('integration_processed_events').insert({
    source: sourceProject,
    event_id: eventId,
    event_type: `patient.${event.toLowerCase()}`,
    aggregate_id: sourceMotherId,
    destination_id: patientId,
    result,
  });
  if (error && error.code !== '23505') throw error;
}

async function findExistingPatient(
  supabase: SupabaseAdmin,
  sourceMotherId: string,
): Promise<{
  id: string;
  source_updated_at: string | null;
  source_deleted_at: string | null;
} | null> {
  const { data, error } = await supabase
    .from(destinationTable)
    .select('id,source_updated_at,source_deleted_at')
    .eq('source_project', sourceProject)
    .eq('source_mother_id', sourceMotherId)
    .maybeSingle();
  if (error) throw error;
  return data as {
    id: string;
    source_updated_at: string | null;
    source_deleted_at: string | null;
  } | null;
}

async function insertPatient(
  supabase: SupabaseAdmin,
  payload: JsonRecord,
): Promise<string | null> {
  const { data, error } = await supabase
    .from(destinationTable)
    .insert(payload)
    .select('id')
    .single();
  if (!error) return data.id as string;
  if (error.code === '23505') return null;
  throw error;
}

async function updatePatient(
  supabase: SupabaseAdmin,
  patientId: string,
  payload: JsonRecord,
): Promise<void> {
  const { error } = await supabase
    .from(destinationTable)
    .update(payload)
    .eq('id', patientId);
  if (error) throw error;
}

function assignIfPresent(
  fields: JsonRecord,
  destination: string,
  value: unknown,
): void {
  if (value !== undefined) fields[destination] = value;
}

function isStaleSourceVersion(
  storedValue: string | null,
  sourceDeletedAt: string | null,
  event: SyncEvent,
  sourceRecord: JsonRecord,
): boolean {
  const incomingValue = dateField(sourceRecord, [
    'source_updated_at',
    'updated_at',
  ]);
  if (sourceDeletedAt && event !== 'DELETE' && !incomingValue) return true;
  if (!storedValue || !incomingValue) return false;
  const storedTime = Date.parse(storedValue);
  const incomingTime = Date.parse(incomingValue);
  if (!Number.isFinite(storedTime) || !Number.isFinite(incomingTime)) {
    return false;
  }
  return incomingTime < storedTime ||
    (Boolean(sourceDeletedAt) && event !== 'DELETE' && incomingTime <= storedTime);
}

function textField(
  sourceRecord: JsonRecord,
  keys: string[],
): string | null | undefined {
  const picked = pickValue(sourceRecord, keys);
  if (!picked.found) return undefined;
  return optionalText(picked.value);
}

function dateField(
  sourceRecord: JsonRecord,
  keys: string[],
): string | null | undefined {
  const picked = pickValue(sourceRecord, keys);
  if (!picked.found) return undefined;
  const value = optionalText(picked.value);
  if (!value) return null;
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
  if (value === null || value === undefined) return null;
  const text = String(value).trim();
  return text.length === 0 ? null : text;
}

function requiredUuid(value: unknown): string {
  const text = optionalText(value);
  if (!text || !uuidPattern.test(text)) {
    throw new PayloadError('Source mother ID must be a UUID.');
  }
  return text.toLowerCase();
}

function isRecord(value: unknown): value is JsonRecord {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function destinationId(sourceMotherId: string): string {
  return `dawa_mom_${sourceMotherId.replaceAll('-', '')}`;
}

async function uuidFromText(value: string): Promise<string> {
  const digest = new Uint8Array(
    await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)),
  ).slice(0, 16);
  digest[6] = (digest[6] & 0x0f) | 0x50;
  digest[8] = (digest[8] & 0x3f) | 0x80;
  const hex = [...digest].map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
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
