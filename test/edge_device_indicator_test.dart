import 'package:clinician/components/navigation_design_system.dart';
import 'clinician_navigation_test.dart' show loadNavigationFonts;
import 'dart:async';
import 'dart:convert';
import 'package:clinician/components/edge_device_indicator.dart';
import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_manager.dart';
import 'package:clinician/services/edge_device/edge_device_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUpAll(() async {
    await loadNavigationFonts();
    final font = FontLoader('DeviceQA')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'));
    await font.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  for (final state in ['stopped', 'ready', 'starting', 'error', 'offline']) {
    testWidgets('indicator and popover show actual $state status',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });
      final manager = EdgeDeviceManager(
          client: EdgeDeviceClient(
              config: const EdgeDeviceConfig(
                  baseUrl: 'http://dawa.local', modelManagementEnabled: true),
              httpClient: MockClient((request) async {
                expect(request.method, 'GET');
                expect(request.url.path, '/api/status');
                if (state == 'offline') throw http.ClientException('Offline');
                return http.Response(
                    jsonEncode({
                      'active': state == 'stopped' ? null : 'anemia',
                      'state': state,
                      'ready': state == 'ready'
                    }),
                    200);
              })));
      addTearDown(manager.dispose);
      await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'DeviceQA'),
          home: Scaffold(
              appBar:
                  AppBar(actions: [EdgeDeviceIndicator(manager: manager)]))));
      await tester.pumpAndSettle();
      final dot = tester.widget<AnimatedContainer>(
          find.byKey(const ValueKey('edge-device-status-dot')));
      expect(
          (dot.decoration! as BoxDecoration).color,
          switch (state) {
            'error' => NavigationTokens.error,
            'starting' => NavigationTokens.brand,
            'offline' => NavigationTokens.secondary,
            _ => NavigationTokens.connected,
          });
      final expected = switch (state) {
        'ready' => 'Ready (hub confirmed)',
        'starting' => 'Initializing',
        'error' => 'Device reported an error',
        'stopped' => 'No active model',
        _ => 'Not verified',
      };
      expect(
          find.byTooltip(
              'Edge device: ${state == 'offline' ? 'Offline' : 'Connected'} · $expected'),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('edge-device-control')));
      await tester.pumpAndSettle();
      expect(find.text(expected), findsOneWidget);
      if (const bool.fromEnvironment('CAPTURE_NAV_QA')) {
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('../docs/qa/phase1b/device-$state.png'));
      }
      expect(find.text('Retry Connection'), findsOneWidget);
      await tester.tap(find.text('View Diagnostics'));
      await tester.pumpAndSettle();
      expect(find.text('Device diagnostics'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Retry Connection refreshes the popover after recovery',
      (tester) async {
    var offline = true;
    var requests = 0;
    var now = DateTime(2026, 11, 11, 12);
    final manager = EdgeDeviceManager(
        now: () => now,
        client: EdgeDeviceClient(
            config: const EdgeDeviceConfig(
                baseUrl: 'http://dawa.local', modelManagementEnabled: true),
            httpClient: MockClient((request) async {
              requests++;
              if (offline) throw http.ClientException('Offline');
              return http.Response(
                  '{"active":"anemia","state":"ready","ready":true}', 200);
            })));
    addTearDown(manager.dispose);
    await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
            appBar: AppBar(actions: [EdgeDeviceIndicator(manager: manager)]))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edge-device-control')));
    await tester.pumpAndSettle();
    expect(find.text('Offline'), findsOneWidget);
    offline = false;
    now = now.add(const Duration(seconds: 6));
    await tester.tap(find.text('Retry Connection'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Ready (hub confirmed)'), findsOneWidget);
  });

  testWidgets('reduced motion keeps initialization indicator static',
      (tester) async {
    final manager = EdgeDeviceManager(
        client: EdgeDeviceClient(
            config: const EdgeDeviceConfig(
                baseUrl: 'http://dawa.local', modelManagementEnabled: true),
            httpClient: MockClient((_) async => http.Response(
                '{"active":"anemia","state":"starting","ready":false}', 200))));
    addTearDown(manager.dispose);
    await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
                appBar: AppBar(
                    actions: [EdgeDeviceIndicator(manager: manager)])))));
    await tester.pumpAndSettle();
    final opacity = tester.widget<Opacity>(find
        .ancestor(
            of: find.byWidgetPredicate((w) =>
                w is NavigationIcon && w.symbol == NavigationSymbol.device),
            matching: find.byType(Opacity))
        .first);
    expect(opacity.opacity, 1);
    expect(tester.binding.hasScheduledFrame, false);
  });

  test('checks coalesce, throttle, retry and preserve clinical state',
      () async {
    var requests = 0;
    var offline = true;
    var now = DateTime(2026, 11, 11);
    final gate = Completer<void>();
    final manager = EdgeDeviceManager(
        now: () => now,
        client: EdgeDeviceClient(
            config: const EdgeDeviceConfig(
                baseUrl: 'http://dawa.local', modelManagementEnabled: true),
            httpClient: MockClient((request) async {
              requests++;
              await gate.future;
              if (offline) throw http.ClientException('Offline');
              return http.Response(
                  '{"active":"anemia","state":"ready","ready":true}', 200);
            })));
    addTearDown(manager.dispose);
    final a = manager.checkHubConnection();
    final b = manager.checkHubConnection();
    gate.complete();
    await Future.wait([a, b]);
    expect(requests, 1);
    expect(manager.hubConnected, false);
    await manager.checkHubConnection(retry: true);
    expect(requests, 1);
    offline = false;
    now = now.add(const Duration(seconds: 6));
    await manager.checkHubConnection(retry: true);
    expect(requests, 2);
    expect(manager.hubConnected, true);
    expect(manager.lastSuccessfulCheck, now);
    expect(manager.state, EdgeDeviceState.disconnected);
    expect(manager.activeExaminationId, isNull);
    expect(manager.activeModel, isNull);
  });

  testWidgets('read-only retry does no requests during an active examination',
      (tester) async {
    var statusRequests = 0;
    final manager = EdgeDeviceManager(
        client: EdgeDeviceClient(
            config: const EdgeDeviceConfig(
                baseUrl: 'http://dawa.local', modelManagementEnabled: true),
            httpClient: MockClient((request) async {
              if (request.url.path == '/api/status') {
                statusRequests++;
                return http.Response(
                    '{"active":"anemia","state":"ready","ready":true}', 200);
              }
              return http.Response('{"exam_id":"locked"}', 201);
            })));
    addTearDown(manager.dispose);
    await manager.beginExamination(
        model: EdgeAIModel.anemia, examinationId: 'active');
    final before = statusRequests;
    await manager.checkHubConnection(retry: true);
    expect(statusRequests, before);
    expect(manager.state, EdgeDeviceState.ready);
    expect(manager.activeExaminationId, 'active');
    await manager.completeExamination('active');
  });
}
