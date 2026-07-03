# Arduino Device Connection

The current code describes and implements a local device service that behaves like a Raspberry Pi or Arduino-connected Flask/API gateway. The Flutter app does not talk to a serial port directly; it talks to an HTTP service on the clinic LAN.

## Confirmed Device URL Config

The app reads device URLs from dart defines:

```dart
static const _deviceSpecificBaseUrl = String.fromEnvironment(
  'CERVICAL_DEVICE_BASE_URL',
  defaultValue: '',
);

static const _baseUrl = String.fromEnvironment(
  'PI_DEVICE_BASE_URL',
  defaultValue: 'http://DAWA.local:8084',
);
```

If `CERVICAL_DEVICE_BASE_URL` is set, CaCx uses it. Otherwise it uses `PI_DEVICE_BASE_URL`.

## Required Device API

The app expects:

```text
GET  /health
POST /upload/cervical
```

`GET /health` should return a successful HTTP response when the device is ready.

`POST /upload/cervical` should accept multipart form data.

## Multipart Request Format

The Flutter app sends:

```text
image: cervical image file
patient_id: patient id or "unassigned"
examination_type: "cervical"
```

The confirmed request code uses `http.MultipartRequest`:

```dart
final request = http.MultipartRequest(
  'POST',
  Uri.parse(CervicalDeviceConfig.imagePostUrl),
)
  ..fields['patient_id'] = patientId ?? 'unassigned'
  ..fields['examination_type'] = 'cervical'
  ..files.add(
    http.MultipartFile.fromBytes(
      'image',
      decoded.bytes,
      filename: 'cervical.${decoded.extension}',
      contentType: MediaType.parse(decoded.mimeType),
    ),
  );
```

## Expected Response

The parser accepts flexible response keys. Any of these can carry the label:

```text
result
label
prediction
class
classification
diagnosis
interpretation
risk
risk_level
status
```

Any of these can carry confidence:

```text
confidence
confidence_percent
probability
score
```

Example response:

```json
{
  "label": "CIN1",
  "confidence": 0.92,
  "risk_level": "borderline"
}
```

## Timeout And Retry Behavior

Confirmed defaults:

| Setting | Default |
| --- | ---: |
| `CERVICAL_IMAGE_TIMEOUT_SECONDS` | 120 |
| `CERVICAL_HEALTH_TIMEOUT_SECONDS` | 5 |
| `CERVICAL_DEVICE_RETRY_INTERVAL_SECONDS` | 5 |

The UI tracks device wait state and can fall back to online scan when online. When offline, online fallback is not used.

## Offline Behavior

When offline:

1. The app checks device reachability.
2. If the device is not connected, it shows an offline-device message.
3. If the device is connected, it sends the image.
4. If the device succeeds, it saves the result locally into the pending CaCx queue.
5. The queued result should sync to Supabase when connectivity returns.

## Known Limitations

- The physical device firmware/API is not in this repository.
- The local service implementation is not included, so Flask/Arduino internals are needs confirmation.
- Web deployments over HTTPS may not be allowed to call HTTP LAN devices.
- CORS must be configured on the device API for Flutter web.
- Device authentication is not confirmed in the current app code.
