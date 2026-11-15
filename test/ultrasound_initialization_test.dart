import 'dart:convert';

import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_manager.dart';
import 'package:clinician/services/edge_device/edge_device_models.dart';
import 'package:clinician/components/edge_device_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('hub requires all three readiness fields', () {
    for (final ready in [null, false, 'true', true]) {
      final hub = EdgeHubStatus.fromJson({
        'active': 'ultrasound',
        'state': 'ready',
        'ready': ready,
      });
      expect(hub.isReadyFor('ultrasound'), ready == true);
      expect(hub.isReadyFor('cervitriage'), false);
    }
    expect(
        const EdgeDeviceConfig(baseUrl: 'http://dawa.local').modelPollInterval,
        const Duration(seconds: 3));
    expect(EdgeDeviceConfig.fromEnvironment().modelReadyTimeout,
        const Duration(seconds: 300));
    expect(EdgeDeviceConfig.fromEnvironment().configurationProblem(), isNull);
  });

  for (final seconds in [30, 60, 90]) {
    testWidgets('startup after $seconds seconds uses status and one selection',
        (tester) async {
      var elapsedTime = Duration.zero;
      var polls = 0;
      var selects = 0;
      var ready = false;
      final manager = EdgeDeviceManager(
          now: () => DateTime(2026).add(elapsedTime),
          client: EdgeDeviceClient(
            config: const EdgeDeviceConfig(baseUrl: 'http://dawa.local'),
            httpClient: MockClient((request) async {
              if (request.url.path == '/api/select') {
                selects++;
                expectSync(jsonDecode(request.body), {'module': 'ultrasound'});
                // Even a ready-looking 202 must not enable inference.
                return http.Response(
                    '{"active":"ultrasound","state":"ready","ready":true}',
                    202);
              }
              if (request.url.path == '/health') {
                return http.Response('{"status":"ok","ready":true}', 200);
              }
              expectSync(request.url.path, '/api/status');
              polls++;
              return http.Response(
                  jsonEncode({
                    'active': selects == 0 ? null : 'ultrasound',
                    'state': ready ? 'ready' : 'starting',
                    'ready': ready,
                    'message': 'Loading models (this can take a minute)...',
                  }),
                  200);
            }),
          ));
      final work = manager.prepareWorkflow(EdgeAIModel.ultrasound);
      await tester.pump();
      expect(manager.state, EdgeDeviceState.loadingModel);
      for (var elapsed = 3; elapsed <= seconds; elapsed += 3) {
        elapsedTime += const Duration(seconds: 3);
        await tester.pump(const Duration(seconds: 3));
      }
      expect(manager.state, EdgeDeviceState.loadingModel);
      expect(manager.readinessMessage,
          'Loading models (this can take a minute)...');
      if (seconds == 90) expect(manager.takingLongerThanExpected, true);
      expect(manager.activeExaminationId, isNull);
      ready = true;
      await tester.pump(const Duration(seconds: 3));
      await work;
      expect(manager.state, EdgeDeviceState.ready);
      expect(manager.observedReadyModel, EdgeAIModel.ultrasound);
      expect(selects, 1);
      expect(polls, seconds ~/ 3 + 2);
      manager.dispose();
    });
  }

  testWidgets('warm loading warns after 30 seconds and reuses the active model',
      (tester) async {
    var elapsed = Duration.zero;
    var ready = true;
    var selections = 0;
    final manager = EdgeDeviceManager(
      now: () => DateTime(2026).add(elapsed),
      client: EdgeDeviceClient(
        config: const EdgeDeviceConfig(baseUrl: 'http://dawa.local'),
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/select') selections++;
          if (request.url.path == '/health')
            return http.Response('{"status":"ok","ready":true}', 200);
          return http.Response(
              jsonEncode({
                'active': 'ultrasound',
                'state': ready ? 'ready' : 'starting',
                'ready': ready
              }),
              200);
        }),
      ),
    );
    await manager.prepareWorkflow(EdgeAIModel.ultrasound);
    ready = false;
    final warming = manager.prepareWorkflow(EdgeAIModel.ultrasound);
    await tester.pump();
    for (var i = 0; i < 11; i++) {
      elapsed += const Duration(seconds: 3);
      await tester.pump(const Duration(seconds: 3));
    }
    expect(manager.takingLongerThanExpected, true);
    expect(manager.state, EdgeDeviceState.loadingModel);
    ready = true;
    await tester.pump(const Duration(seconds: 3));
    await warming;
    expect(manager.state, EdgeDeviceState.ready);
    expect(selections, 0);
    manager.dispose();
  });

  for (final scenario in ['timeout', 'conflict', 'disconnect', 'failed']) {
    testWidgets(
        'initialization handles $scenario without inference or reselection',
        (tester) async {
      var elapsed = Duration.zero;
      var selections = 0;
      var polls = 0;
      final manager = EdgeDeviceManager(
        now: () => DateTime(2026).add(elapsed),
        client: EdgeDeviceClient(
          config: const EdgeDeviceConfig(baseUrl: 'http://dawa.local'),
          httpClient: MockClient((request) async {
            if (scenario == 'disconnect')
              throw http.ClientException('unreachable');
            if (request.url.path == '/api/select') {
              selections++;
              if (scenario == 'conflict')
                return http.Response('{"code":"exam_in_progress"}', 409);
              return http.Response(
                  '{"active":"ultrasound","state":"starting","ready":false}',
                  202);
            }
            expectSync(request.url.path, '/api/status');
            polls++;
            return http.Response(
                jsonEncode({
                  'active': selections == 0 ? null : 'ultrasound',
                  'state': scenario == 'failed' && selections > 0
                      ? 'error'
                      : 'starting',
                  'ready': false,
                  'message': 'Device startup message',
                }),
                200);
          }),
        ),
      );
      final warming = manager.prepareWorkflow(EdgeAIModel.ultrasound);
      await tester.pump();
      if (scenario == 'timeout') {
        for (var i = 0; i < 102; i++) {
          elapsed += const Duration(seconds: 3);
          await tester.pump(const Duration(seconds: 3));
        }
      } else {
        await tester.pump(const Duration(seconds: 3));
      }
      await warming;
      expect(
          manager.state,
          switch (scenario) {
            'conflict' => EdgeDeviceState.busy,
            'disconnect' => EdgeDeviceState.disconnected,
            _ => EdgeDeviceState.error,
          });
      expect(manager.observedReadyModel, isNull);
      expect(manager.activeExaminationId, isNull);
      expect(selections, scenario == 'disconnect' ? 0 : 1);
      if (scenario == 'timeout') expect(polls, greaterThanOrEqualTo(100));
      if (scenario == 'failed')
        expect(manager.readinessMessage, 'Device startup message');
      manager.dispose();
    });
  }

  testWidgets('navigation cancels polling and ignores an in-flight response',
      (tester) async {
    var polls = 0;
    final manager = EdgeDeviceManager(
        client: EdgeDeviceClient(
      config: const EdgeDeviceConfig(baseUrl: 'http://dawa.local'),
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/status') polls++;
        return http.Response(
            '{"active":"ultrasound","state":"starting","ready":false}', 200);
      }),
    ));
    final work = manager.prepareWorkflow(EdgeAIModel.ultrasound);
    await tester.pump();
    manager.cancelWorkflowPreparation(EdgeAIModel.ultrasound);
    await tester.pump(const Duration(seconds: 3));
    await work;
    expect(polls, 1);
    expect(manager.observedReadyModel, isNull);
    manager.dispose();
  });

  testWidgets('loading UI shows device message, timing and no percentage',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: EdgeDeviceStatusBanner(
                state: EdgeDeviceState.loadingModel,
                model: EdgeAIModel.ultrasound,
                message: 'Loading encoder',
                takingLongerThanExpected: true))));
    expect(find.text('Loading encoder'), findsOneWidget);
    expect(find.textContaining('30 seconds'), findsOneWidget);
    expect(find.textContaining('Taking longer than expected'), findsOneWidget);
    expect(
        tester
            .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator))
            .value,
        isNull);
    expect(find.textContaining('%'), findsNothing);
  });
}
