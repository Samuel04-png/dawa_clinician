import 'dart:convert';

import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_exceptions.dart';
import 'package:clinician/services/edge_device/edge_device_manager.dart';
import 'package:clinician/services/edge_device/edge_device_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
      'heartbeat every 30 seconds; lost lock blocks upload until reacquired',
      (tester) async {
    var heartbeats = 0;
    var starts = 0;
    var ends = 0;
    var lockLost = false;
    var conflict = false;
    final manager = EdgeDeviceManager(
      client: EdgeDeviceClient(
        config: const EdgeDeviceConfig(
          baseUrl: 'http://device.local',
          modelManagementEnabled: true,
        ),
        httpClient: MockClient((request) async {
          Map<String, Object?> body;
          var status = 200;
          switch (request.url.path) {
            case '/api/status':
              body = {'active': 'cervitriage', 'state': 'ready'};
            case '/health':
              body = {'status': 'ok', 'ready': true};
            case '/api/exam/start':
              starts++;
              status = conflict ? 409 : 201;
              body = conflict
                  ? {'error': 'Held by another app', 'code': 'exam_in_progress'}
                  : {'exam_id': 'device-exam-$starts', 'ttl_s': 120};
            case '/api/exam/heartbeat':
              heartbeats++;
              status = lockLost ? 404 : 200;
              body = lockLost
                  ? {'error': 'Expired', 'code': 'exam_not_found'}
                  : {'ttl_s': 120};
            case '/api/exam/end':
              ends++;
              body = {'ended': true};
            default:
              throw StateError('Unexpected request: ${request.url}');
          }
          return http.Response(jsonEncode(body), status);
        }),
      ),
    );
    addTearDown(manager.dispose);
    await manager.beginExamination(
      model: EdgeAIModel.cervicalCancer,
      examinationId: 'heartbeat-test',
    );
    await tester.pump(const Duration(seconds: 29));
    expect(heartbeats, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(heartbeats, 1);
    lockLost = true;
    await tester.pump(const Duration(seconds: 30));
    expect(manager.state, EdgeDeviceState.error);
    await expectLater(manager.markExamining('heartbeat-test'),
        throwsA(isA<EdgeDeviceException>()));
    conflict = true;
    await expectLater(manager.reconcileActiveExamination(),
        throwsA(isA<EdgeDeviceException>()));
    expect(manager.state, EdgeDeviceState.error);
    conflict = false;
    lockLost = false;
    await manager.reconcileActiveExamination();
    expect(starts, 3);
    expect(manager.state, EdgeDeviceState.ready);
    await tester.pump(const Duration(seconds: 30));
    expect(heartbeats, 3);
    await manager.completeExamination('heartbeat-test');
    expect(ends, 1);
    await tester.pump(const Duration(seconds: 60));
    expect(heartbeats, 3);
  });
}
