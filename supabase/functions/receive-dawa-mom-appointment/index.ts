import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
import { corsHeaders } from '../_shared/cors.ts';

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const datePattern = /^\d{4}-\d{2}-\d{2}$/;
const timePattern = /^([01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$/;

type JsonRecord = Record<string, unknown>;
type AppointmentEvent = {
  event_id?: unknown;
  event_type?: unknown;
  record?: unknown;
  payload?: unknown;
};

class PayloadError extends Error {}

export async function handleRequest(req: Request): Promise<Response> {
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405, { Allow: 'POST' });
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

  let eventId: string;
  let eventType: string;
  let record: JsonRecord;
  try {
    const body = await req.json() as AppointmentEvent;
    eventId = requiredUuid(body.event_id, 'event_id');
    eventType = requiredText(body.event_type).toLowerCase();
    record = asRecord(body.record ?? body.payload);
    if (eventType !== 'appointment.created' && eventType !== 'appointment.cancelled') {
      throw new PayloadError('Unsupported appointment event type.');
    }
  } catch (error) {
    return jsonResponse({
      error: error instanceof PayloadError ? error.message : 'Invalid JSON payload.',
    }, 400);
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
    if (eventType === 'appointment.cancelled') {
      const sourceAppointmentId = requiredUuid(
        record.source_appointment_id,
        'source_appointment_id',
      );
      const { data, error } = await supabase.rpc('cancel_dawa_mom_appointment', {
        p_event_id: eventId,
        p_source_appointment_id: sourceAppointmentId,
        p_effective_at: optionalTimestamp(record.updated_at),
      });
      if (error) throw error;
      return jsonResponse(asRecord(data));
    }

    const sourceAppointmentId = requiredUuid(
      record.source_appointment_id,
      'source_appointment_id',
    );
    const sourceMotherId = requiredUuid(record.source_mother_id, 'source_mother_id');
    const clinicianId = requiredUuid(
      record.dawa_clinician_clinician_id,
      'dawa_clinician_clinician_id',
    );
    const clinicId = requiredUuid(
      record.dawa_clinician_clinic_id,
      'dawa_clinician_clinic_id',
    );
    const appointmentDate = requiredDate(record.appointment_date);
    const startTime = requiredTime(record.start_time, 'start_time');
    const endTime = requiredTime(record.end_time, 'end_time');

    const { data, error } = await supabase.rpc('receive_dawa_mom_appointment', {
      p_event_id: eventId,
      p_source_appointment_id: sourceAppointmentId,
      p_source_mother_id: sourceMotherId,
      p_patient_id: optionalText(record.dawa_clinician_patient_id),
      p_clinician_integration_id: clinicianId,
      p_clinic_integration_id: clinicId,
      p_appointment_date: appointmentDate,
      p_start_time: startTime,
      p_end_time: endTime,
      p_appointment_type: optionalText(record.appointment_type) ?? 'maternal_health',
      p_reason: boundedText(record.reason, 1000),
      p_notes: boundedText(record.notes, 2000),
      p_source_created_at: optionalTimestamp(record.created_at),
      p_source_updated_at: optionalTimestamp(record.updated_at),
    });
    if (error) throw error;
    return jsonResponse(asRecord(data));
  } catch (error) {
    if (error instanceof PayloadError) {
      return jsonResponse({ error: error.message }, 400);
    }
    const code = isPostgrestError(error) ? error.code : null;
    if (code === '23P01') {
      return jsonResponse({
        code: 'SLOT_UNAVAILABLE',
        error: 'That appointment time is no longer available.',
        retryable: false,
      }, 409);
    }
    if (code === 'P0002') {
      if (eventType === 'appointment.cancelled') {
        return jsonResponse({
          code: 'APPOINTMENT_NOT_READY',
          error: 'The appointment mapping is not ready yet.',
          retryable: true,
        }, 409);
      }
      return jsonResponse({
        code: 'PATIENT_NOT_SYNCED',
        error: 'The patient mapping is not ready yet.',
        retryable: true,
      }, 409);
    }
    if (code === '23514' || code === '22023') {
      return jsonResponse({
        code: 'APPOINTMENT_INVALID',
        error: 'The clinician, clinic, or appointment time is no longer valid.',
        retryable: false,
      }, 409);
    }
    console.error('[receive-dawa-mom-appointment] Appointment delivery failed.');
    return jsonResponse({
      code: 'APPOINTMENT_DELIVERY_FAILED',
      error: 'The appointment could not be delivered right now.',
      retryable: true,
    }, 500);
  }
}

if (import.meta.main) {
  serve(handleRequest);
}

function asRecord(value: unknown): JsonRecord {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new PayloadError('Appointment payload must be an object.');
  }
  return value as JsonRecord;
}

function requiredUuid(value: unknown, field: string): string {
  const candidate = requiredText(value);
  if (!uuidPattern.test(candidate)) {
    throw new PayloadError(`${field} must be a UUID.`);
  }
  return candidate.toLowerCase();
}

function requiredDate(value: unknown): string {
  const candidate = requiredText(value);
  const parsed = new Date(`${candidate}T00:00:00Z`);
  if (
    !datePattern.test(candidate) || Number.isNaN(parsed.getTime()) ||
    parsed.toISOString().slice(0, 10) !== candidate
  ) {
    throw new PayloadError('appointment_date must be a valid date.');
  }
  return candidate;
}

function requiredTime(value: unknown, field: string): string {
  const candidate = requiredText(value);
  if (!timePattern.test(candidate)) {
    throw new PayloadError(`${field} must be a valid 24-hour time.`);
  }
  return candidate.slice(0, 5);
}

function requiredText(value: unknown): string {
  const candidate = optionalText(value);
  if (!candidate) throw new PayloadError('A required field is missing.');
  return candidate;
}

function optionalText(value: unknown): string | null {
  if (value === null || value === undefined) return null;
  const candidate = String(value).trim();
  return candidate.length === 0 ? null : candidate;
}

function boundedText(value: unknown, maxLength: number): string | null {
  return optionalText(value)?.slice(0, maxLength) ?? null;
}

function optionalTimestamp(value: unknown): string | null {
  const candidate = optionalText(value);
  if (!candidate) return null;
  const parsed = new Date(candidate);
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
}

function isPostgrestError(value: unknown): value is { code: string } {
  return typeof value === 'object' && value !== null &&
    typeof (value as { code?: unknown }).code === 'string';
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
