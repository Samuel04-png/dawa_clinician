# Patient Management

Patient management currently uses both the original maternal-record screens and a newer patient details page optimized for screening history.

## Patient List

The patient list lives in `lib/application/moms/moms_widget.dart`.

Confirmed behavior:

- Uses `MotherRecord.collection.orderBy('mother_id')`.
- Supports desktop sidebar and mobile drawer/bottom navigation.
- Includes search/filter state.
- Includes a create-patient floating action button.
- Uses FlutterFlow paging patterns and Supabase-backed record queries.

## Create Patient Flow

The app has a full create mother/patient form in `lib/application/create_mom/create_mom_widget.dart` and a modal entry point in `lib/application/create_mom/create_patient_modal_widget.dart`.

Confirmed behavior:

- Creates or updates `UserRecord` and `MotherRecord` data.
- Can generate a mother account email when email/password fields are left blank.
- Writes patient details such as name, date of birth, occupation, phone, and address.

Needs review:

- The account creation flow can log out the current user to create a mother account. That behavior should be reviewed for clinic workflow and auth safety.

## New Patient Details Page

The newer screen is `lib/application/patient_details/patient_details_widget.dart`.

Confirmed behavior:

- Loads the selected `MotherRecord`.
- Shows profile details and quick actions.
- Computes a patient identifier from `mother_id` or the row reference ID.
- Loads screening history from `public.cacx_screening_results`.
- Shows latest screening, risk summary, screening history, and detail modal.
- Opens CaCx with the patient already selected.

Core query:

```dart
supabaseClient
    .from('cacx_screening_results')
    .select()
    .eq('patient_id', patientId)
    .order('created_at', ascending: false);
```

## Add Screening Flow

From patient details:

1. The app builds a CaCx `Patient` object from the `MotherRecord`.
2. It opens `CaCxApp` with `initialPatient`.
3. `autoStartScreening` starts the scan flow.
4. `returnToPreviousOnSave` returns to the patient details page after saving.
5. The page increments `_historyRefreshKey` to reload screening history.

## Legacy Maternal Record

`lib/application/mom_details` and `lib/application/mom_details2` remain important. They handle:

- Pregnancy history.
- First encounter creation.
- Parity rows.
- ANC and maternal risk fields.
- Encounter list and encounter detail routing.
- Add encounter flow.

These screens are large generated files and should be regression tested carefully after changes.

## Known Issues

- There are two patient detail experiences, which can confuse new developers.
- CaCx history uses `patient_id` text matching, so patient ID consistency matters.
- The patient details page depends on `cacx_screening_results`; if that table is missing in a target Supabase project, history loading fails.
- Some legacy screens still use generated naming and very large widget files.
