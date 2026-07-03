# CaCx Analysis

The CaCx module is one of the most developed parts of the app. It combines image selection, local device analysis, online second opinion, clinical recommendation UI, Supabase result storage, and offline behavior.

## Main Files

| File | Purpose |
| --- | --- |
| `lib/application/cacx/cacx_widget.dart` | Main CaCx UI and flow orchestration. |
| `lib/application/cacx/cacx_model.dart` | CaCx data models, prediction parsing helpers, image picker, and legacy Gradio service code. |
| `lib/application/cacx/cacx_upload_service.dart` | Device API config, multipart upload, risk mapping, and Supabase result repository. |
| `supabase/migrations/20260602120000_add_cacx_screening_results.sql` | Structured CaCx result table and RLS policies. |
| `test/cacx_upload_routing_test.dart` | Device URL and second-opinion routing tests. |
| `test/cacx_prediction_breakdown_test.dart` | Confidence normalization and duplicate label merge tests. |

## Image Selection

The app supports gallery and camera image selection through `image_picker`. Images are read as bytes and converted into base64 data URLs.

```dart
final XFile? image = await _picker.pickImage(
  source: ImageSource.gallery,
  imageQuality: 85,
  maxWidth: 1024,
  maxHeight: 1024,
);
```

## Online/Offline Decision

Before analysis, the app checks connectivity:

```dart
final connectivity = await OfflineConnectivityService.refreshStatus();
if (connectivity.isOffline) {
  await _analyzeImageOfflineOnly(...);
  return;
}
```

When online, the app attempts the device and can use online second opinion. When offline, it only uses the local device path.

## Primary Device Analysis

The primary route sends the image to the configured device service:

```dart
final result = await CervicalDeviceService.analyzeImage(
  image,
  patientId,
  timeout: remaining,
);
```

The device response is parsed into:

- `label`
- `confidence`
- `rawResponse`
- `riskLevel`
- `deviceStatus`
- `deviceEndpoint`
- optional `error`

## Risk Mapping

Confirmed labels include:

- Normal, negative, healthy -> `normal`
- Low risk -> `low`
- Borderline, suspicious, CIN1, inconclusive -> `borderline`
- CIN2, CIN3, cancer, high risk, positive -> `high`

The app requires a second opinion for anything outside normal/low risk, and also for device failures.

## Supabase Save

Primary results are inserted into `cacx_screening_results`:

```dart
await supabaseClient
    .from('cacx_screening_results')
    .insert(payload)
    .select('id')
    .single();
```

If saving fails, the payload is queued locally under `dawa_pending_cacx_screenings_v1`.

## Online Second Opinion

The active online second-opinion path in `cacx_widget.dart` calls a Hugging Face/Gradio Space at:

```text
https://kmunzwa-medsiglip-demo.hf.space
```

The app uploads the image, calls prediction, polls the result, parses response data, and updates the second-opinion fields in Supabase when a record ID exists.

## Result UI

The result screen includes:

- Image preview.
- Diagnosis.
- Risk level.
- Confidence percentage.
- Prediction breakdown.
- Primary device summary.
- Second-opinion summary.
- Recommendation card.
- Language selector.
- Save and share actions.
- Clinical disclaimer.

## Known Issues

- The online AI endpoint is a hardcoded external Space and needs production reliability review.
- `analyze-via-image` Edge Function exists but the active client flow uses direct Gradio calls.
- Actual screenshot evidence is missing.
- Clinical recommendation text needs clinical governance review.
- Supabase table must exist in the target project or patient history and saves will fail.
