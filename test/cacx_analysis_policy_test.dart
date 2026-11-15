import 'dart:async';
import 'package:clinician/application/cacx/cacx_analysis_policy.dart';
import 'package:clinician/application/cacx/cacx_device_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final kind in CacxDeviceFailureKind.values) {
    test('automatic fallback classification: ${kind.name}', () {
      final infrastructure = {
        CacxDeviceFailureKind.configuration,
        CacxDeviceFailureKind.browserTransport,
        CacxDeviceFailureKind.network,
        CacxDeviceFailureKind.timeout,
        CacxDeviceFailureKind.modelUnavailable,
        CacxDeviceFailureKind.deviceError,
      }.contains(kind);
      expect(
          cacxAllowsAutomaticFallback(
              enabled: true, deviceStatus: 'failed', failure: kind),
          infrastructure);
      expect(
          cacxAllowsAutomaticFallback(
              enabled: false, deviceStatus: 'failed', failure: kind),
          false);
      for (final status in ['success', 'rejected']) {
        expect(
            cacxAllowsAutomaticFallback(
                enabled: true, deviceStatus: status, failure: kind),
            false);
      }
    });
  }
  test('not-ready/unreachable and timeout permit one online attempt', () {
    for (final status in ['failed', 'timeout', 'unavailable']) {
      expect(cacxAllowsAutomaticFallback(enabled: true, deviceStatus: status),
          true);
    }
  });
  test('attempt lock prevents double submission and releases after failure',
      () async {
    final attempt = CacxAnalysisAttempt();
    final gate = Completer<void>();
    var calls = 0;
    final first = attempt.run(() async {
      calls++;
      await gate.future;
    });
    await attempt.run(() async {
      calls++;
    });
    expect(calls, 1);
    gate.complete();
    await first;
    await expectLater(attempt.run(() async {
      throw StateError('both paths failed');
    }), throwsStateError);
    expect(attempt.running, false);
    await attempt.run(() async {
      calls++;
    });
    expect(calls, 2);
  });
}
