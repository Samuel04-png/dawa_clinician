import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import {
  createClient,
  type SupabaseClient,
} from 'https://esm.sh/@supabase/supabase-js@2.45.4';
import { corsHeaders } from '../_shared/cors.ts';

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const datePattern = /^\d{4}-\d{2}-\d{2}$/;

type JsonRecord = Record<string, unknown>;
type SupabaseAdmin = SupabaseClient<any, 'public', any>;
type DirectoryRequest = {
  action?: unknown;
  clinic_id?: unknown;
  clinician_id?: unknown;
  date?: unknown;
};

type DirectoryRow = {
  id: string;
  display_name: string;
  professional_title?: string | null;
  speciality?: string | null;
  clinic_id: string;
  clinic_name: string;
  profile_image_url?: string | null;
  is_active: boolean;
  is_bookable: boolean;
  start_time?: string | null;
  end_time?: string | null;
  slot_minutes?: number | null;
};

export async function handleRequest(req: Request): Promise<Response> {
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405, { Allow: 'POST' });
  }

  const expectedSecret = Deno.env.get('DAWA_CLINICIAN_DIRECTORY_SECRET') ?? '';
  const providedSecret = req.headers.get('x-dawa-directory-secret') ?? '';
  if (!expectedSecret) {
    return jsonResponse({
      code: 'DIRECTORY_NOT_CONFIGURED',
      error: 'Clinician directory is not configured.',
    }, 500);
  }
  if (!timingSafeEqual(providedSecret, expectedSecret)) {
    return jsonResponse({ error: 'Unauthorized.' }, 401);
  }

  let body: DirectoryRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON payload.' }, 400);
  }

  const action = text(body.action)?.toLowerCase() ?? 'list';
  if (action !== 'list' && action !== 'availability') {
    return jsonResponse({ error: 'Unsupported directory action.' }, 400);
  }

  const clinicId = optionalUuid(body.clinic_id);
  if (body.clinic_id != null && !clinicId) {
    return jsonResponse({ error: 'clinic_id must be a UUID.' }, 400);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({
      code: 'DIRECTORY_NOT_CONFIGURED',
      error: 'Clinician directory is not configured.',
    }, 500);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  try {
    const { data, error } = await supabase.rpc(
      'get_bookable_clinician_directory',
      { p_clinic_integration_id: clinicId },
    );
    if (error) throw error;
    const rows = ((data ?? []) as DirectoryRow[]).map(toPublicClinician);

    if (action === 'list') {
      return jsonResponse({ clinicians: rows });
    }

    const clinicianId = optionalUuid(body.clinician_id);
    const date = text(body.date);
    if (!clinicianId || !date || !datePattern.test(date) || !isValidDate(date)) {
      return jsonResponse({
        error: 'clinician_id and a valid date are required.',
      }, 400);
    }

    const selected = rows.find((row) => row.id === clinicianId);
    if (!selected || (clinicId && selected.clinic_id !== clinicId)) {
      return jsonResponse({ error: 'Clinician is not available for booking.' }, 404);
    }

    const { data: doctor, error: doctorError } = await supabase
      .from('doctor')
      .select('id')
      .eq('integration_id', clinicianId)
      .eq('is_active', true)
      .eq('is_bookable', true)
      .maybeSingle();
    if (doctorError) throw doctorError;
    if (!doctor?.id) {
      return jsonResponse({ error: 'Clinician is not available for booking.' }, 404);
    }

    const bookedStarts = await loadBookedStarts(supabase, doctor.id, date);
    const availability = selected.availability_summary as JsonRecord;
    const startTime = text(availability.start_time) ?? '08:00';
    const endTime = text(availability.end_time) ?? '16:00';
    const slotMinutes = Number(availability.slot_minutes) || 30;
    const slots = buildSlots(date, startTime, endTime, slotMinutes, bookedStarts);

    return jsonResponse({
      clinician_id: clinicianId,
      clinic_id: selected.clinic_id,
      date,
      timezone: 'Africa/Lusaka',
      slots,
    });
  } catch {
    console.error('[list-bookable-clinicians] Directory request failed.');
    return jsonResponse({
      code: 'DIRECTORY_UNAVAILABLE',
      error: 'The clinician directory is temporarily unavailable.',
      retryable: true,
    }, 503);
  }
}

if (import.meta.main) {
  serve(handleRequest);
}

function toPublicClinician(row: DirectoryRow): JsonRecord {
  return {
    id: row.id,
    display_name: row.display_name,
    professional_title: row.professional_title ?? null,
    speciality: row.speciality ?? null,
    clinic_id: row.clinic_id,
    clinic_name: row.clinic_name,
    profile_image_url: row.profile_image_url ?? null,
    is_active: row.is_active,
    is_bookable: row.is_bookable,
    availability_summary: {
      start_time: normalizeTime(row.start_time, '08:00'),
      end_time: normalizeTime(row.end_time, '16:00'),
      slot_minutes: clampSlotMinutes(row.slot_minutes),
    },
  };
}

async function loadBookedStarts(
  supabase: SupabaseAdmin,
  doctorId: string,
  date: string,
): Promise<Set<string>> {
  const [appointmentResult, legacyAppointmentResult, encounterResult] = await Promise.all([
    supabase
      .from('appointments')
      .select('start_time,status')
      .eq('assigned_doctor_id', doctorId)
      .eq('appointment_date', date)
      .in('status', ['pending', 'confirmed', 'rescheduled', 'scheduled']),
    supabase
      .from('appointments')
      .select('time,status,date')
      .eq('source_project', 'clinician')
      .in('doctor_id', [doctorId, `doctor/${doctorId}`])
      .gte('date', `${date}T00:00:00+02:00`)
      .lt('date', `${nextDate(date)}T00:00:00+02:00`),
    supabase
      .from('encounter')
      .select('time,status,date')
      .in('doctor_id', [doctorId, `doctor/${doctorId}`])
      .gte('date', `${date}T00:00:00+02:00`)
      .lt('date', `${nextDate(date)}T00:00:00+02:00`),
  ]);
  if (appointmentResult.error) throw appointmentResult.error;
  if (legacyAppointmentResult.error) throw legacyAppointmentResult.error;
  if (encounterResult.error) throw encounterResult.error;

  const booked = new Set<string>();
  for (const row of appointmentResult.data ?? []) {
    const value = normalizeTime(row.start_time, null);
    if (value) booked.add(value);
  }
  for (const row of legacyAppointmentResult.data ?? []) {
    const status = text(row.status)?.toLowerCase() ?? 'scheduled';
    if (['cancelled', 'canceled', 'declined'].includes(status)) continue;
    const value = normalizeTime(row.time, null);
    if (value) booked.add(value);
  }
  for (const row of encounterResult.data ?? []) {
    const status = text(row.status)?.toLowerCase() ?? 'scheduled';
    if (['cancelled', 'canceled', 'declined'].includes(status)) continue;
    const value = normalizeTime(row.time, null);
    if (value) booked.add(value);
  }
  return booked;
}

function buildSlots(
  date: string,
  startTime: string,
  endTime: string,
  slotMinutes: number,
  bookedStarts: Set<string>,
): JsonRecord[] {
  const start = minutesFromTime(startTime);
  const end = minutesFromTime(endTime);
  if (start == null || end == null || end <= start) return [];

  const now = Date.now();
  const slots: JsonRecord[] = [];
  for (let cursor = start; cursor + slotMinutes <= end; cursor += slotMinutes) {
    const startLabel = timeFromMinutes(cursor);
    const endLabel = timeFromMinutes(cursor + slotMinutes);
    const startsAt = new Date(`${date}T${startLabel}:00+02:00`).getTime();
    slots.push({
      start_time: startLabel,
      end_time: endLabel,
      is_available: startsAt > now && !bookedStarts.has(startLabel),
    });
  }
  return slots;
}

function normalizeTime(value: unknown, fallback: string | null): string | null {
  const raw = text(value);
  if (!raw) return fallback;
  const twentyFour = /^(\d{1,2}):(\d{2})(?::\d{2})?$/.exec(raw);
  if (twentyFour) {
    const hour = Number(twentyFour[1]);
    const minute = Number(twentyFour[2]);
    if (hour <= 23 && minute <= 59) {
      return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
    }
  }

  const twelveHour = /^(\d{1,2})(?::(\d{2}))?\s*(am|pm)$/i.exec(raw);
  if (twelveHour) {
    let hour = Number(twelveHour[1]);
    const minute = Number(twelveHour[2] ?? '0');
    if (hour >= 1 && hour <= 12 && minute <= 59) {
      if (hour === 12) hour = 0;
      if (twelveHour[3].toLowerCase() === 'pm') hour += 12;
      return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
    }
  }
  return fallback;
}

function minutesFromTime(value: string): number | null {
  const normalized = normalizeTime(value, null);
  if (!normalized) return null;
  const [hour, minute] = normalized.split(':').map(Number);
  return hour * 60 + minute;
}

function timeFromMinutes(value: number): string {
  const hour = Math.floor(value / 60);
  const minute = value % 60;
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
}

function clampSlotMinutes(value: unknown): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= 5 && parsed <= 240
    ? Math.round(parsed)
    : 30;
}

function optionalUuid(value: unknown): string | null {
  const candidate = text(value);
  return candidate && uuidPattern.test(candidate) ? candidate.toLowerCase() : null;
}

function text(value: unknown): string | null {
  if (value === null || value === undefined) return null;
  const candidate = String(value).trim();
  return candidate.length === 0 ? null : candidate;
}

function isValidDate(value: string): boolean {
  const parsed = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
}

function nextDate(value: string): string {
  const parsed = new Date(`${value}T00:00:00Z`);
  parsed.setUTCDate(parsed.getUTCDate() + 1);
  return parsed.toISOString().slice(0, 10);
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
        'authorization, x-client-info, apikey, content-type, x-dawa-directory-secret',
      'Content-Type': 'application/json',
      ...extraHeaders,
    },
  });
}
