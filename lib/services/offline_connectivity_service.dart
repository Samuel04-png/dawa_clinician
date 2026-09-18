import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '/backend/supabase/supabase_config.dart';

class OfflineConnectivitySnapshot {
  const OfflineConnectivitySnapshot({
    required this.internetAvailable,
    required this.supabaseReachable,
    required this.deviceReachable,
    required this.checkedAt,
  });

  final bool internetAvailable;
  final bool supabaseReachable;
  final bool deviceReachable;
  final DateTime checkedAt;

  bool get isOffline => !internetAvailable || !supabaseReachable;

  String get message {
    if (!internetAvailable) {
      return 'Offline mode: no internet connection. Cached data will be used where available.';
    }
    if (!supabaseReachable) {
      return 'Supabase is unreachable. Cached data will be used where available.';
    }
    return 'Online';
  }
}

class OfflineConnectivityService {
  const OfflineConnectivityService._();

  static final ValueNotifier<OfflineConnectivitySnapshot?> statusNotifier =
      ValueNotifier<OfflineConnectivitySnapshot?>(null);

  static const internetTimeout = Duration(seconds: 4);
  static const supabaseTimeout = Duration(seconds: 6);
  static const _deviceSpecificBaseUrl = String.fromEnvironment(
    'CERVICAL_DEVICE_BASE_URL',
    defaultValue: '',
  );
  static const _piDeviceBaseUrl = String.fromEnvironment(
    'PI_DEVICE_BASE_URL',
    defaultValue: 'http://DAWA.local:8084',
  );
  static const _deviceHealthTimeoutSeconds = int.fromEnvironment(
    'CERVICAL_HEALTH_TIMEOUT_SECONDS',
    defaultValue: 5,
  );

  static Future<OfflineConnectivitySnapshot> refreshStatus({
    bool checkDevice = false,
  }) async {
    final results = await Future.wait<bool>([
      hasInternet(),
      isSupabaseReachable(),
      if (checkDevice) isDeviceReachable() else Future.value(false),
    ]);

    final supabaseReachable = results[1];
    final snapshot = OfflineConnectivitySnapshot(
      internetAvailable: results[0] || supabaseReachable,
      supabaseReachable: supabaseReachable,
      deviceReachable: results[2],
      checkedAt: DateTime.now(),
    );
    statusNotifier.value = snapshot;
    return snapshot;
  }

  static Future<bool> hasInternet() async {
    final probes = <Uri>[
      Uri.parse('https://www.gstatic.com/generate_204'),
      Uri.parse('https://cloudflare.com/cdn-cgi/trace'),
    ];

    for (final uri in probes) {
      if (await _httpReachable(uri, timeout: internetTimeout)) {
        return true;
      }
    }
    return false;
  }

  static Future<bool> isSupabaseReachable() async {
    final healthUri = Uri.parse('$supabaseUrl/auth/v1/health');
    if (await _httpReachable(healthUri, timeout: supabaseTimeout)) {
      return true;
    }

    final restUri = Uri.parse('$supabaseUrl/rest/v1/');
    return _httpReachable(
      restUri,
      timeout: supabaseTimeout,
      headers: const {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $supabaseAnonKey',
      },
    );
  }

  static Future<bool> isDeviceReachable() async {
    final baseUrl = _deviceSpecificBaseUrl.trim().isNotEmpty
        ? _deviceSpecificBaseUrl.trim()
        : _piDeviceBaseUrl.trim();
    final normalized = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    return _httpReachable(
      Uri.parse('$normalized/health'),
      timeout: const Duration(seconds: _deviceHealthTimeoutSeconds),
    );
  }

  static Future<bool> _httpReachable(
    Uri uri, {
    required Duration timeout,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http.get(uri, headers: headers).timeout(timeout);
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (error) {
      debugPrint('[Offline] Reachability check failed for $uri: $error');
      return false;
    }
  }
}
