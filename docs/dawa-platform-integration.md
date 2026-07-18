# Dawa Platform Integration

## Scope and boundary

Dawa Clinician (`eatliepvwrviogsnqavu`) and Dawa Mom (`himbfndvsuwiudtzjojh`) are independent Supabase projects. Their Flutter sessions, Auth users, service-role keys and migration histories are never shared. Integration traffic is server-to-server through authenticated Edge Functions.

The production backend rollout was completed on 18 July 2026: integration migrations/functions were deployed, the two Vault-backed workers were scheduled, the Mom patient backfill was completed in gated batches, and source/destination mappings were reconciled.

## Stable identifiers

The Clinician schema keeps its legacy text primary keys. It adds stable public UUID `integration_id` values to `doctor` and `clinic`, and preserves source mappings instead of matching by demographics.

| Record | Stable mapping |
| --- | --- |
| Imported patient | `source_project = 'dawa_mom'` plus unique `source_mother_id` |
| Clinician | Native text `doctor.id` plus public `doctor.integration_id` |
| Clinic | Native text `clinic.id` plus public `clinic.integration_id` |
| Imported appointment | Native text `appointments.id` plus unique Dawa Mom `source_appointment_id` |
| Event | Unique `(source, event_id)` processed-event record |

Names, phone numbers, NRC values and dates of birth may flag a possible duplicate for human review, but are not integration keys.

## Patient upsert and ownership

`sync-dawa-mom-patient` validates the directional secret, source project/table, UUID source ID and event. It replays an existing result for the same event, rejects stale source versions, upserts only approved Mom-owned demographic columns and soft-archives deletions.

It must not overwrite `first_encounter_id`, local Clinician user links, assignments, encounters, notes, diagnoses, screening results or treatment data. Those remain clinician-controlled. The imported-patient mapping is unique, so retries and concurrent conflicts do not create a second destination patient.

The enhanced local create-patient form includes patient ID/NRC/village/clinic fields and duplicate review. Its supporting migration `202607130001_add_patient_registration_identifiers.sql` is versioned but was not applied as part of the verified production integration rollout. Review it independently before any future live `db push`.

## Directory and appointment receiver

`list-bookable-clinicians` returns only active/bookable clinicians with a valid auth and clinic mapping, public booking fields and stable integration UUIDs. Dawa Mom stores a mapped local cache; it never receives Clinician credentials or unrestricted doctor records.

`receive-dawa-mom-appointment` runs transactionally. It validates the patient mapping, clinician/clinic assignment and requested slot, takes an advisory lock, rejects collisions, creates the appointment and assigned-clinician notification once, and returns the native destination mapping. Replaying the same event returns the stored safe result.

## Status, notification and outbox flow

Clinicians see imported requests in the Dawa Mom request view and receive recipient-scoped notifications. Only the assigned clinician can perform permitted transition RPCs. Those RPCs enforce the transition graph, update the schedule/status and enqueue a callback event.

`process-dawa-mom-status-outbox` claims events with recoverable leases and sends safe status/schedule fields to Dawa Mom. Retries keep the original event ID and per-appointment ordering. Completing an outbox row records success or a bounded retry; it does not expose service credentials to Flutter.

## RLS and trust boundaries

- RLS remains enabled on imported appointments, notifications and private integration tables.
- Processed-event and outbox tables grant no direct access to `anon` or `authenticated`.
- Notification reads/mark-read updates are scoped to the authenticated recipient.
- Imported appointment source/mapping fields are server-managed.
- Directory identity fields are guarded against unauthorized client writes/deletes.
- Service-role keys and directional/worker secrets live only in Supabase secrets or Vault.

## Functions and environment names

Integration functions:

- `sync-dawa-mom-patient`
- `list-bookable-clinicians`
- `receive-dawa-mom-appointment`
- `process-dawa-mom-status-outbox`

Required names include `DAWA_CLINICIAN_SYNC_SECRET`, `DAWA_CLINICIAN_DIRECTORY_SECRET`, `DAWA_MOM_STATUS_CALLBACK_URL`, `DAWA_MOM_SYNC_SECRET` and `DAWA_CLINICIAN_WORKER_SECRET`. Supabase supplies the project-local `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`. No values are documented here.

## Deployment and verification

For a new environment: back up both projects; apply/review the Clinician integration migration; verify RLS and legacy data; deploy and test all four Clinician functions; then deploy the Mom integration; validate one patient, directory, appointment, notification and status callback; configure the Vault-backed schedules; finally run the Mom backfill in dry-run, one-record, small-batch and approved remainder stages.

The verified rollout reconciled 19 active imported patients with 19 Mom mappings, with no duplicates or mapping errors. The directory exposed 26 bookable clinicians. Both scheduled workers reported successful live runs. Remaining release checks are Android/iOS compilation and one designated non-production end-to-end UI flow.
