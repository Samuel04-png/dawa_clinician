# Current appointment-results flow

This is the pre-implementation baseline for the two independent Flutter and
Supabase applications.

## 1. Dawa Mom appointment booking — Working

`AppointmentRepository.bookAppointment` validates the signed-in mother,
clinician/clinic mapping, fresh slot availability, and duplicates before
inserting a `pending` row into Dawa Mom `public.appointments`. The insert sets
`source = 'dawa_mom'` and `integration_status = 'pending'`.

## 2. Synchronisation to Dawa Clinician — Working

The Dawa Mom `enqueue_dawa_mom_appointment_sync` trigger writes an
`appointment.created` event to `integration_outbox`. The scheduled
`process-dawa-platform-outbox` Edge Function calls the Dawa Clinician
`receive-dawa-mom-appointment` function. Dawa Clinician receives it through an
idempotent SQL function, resolves patient/clinician/clinic mappings, locks the
slot, inserts or deduplicates the local appointment, records the processed
event, and creates an appointment notification.

## 3. Clinician appointment visibility — Working

`ClinicianAppointmentRepository.watchDawaMomAppointments` streams rows from
Dawa Clinician `appointments` where `source_project = 'dawa_mom'`, then
hydrates patient and clinic names. `DawaMomAppointmentRequests` presents those
rows and their notifications.

## 4. Clinician appointment status updates — Working

Confirm, decline, reschedule, cancel, and complete actions call the
`update_dawa_mom_appointment_status` RPC. Assignment and status transitions
are checked in SQL. Rescheduling also re-checks slot conflicts.

## 5. Appointment completion — Broken

The current Complete button directly calls the generic status RPC with
`completed`. No assessment UI is opened, no required clinical data is
validated, and completion is not coupled to an encounter or result summary.

## 6. Clinical encounter creation — Missing from appointment flow

Dawa Clinician already has a legacy `encounter` table and existing encounter
screens with maternal/pregnancy/fetal fields, including blood pressure, pulse,
haemoglobin readings, heartbeat, heartbeat quality, womb position, estimated
baby size, clinical comments, referrals, ultrasound notes, and next visit.
However, synced appointments have no appointment-to-encounter link, and
completing an appointment does not create or complete an encounter.

## 7. Status synchronisation back to Dawa Mom — Working for status only

The clinician status RPC creates an `appointment.status.changed` outbox event.
The scheduled `process-dawa-mom-status-outbox` Edge Function sends it to Dawa
Mom `receive-dawa-clinician-appointment-status`. Dawa Mom applies it through an
idempotent SQL function and stores the processed event. Clinical encounter or
result information is not sent.

## 8. Dawa Mom appointment details — Partially working

The Appointment Details page loads the appointment, shows status, time,
clinician, clinic, reason, booking metadata, and cancellation when permitted.
Its layout is light and width-constrained, but a completed appointment has only
a generic completed message and no assessment result.

## 9. Patient-facing result presentation — Missing

Dawa Mom has a legacy encounter-details UI, but it is not backed by the synced
appointment workflow. Dawa Mom has no appointment-result-summary table/domain
model or receiver path. Therefore a mother cannot open a completed synced
appointment and see the results.

## Pregnancy-state mapping — Partially working

Dawa Mom already models four explicit profile states: `pregnant`,
`not_pregnant`, `not_provided`, and `prefer_not_to_say`, with LNMP/EDD stored
separately. Its current patient-sync payload only sends demographics. Dawa
Clinician consequently infers pregnancy availability from a local
`firstEncounterId`, which collapses several distinct states into the misleading
label “Missing Data.” The screenshots expose this mismatch.

## Overlay error — Broken

Dawa Clinician's `MaterialApp.builder` ignores its routed child and wraps a
manually-created `Router` with `OfflineStatusScope`. The banner is therefore
outside the Router/Navigator Overlay. Its dismiss `IconButton` supplies a
tooltip, and `RawTooltip` fails to find an ancestor Overlay. The root widget
tree must be corrected; suppressing the red screen would not fix the exception.

## Direct answers

- Appointment already links to encounter: **No**.
- Completion currently creates an encounter: **No**.
- Encounter information is sent to Dawa Mom: **No**.
- Dawa Mom already has a synced result-summary model: **No**.
- The apps use separate Supabase projects: **Yes**.
- Current Mom-to-Clinician functions: Dawa Mom
  `process-dawa-platform-outbox`; Dawa Clinician
  `receive-dawa-mom-appointment` and `sync-dawa-mom-patient`.
- Current Clinician-to-Mom functions: Dawa Clinician
  `process-dawa-mom-status-outbox`; Dawa Mom
  `receive-dawa-clinician-appointment-status`.
