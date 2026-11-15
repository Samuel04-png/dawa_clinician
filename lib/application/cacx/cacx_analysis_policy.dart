import 'cacx_device_failure.dart';

abstract final class CacxAnalysisConfig {
  static const allowOnlineFallback =
      bool.fromEnvironment('ALLOW_CACX_ONLINE_FALLBACK', defaultValue: true);
}

/// Only infrastructure failures permit a different provider. Completed
/// classifications and image/authorization/application errors end the attempt.
bool cacxAllowsAutomaticFallback({
  required bool enabled,
  required String deviceStatus,
  CacxDeviceFailureKind? failure,
}) {
  if (!enabled || deviceStatus == 'success' || deviceStatus == 'rejected')
    return false;
  if (failure == null)
    return deviceStatus == 'failed' ||
        deviceStatus == 'timeout' ||
        deviceStatus == 'unavailable';
  return {
    CacxDeviceFailureKind.configuration,
    CacxDeviceFailureKind.browserTransport,
    CacxDeviceFailureKind.network,
    CacxDeviceFailureKind.timeout,
    CacxDeviceFailureKind.modelUnavailable,
    CacxDeviceFailureKind.deviceError,
  }.contains(failure);
}

/// Acquired synchronously before any await; also covers persistence and online
/// requests so double taps cannot create parallel analyses.
class CacxAnalysisAttempt {
  bool _running = false;
  bool get running => _running;
  Future<void> run(Future<void> Function() action) async {
    if (_running) return;
    _running = true;
    try {
      await action();
    } finally {
      _running = false;
    }
  }
}
