import 'dart:async';

import 'package:clinician/application/cacx/cacx_device_failure.dart';
import 'package:clinician/application/cacx/cacx_model.dart';
import 'package:clinician/application/cacx/cacx_upload_service.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selected image bytes determine the multipart image type', () {
    expect(
      ImagePickerService.encodePickedImage([0xff, 0xd8, 0xff, 0]),
      startsWith('data:image/jpeg;base64,'),
    );
    expect(
      ImagePickerService.encodePickedImage(
          [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
      startsWith('data:image/png;base64,'),
    );
    expect(
        () => ImagePickerService.encodePickedImage([]), throwsFormatException);
  });

  group('device configuration diagnostics', () {
    test('rejects the legacy https://dawa.local URL for the real hub', () {
      const config = EdgeDeviceConfig(
        baseUrl: 'https://dawa.local',
        modelManagementEnabled: true,
      );
      expect(config.configurationProblem(), contains('plain HTTP'));
    });

    test('flags a missing build-time URL as a compile-time problem', () {
      const config = EdgeDeviceConfig(
        baseUrl: 'https://dawa.local',
        baseUrlExplicit: false,
        modelManagementEnabled: true,
      );
      expect(config.configurationProblem(), contains('compile-time'));
    });

    test('rejects a base URL that embeds a port', () {
      const config = EdgeDeviceConfig(
        baseUrl: 'http://10.127.36.206:8080',
        modelManagementEnabled: true,
      );
      expect(
          config.configurationProblem(), contains('must not include a port'));
    });

    test('accepts the correct HTTP hub configuration', () {
      const config = EdgeDeviceConfig(
        baseUrl: 'http://10.127.36.206',
        modelManagementEnabled: true,
      );
      expect(config.configurationProblem(), isNull);
      expect(config.hubEndpoint('/api/status').toString(),
          'http://10.127.36.206:8080/api/status');
      expect(
        config.endpoint('/predict', port: config.cervicalPort).toString(),
        'http://10.127.36.206:8085/predict',
      );
    });

    test('an HTTPS web page cannot reach the HTTP device (mixed content)', () {
      const config = EdgeDeviceConfig(
        baseUrl: 'http://10.127.36.206',
        modelManagementEnabled: true,
      );
      expect(
        config.configurationProblem(
          isWeb: true,
          pageUri: Uri.parse('https://app.example.org/'),
        ),
        contains('mixed content'),
      );
      expect(
        config.configurationProblem(
          isWeb: true,
          pageUri: Uri.parse('http://localhost:5000/'),
        ),
        isNull,
      );
    });

    test('legacy mode (management off) is not blocked by the check', () {
      const config = EdgeDeviceConfig(baseUrl: 'https://dawa.local');
      expect(config.configurationProblem(), isNull);
    });

    test('connectivity, select, readiness and inference are separate', () {
      const config = EdgeDeviceConfig(baseUrl: 'http://10.127.36.206');
      expect(config.requestTimeout, const Duration(seconds: 5));
      expect(config.modelRequestTimeout, const Duration(seconds: 30));
      expect(config.modelReadyTimeout, const Duration(seconds: 300));
      expect(config.inferenceTimeout, const Duration(seconds: 120));
    });

    test('diagnostics omit paths, query and credentials', () {
      const config = EdgeDeviceConfig(baseUrl: 'http://10.127.36.206');
      final text = config.diagnosticSummary();
      expect(text, contains('http://10.127.36.206'));
      expect(text, isNot(contains('apikey')));
    });
  });

  group('device failure classification', () {
    CacxDeviceFailureKind kind(Object e, {bool web = false}) =>
        classifyCacxDeviceFailure(e, isWeb: web).kind;

    test('distinguishes the failure classes', () {
      expect(kind(TimeoutException('x')), CacxDeviceFailureKind.timeout);
      expect(
        kind(const CervicalDeviceHttpException(401, '')),
        CacxDeviceFailureKind.unauthorized,
      );
      expect(
        kind(const CervicalDeviceHttpException(409, 'exam_in_progress')),
        CacxDeviceFailureKind.busy,
      );
      expect(
        kind(const CervicalDeviceHttpException(503, '')),
        CacxDeviceFailureKind.modelUnavailable,
      );
      expect(
        kind(const EdgeDeviceException(
          failure: EdgeDeviceFailure.invalidConfiguration,
          message: 'bad',
        )),
        CacxDeviceFailureKind.configuration,
      );
      expect(
        kind(const EdgeDeviceException(
          failure: EdgeDeviceFailure.modelInitialization,
          message: 'model error',
        )),
        CacxDeviceFailureKind.modelUnavailable,
      );
    });

    test('a browser transport failure is named as such, not as a timeout', () {
      const error = EdgeDeviceException(
        failure: EdgeDeviceFailure.connection,
        message: 'ClientException: Failed to fetch',
      );
      expect(kind(error, web: true), CacxDeviceFailureKind.browserTransport);
      expect(kind(error), CacxDeviceFailureKind.network);
    });

    test('exam conflict is a conflict, offering retry rather than a fallback',
        () {
      final failure = classifyCacxDeviceFailure(
        const CervicalDeviceHttpException(409, '{"error":"exam_in_progress"}'),
      );
      expect(failure.isConflict, isTrue);
      expect(failure.message, contains('Another examination'));
    });

    test('messages never echo raw response bodies', () {
      final failure = classifyCacxDeviceFailure(
        const CervicalDeviceHttpException(500, 'patient=Jane Doe secret'),
      );
      expect(failure.message, isNot(contains('Jane')));
      expect(failure.message, isNot(contains('secret')));
    });

    test('RangeError is an application error, not a device failure', () {
      final failure = classifyCacxDeviceFailure(RangeError.index(1, []));
      expect(failure.kind, CacxDeviceFailureKind.application);
      expect(failure.isApplicationError, isTrue);
      expect(failure.message, contains('retained for retry'));
    });

    test('rejected attempts are not stored as successful predictions', () {
      final rejected = CervicalDeviceInterpretation.failure(
        label: 'Image rejected',
        message: 'Test rejection',
        rawResponse: {'gatekeeper_flagged': true},
        deviceStatus: 'rejected',
      );
      expect(
        CacxScreeningResultsRepository.persistedDeviceStatus(rejected),
        'failed',
      );
      expect(rejected.rawResponse['gatekeeper_flagged'], isTrue);
      expect(cacxOutcomeStatus(rejected, saved: true),
          'Image rejected; attempt saved to Supabase');
      expect(cacxOutcomeStatus(rejected, saved: false),
          'Image rejected; attempt not saved to Supabase');
    });

    test('valid result only reports persistence when confirmed', () {
      final result = CervicalDeviceService.parseCervitriageResponse(
        200,
        '{"classification":"Normal","confidence":0.95}',
        deviceEndpoint: 'http://localhost:18085/predict',
      );
      expect(cacxOutcomeStatus(result, saved: false),
          'Inference completed; Supabase save failed');
      expect(cacxOutcomeStatus(result, saved: true),
          'Inference completed and result saved to Supabase');
    });
  });
}
