import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import { buildRpcParams, handleRequest } from "./index.ts";

const eventId = "44444444-4444-4444-8444-444444444444";
const alertId = "33333333-3333-4333-8333-333333333333";
const motherId = "22222222-2222-4222-8222-222222222222";

function upsertPayload(): Record<string, unknown> {
  return {
    event_id: eventId,
    event_type: "risk_alert.upsert",
    type: "UPDATE",
    schema: "public",
    table: "clinician_risk_alerts",
    record: {
      source: "dawa_mom",
      source_alert_id: alertId,
      source_mother_id: motherId,
      alert_type: "hypertension",
      severity: "high",
      status: "open",
      title: "Severe hypertension at ANC visit",
      summary: "BP 165/112 with headache.",
      details: "Repeat measurement confirmed.",
      recommendation: "Same-day clinician review.",
      vital_context: { systolic: 165, diastolic: 112 },
      provenance: "dawa_mom",
      detected_at: "2026-09-24T07:00:00.000Z",
      acknowledged_at: null,
      resolved_at: null,
      dismissed_at: null,
      source_created_at: "2026-09-24T07:00:00.000Z",
      source_updated_at: "2026-09-24T07:00:00.000Z",
      source_deleted_at: null,
      source_record: { id: alertId, severity: "high" },
    },
  };
}

Deno.test("buildRpcParams maps an upsert event onto the receiver contract", () => {
  const params = buildRpcParams(upsertPayload());

  assertEquals(params.p_event_id, eventId);
  assertEquals(params.p_event_type, "risk_alert.upsert");
  assertEquals(params.p_source_alert_id, alertId);
  assertEquals(params.p_source_mother_id, motherId);
  assertEquals(params.p_severity, "high");
  assertEquals(params.p_status, "open");
  assertEquals(params.p_title, "Severe hypertension at ANC visit");
  assertEquals(params.p_vital_context, { systolic: 165, diastolic: 112 });
  assertEquals(params.p_detected_at, "2026-09-24T07:00:00.000Z");
  assertEquals(params.p_source_deleted_at, null);
  assertEquals(params.p_source_record, { id: alertId, severity: "high" });
});

Deno.test("buildRpcParams treats a DELETE event as an archive and allows null lifecycle fields", () => {
  const payload = upsertPayload();
  payload.event_type = "risk_alert.archived";
  payload.type = "DELETE";
  const record = payload.record as Record<string, unknown>;
  record.severity = null;
  record.status = null;
  record.source_deleted_at = "2026-09-24T08:00:00.000Z";

  const params = buildRpcParams(payload);

  assertEquals(params.p_event_type, "risk_alert.archived");
  assertEquals(params.p_severity, null);
  assertEquals(params.p_status, null);
  assertEquals(params.p_source_deleted_at, "2026-09-24T08:00:00.000Z");
});

Deno.test("buildRpcParams rejects an out-of-contract severity", () => {
  const payload = upsertPayload();
  (payload.record as Record<string, unknown>).severity = "catastrophic";

  assertThrows(() => buildRpcParams(payload), Error, "not supported");
});

Deno.test("buildRpcParams rejects a missing source alert identifier", () => {
  const payload = upsertPayload();
  delete (payload.record as Record<string, unknown>).source_alert_id;

  assertThrows(
    () => buildRpcParams(payload),
    Error,
    "source_alert_id must be a UUID",
  );
});

Deno.test("buildRpcParams rejects an unknown explicit event type instead of treating it as an upsert", () => {
  const payload = upsertPayload();
  payload.event_type = "risk_alert.deleted";

  assertThrows(
    () => buildRpcParams(payload),
    Error,
    "event_type is not supported",
  );
});

Deno.test("buildRpcParams rejects an invalid timestamp instead of silently dropping it", () => {
  const payload = upsertPayload();
  (payload.record as Record<string, unknown>).source_updated_at =
    "not-a-timestamp";

  assertThrows(
    () => buildRpcParams(payload),
    Error,
    "source_updated_at must be an ISO-8601 timestamp",
  );
});

Deno.test("buildRpcParams preserves compatibility for legacy status and a missing title", () => {
  const payload = upsertPayload();
  const record = payload.record as Record<string, unknown>;
  record.status = "unacknowledged";
  record.title = null;

  const params = buildRpcParams(payload);

  assertEquals(params.p_status, "open");
  assertEquals(params.p_title, "Clinical risk alert");
});

Deno.test("handleRequest rejects non-POST methods", async () => {
  const response = await handleRequest(
    new Request("https://example.test", { method: "GET" }),
  );
  assertEquals(response.status, 405);
});

Deno.test("handleRequest requires the shared secret", async () => {
  Deno.env.set("DAWA_CLINICIAN_SYNC_SECRET", "unit-test-secret");
  const response = await handleRequest(
    new Request("https://example.test", {
      method: "POST",
      body: JSON.stringify(upsertPayload()),
    }),
  );
  assertEquals(response.status, 401);
});

Deno.test("handleRequest returns 400 for an invalid payload before touching the database", async () => {
  Deno.env.set("DAWA_CLINICIAN_SYNC_SECRET", "unit-test-secret");
  const payload = upsertPayload();
  (payload.record as Record<string, unknown>).source_mother_id = "not-a-uuid";

  const response = await handleRequest(
    new Request("https://example.test", {
      method: "POST",
      headers: { "x-dawa-sync-secret": "unit-test-secret" },
      body: JSON.stringify(payload),
    }),
  );
  const body = await response.json() as Record<string, unknown>;

  assertEquals(response.status, 400);
  assertEquals(body.code, "INVALID_RISK_ALERT_PAYLOAD");
  assertEquals(body.retryable, false);
  assert(typeof body.error === "string");
});
