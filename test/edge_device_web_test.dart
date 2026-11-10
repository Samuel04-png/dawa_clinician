import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:clinician/application/cacx/cacx_upload_service.dart';
import 'package:clinician/components/edge_device_status_banner.dart';
import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_manager.dart';
import 'package:clinician/services/edge_device/edge_device_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('former web request-ID bound reproduces RangeError with stack', () {
    if (!kIsWeb) return;
    try {
      Random.secure().nextInt(1 << 32);
      fail('The previous request-ID expression should fail on the web.');
    } on RangeError catch (error, stack) {
      debugPrint('Reproduced former request-ID error: $error\n$stack');
      expect(stack.toString(), isNotEmpty);
    }
  });

  test('an old passive check cannot overwrite an active examination', () async {
    final firstStatus = Completer<http.Response>();
    var statusCalls = 0;
    final manager = EdgeDeviceManager(
      client: EdgeDeviceClient(
        config: const EdgeDeviceConfig(
          baseUrl: 'http://localhost',
          modelManagementEnabled: true,
        ),
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/status') {
            if (++statusCalls == 1) return firstStatus.future;
            return http.Response(
              '{"active":"cervitriage","state":"ready","modules":{"cervitriage":{}}}',
              200,
            );
          }
          return http.Response('{"status":"ok","ready":true}', 200);
        }),
      ),
    );
    addTearDown(manager.dispose);
    final refresh =
        manager.refreshObservedReadiness(EdgeAIModel.cervicalCancer);
    await manager.beginExamination(
      model: EdgeAIModel.cervicalCancer,
      examinationId: 'active-test',
    );
    firstStatus
        .complete(http.Response('{"active":null,"state":"stopped"}', 200));
    await refresh;
    expect(manager.state, EdgeDeviceState.ready);
    expect(manager.activeExaminationId, 'active-test');
    await manager.completeExamination('active-test');
  });

  test('programming errors are not converted to transport failures', () async {
    final manager = EdgeDeviceManager(
      client: EdgeDeviceClient(
        config: const EdgeDeviceConfig(
          baseUrl: 'http://localhost',
          modelManagementEnabled: true,
        ),
        httpClient: MockClient((_) async => throw RangeError('test error')),
      ),
    );
    addTearDown(manager.dispose);
    await expectLater(
      CervicalDeviceService.analyzeImage(
        'data:image/png;base64,${base64Encode([1, 2, 3])}',
        null,
        deviceManager: manager,
      ),
      throwsA(isA<RangeError>()),
    );
    expect(manager.state, EdgeDeviceState.error);
    expect(manager.activeExaminationId, isNull);
  });

  testWidgets('browser readiness is verified before an examination',
      (tester) async {
    final requests = <Uri>[];
    var predictUploads = 0;
    final manager = EdgeDeviceManager(
      client: EdgeDeviceClient(
        config: const EdgeDeviceConfig(
          baseUrl: 'http://localhost',
          modelManagementEnabled: true,
        ),
        httpClient: MockClient((request) async {
          requests.add(request.url);
          if (request.url.path == '/api/status') {
            return http.Response(
              '{"active":"cervitriage","state":"ready","modules":{"cervitriage":{}}}',
              200,
            );
          }
          if (request.url.path == '/predict') {
            expect(request.method, 'POST');
            expect(request.url.port, 8085);
            expect(request.headers['content-type'],
                contains('multipart/form-data'));
            expect(request.body, contains('name="image"'));
            predictUploads++;
            return http.Response(
              '{"classification":"Rejected","confidence":1.0,'
              '"gatekeeper_flagged":true,"message":"Synthetic test image"}',
              422,
            );
          }
          return http.Response('{"status":"ok","ready":true}', 200);
        }),
      ),
    );
    addTearDown(manager.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AnimatedBuilder(
          animation: manager,
          builder: (_, __) => EdgeDeviceStatusBanner(
            state: manager.state,
            model: EdgeAIModel.cervicalCancer,
            message: manager.readinessMessage,
          ),
        ),
      ),
    ));
    await tester.runAsync(
      () => manager.refreshObservedReadiness(EdgeAIModel.cervicalCancer),
    );
    await tester.pump();
    expect(find.text('Model ready'), findsOneWidget);
    expect(find.text('Model readiness unverified'), findsNothing);
    expect(requests.map((uri) => '${uri.port}${uri.path}'), [
      '8080/api/status',
      '8085/health',
      '8080/api/status',
    ]);

    await tester.runAsync(
      () => manager.beginExamination(
        model: EdgeAIModel.cervicalCancer,
        examinationId: 'non-patient-test',
      ),
    );
    expect(manager.state, EdgeDeviceState.ready);
    expect(requests.where((uri) => uri.path == '/api/select'), isEmpty);
    await manager.completeExamination('non-patient-test');

    final result = await tester.runAsync(
      () => CervicalDeviceService.analyzeImage(
        'data:image/png;base64,${base64Encode([1, 2, 3])}',
        null,
        deviceManager: manager,
      ),
    );
    expect(result!.deviceStatus, 'rejected');
    expect(predictUploads, 1);
    expect(requests.where((uri) => uri.path == '/api/select'), isEmpty);
  });
}
