import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '/backend/supabase/supabase_config.dart';
import '/services/edge_device/edge_device_client.dart';
import '/services/edge_device/edge_device_config.dart';
import '/services/edge_device/edge_device_exceptions.dart';
import '/services/edge_device/edge_device_manager.dart';

enum DeviceHealthFailure {
  none,
  timeout,
  hostnameResolution,
  connectionRefused,
  tlsCertificate,
  corsOrBrowserTransport,
  httpFailure,
  unknown,
}

class DeviceHealthResult {
  const DeviceHealthResult({
    required this.reachable,
    required this.failure,
    this.statusCode,
  });

  const DeviceHealthResult.available(int statusCode)
      : this(
          reachable: true,
          failure: DeviceHealthFailure.none,
          statusCode: statusCode,
        );

  final bool reachable;
  final DeviceHealthFailure failure;
  final int? statusCode;
}

enum CacxRoutingDecision { localDevice, gradio, offline }

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

  static CacxRoutingDecision cacxRouteFor({
    required bool deviceReachable,
    required bool internetAvailable,
  }) {
    if (deviceReachable) return CacxRoutingDecision.localDevice;
    if (internetAvailable) return CacxRoutingDecision.gradio;
    return CacxRoutingDecision.offline;
  }

  static const internetTimeout = Duration(seconds: 4);
  static const supabaseTimeout = Duration(seconds: 6);
  static EdgeDeviceClient get _deviceClient => EdgeDeviceManager.shared.client;

  static String get _internetProbeUrl {
    const configured = String.fromEnvironment(
      'INTERNET_CONNECTIVITY_URL',
      defaultValue: '',
    );
    return configured.trim().isNotEmpty
        ? configured.trim()
        : '$supabaseUrl/auth/v1/health';
  }

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
    // Browser fetch cannot read arbitrary cross-origin probes such as
    // gstatic's generate_204 endpoint. Use an application-controlled,
    // CORS-enabled Supabase endpoint instead. Any HTTP response proves that
    // the network path is available, including an authorization response.
    return _httpReachable(
      Uri.parse(_internetProbeUrl),
      timeout: internetTimeout,
      headers: _supabaseHeaders,
    );
  }

  static const _supabaseHeaders = {
    'apikey': supabaseAnonKey,
    'Authorization': 'Bearer $supabaseAnonKey',
  };

  static Future<bool> isSupabaseReachable() async {
    final restUri = Uri.parse('$supabaseUrl/auth/v1/health');
    if (await _httpReachable(
      restUri,
      timeout: supabaseTimeout,
      headers: _supabaseHeaders,
    )) {
      return true;
    }

    // Keep the auth health endpoint as a fallback, but classify a 401 as a
    // reachable server response rather than as a network outage.
    return _httpReachable(
      Uri.parse('$supabaseUrl/auth/v1/health'),
      timeout: supabaseTimeout,
      headers: _supabaseHeaders,
    );
  }

  static Future<bool> isDeviceReachable() async {
    return (await checkDeviceHealth()).reachable;
  }

  static String _healthUri() {
    final config = _deviceClient.config;
    return (config.modelManagementEnabled
            ? config.hubEndpoint(config.hubStatusPath)
            : config.endpoint(config.healthPath))
        .toString();
  }

  static Future<DeviceHealthResult> checkDeviceHealth() async {
    try {
      final statusCode = await _deviceClient.checkHealth();
      debugPrint('[Device] Health check success (HTTP $statusCode): '
          '${_healthUri()}');
      return DeviceHealthResult.available(statusCode);
    } on EdgeDeviceException catch (error) {
      final failure = switch (error.failure) {
        EdgeDeviceFailure.timeout => DeviceHealthFailure.timeout,
        EdgeDeviceFailure.http ||
        EdgeDeviceFailure.unauthorized ||
        EdgeDeviceFailure.unsupported =>
          DeviceHealthFailure.httpFailure,
        _ => _classifyDeviceTransportFailure(error.toString()),
      };
      final uri = Uri.tryParse(_healthUri()) ?? Uri();
      return _deviceFailure(failure, uri, error);
    }
  }

  static DeviceHealthFailure _classifyDeviceTransportFailure(String error) {
    final text = error.toLowerCase();
    if (text.contains('certificate') ||
        text.contains('authority') ||
        text.contains('ssl') ||
        text.contains('tls')) {
      return DeviceHealthFailure.tlsCertificate;
    }
    if (text.contains('cors') || text.contains('failed to fetch')) {
      return DeviceHealthFailure.corsOrBrowserTransport;
    }
    if (text.contains('failed host lookup') ||
        text.contains('name or service not known') ||
        text.contains('nodename')) {
      return DeviceHealthFailure.hostnameResolution;
    }
    if (text.contains('connection refused')) {
      return DeviceHealthFailure.connectionRefused;
    }
    return DeviceHealthFailure.unknown;
  }

  static DeviceHealthResult _deviceFailure(
    DeviceHealthFailure failure,
    Uri uri,
    Object error,
  ) {
    debugPrint('[Device] Health check ${failure.name}: $uri ($error)');
    return DeviceHealthResult(reachable: false, failure: failure);
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
