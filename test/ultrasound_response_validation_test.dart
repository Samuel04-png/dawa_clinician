import 'package:clinician/application/ultrasound/models/ultrasound_models.dart';
import 'package:clinician/application/ultrasound/services/ultrasound_ai_service.dart';
import 'package:clinician/application/ultrasound/services/ultrasound_edge_service.dart';
import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_exceptions.dart';
import 'package:clinician/services/edge_device/edge_device_manager.dart';
import 'package:clinician/services/edge_device/edge_device_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Ultrasound AI response validation', () {
    test('rejects malformed responses without manufacturing normal findings',
        () {
      final result = UltrasoundAIService.parseResponse('image', {
        'analysisProvider': 'gemini',
        'findings': 'not a list',
        'overallAssessment': 'Normal scan',
        'overallLevel': 'normal',
        'recommendation': 'Routine care',
      });

      expect(result.error, isNotNull);
      expect(result.provider, UltrasoundAnalysisProvider.unavailable);
      expect(result.findings, isEmpty);
      expect(result.overallAssessment, 'Analysis unavailable');
    });

    test('identifies backend no-model responses as unavailable', () {
      final result = UltrasoundAIService.parseResponse('image', {
        'analysisProvider': 'unavailable',
        'findings': const [],
        'overallAssessment': 'Model is not configured.',
        'overallLevel': 'monitor',
        'recommendation': 'Configure a model.',
      });

      expect(result.error, isNotNull);
      expect(result.provider, UltrasoundAnalysisProvider.unavailable);
      expect(result.findings, isEmpty);
    });

    test('accepts a structurally valid cloud response with provenance', () {
      final result = UltrasoundAIService.parseResponse('image', {
        'analysisProvider': 'gemini',
        'findings': [
          {
            'category': 'Image quality',
            'finding': 'Image received',
            'level': 'monitor',
          }
        ],
        'overallAssessment': 'Review image.',
        'overallLevel': 'monitor',
        'recommendation': 'Confirm clinically.',
        'examinationId': 'exam-valid',
        'modelId': 'gemini-ultrasound',
      });

      expect(result.error, isNull);
      expect(result.provider, UltrasoundAnalysisProvider.cloud);
      expect(result.findings, hasLength(1));
    });

    test('rejects cloud responses that also include an error', () {
      final result = UltrasoundAIService.parseResponse('image', {
        'analysisProvider': 'gemini',
        'error': 'The model request failed.',
        'findings': const [],
        'overallAssessment': 'Normal scan',
        'overallLevel': 'normal',
        'recommendation': 'Routine care',
      });

      expect(result.error, 'The model request failed.');
      expect(result.provider, UltrasoundAnalysisProvider.unavailable);
      expect(result.findings, isEmpty);
    });
  });

  test('Ultrasound edge inference blocks until matching readiness exists',
      () async {
    final serviceManager = EdgeDeviceManager(
      client: EdgeDeviceClient(
        config: const EdgeDeviceConfig(baseUrl: 'https://device.local'),
      ),
    );
    final service = UltrasoundEdgeService(deviceManager: serviceManager);
    await expectLater(
      service.analyzeImage(image: 'sample', examinationId: 'exam-1'),
      throwsA(
        isA<EdgeDeviceException>().having(
          (error) => error.failure,
          'failure',
          EdgeDeviceFailure.conflict,
        ),
      ),
    );
    serviceManager.dispose();
  });
}
