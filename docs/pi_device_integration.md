# Raspberry Pi Device Integration

The app can talk to a Raspberry Pi device API over HTTPS on the clinic LAN.
CaCx already uses this path through `CervicalDeviceService`.

## Configure the Pi URL

Use the shared build flag for the Pi API base URL:

```bash
flutter run --dart-define=PI_DEVICE_BASE_URL=https://dawa.local
```

CaCx can also override just its own endpoint:

```bash
flutter run --dart-define=CERVICAL_DEVICE_BASE_URL=https://dawa.local
```

If neither flag is provided, the app defaults to:

```text
https://dawa.local
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

## HTTPS and certificate requirements

The browser controls TLS validation for Flutter Web. The app intentionally has
no trust-all or `badCertificateCallback` path. The Pi deployment must serve:

```text
trusted DAWA local CA
  -> server certificate for dawa.local
```

The server certificate must contain `DNS:dawa.local` in its Subject Alternative
Name extension, and the Pi must serve the complete required chain. Install the
DAWA CA root in the clinician computer's operating system/browser trust store.
Do not use Chrome's ignore-certificate-errors flag or `curl -k` as validation.

This repository does not contain the Pi's nginx, Caddy, Flask, FastAPI, or
certificate configuration. Certificate issuance, installation, and renewal
must be completed on the physical Pi and clinician machines. Reissuing a
certificate for the same hostname does not require an app change.

## Platform Notes

The DAWA service now runs on HTTPS at `https://dawa.local`. Plain HTTP on
port `8084` is no longer used.

Android has a global `network-security-config` that permits cleartext traffic.
It is no longer needed for `dawa.local` (now HTTPS), but it has been left in
place because the DAWA HTTP deployment existed previously and other local LAN
services (for example the ultrasound/HemoNix module paths) may still use HTTP.
Only remove it after confirming no remaining service needs cleartext.

iOS is configured for local-network access and includes a local-network
permission prompt description. For HTTPS this works as-is; iOS trusts the
system CA store, so a self-signed or locally-issued `dawa.local` certificate
that is not trusted by the device will still be rejected (see certificate
notes below). Android similarly verifies HTTPS certificates against the system
trust store by default.

Flutter Web can call `https://dawa.local` only when the page is also served
over HTTPS (no mixed-content blocking). Because `dawa.local` is a `.local`
mDNS name and the certificate may be locally issued/self-signed, a browser may
still reject the connection unless its certificate is trusted by the browser.

## CORS requirements for Flutter Web

The Pi API must allow the deployed Flutter Web origin and the dynamically
allocated localhost origins used during development, such as
`http://localhost:62080`. Keep this list narrow; do not use `*` when upload
authentication or credentials are enabled.

Support `GET`, `POST`, and `OPTIONS`, plus `Content-Type`, `Authorization`, and
the existing device token header if one is configured. Handle preflight
`OPTIONS` requests for `/health` and `/upload/cervical`. `GET /health` must
return a simple 2xx response. Preserve upload authentication and never put a
server secret or Supabase service role key in the Flutter bundle.

## Connectivity behavior

`OfflineConnectivityService` keeps internet/Supabase reachability separate from
the local device health check. Its browser-safe internet probe uses the
CORS-enabled Supabase REST origin rather than `www.gstatic.com/generate_204`;
an HTTP 401 still proves that the network path reached a server. CaCx checks
`https://dawa.local/health` for the local route first. A reachable local device
is used even with no internet. If it is unavailable, the existing Gradio
fallback is used when internet is available; otherwise the existing
offline-device behavior is shown.

For diagnosis, inspect the browser console for hostname resolution, connection
refusal, timeout, TLS certificate, HTTP health, or browser CORS/transport
failures.
