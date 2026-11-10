import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clinician/application/cacx/cacx_upload_service.dart';
import 'package:clinician/application/ultrasound/services/ultrasound_edge_service.dart';
import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_exceptions.dart';
import 'package:clinician/services/edge_device/edge_device_manager.dart';
import 'package:clinician/services/edge_device/edge_device_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';

/// Local simulation of the hub, cervitriage and ultrasound HTTP schemas from
/// the supplied device source. Passing these tests proves only that the
/// Flutter client matches that source; it is NOT evidence that a physical
/// device behaves this way.
void main() {
  setUpAll(() => HttpOverrides.global = null);

  test('CaCx: select cervitriage, verify health, POST /predict', () async {
    final device = await _MockDevice.start();
    final manager = _manager(device);
    try {
      final result = await CervicalDeviceService.analyzeImage(
        base64Encode([1, 2, 3]),
        'patient-1',
        deviceManager: manager,
      );
      expect(device.selects, ['cervitriage']);
      expect(device.cervicalPredicts, 1);
      expect(device.cervicalUploads, 0);
      expect(result.failed, isFalse);
      expect(result.label, 'Normal');
      expect(device.stopCalls, 0);
      expect(manager.activeExaminationId, isNull);
    } finally {
      manager.dispose();
      await device.close();
    }
  });

  test('CaCx: gatekeeper HTTP 422 is a quality outcome', () async {
    final device = await _MockDevice.start()
      ..cervicalReject = true;
    final manager = _manager(device);
    try {
      final result = await CervicalDeviceService.analyzeImage(
        base64Encode([1, 2, 3]),
        'patient-1',
        deviceManager: manager,
      );
      expect(result.deviceStatus, 'rejected');
      expect(result.riskLevel, 'unknown');
      expect(device.cervicalUploads, 0, reason: 'must not fall back');
    } finally {
      manager.dispose();
      await device.close();
    }
  });

  test('CaCx: explicitly configured legacy mode uses /upload/cervical',
      () async {
    final device = await _MockDevice.start()
      ..hubAvailable = false;
    // Legacy deployments serve /upload/cervical from the base URL itself.
    final manager = _manager(
      device,
      baseUrl: 'http://127.0.0.1:${device.cervical.port}',
      management: false,
    );
    try {
      final result = await CervicalDeviceService.analyzeImage(
        base64Encode([1, 2, 3]),
        'patient-legacy',
        deviceManager: manager,
      );
      expect(device.cervicalUploads, 1);
      expect(result.failed, isFalse);
    } finally {
      manager.dispose();
      await device.close();
    }
  });

  test('Ultrasound: select, wait for ready:true, POST, then back to CaCx',
      () async {
    final device = await _MockDevice.start();
    final manager = _manager(device);
    final service = UltrasoundEdgeService(deviceManager: manager);
    try {
      await service.prepareExamination(examinationId: 'us-1');
      expect(device.selects, ['ultrasound']);
      expect(manager.state, EdgeDeviceState.ready);

      final result = await service.analyzeImage(
        image: 'data:image/jpeg;base64,AQID',
        examinationId: 'us-1',
        pixelSpacingMm: 0.3,
      );
      expect(result.error, isNull);
      expect(result.provider.name, 'edgeDevice');
      expect(result.modelId, 'ultrasound');
      expect(result.findings, isEmpty);
      expect(result.overallLevel, isNull);
      expect(result.segmentation!.found, isTrue);
      expect(result.segmentation!.isCalibrated, isTrue);
      expect(device.lastUltrasoundFields['pixel_spacing_mm'], '0.3');

      await manager.completeExamination('us-1');
      await manager.beginExamination(
        model: EdgeAIModel.cervicalCancer,
        examinationId: 'cx-2',
      );
      expect(device.selects, ['ultrasound', 'cervitriage']);
      expect(device.stopCalls, 0);
    } finally {
      manager.dispose();
      await device.close();
    }
  });

  test('Ultrasound: no segmentation is not a normal result', () async {
    final device = await _MockDevice.start()
      ..usFound = false;
    final manager = _manager(device);
    final service = UltrasoundEdgeService(deviceManager: manager);
    try {
      await service.prepareExamination(examinationId: 'us-2');
      final result = await service.analyzeImage(
        image: 'data:image/png;base64,AQID',
        examinationId: 'us-2',
      );
      expect(result.segmentation!.found, isFalse);
      expect(result.overallLevel, isNull);
      expect(result.findings, isEmpty);
      expect(result.overallAssessment.toLowerCase(),
          contains('no abdominal segmentation'));
    } finally {
      manager.dispose();
      await device.close();
    }
  });

  test('Ultrasound: ready:false (HTTP 200) never enables inference', () async {
    final device = await _MockDevice.start()
      ..usReady = false;
    final manager = _manager(device, ready: const Duration(milliseconds: 150));
    final service = UltrasoundEdgeService(deviceManager: manager);
    try {
      await expectLater(
        service.prepareExamination(examinationId: 'us-3'),
        throwsA(isA<EdgeDeviceException>().having(
          (e) => e.failure,
          'failure',
          EdgeDeviceFailure.timeout,
        )),
      );
      await expectLater(
        service.analyzeImage(
          image: 'data:image/jpeg;base64,AQID',
          examinationId: 'us-3',
        ),
        throwsA(isA<EdgeDeviceException>()),
      );
      expect(device.ultrasoundPredicts, 0);
    } finally {
      manager.dispose();
      await device.close();
    }
  });

  test('module health can become ready after the former grace period',
      () async {
    final device = await _MockDevice.start()
      ..cervicalReady = false;
    final manager = _manager(device,
        ready: const Duration(seconds: 2),
        grace: const Duration(milliseconds: 20));
    final timer = Timer(const Duration(milliseconds: 120), () {
      expect(device.cervicalPredicts, 0);
      device.cervicalReady = true;
    });
    try {
      final result = await CervicalDeviceService.analyzeImage(
        base64Encode([1, 2, 3]),
        'patient-1',
        deviceManager: manager,
      );
      expect(result.deviceStatus, 'success');
      expect(device.cervicalPredicts, 1);
    } finally {
      timer.cancel();
      manager.dispose();
      await device.close();
    }
  });

  test('hub reporting another active module blocks inference', () async {
    final device = await _MockDevice.start()
      ..stickyActive = 'cervitriage';
    final manager = _manager(device, ready: const Duration(milliseconds: 400));
    try {
      await expectLater(
        manager.beginExamination(
          model: EdgeAIModel.ultrasound,
          examinationId: 'us-4',
        ),
        throwsA(isA<EdgeDeviceException>()),
      );
      expect(device.ultrasoundPredicts, 0);
    } finally {
      manager.dispose();
      await device.close();
    }
  });

  test('hub error state and 409 switch conflict surface as failures', () async {
    final device = await _MockDevice.start()
      ..hubErrors = true;
    final manager = _manager(device);
    try {
      await expectLater(
        manager.beginExamination(
          model: EdgeAIModel.ultrasound,
          examinationId: 'us-5',
        ),
        throwsA(isA<EdgeDeviceException>().having(
          (e) => e.failure,
          'failure',
          EdgeDeviceFailure.modelInitialization,
        )),
      );
    } finally {
      manager.dispose();
      await device.close();
    }

    final busy = await _MockDevice.start()
      ..selectConflict = true;
    final busyManager = _manager(busy);
    try {
      await expectLater(
        busyManager.beginExamination(
          model: EdgeAIModel.ultrasound,
          examinationId: 'us-6',
        ),
        throwsA(isA<EdgeDeviceException>().having(
          (e) => e.failure,
          'failure',
          EdgeDeviceFailure.busy,
        )),
      );
    } finally {
      busyManager.dispose();
      await busy.close();
    }
  });

  test('switching is refused while an examination is active', () async {
    final device = await _MockDevice.start();
    final manager = _manager(device);
    try {
      await manager.beginExamination(
        model: EdgeAIModel.cervicalCancer,
        examinationId: 'cx-active',
      );
      await expectLater(
        manager.beginExamination(
          model: EdgeAIModel.ultrasound,
          examinationId: 'us-intruder',
        ),
        throwsA(isA<EdgeDeviceException>()),
      );
      expect(device.selects, ['cervitriage']);
      expect(manager.activeExaminationId, 'cx-active');
    } finally {
      manager.dispose();
      await device.close();
    }
  });

  test('invalid ultrasound payload is rejected, not shown as success',
      () async {
    final device = await _MockDevice.start()
      ..usInvalid = true;
    final manager = _manager(device);
    final service = UltrasoundEdgeService(deviceManager: manager);
    try {
      await service.prepareExamination(examinationId: 'us-7');
      await expectLater(
        service.analyzeImage(
          image: 'data:image/jpeg;base64,AQID',
          examinationId: 'us-7',
        ),
        throwsA(isA<Exception>()),
      );
    } finally {
      manager.dispose();
      await device.close();
    }
  });

  test('disconnected device raises a connection failure', () async {
    final device = await _MockDevice.start();
    final manager = _manager(device);
    await device.close();
    try {
      await expectLater(
        manager.beginExamination(
          model: EdgeAIModel.ultrasound,
          examinationId: 'us-8',
        ),
        throwsA(isA<EdgeDeviceException>()),
      );
    } finally {
      manager.dispose();
    }
  });

  test('already-ready requested module is not re-selected', () async {
    final device = await _MockDevice.start()
      ..active = 'cervitriage'
      ..hubState = 'ready';
    final manager = _manager(device);
    try {
      await manager.beginExamination(
        model: EdgeAIModel.cervicalCancer,
        examinationId: 'cx-warm',
      );
      expect(device.selects, isEmpty);
      expect(manager.state, EdgeDeviceState.ready);
    } finally {
      manager.dispose();
      await device.close();
    }
  });

  test('read-only readiness verifies hub and model without selecting',
      () async {
    final device = await _MockDevice.start()
      ..active = 'cervitriage'
      ..hubState = 'ready';
    final manager = _manager(device);
    try {
      await manager.refreshObservedReadiness(EdgeAIModel.cervicalCancer);
      expect(manager.state, EdgeDeviceState.ready);
      expect(manager.observedReadyModel, EdgeAIModel.cervicalCancer);
      expect(device.selects, isEmpty);
      expect(device.statusPolls, 2);

      device.cervicalReady = false;
      await manager.refreshObservedReadiness(EdgeAIModel.cervicalCancer);
      expect(manager.state, EdgeDeviceState.unverified);
      expect(manager.observedReadyModel, isNull);
      expect(device.selects, isEmpty);

      device.active = 'ultrasound';
      await manager.refreshObservedReadiness(EdgeAIModel.cervicalCancer);
      expect(manager.state, EdgeDeviceState.unverified);
      expect(device.selects, isEmpty);
    } finally {
      manager.dispose();
      await device.close();
    }
  });

  test('already-starting requested module is polled without selecting again',
      () async {
    final device = await _MockDevice.start()
      ..active = 'cervitriage'
      ..hubState = 'starting';
    final manager = _manager(device);
    final timer = Timer(
      const Duration(milliseconds: 100),
      () => device.hubState = 'ready',
    );
    try {
      await manager.beginExamination(
        model: EdgeAIModel.cervicalCancer,
        examinationId: 'cx-already-starting',
      );
      expect(manager.state, EdgeDeviceState.ready);
      expect(device.selects, isEmpty);
      expect(device.statusPolls, greaterThan(1));
    } finally {
      timer.cancel();
      manager.dispose();
      await device.close();
    }
  });

  test('enabled management never falls back to legacy upload on hub failure',
      () async {
    final device = await _MockDevice.start()
      ..hubAvailable = false;
    final manager = _manager(device);
    try {
      await expectLater(
        CervicalDeviceService.analyzeImage(
          base64Encode([1, 2, 3]),
          null,
          deviceManager: manager,
        ),
        throwsA(isA<CervicalDeviceHttpException>()),
      );
      expect(device.cervicalUploads, 0);
      expect(device.cervicalPredicts, 0);
    } finally {
      manager.dispose();
      await device.close();
    }
  });

  test('exam_in_progress 409 is reported as busy without fallback', () async {
    final device = await _MockDevice.start()
      ..selectConflict = true
      ..conflictCode = 'exam_in_progress';
    final manager = _manager(device);
    try {
      await expectLater(
        manager.beginExamination(
          model: EdgeAIModel.ultrasound,
          examinationId: 'us-locked',
        ),
        throwsA(isA<EdgeDeviceException>()
            .having((e) => e.failure, 'failure', EdgeDeviceFailure.busy)
            .having((e) => e.message, 'message', contains('exam_in_progress'))),
      );
      expect(manager.state, EdgeDeviceState.busy);
      expect(device.cervicalUploads, 0);
    } finally {
      manager.dispose();
      await device.close();
    }
  });

  test('extended model start-up is polled, selected once, then ready',
      () async {
    final device = await _MockDevice.start()
      ..startDelay = const Duration(milliseconds: 600);
    final manager = _manager(device, ready: const Duration(seconds: 5));
    try {
      await manager.beginExamination(
        model: EdgeAIModel.cervicalCancer,
        examinationId: 'cx-slow-start',
      );
      expect(device.selects, ['cervitriage'], reason: 'select sent once');
      expect(device.statusPolls, greaterThan(5), reason: 'kept polling');
      expect(manager.state, EdgeDeviceState.ready);
    } finally {
      manager.dispose();
      await device.close();
    }
  });

  test('startup is never reported as a failure before the timeout', () async {
    final device = await _MockDevice.start()
      ..startDelay = const Duration(milliseconds: 400);
    final manager = _manager(device, ready: const Duration(seconds: 5));
    final states = <EdgeDeviceState>[];
    manager.addListener(() => states.add(manager.state));
    try {
      await manager.beginExamination(
        model: EdgeAIModel.cervicalCancer,
        examinationId: 'cx-states',
      );
      expect(states, isNot(contains(EdgeDeviceState.error)));
      expect(states, isNot(contains(EdgeDeviceState.unsupported)));
      expect(states, contains(EdgeDeviceState.loadingModel));
    } finally {
      manager.dispose();
      await device.close();
    }
  });

  test('CaCx /predict request reaches port 8085 with the image', () async {
    final device = await _MockDevice.start();
    final manager = _manager(device);
    try {
      await CervicalDeviceService.analyzeImage(
        base64Encode([9, 9, 9]),
        'test-patient',
        deviceManager: manager,
      );
      expect(device.cervicalPredicts, 1);
      expect(device.selects, ['cervitriage']);
    } finally {
      manager.dispose();
      await device.close();
    }
  });

  test('hub that never becomes ready times out', () async {
    final device = await _MockDevice.start()
      ..neverReady = true;
    final manager = _manager(device, ready: const Duration(milliseconds: 300));
    try {
      await expectLater(
        manager.beginExamination(
          model: EdgeAIModel.cervicalCancer,
          examinationId: 'cx-slow',
        ),
        throwsA(isA<EdgeDeviceException>().having(
          (e) => e.failure,
          'failure',
          EdgeDeviceFailure.timeout,
        )),
      );
    } finally {
      manager.dispose();
      await device.close();
    }
  });

  test('active not_ready module is polled until ready without selecting again',
      () async {
    final device = await _MockDevice.start()
      ..active = 'cervitriage'
      ..hubState = 'not_ready';
    final manager = _manager(device);
    final timer = Timer(
        const Duration(milliseconds: 100), () => device.hubState = 'ready');
    try {
      final result = await manager.beginExamination(
        model: EdgeAIModel.cervicalCancer,
        examinationId: 'cx-not-ready',
      );
      expect(result.state, EdgeDeviceModelState.ready);
      expect(device.statusPolls, greaterThan(1));
      expect(device.selects, isEmpty);
      await manager.completeExamination('cx-not-ready');
    } finally {
      timer.cancel();
      manager.dispose();
      await device.close();
    }
  });
}

EdgeDeviceManager _manager(
  _MockDevice device, {
  Duration ready = const Duration(seconds: 5),
  Duration grace = const Duration(seconds: 1),
  String? baseUrl,
  bool management = true,
}) {
  final client = EdgeDeviceClient(
    config: EdgeDeviceConfig(
      baseUrl: baseUrl ?? 'http://127.0.0.1',
      modelManagementEnabled: management,
      ultrasoundInferenceEnabled: true,
      hubPort: device.hub.port,
      cervicalPort: device.cervical.port,
      ultrasoundPort: device.ultrasound.port,
      requestTimeout: const Duration(seconds: 2),
      uploadTimeout: const Duration(seconds: 5),
      modelRequestTimeout: const Duration(seconds: 2),
      modelReadyTimeout: ready,
      modelPollInterval: const Duration(milliseconds: 5),
      moduleHealthGrace: grace,
    ),
    httpClient: IOClient(HttpClient()),
  );
  return EdgeDeviceManager(client: client);
}

class _MockDevice {
  _MockDevice(this.hub, this.cervical, this.ultrasound);

  final HttpServer hub;
  final HttpServer cervical;
  final HttpServer ultrasound;

  final selects = <String>[];
  int stopCalls = 0;
  int cervicalPredicts = 0;
  int cervicalUploads = 0;
  int ultrasoundPredicts = 0;
  Map<String, String> lastUltrasoundFields = {};

  String? active;
  String hubState = 'stopped';
  String? stickyActive;
  bool hubAvailable = true;
  bool hubErrors = false;
  bool selectConflict = false;
  String conflictCode = 'busy';
  bool neverReady = false;
  Duration startDelay = Duration.zero;
  int statusPolls = 0;
  bool cervicalReject = false;
  bool cervicalReady = true;
  bool usReady = true;
  bool usFound = true;
  bool usInvalid = false;

  static Future<_MockDevice> start() async {
    final hub = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final cervical = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final ultrasound = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final device = _MockDevice(hub, cervical, ultrasound);
    hub.listen(device._hub);
    cervical.listen(device._cervical);
    ultrasound.listen(device._ultrasound);
    return device;
  }

  Future<void> close() async {
    await hub.close(force: true);
    await cervical.close(force: true);
    await ultrasound.close(force: true);
  }

  Future<void> _json(HttpRequest r, int code, Object body) async {
    r.response
      ..statusCode = code
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await r.response.close();
  }

  Map<String, dynamic> _status() => {
        'active': stickyActive ?? active,
        'state': hubErrors && active != null
            ? 'error'
            : neverReady
                ? 'starting'
                : hubState,
        'message': '',
        'health': null,
        'modules': {
          'cervitriage': {'label': 'CerviTriage', 'subtitle': '', 'port': 8085},
          'ultrasound': {'label': 'Ultrasound', 'subtitle': '', 'port': 8086},
        },
      };

  Future<void> _hub(HttpRequest r) async {
    if (!hubAvailable) {
      r.response.statusCode = 404;
      await r.response.close();
      return;
    }
    final path = r.uri.path;
    if (path == '/health') return _json(r, 200, {'status': 'ok', 'hub': true});
    if (path == '/api/status') {
      statusPolls += 1;
      return _json(r, 200, _status());
    }
    if (path == '/api/stop') {
      stopCalls += 1;
      return _json(r, 200, _status());
    }
    if (path == '/api/select' && r.method == 'POST') {
      final body = jsonDecode(await utf8.decoder.bind(r).join()) as Map;
      final module = body['module'] as String;
      if (module != 'cervitriage' && module != 'ultrasound') {
        return _json(r, 400, {'error': 'Unknown module: $module'});
      }
      if (selectConflict) {
        return _json(r, 409, {'error': conflictCode});
      }
      selects.add(module);
      active = module;
      if (startDelay == Duration.zero) {
        hubState = 'ready';
      } else {
        hubState = 'starting';
        Timer(startDelay, () => hubState = 'ready');
      }
      return _json(r, 202, _status());
    }
    return _json(r, 404, {'error': 'not found'});
  }

  Future<void> _cervical(HttpRequest r) async {
    switch (r.uri.path) {
      case '/health':
        return _json(r, 200, {
          'status': 'ok',
          'models_loaded': cervicalReady,
          'ready': cervicalReady
        });
      case '/predict':
        await r.drain<void>();
        cervicalPredicts += 1;
        if (cervicalReject) {
          return _json(r, 422, {
            'classification': 'Rejected',
            'confidence': 1.0,
            'gatekeeper_flagged': true,
            'message': 'The system detected non-cervical anatomy.',
          });
        }
        return _json(r, 200, {
          'classification': 'Normal',
          'confidence': 0.91,
          'probabilities': {
            'Normal': 0.91,
            'CIN1': 0.04,
            'CIN2': 0.02,
            'CIN3': 0.02,
            'Cancer': 0.01,
          },
          'gatekeeper_flagged': false,
          'timings_ms': {'total': 10.0},
          'record_id': 1,
        });
      case '/upload/cervical':
        await r.drain<void>();
        cervicalUploads += 1;
        return _json(r, 200, {
          'result': 'Negative',
          'confidence': 90.0,
        });
    }
    return _json(r, 404, {'error': 'not found'});
  }

  Future<void> _ultrasound(HttpRequest r) async {
    if (r.uri.path == '/health') {
      return _json(r, 200, {
        'status': usReady ? 'ok' : 'waiting_for_model',
        'ready': usReady,
        'mode': 'sam_two_stage',
        'message': usReady ? 'ok' : 'Waiting for the model files',
      });
    }
    if (r.uri.path == '/predict') {
      final raw = latin1.decode(
        await r.fold<List<int>>([], (a, b) => a..addAll(b)),
      );
      ultrasoundPredicts += 1;
      lastUltrasoundFields = {
        for (final m
            in RegExp(r'name="(\w+)"\r\n\r\n([^\r]*)\r\n').allMatches(raw))
          m.group(1)!: m.group(2)!,
      };
      if (!usReady) {
        return _json(r, 503, {'error': 'model not ready', 'ready': false});
      }
      if (usInvalid) return _json(r, 200, {'found': 'maybe'});
      final spacing = lastUltrasoundFields['pixel_spacing_mm'];
      return _json(r, 200, {
        'found': usFound,
        if (usFound) 'area_px': 51000.0,
        if (usFound) 'circumference_px': 800.0,
        if (usFound)
          'ellipse': {
            'cx': 300.0,
            'cy': 240.0,
            'axis1_px': 260.0,
            'axis2_px': 250.0,
            'angle_deg': 10.0,
          },
        if (usFound && spacing != null) 'circumference_mm': 240.0,
        if (usFound && spacing != null) 'area_mm2': 4590.0,
        'iou_score': 0.9,
        'image_size': [640, 480],
        'overlay': 'data:image/jpeg;base64,AAAA',
        'timings_ms': {'total': 100.0},
        'record_id': 3,
      });
    }
    return _json(r, 404, {'error': 'not found'});
  }
}
