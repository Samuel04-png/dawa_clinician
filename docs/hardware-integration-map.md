# Hardware Integration Map

This document maps what the app currently accepts, where it is stored, and what should be added before cervical cancer scanners, ultrasound machines, anemia devices, or other diagnostic hardware communicate with the app.

## Current Architecture

- The Flutter app uses Supabase through a Firestore compatibility facade in `lib/backend/supabase/supabase_firestore_compat.dart`.
- Persisted clinical data is defined in `supabase/migrations/20260507111000_clinician_supabase_schema.sql`.
- Main persisted clinical tables are `mother`, `first_encounter`, `encounter`, `parity`, and `appointments`.
- Cervical cancer and ultrasound modules have richer local/demo models, but those results are mostly not persisted to Supabase yet.
- The app has these deployed/declared edge functions: `send-sms`, `delete-user`, `gemini`, `analyze-via-image`, and `analyze-ultrasound-image`.
- The ultrasound analysis function uses `GEMINI_API_KEY` when configured and returns a clinician-review fallback response when no vision model secret is available.

## Persisted Data The App Accepts Today

### Patient Identity: `mother`

Used for patient registration and linking encounters.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | text | Primary row id. App also later copies this to `mother_id`. |
| `dateOfBirth` | timestamp | Patient date of birth. |
| `occupation` | text | Free text. |
| `address` | text | Free text. |
| `user_Id` | text/ref path | Linked app user. |
| `name` | text | Patient name. |
| `phone_number` | text | Patient contact. |
| `mother_id` | text | App-visible mother id, usually row id. |
| `first_encounter_id` | text/ref path | Links first encounter history. |

### First ANC / History: `first_encounter`

Used for pregnancy history, risk factors, cervical screening history, anemia symptoms, and ANC dates.

| Field | Type | Hardware relevance |
| --- | --- | --- |
| `mother_Id` | text/ref path | Link to patient. |
| `gravidity` | text | Patient history. |
| `parity` | integer | Patient history. |
| `estimated_due_date` | timestamp | Pregnancy dating. |
| `lnmp` | timestamp | Last normal menstrual period. |
| `hiv_status` | text | History/risk context. |
| `last_vl` | text | HIV viral load text. |
| `cd4` | text | CD4 text. |
| `diabetes_mellitus` | text | Risk context. |
| `hypertension` | text | Risk context. |
| `cardiac_disease` | text | Risk context. |
| `epilepsy`, `asthma`, `tb`, `sickle_cell` | text | Risk context. |
| `sign_of_imminent_eclampsia` | text[] | Symptom checklist. |
| `signs_of_anaemia` | text[] | Manual anemia signs. |
| `symptoms_of_uti` | text[] | Manual UTI symptoms. |
| `perceiving_foetal_movement` | text | Manual pregnancy status. |
| `draining_any_liquor` | text | Manual pregnancy status. |
| `cacx` | text | Cervical cancer screening history/result, currently only a text field. |
| `cacx_date_of_screen` | timestamp | Cervical screening date. |
| `menstruation_regular` | text | History. |
| `duration_of_menstruation` | text | History. |
| `age_of_menarche` | text | History. |
| `sti` | text[] | STI checklist. |
| `drugs_taken` | text[] | Medication checklist. |
| `herbs_taken` | text | Free text. |
| `any_allergies` | text | Free text. |
| `side_effect` | text | Free text. |
| `parity_id` | text[]/ref paths | Links parity rows. |
| `anc_dates` | timestamp[] | Planned ANC dates. |

### Visit / Test Results: `encounter`

This is the closest existing table for machine readings collected during a visit.

| Field | Type | Hardware relevance |
| --- | --- | --- |
| `id` | text | Primary row id. |
| `mother_id` | text/ref path | Required to link result to patient. |
| `doctor_id` | text/ref path | Clinician/owner. |
| `clinic_id` | text/ref path | Clinic, currently nullable. |
| `status` | text | Current values include `scheduled` and `completed`. |
| `is_instant` | boolean | True for direct visit entry, false for scheduled appointment. |
| `date` | timestamp | Encounter date or scheduled date. |
| `time` | text | Time string like `Hm`. |
| `performed_by` | text/ref path | Clinician who completed the encounter. |
| `date_performed` | timestamp | Completion time. |
| `bp` | text | Blood pressure, free text like `120/80`. |
| `pulse` | integer | Pulse. |
| `next_visit` | timestamp | Follow-up date. |
| `comment` | text | Free-text notes. |
| `us_obstetrics` | text | Ultrasound/obstetric notes, defined but not written by the main encounter form. |
| `heart_beat` | integer | Fetal heartbeat or heartbeat value. |
| `heart_beat_quality` | text | Categorical quality value. |
| `womb_position` | text | Categorical position value. |
| `estimated_baby_size` | integer | Current app uses integer only. |
| `hemocheck` | integer | Maternal hemoglobin/anemia device can map here today, but unit/precision are missing. |
| `foetal_hemocheck` | integer | Fetal hemocheck value if applicable. |
| `refer_for_anemia` | text | Categorical referral decision. |
| `leucocytes_esterase` | text | Urinalysis. |
| `nitrates` | text | Urinalysis, probably nitrites. |
| `urologobulin` | text | Urinalysis, probably urobilinogen. |
| `protein` | text | Urinalysis. |
| `ph` | text | Urinalysis. |
| `blood` | text | Urinalysis. |
| `ketones` | text | Urinalysis. |
| `bilirubin` | text | Urinalysis. |
| `glucose` | text | Urinalysis. |
| `specific_gravity` | text | Urinalysis. |
| `color` | text | Urinalysis/visual. |
| `clarity` | text | Urinalysis/visual. |
| `odor` | text | Urinalysis/visual. |
| `casts` | text | Urinalysis/microscopy. |

### Parity / Obstetric History: `parity`

Used for prior pregnancy and maternal social/obstetric history. It is not the best target for real-time machine readings.

Key fields: `year_of_birth`, `weight`, `state`, `mode_of_delivery`, `complications`, `marital_status`, `mothers_height`, `prepregnancy_weight`, `mothers_education`, `fathers_age`, `fathers_education`, `kids_alive`, `kids_dead`, `miscarriages`, `birth_number`, `prenatal_care_start`, `expected_prenatal_visits`, cigarette counts, `risk_factors`, delivery and labor fields.

## Service Mapping

### Cervical Cancer Scanner / VIA Device

Current app behavior:

- The CaCx module accepts an image from camera/gallery as a base64 data URL.
- It calls an external Gradio/Hugging Face style API from the client code and converts the model output into:
  - `label`
  - `confidence`
  - `suspicionLevel`
  - `recommendation`
  - `imageUrl`/base64 image
  - optional `rawOutput` and `error`
- Saved CaCx records are currently in local app state as `VIATestRecord`, not in the Supabase clinical schema.
- The only persisted cervical fields today are `first_encounter.cacx` and `first_encounter.cacx_date_of_screen`.

Minimum safe persisted data to add:

- Patient link: `mother_id`.
- Encounter link: `encounter_id`, if the scan happens during a visit.
- Device details: `device_id`, serial number, firmware, model.
- Media: Supabase Storage path, MIME type, checksum, capture timestamp.
- Result: raw class, normalized result, confidence, suspicion/risk level, recommendation, model name/version.
- Human review: reviewer id, review status, reviewed timestamp, comments.
- Raw payload: vendor payload stored in a controlled audit/event table.

### Ultrasound Machine

Current app behavior:

- The ultrasound module accepts image capture/gallery as base64.
- It sends `{ imageBase64, gestationalAgeWeeks }` to a Supabase function named `analyze-ultrasound-image`.
- That edge function is present in `supabase/functions/analyze-ultrasound-image` and can return Gemini-backed structured findings when `GEMINI_API_KEY` is configured.
- Saved ultrasound scan records are currently local app state as `UltrasoundScanRecord`, not persisted to Supabase.
- Existing persisted fields that can partially receive ultrasound results are:
  - `encounter.us_obstetrics`
  - `encounter.heart_beat`
  - `encounter.heart_beat_quality`
  - `encounter.womb_position`
  - `encounter.estimated_baby_size`
  - `first_encounter.estimated_due_date`
  - `first_encounter.lnmp`

Minimum safe persisted data to add:

- Study metadata: study id, accession/idempotency id, device id, probe type, operator, clinic, timestamps.
- Media/files: image, cine loop, DICOM file path if available, thumbnail path, checksum.
- Measurements: BPD, HC, AC, FL, CRL, NT, EFW, AFI, fetal heart rate, gestational age estimate.
- Findings: fetal presentation, placenta position/grade, amniotic fluid, fetal growth, anomalies, urgency level.
- Review workflow: draft/imported/reviewed/amended/rejected.

### Anemia / Hemoglobin Device

Current app fields:

- `encounter.hemocheck` stores an integer maternal value.
- `encounter.foetal_hemocheck` stores an integer fetal value if used.
- `encounter.refer_for_anemia` stores a categorical referral decision.
- `first_encounter.signs_of_anaemia` stores manual signs/symptoms.

Important gap:

- Hemoglobin readings often need decimals and units, for example `10.8 g/dL`. The current `integer` field loses precision and has no unit, method, range, or quality flag.

Minimum safe persisted data to add:

- `value`, `unit`, `method`, `specimen_type`, `reference_range`, `abnormal_flag`, `quality_flag`, `device_id`, `captured_at`.
- Optional derived decision: anemia severity, referral recommendation, clinician confirmation.

### Urinalysis / Dipstick Analyzer

Current `encounter` fields already cover many strip values:

- `leucocytes_esterase`
- `nitrates`
- `urologobulin`
- `protein`
- `ph`
- `blood`
- `ketones`
- `bilirubin`
- `glucose`
- `specific_gravity`
- `color`
- `clarity`
- `odor`
- `casts`

Recommended additions:

- Use a structured observation table for each analyte so values can include unit, scale, abnormal flag, raw device code, and quality control status.
- Keep the current `encounter` columns as a summary for the existing UI.

## Recommended Device Payload Envelope

Hardware should not write directly to clinical tables. It should send a signed payload to a controlled edge function such as `device-ingest`.

```json
{
  "message_id": "device-event-000001",
  "device": {
    "id": "hemonix-01",
    "type": "hemoglobin",
    "manufacturer": "Vendor",
    "model": "Model",
    "serial_number": "SN123",
    "firmware_version": "1.0.0"
  },
  "context": {
    "clinic_id": "clinic/abc",
    "mother_id": "mother/xyz",
    "encounter_id": "encounter/optional",
    "operator_id": "doctor/abc"
  },
  "captured_at": "2026-05-27T08:30:00Z",
  "sent_at": "2026-05-27T08:30:03Z",
  "modality": "hemoglobin",
  "observations": [
    {
      "code": "hemoglobin",
      "display": "Hemoglobin",
      "value": 10.8,
      "unit": "g/dL",
      "abnormal_flag": "low",
      "method": "capillary",
      "quality_flag": "accepted"
    }
  ],
  "files": [],
  "raw_vendor_payload": {},
  "signature": "hmac-or-jwt-proof"
}
```

## Recommended New Tables

Add these before connecting production medical hardware:

### `device`

Registry of trusted devices.

- `id`
- `type`
- `manufacturer`
- `model`
- `serial_number`
- `firmware_version`
- `clinic_id`
- `status`
- `created_at`
- `updated_at`

### `device_ingest_event`

Immutable inbound event log.

- `id`
- `message_id`
- `device_id`
- `mother_id`
- `encounter_id`
- `clinic_id`
- `operator_id`
- `modality`
- `captured_at`
- `received_at`
- `payload`
- `payload_hash`
- `status`
- `error`

### `device_observation`

Normalized machine readings.

- `id`
- `event_id`
- `mother_id`
- `encounter_id`
- `code`
- `display`
- `value_numeric`
- `value_text`
- `unit`
- `abnormal_flag`
- `reference_range`
- `method`
- `confidence`
- `quality_flag`

### `device_media`

Device images, DICOM objects, cine loops, thumbnails, and analysis inputs.

- `id`
- `event_id`
- `mother_id`
- `encounter_id`
- `storage_path`
- `mime_type`
- `media_type`
- `checksum`
- `size_bytes`
- `captured_at`

### `device_result_review`

Clinical review workflow.

- `id`
- `event_id`
- `review_status`
- `reviewed_by`
- `reviewed_at`
- `clinical_note`
- `amended_result`

## Safety Checklist

- Use TLS for all device communication.
- Do not place Supabase service-role keys on hardware or in the mobile app.
- Authenticate each device with short-lived tokens, HMAC signatures, or a gateway certificate.
- Require `message_id` idempotency so duplicate device sends do not create duplicate results.
- Validate patient, clinic, and clinician links before accepting the result.
- Validate result ranges, units, timestamps, MIME types, and file sizes.
- Store raw payloads for audit, but keep the app UI on normalized fields.
- Make AI or machine interpretations "needs review" by default until a clinician confirms them.
- Add row-level security by clinic/device role. Current policies are broad for authenticated users.
- Keep image files in private Supabase Storage buckets with signed URLs.
- Log every imported, reviewed, amended, or rejected machine result.

## Integration Steps

1. Collect the hardware output format for each machine: REST, HL7, FHIR, DICOM, USB serial, Bluetooth, or exported file.
2. Add the device tables above in a new Supabase migration.
3. Build a `device-ingest` Supabase edge function for authentication, validation, deduplication, file upload, and normalized writes.
4. Map each device output to `device_observation` and, where useful for existing screens, copy summary values into `encounter`.
5. Add UI in the app to show imported device results under the patient/encounter and require clinician review.
6. Add tests for malformed payloads, duplicate `message_id`, missing patient links, invalid units, expired credentials, and oversized images.

## Current Gaps To Fix Before Production Hardware

- Cervical cancer scan results are not persisted to Supabase in a structured table.
- Ultrasound scan results are not persisted to Supabase in a structured table.
- `analyze-ultrasound-image` returns analysis results, but production deployments still need a configured vision model secret and clinical validation workflow.
- `encounter.hemocheck` is integer-only and does not store units or decimal precision.
- There is no device registry, device event audit table, media table, or clinician review table.
- Existing row-level security allows any authenticated user to manage core clinical records, so device ingestion needs tighter authorization.
