# Cervical details and anemia patient-access diagnosis — 2026-11-14

A read-only query against the linked database confirmed 45 non-deleted patient
records, zero anemia clinician memberships and zero anemia patient assignments.
`list_anemia_patients` joins those assignment tables; an empty list is therefore
expected both online and from the downloaded snapshot. Granting access requires
the intended clinician, clinic and patient scope. No access grants or database
policy changes were made. The user has been asked to specify that scope.

The anemia screen now distinguishes unavailable offline downloads from empty
online assignments and explains how assignment setup relates to offline use.
It continues to use server-authorized anemia assignments rather than substituting
a general patient list.

Cervical result conversion now carries edge class probabilities into the UI and
retains the original online response. Existing returned recommendations are used
when supplied; the default device text describes AI screening requiring clinical
review instead of declaring a diagnosis complete. The result screen adds patient
context, database/local persistence status and separate device/online output
sections. Returned model messages, image suitability, record references, model
identity/version, findings and timings are shown when supplied. Missing class
breakdowns no longer imply that the returned top confidence score is unavailable.
Queued records show a pending-sync label, and source text/class labels can wrap.
No missing model measurements, probabilities or findings are fabricated.

Validation includes edge result preservation, missing-data handling, original
online-response retention, and result details on 390px and 1440px screens, alongside
existing cervical/anemia/offline regression tests. The read-only database check
is live; scan-device and model tests use controlled fixtures.

## Access provisioned after user clarification

The user explicitly requested all patients and all clinician accounts. Executed
`supabase/admin/enable_anemia_all_clinicians.sql` against the linked database:
34 existing active clinician accounts, 45 patient records, 1,530 assignments.
Dawa Mom was the sole configured clinic; the six clinicians without a directory
clinic link received an explicit anemia membership there. Auth-only accounts
without an active clinician profile were excluded.

The transaction checked `list_anemia_patients()` under each clinician's JWT subject
and asserted the expected count before committing. Every account returned 44
named, non-deleted patients. The remaining patient has no name and is excluded by
the existing patient-list RPC. Existing RLS and review validation are unchanged.
Previously downloaded empty lists require an online refresh before offline use.
The admin script is idempotent and can be rerun for additional approved accounts;
this provisioning covers the existing accounts rather than adding automatic
membership for arbitrary future signups.
