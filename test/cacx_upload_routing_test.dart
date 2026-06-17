import 'package:clinician/application/cacx/cacx_upload_service.dart';
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
      'http://DAWA.local:8084',
    );
    expect(
      CervicalDeviceConfig.healthUrl,
      'http://DAWA.local:8084/health',
    );
    expect(
      CervicalDeviceConfig.imagePostUrl,
      'http://DAWA.local:8084/upload/cervical',
    );
    expect(CervicalDeviceConfig.timeoutSeconds, 120);
    expect(CervicalDeviceConfig.healthTimeoutSeconds, 5);
    expect(CervicalDeviceConfig.retryIntervalSeconds, 5);
  });
}
