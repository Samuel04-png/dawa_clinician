# Offline Mode

Offline mode is partially implemented. I have enough confirmed code to say the app supports cached auth identity, cached Supabase query/document reads, visible connectivity status, and a device-only CaCx path when offline.

## What Currently Exists

| Feature | Status | Files |
| --- | --- | --- |
| Supabase reachability check | Done | `lib/services/offline_connectivity_service.dart` |
| Internet probe checks | Done | `lib/services/offline_connectivity_service.dart` |
| Device `/health` check | Done | `lib/services/offline_connectivity_service.dart` |
| Offline banner | Done | `lib/components/offline_status_banner.dart`, `lib/main.dart` |
| Cached Supabase user identity | Partially Done | `lib/services/offline_auth_cache.dart` |
| Offline cached sign-in fallback | Partially Done | `lib/auth/firebase_auth/firebase_auth_manager.dart` |
| Cached query/document rows | Partially Done | `lib/backend/supabase/supabase_offline_cache.dart` |
| CaCx offline device-only flow | Partially Done | `lib/application/cacx/cacx_widget.dart` |
| Pending CaCx result queue | Partially Done | `lib/application/cacx/cacx_upload_service.dart` |

## Intended Offline Behavior

The intended behavior is:

1. A user logs in online once.
2. The app caches that user identity.
3. If Supabase becomes unreachable, the user can continue with cached access.
4. Previously fetched rows can be shown from local cache where available.
5. CaCx can still be used offline if the local Arduino/Raspberry Pi device service is connected.
6. Offline CaCx should not rely on online Hugging Face/Gradio services.
7. Successful offline device results should queue locally and sync to Supabase when connectivity returns.

## Confirmed CaCx Offline Flow

When CaCx starts analysis, it refreshes connectivity. If the app is offline:

- It checks whether the device is reachable.
- If the device is not reachable, it shows an offline-device-unavailable message.
- If the device is reachable, it sends the image to the device.
- If the device succeeds, it queues the primary result locally.
- It opens the results screen with the device interpretation.

## What Is Cached

### Auth

`OfflineAuthCache` stores:

- `uid`
- `email`
- `displayName`
- `photoUrl`
- `phoneNumber`
- `emailVerified`
- `cachedAt`

### Supabase Rows

`SupabaseOfflineCache` stores:

- Query result rows by generated query key.
- Document rows by table and ID.

## What Still Needs Implementation

- Durable sync engine for all writes, not only CaCx pending inserts.
- Conflict handling when the same record is edited offline and online.
- Cache expiry rules.
- Encrypted local storage for sensitive clinical cache.
- A manual sync status screen.
- Offline test coverage with simulated Supabase outage.
- End-to-end testing with the physical device while offline.

## Important Limit

Offline mode should be described as field-support work, not as complete production-grade offline EHR behavior yet.
