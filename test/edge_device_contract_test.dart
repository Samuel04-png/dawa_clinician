import 'package:clinician/application/cacx/cacx_upload_service.dart';
import 'package:clinician/application/ultrasound/models/ultrasound_models.dart';
import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_exceptions.dart';
import 'package:clinician/services/edge_device/edge_device_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Payload shapes below are copied from the supplied device source
// (dawa/main.py, cervitriage/main.py, ultrasound/main.py).
void main() {
  group('EdgeDeviceConfig', () {
    test('rejects invalid URLs and URLs containing embedded credentials', () {
      for (final url in [
        'not a url',
        'file:///tmp/device',
        'https://device.local?token=secret',
        'https://device.local/#fragment',
        'https://user:pw@device.local',
      ]) {
        expect(
          () => EdgeDeviceConfig(baseUrl: url).endpoint('/health'),
          throwsFormatException,
          reason: url,
        );
      }
    });

    test('keeps a base path for legacy endpoints', () {
      final config = EdgeDeviceConfig(baseUrl: 'http://device.local/edge/');
      expect(
        config.endpoint('/upload/cervical').toString(),
        'http://device.local/edge/upload/cervical',
      );
    });

    test('maps hub and module ports from the device configuration', () {
      final config = EdgeDeviceConfig(baseUrl: 'http://dawa.local');
      expect(config.hubEndpoint('/api/select').toString(),
          'http://dawa.local:8080/api/select');
      expect(
        config
            .moduleEndpoint(EdgeAIModel.cervicalCancer, '/predict')
            .toString(),
        'http://dawa.local:8085/predict',
      );
      expect(
        config.moduleEndpoint(EdgeAIModel.ultrasound, '/predict').toString(),
        'http://dawa.local:8086/predict',
      );
      expect(config.modelId(EdgeAIModel.cervicalCancer), 'cervitriage');
      expect(config.modelId(EdgeAIModel.ultrasound), 'ultrasound');
      expect(config.modelManagementEnabled, isFalse);
      expect(config.ultrasoundInferenceEnabled, isFalse);
    });
  });

  group('EdgeDeviceClient', () {
    test('hub reachability checks status even when no module is selected',
        () async {
      final requests = <Uri>[];
      final client = EdgeDeviceClient(
        config: const EdgeDeviceConfig(
          baseUrl: 'http://localhost',
          modelManagementEnabled: true,
        ),
        httpClient: MockClient((request) async {
          requests.add(request.url);
          return http.Response('{"active":null,"state":"stopped"}', 200);
        }),
      );
      expect(await client.checkHealth(), 200);
      expect(requests.single.toString(), 'http://localhost:8080/api/status');
    });

    test('device APIs are disabled by default', () async {
      var calls = 0;
      final client = EdgeDeviceClient(
        config: const EdgeDeviceConfig(baseUrl: 'http://device.local'),
        httpClient: MockClient((_) async {
          calls += 1;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        client.getHubStatus(),
        throwsA(_failure(EdgeDeviceFailure.disabled)),
      );
      await expectLater(
        client.selectModel(EdgeAIModel.ultrasound),
        throwsA(_failure(EdgeDeviceFailure.disabled)),
      );
      await expectLater(
        client.predictUltrasound(
          imageBytes: const [1],
          filename: 'x.jpg',
          mimeType: 'image/jpeg',
        ),
        throwsA(_failure(EdgeDeviceFailure.disabled)),
      );
      expect(calls, 0);
    });

    test('rejects non-positive pixel spacing and malformed boxes', () async {
      final client = EdgeDeviceClient(
        config: const EdgeDeviceConfig(
          baseUrl: 'http://device.local',
          modelManagementEnabled: true,
          ultrasoundInferenceEnabled: true,
        ),
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      for (final spacing in [0.0, -1.0, double.nan]) {
        await expectLater(
          client.predictUltrasound(
            imageBytes: const [1],
            filename: 'x.jpg',
            mimeType: 'image/jpeg',
            pixelSpacingMm: spacing,
          ),
          throwsA(_failure(EdgeDeviceFailure.invalidConfiguration)),
        );
      }
      await expectLater(
        client.predictUltrasound(
          imageBytes: const [1],
          filename: 'x.jpg',
          mimeType: 'image/jpeg',
          box: const [1, 2, 3],
        ),
        throwsA(_failure(EdgeDeviceFailure.invalidConfiguration)),
      );
    });

    test('module health HTTP 200 is not model readiness', () async {
      final client = EdgeDeviceClient(
        config: const EdgeDeviceConfig(
          baseUrl: 'http://device.local',
          modelManagementEnabled: true,
        ),
        httpClient: MockClient((request) async {
          if (request.url.port == 8086) {
            return http.Response(
              '{"status":"waiting_for_model","ready":false,"mode":"sam_two_stage","message":"Waiting for the model files: storage/ultrasam_encoder.onnx"}',
              200,
            );
          }
          return http.Response(
              '{"status":"loading","models_loaded":false}', 200);
        }),
      );
      final ultrasound = await client.getModuleHealth(EdgeAIModel.ultrasound);
      expect(ultrasound.serverReachable, isTrue);
      expect(ultrasound.modelLoaded, isFalse);
      expect(ultrasound.inferenceReady, isFalse);
      expect(ultrasound.message, contains('Waiting for the model files'));
      final cervical = await client.getModuleHealth(EdgeAIModel.cervicalCancer);
      expect(cervical.inferenceReady, isFalse);
    });

    test('module health requires the affirmative field and an ok status',
        () async {
      final client = EdgeDeviceClient(
        config: const EdgeDeviceConfig(
          baseUrl: 'http://device.local',
          modelManagementEnabled: true,
        ),
        httpClient: MockClient((request) async {
          return http.Response(
            request.url.port == 8086
                ? '{"status":"ok","ready":"true"}'
                : '{"status":"ok","models_loaded":true,"ready":true}',
            200,
          );
        }),
      );
      expect(
        (await client.getModuleHealth(EdgeAIModel.ultrasound)).inferenceReady,
        isFalse,
        reason: 'a string is not an affirmative boolean',
      );
      expect(
        (await client.getModuleHealth(EdgeAIModel.cervicalCancer))
            .inferenceReady,
        isTrue,
      );
    });

    test('loaded cervical model is not ready after failed warm-up', () async {
      final client = EdgeDeviceClient(
        config: const EdgeDeviceConfig(
          baseUrl: 'http://device.local',
          modelManagementEnabled: true,
        ),
        httpClient: MockClient((_) async => http.Response(
            '{"status":"ok","models_loaded":true,"ready":false}', 200)),
      );
      expect(
          (await client.getModuleHealth(EdgeAIModel.cervicalCancer))
              .inferenceReady,
          isFalse);
    });

    test('hub accepts not_ready without treating it as ready', () {
      final status = EdgeHubStatus.fromJson({
        'active': 'cervitriage',
        'state': 'not_ready',
      });
      expect(status.state, EdgeHubModuleState.notReady);
    });

    test('hub 409 is a busy conflict and 400 an unsupported module', () async {
      final client = EdgeDeviceClient(
        config: const EdgeDeviceConfig(
          baseUrl: 'http://device.local',
          modelManagementEnabled: true,
        ),
        httpClient: MockClient((request) async {
          final module = request.body.contains('ultrasound');
          return module
              ? http.Response(
                  '{"error":"A switch is already in progress."}', 409)
              : http.Response('{"error":"Unknown module: cervitriage"}', 400);
        }),
      );
      await expectLater(
        client.selectModel(EdgeAIModel.ultrasound),
        throwsA(_failure(EdgeDeviceFailure.busy)),
      );
      await expectLater(
        client.selectModel(EdgeAIModel.cervicalCancer),
        throwsA(_failure(EdgeDeviceFailure.http)),
      );
    });

    test('invalid hub JSON and unknown states are rejected', () async {
      for (final body in ['not json', '[]', '{"state":"warming"}']) {
        final client = EdgeDeviceClient(
          config: const EdgeDeviceConfig(
            baseUrl: 'http://device.local',
            modelManagementEnabled: true,
          ),
          httpClient: MockClient((_) async => http.Response(body, 200)),
        );
        await expectLater(
          client.getHubStatus(),
          throwsA(_failure(EdgeDeviceFailure.invalidResponse)),
          reason: body,
        );
      }
    });
  });

  group('UltrasoundSegmentation.fromDeviceJson', () {
    test('parses a calibrated segmentation response', () {
      final seg = UltrasoundSegmentation.fromDeviceJson(_ultrasoundFound(
        calibrated: true,
      ));
      expect(seg.found, isTrue);
      expect(seg.circumferencePx, 812.4);
      expect(seg.circumferenceMm, 243.7);
      expect(seg.isCalibrated, isTrue);
      expect(seg.ellipse!.axis1Px, 260.1);
      expect(seg.recordId, 7);
      expect(seg.timingsMs['total'], 2310.5);
      expect(seg.overlay, startsWith('data:image/jpeg;base64,'));
    });

    test('uncalibrated responses carry pixels only', () {
      final seg = UltrasoundSegmentation.fromDeviceJson(_ultrasoundFound());
      expect(seg.isCalibrated, isFalse);
      expect(seg.circumferenceMm, isNull);
      expect(seg.areaMm2, isNull);
      expect(seg.toJson().containsKey('circumference_mm'), isFalse);
      expect(seg.toJson().containsKey('overlay'), isFalse);
    });

    test('found:false produces no measurement and no risk level', () {
      final seg = UltrasoundSegmentation.fromDeviceJson({
        'found': false,
        'iou_score': 0.2,
        'image_size': [640, 480],
        'overlay': 'data:image/jpeg;base64,AAAA',
        'timings_ms': {'total': 100.0},
        'record_id': 8,
      });
      expect(seg.found, isFalse);
      expect(seg.circumferencePx, isNull);
      expect(seg.ellipse, isNull);
    });

    test('rejects malformed or inconsistent responses', () {
      final bad = <Map<String, dynamic>>[
        {..._ultrasoundFound(), 'found': 'yes'},
        {
          ..._ultrasoundFound(),
          'image_size': [640]
        },
        {..._ultrasoundFound()}..remove('circumference_px'),
        {..._ultrasoundFound()}..remove('ellipse'),
        {..._ultrasoundFound(), 'circumference_px': -3},
        {..._ultrasoundFound(), 'circumference_mm': 10.0},
        {..._ultrasoundFound(), 'record_id': 'x'},
        {..._ultrasoundFound(), 'overlay': 'not-an-image'},
        {..._ultrasoundFound(), 'timings_ms': 'fast'},
      ];
      for (final json in bad) {
        expect(
          () => UltrasoundSegmentation.fromDeviceJson(json),
          throwsFormatException,
          reason: json.toString(),
        );
      }
    });

    test('round-trips through its persisted form without the overlay', () {
      final original = UltrasoundSegmentation.fromDeviceJson(
        _ultrasoundFound(calibrated: true),
      );
      final restored = UltrasoundSegmentation.fromJson(original.toJson());
      expect(restored.circumferencePx, original.circumferencePx);
      expect(restored.circumferenceMm, original.circumferenceMm);
      expect(restored.recordId, original.recordId);
      expect(restored.overlay, isNull);
    });
  });

  group('cervitriage response parsing', () {
    const endpoint = 'http://dawa.local:8085/predict';

    test('maps a successful /predict response', () {
      final result = CervicalDeviceService.parseCervitriageResponse(
        200,
        '{"classification":"CIN2","confidence":0.8123,"probabilities":{"Normal":0.01,"CIN1":0.1,"CIN2":0.8123,"CIN3":0.05,"Cancer":0.0277},"gatekeeper_flagged":false,"gatekeeper_scores":{"cervical":0.99,"non_cervical":0.01},"timings_ms":{"total":3400.0},"record_id":12}',
        deviceEndpoint: endpoint,
      );
      expect(result.failed, isFalse);
      expect(result.deviceStatus, 'success');
      expect(result.label, 'CIN2');
      expect(result.confidence, 81.2);
      expect(result.riskLevel, 'high');
      expect(result.rawResponse['record_id'], 12);
    });

    test('HTTP 422 is a gatekeeper outcome, not a connection failure', () {
      final result = CervicalDeviceService.parseCervitriageResponse(
        422,
        '{"classification":"Rejected","confidence":1.0,"gatekeeper_flagged":true,"message":"The system detected non-cervical anatomy. Please upload a clear screening scan.","record_id":13}',
        deviceEndpoint: endpoint,
      );
      expect(result.deviceStatus, 'rejected');
      expect(result.failed, isTrue);
      expect(result.riskLevel, 'unknown');
      expect(result.error, contains('non-cervical anatomy'));
    });

    test('missing or invalid fields never become a result', () {
      for (final body in [
        '{}',
        '{"classification":"Normal"}',
        '{"classification":"Normal","confidence":4}',
        '{"classification":"Surprise","confidence":0.5}',
        '{"classification":"Normal","confidence":0.5,"gatekeeper_flagged":"false"}',
        '{"classification":"Normal","confidence":0.5,"probabilities":{"Normal":1.5}}',
        '[]',
        'not json',
      ]) {
        final result = CervicalDeviceService.parseCervitriageResponse(
          200,
          body,
          deviceEndpoint: endpoint,
        );
        expect(result.deviceStatus, 'failed', reason: body);
        expect(result.riskLevel, 'unknown', reason: body);
      }
    });
  });
}

Matcher _failure(EdgeDeviceFailure failure) => isA<EdgeDeviceException>()
    .having((error) => error.failure, 'failure', failure);

Map<String, dynamic> _ultrasoundFound({bool calibrated = false}) => {
      'found': true,
      'area_px': 51234.5,
      'circumference_px': 812.4,
      'ellipse': {
        'cx': 320.5,
        'cy': 240.0,
        'axis1_px': 260.1,
        'axis2_px': 250.9,
        'angle_deg': 12.3,
      },
      if (calibrated) 'circumference_mm': 243.7,
      if (calibrated) 'area_mm2': 4610.9,
      'iou_score': 0.9132,
      'image_size': [640, 480],
      'overlay': 'data:image/jpeg;base64,AAAA',
      'timings_ms': {
        'preprocess': 10.0,
        'encoder': 2000.0,
        'decoder': 200.0,
        'decode': 5.0,
        'postprocess': 12.0,
        'total': 2310.5,
      },
      'record_id': 7,
    };
