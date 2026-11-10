import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { corsHeaders } from "../_shared/cors.ts";

type JsonRecord = Record<string, unknown>;
type RiskAlertEvent = {
  event_id?: unknown;
  event_type?: unknown;
  type?: unknown;
  record?: unknown;
  payload?: unknown;
};
type SupabaseAdmin = ReturnType<typeof createClient<any, "public", any>>;

class PayloadError extends Error {}

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const canonicalSeverities = ["low", "moderate", "high", "critical"];
const canonicalStatuses = [
  "open",
  "acknowledged",
  "resolved",
  "dismissed",
  "archived",
];

export async function handleRequest(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405, {
      Allow: "POST",
    });
  }

  // Same shared-secret contract as the existing Dawa Mom receivers.
  const expectedSecret = Deno.env.get("DAWA_CLINICIAN_SYNC_SECRET") ??
    Deno.env.get("DAWA_SYNC_SECRET") ?? "";
  const providedSecret = req.headers.get("x-dawa-sync-secret") ?? "";
  if (!expectedSecret) {
    return jsonResponse({ error: "Sync secret is not configured." }, 500);
  }
  if (!timingSafeEqual(providedSecret, expectedSecret)) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  let body: RiskAlertEvent;
  try {
    body = await req.json() as RiskAlertEvent;
  } catch {
    return jsonResponse({ error: "Invalid JSON payload." }, 400);
  }

  let params: JsonRecord;
  try {
    params = buildRpcParams(body);
  } catch (error) {
    if (error instanceof PayloadError) {
      return jsonResponse({
        code: "INVALID_RISK_ALERT_PAYLOAD",
        error: error.message,
        retryable: false,
      }, 400);
    }
    throw error;
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(
      { error: "Supabase service credentials are missing." },
      500,
    );
  }

  // Service-role client stays server-side; the payload never reaches a client.
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  }) as SupabaseAdmin;

  const { data, error } = await supabase.rpc(
    "apply_dawa_mom_risk_alert",
    params,
  );

  if (error) {
    return mapRpcError(error);
  }

  return jsonResponse(asRecord(data));
}

if (import.meta.main) {
  serve(handleRequest);
}

export function buildRpcParams(body: RiskAlertEvent): JsonRecord {
  const eventId = requiredUuid(body.event_id, "event_id");
  const record = asRecord(body.record ?? body.payload);

  const rawEventType = optionalText(body.event_type)?.toLowerCase() ?? null;
  const rawType = optionalText(body.type)?.toUpperCase() ?? null;
  const eventType = resolveEventType(rawEventType, rawType);
  const isArchive = eventType === "risk_alert.archived";
  const sourceAlertId = requiredUuid(record.source_alert_id, "source_alert_id");
  const sourceMotherId = requiredUuid(
    record.source_mother_id,
    "source_mother_id",
  );

  return {
    p_event_id: eventId,
    p_event_type: eventType,
    p_source_alert_id: sourceAlertId,
    p_source_mother_id: sourceMotherId,
    p_alert_type: boundedText(record.alert_type, 120),
    p_severity: requiredOneOf(
      record.severity,
      canonicalSeverities,
      "severity",
      !isArchive,
    ),
    p_status: normalizedStatus(
      record.status,
      !isArchive,
    ),
    // Source installations predating the title constraint can still emit a
    // null title. Keep those alerts deliverable without changing their source
    // row; the source record remains attached for clinical review.
    p_title: boundedText(record.title, 240) ?? "Clinical risk alert",
    p_summary: boundedText(record.summary, 1000),
    p_details: boundedText(record.details, 4000),
    p_recommendation: boundedText(record.recommendation, 1000),
    p_vital_context: asOptionalRecord(record.vital_context),
    p_provenance: boundedText(record.provenance, 60),
    p_detected_at: optionalTimestamp(record.detected_at, "detected_at"),
    p_acknowledged_at: optionalTimestamp(
      record.acknowledged_at,
      "acknowledged_at",
    ),
    p_resolved_at: optionalTimestamp(record.resolved_at, "resolved_at"),
    p_dismissed_at: optionalTimestamp(record.dismissed_at, "dismissed_at"),
    p_source_created_at: optionalTimestamp(
      record.source_created_at,
      "source_created_at",
    ),
    p_source_updated_at: optionalTimestamp(
      record.source_updated_at,
      "source_updated_at",
    ),
    p_source_deleted_at: optionalTimestamp(
      record.source_deleted_at,
      "source_deleted_at",
    ),
    p_source_record: asOptionalRecord(record.source_record),
  };
}

function resolveEventType(
  rawEventType: string | null,
  rawType: string | null,
): "risk_alert.upsert" | "risk_alert.archived" {
  if (rawEventType !== null) {
    if (
      rawEventType === "risk_alert.upsert" ||
      rawEventType === "risk_alert.archived"
    ) {
      return rawEventType;
    }
    throw new PayloadError("event_type is not supported.");
  }

  if (rawType === null || rawType === "INSERT" || rawType === "UPDATE") {
    return "risk_alert.upsert";
  }
  if (rawType === "DELETE") return "risk_alert.archived";
  throw new PayloadError("type is not supported.");
}

function mapRpcError(error: { code?: string; message?: string }): Response {
  const code = optionalText(error.code) ?? "";
  const message = optionalText(error.message) ?? "";

  if (message.includes("Mapped patient was not found")) {
    // The patient sync may still be in flight, so the sender should retry.
    return jsonResponse({
      code: "PATIENT_NOT_SYNCED",
      error: "The mapped Dawa Clinician patient is not available yet.",
      retryable: true,
    }, 409);
  }

  if (
    message.includes("Unsupported risk alert") ||
    message.includes("Risk alert title is required") ||
    message.includes("Risk alert and source mother identifiers are required")
  ) {
    return jsonResponse({
      code: "INVALID_RISK_ALERT_PAYLOAD",
      error: "The risk alert payload does not satisfy the sync contract.",
      retryable: false,
    }, 400);
  }

  if (
    code === "23505" || message.includes("already used by a clinician record")
  ) {
    return jsonResponse({
      code: "RISK_ALERT_ID_CONFLICT",
      error: "The risk alert identifier is already used by a clinician record.",
      retryable: false,
    }, 409);
  }

  console.error("[sync-dawa-mom-risk-alert] Risk alert delivery failed.");
  return jsonResponse({
    code: "RISK_ALERT_DELIVERY_FAILED",
    error: "The risk alert could not be delivered right now.",
    retryable: true,
  }, 500);
}

function asRecord(value: unknown): JsonRecord {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new PayloadError("Risk alert payload must be an object.");
  }
  return value as JsonRecord;
}

function asOptionalRecord(value: unknown): JsonRecord {
  if (value === null || value === undefined) return {};
  return asRecord(value);
}

function requiredUuid(value: unknown, field: string): string {
  const candidate = optionalText(value);
  if (!candidate || !uuidPattern.test(candidate)) {
    throw new PayloadError(`${field} must be a UUID.`);
  }
  return candidate.toLowerCase();
}

function requiredOneOf(
  value: unknown,
  allowed: string[],
  field: string,
  required: boolean,
): string | null {
  const candidate = optionalText(value)?.toLowerCase() ?? null;
  if (candidate === null) {
    if (required) throw new PayloadError(`${field} is required.`);
    return null;
  }
  if (!allowed.includes(candidate)) {
    throw new PayloadError(`${field} is not supported.`);
  }
  return candidate;
}

function normalizedStatus(value: unknown, required: boolean): string | null {
  const candidate = optionalText(value)?.toLowerCase() ?? null;
  if (candidate === null) {
    if (required) throw new PayloadError("status is required.");
    return null;
  }
  // `unacknowledged` was used by early Mom records for the same state now
  // called `open`. Accept it at the service boundary so replayed legacy
  // outbox events cannot be permanently failed by the destination.
  const normalized = candidate === "unacknowledged" ? "open" : candidate;
  if (!canonicalStatuses.includes(normalized)) {
    throw new PayloadError("status is not supported.");
  }
  return normalized;
}

function optionalText(value: unknown): string | null {
  if (value === null || value === undefined) return null;
  const candidate = String(value).trim();
  return candidate.length === 0 ? null : candidate;
}

function boundedText(value: unknown, maxLength: number): string | null {
  return optionalText(value)?.slice(0, maxLength) ?? null;
}

function optionalTimestamp(value: unknown, field: string): string | null {
  const candidate = optionalText(value);
  if (!candidate) return null;
  const parsed = new Date(candidate);
  if (Number.isNaN(parsed.getTime())) {
    throw new PayloadError(`${field} must be an ISO-8601 timestamp.`);
  }
  return parsed.toISOString();
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
      "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type, x-dawa-sync-secret",
      "Content-Type": "application/json",
      ...extraHeaders,
    },
  });
}
