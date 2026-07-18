# Current UI and Appointment Workflow

## Responsive clinician shell

The clinician experience supports desktop navigation and narrower tablet/mobile layouts. Patient lists, clinical tools and quick-access modules have automated overflow/layout coverage. Imported Dawa Mom appointment requests are available without replacing the existing scheduled-encounter workflow.

## Branding and theme

- The application is light-mode only; system/dark preference storage and profile dark-mode controls were removed.
- The transparent `assets/dawa_intro.gif` plays once for approximately 8.3 seconds on Clinician blue (`#1E3A8A`).
- Web and Android startup surfaces use the same brand color before the light application surface.
- Login/navigation logos, clinician avatar and shared no-data illustration use verified transparent assets with `BoxFit.contain`.

## Patient records

Imported Dawa Mom rows retain stable source metadata and remain distinguishable from native Clinician records. The app preserves clinician-owned medical content. The patient list and details pages use light design tokens and responsive card/surface behavior.

The local create-patient modal now validates required details, supports patient ID/NRC/village/clinic fields, checks likely duplicates and offers a reviewed existing-record path. This is separate from automated Dawa Mom source mapping.

## Appointment requests and notifications

The Dawa Mom request view loads imported appointments, shows pending/confirmed/rescheduled/completed/cancelled states and invokes guarded status RPCs. Assigned clinicians receive recipient-scoped notification rows and a badge/deep link. Realtime updates refresh requests and notification state.

Status changes are not direct unrestricted table updates. The server validates assignment and transition, queues the callback and synchronises only patient-safe status/schedule information to the owning Dawa Mom appointment.

## Known UI limitations

Real-device screenshots, accessibility review and landscape QA remain release checks. HemoNix/CT quick-access and some ultrasound data remain mock/local where documented; the cross-project appointment integration does not make those modules production-persistent.
