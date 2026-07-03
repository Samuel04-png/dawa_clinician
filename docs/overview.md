# Overview

Dawa Clinician is built around the daily work of a clinician: finding a patient, reviewing clinical history, recording encounters, launching screening tools, interpreting results, and saving enough structured data for follow-up.

The main problem I am solving is that screening and maternal-health data often live in separate places: paper forms, device apps, AI demos, Firebase records, and one-off files. This project brings those workflows closer together inside a single Flutter app backed by Supabase.

## Main Workflows

1. A clinician signs in.
2. The app resolves the clinician profile through the Supabase-backed `user` and `doctor` records.
3. The clinician opens the home dashboard, patient list, care tools, or scheduled encounters.
4. The clinician opens a patient record.
5. From the newer patient details page, the clinician can start a CaCx screening with that patient already selected.
6. The CaCx flow accepts a camera/gallery image, tries the configured local device service, saves the primary result, and uses online AI as a second opinion when needed.
7. Screening history is shown back on the patient details page from `public.cacx_screening_results`.

## What Has Been Built

- Supabase initialization and request timeout handling.
- Supabase Auth sign-in, sign-up, reset password, OAuth, OTP, and delete-user function calls.
- A Firestore-shaped compatibility layer that keeps existing FlutterFlow generated calls working while reading and writing Supabase tables.
- A schema migration for the core clinical tables.
- Migration tools for Firebase Auth and Firestore data.
- A structured `cacx_screening_results` migration.
- CaCx primary device upload, online second opinion, pending local queue, and patient-linked result history.
- Offline auth cache, document/query cache, connectivity banner, and Supabase reachability checks.
- Brand refresh and responsive UI upgrades.
- Ultrasound and BP Monitor care tools.
- Tests for app smoke, quick-access pages, responsive layouts, CaCx routing, and prediction parsing.

## Still In Progress

- Confirming all migrations are applied to the live Supabase project.
- Tightening RLS policies around clinic, clinician, patient, and device access.
- Replacing mock/local feature state where production persistence is needed.
- Capturing real app screenshots for GitBook.
- Validating clinical recommendations and translations with qualified reviewers.
- End-to-end testing with the actual Arduino/Raspberry Pi device service.
