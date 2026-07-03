# Code Snippets

These snippets are selected developer references. I redacted secrets and kept only the parts that explain the architecture.

## Supabase Client Initialization

**File:** `lib/backend/supabase/supabase_config.dart`

**Purpose:** Connects the app to Supabase and wraps requests with session refresh and timeout behavior.

```dart
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'your_supabase_url',
);

const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'your_supabase_anon_key',
);

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
}

SupabaseClient get supabaseClient => Supabase.instance.client;
```

**Notes:** The real app file contains defaults. Do not copy real keys into docs, issues, screenshots, or public tickets.

## Supabase Request Wrapper

**File:** `lib/backend/supabase/supabase_config.dart`

**Purpose:** Refreshes sessions, times out slow requests, and retries expired JWT requests.

```dart
Future<T> runSupabaseRequest<T>(FutureOr<T> Function() request) async {
  await ensureFreshSupabaseSession();
  try {
    final result = request();
    if (result is Future<T>) {
      return await result.timeout(supabaseRequestTimeout);
    }
    return result as T;
  } on PostgrestException catch (error) {
    if (!_isExpiredJwtError(error)) rethrow;
    await ensureFreshSupabaseSession(forceRefresh: true);
    return await request();
  }
}
```

## Firestore Compatibility Read

**File:** `lib/backend/supabase/supabase_firestore_compat.dart`

**Purpose:** Keeps generated `FirebaseFirestore` calls working while reading Supabase tables.

```dart
final response = await runSupabaseRequest(
  () => supabaseClient
      .from(collectionName)
      .select()
      .eq('id', id)
      .maybeSingle(),
);
```

**Notes:** The class name is `FirebaseFirestore`, but it does not initialize Firebase.

## Auth Login

**File:** `lib/auth/firebase_auth/email_auth.dart`

**Purpose:** Email/password login through Supabase Auth.

```dart
Future<AuthResponse> emailSignInFunc(
  String email,
  String password,
) =>
    supabaseClient.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
```

## Offline Cached Sign-In

**File:** `lib/auth/firebase_auth/firebase_auth_manager.dart`

**Purpose:** Allows cached account access when Supabase is unreachable.

```dart
final supabaseReachable =
    await OfflineConnectivityService.isSupabaseReachable();
if (supabaseReachable) {
  return null;
}

final cached = await OfflineAuthCache.readSessionForEmail(email);
if (cached == null) {
  return null;
}

final offlineUser = ClinicianCachedUser(cached);
emitClinicianAuthUser(offlineUser);
```

## Patient Screening History

**File:** `lib/application/patient_details/patient_details_widget.dart`

**Purpose:** Loads CaCx screening history for the selected patient.

```dart
final response = await runSupabaseRequest(
  () => supabaseClient
      .from('cacx_screening_results')
      .select()
      .eq('patient_id', patientId)
      .order('created_at', ascending: false),
);
```

## CaCx Device URL Config

**File:** `lib/application/cacx/cacx_upload_service.dart`

**Purpose:** Configures the local device/Pi API.

```dart
static const _deviceSpecificBaseUrl = String.fromEnvironment(
  'CERVICAL_DEVICE_BASE_URL',
  defaultValue: '',
);

static String get deviceBaseUrl {
  final cervicalUrl = _deviceSpecificBaseUrl.trim();
  return cervicalUrl.isNotEmpty ? cervicalUrl : PiDeviceConfig.baseUrl;
}
```

## CaCx Multipart Upload

**File:** `lib/application/cacx/cacx_upload_service.dart`

**Purpose:** Sends the cervical image to the local device service.

```dart
final request = http.MultipartRequest(
  'POST',
  Uri.parse(CervicalDeviceConfig.imagePostUrl),
)
  ..fields['patient_id'] = patientId?.trim().isNotEmpty == true
      ? patientId!.trim()
      : 'unassigned'
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

## CaCx Result Save

**File:** `lib/application/cacx/cacx_upload_service.dart`

**Purpose:** Saves the primary device result to Supabase.

```dart
final response = await runSupabaseRequest(
  () => supabaseClient
      .from('cacx_screening_results')
      .insert(payload)
      .select('id')
      .single(),
);
```

## CaCx Pending Queue

**File:** `lib/application/cacx/cacx_upload_service.dart`

**Purpose:** Queues failed inserts locally.

```dart
pending.add({
  'type': 'insert_primary',
  'queued_at': DateTime.now().toUtc().toIso8601String(),
  'payload': payload,
});
```

## Offline Connectivity

**File:** `lib/services/offline_connectivity_service.dart`

**Purpose:** Checks internet, Supabase, and device status.

```dart
static Future<OfflineConnectivitySnapshot> refreshStatus({
  bool checkDevice = false,
}) async {
  final results = await Future.wait<bool>([
    hasInternet(),
    isSupabaseReachable(),
    if (checkDevice) isDeviceReachable() else Future.value(false),
  ]);
  ...
}
```

## Ultrasound Edge Function Call

**File:** `lib/application/ultrasound/services/ultrasound_ai_service.dart`

**Purpose:** Sends ultrasound image data to the Supabase Edge Function.

```dart
final response = await supabaseClient.functions.invoke(
  'analyze-ultrasound-image',
  body: {
    'imageBase64': base64Image,
    'gestationalAgeWeeks': gestationalAgeWeeks,
  },
);
```

## CaCx Language Selector

**File:** `lib/application/cacx/cacx_widget.dart`

**Purpose:** Lets the clinician choose the recommendation language.

```dart
const languages = [
  'English',
  'Nyanja',
  'Bemba',
  'Tonga',
  'Shona',
  'Ndebele',
];
```

## Routing

**File:** `lib/flutter_flow/nav/nav.dart`

**Purpose:** Defines auth-protected app routes.

```dart
FFRoute(
  name: PatientDetailsWidget.routeName,
  path: PatientDetailsWidget.routePath,
  requireAuth: true,
  builder: ...
)
```

## Design Tokens

**File:** `lib/components/dawa_design_system.dart`

**Purpose:** Central source for the refreshed UI colors and shared components.

```dart
class DawaTokens {
  static const brandPrimary = Color(0xFF1E3A8A);
  static const brandPrimaryLight = Color(0xFF3B5FCF);
  static const statusSuccess = Color(0xFF16A34A);
  static const statusWarning = Color(0xFFD97706);
  static const statusDanger = Color(0xFFDC2626);
}
```
