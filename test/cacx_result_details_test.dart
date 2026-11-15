import 'dart:convert';
import 'package:clinician/application/cacx/cacx_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'edge result preserves class scores, timing, record reference and supplied recommendation',
      () {
    final raw = {
      'classification': 'Normal',
      'confidence': .964,
      'probabilities': {'Normal': .964, 'High Risk': .036},
      'timings_ms': {'inference': 135},
      'record_id': 42,
      'gatekeeper_flagged': false,
      'message': 'Image accepted',
      'recommendation': 'Model-supplied recommendation'
    };
    final parsed = CervicalDeviceService.parseCervitriageResponse(
        200, jsonEncode(raw),
        deviceEndpoint: 'http://dawa.local/upload/cervical');
    final result = parsed.toAnalysisResult('data:image/png;base64,test');
    expect(result.confidence, closeTo(96.4, .01));
    expect(result.predictionBreakdown, hasLength(2));
    expect(result.predictionBreakdown.first.confidence, closeTo(96.4, .01));
    expect(result.rawOutput?['timings_ms'], {'inference': 135});
    expect(result.rawOutput?['record_id'], 42);
    expect(result.recommendation, 'Model-supplied recommendation');
  });
  test('missing class probabilities do not invent a distribution or diagnosis',
      () {
    final parsed = CervicalDeviceService.parseCervitriageResponse(
        200, '{"classification":"Normal","confidence":0.964}',
        deviceEndpoint: 'http://dawa.local/upload/cervical');
    final result = parsed.toAnalysisResult('test');
    expect(result.predictionBreakdown, isEmpty);
    expect(result.confidence, closeTo(96.4, .01));
    expect(result.recommendation, contains('requires clinician review'));
    expect(result.recommendation, isNot(contains('completed the diagnosis')));
  });
}
