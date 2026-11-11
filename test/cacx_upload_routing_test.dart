import 'dart:io';

import 'package:clinician/application/cacx/cacx_upload_service.dart';
import 'package:clinician/services/offline_connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normal and low-risk device labels do not require second opinion', () {
    for (final label in ['Normal', 'Low Risk', 'Negative', 'Healthy']) {
      expect(
        CacxRiskMapper.requiresSecondOpinion(label),
        isFalse,
        reason: label,
      );
    }
  });

  test(
      'borderline, high-risk, error, and unknown labels require second opinion',
      () {
    for (final label in [
      'Borderline',
      'Suspicious',
      'CIN1',
      'CIN2',
      'CIN3',
      'Cancer',
      'High Risk',
      'Positive',
      'Inconclusive',
      'Error',
      'Unsupported Label',
    ]) {
      expect(
        CacxRiskMapper.requiresSecondOpinion(label),
        isTrue,
        reason: label,
      );
    }
  });

  test('device endpoint defaults match cervical upload configuration', () {
    expect(
      CervicalDeviceConfig.deviceBaseUrl,
      'http://dawa.local',
    );
    expect(
      CervicalDeviceConfig.healthUrl,
      'http://dawa.local/health',
    );
    expect(
      CervicalDeviceConfig.imagePostUrl,
      'http://dawa.local/upload/cervical',
    );
    expect(CervicalDeviceConfig.timeoutSeconds, 455);
    expect(CervicalDeviceConfig.healthTimeoutSeconds, 5);
    expect(CervicalDeviceConfig.retryIntervalSeconds, 5);
  });

  test('CaCx routing prioritizes the local device over internet state', () {
    expect(
      OfflineConnectivityService.cacxRouteFor(
        deviceReachable: true,
        internetAvailable: false,
      ),
      CacxRoutingDecision.localDevice,
    );
    expect(
      OfflineConnectivityService.cacxRouteFor(
        deviceReachable: false,
        internetAvailable: true,
      ),
      CacxRoutingDecision.gradio,
    );
    expect(
      OfflineConnectivityService.cacxRouteFor(
        deviceReachable: false,
        internetAvailable: false,
      ),
      CacxRoutingDecision.offline,
    );
  });

  test(
      'web connectivity does not depend on the CORS-incompatible gstatic probe',
      () {
    final source = File(
      'lib/services/offline_connectivity_service.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('https://www.gstatic.com/generate_204')));
  });
}
