# Raspberry Pi Device Integration

The app can talk to a Raspberry Pi device API over plain HTTP on the clinic LAN.
CaCx already uses this path through `CervicalDeviceService`.

## Configure the Pi URL

Use the shared build flag for the Pi API base URL:

```bash
flutter run --dart-define=PI_DEVICE_BASE_URL=http://DAWA.local:8084
```

CaCx can also override just its own endpoint:

```bash
flutter run --dart-define=CERVICAL_DEVICE_BASE_URL=http://DAWA.local:8084
```

If neither flag is provided, the app defaults to:

```text
http://DAWA.local:8084
```

## Pi API Contract

The app expects the Pi to expose:

```text
GET  /health
POST /upload/cervical
```

`GET /health` should return any `2xx` response when the device is ready.

`POST /upload/cervical` receives multipart form data:

```text
image: uploaded image file
patient_id: patient id or "unassigned"
examination_type: "cervical"
```

The response should be JSON. The parser accepts common names, so any of these
fields can carry the result:

```json
{
  "label": "CIN1",
  "confidence": 0.92,
  "risk_level": "borderline"
}
```

Accepted label keys include `result`, `label`, `prediction`, `classification`,
`diagnosis`, `interpretation`, `risk`, `risk_level`, and `status`.

Accepted confidence keys include `confidence`, `confidence_percent`,
`probability`, and `score`. Values can be `0.92` or `92`.

For other diagnostic modules, use the same base URL and add module upload paths
such as:

```text
POST /upload/ultrasound
POST /upload/hemonix
```

## Platform Notes

Android is configured to allow cleartext HTTP traffic for the Pi API.

iOS is configured for local-network HTTP access and includes a local-network
permission prompt description.

Flutter Web cannot call `http://192.168.x.x` from an `https://` hosted page.
Browsers block that as mixed content. For web builds, use one of these:

- Serve the web app over HTTP on the same LAN.
- Put HTTPS on the Pi with a trusted certificate.
- Use an HTTPS proxy that is reachable by both the browser and the Pi.

The Pi API should also send CORS headers for web builds, for example:

```text
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
```
