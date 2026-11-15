import 'dart:convert';
import 'dart:async';
import 'package:clinician/app_state.dart';
import 'package:clinician/backend/supabase/supabase_config.dart';
import 'package:clinician/components/clinical_navigation_shell.dart';
import 'package:clinician/components/clinician_navigation.dart';
import 'package:clinician/components/clinical_tab_bar.dart';
import 'package:clinician/application/cacx/cacx_widget.dart';
import 'package:clinician/components/edge_workflow_status.dart';
import 'package:clinician/application/hemonix/models/anemia_result.dart';
import 'package:clinician/application/hemonix/repository/anemia_repository.dart';
import 'package:clinician/application/hemonix/screens/hemonix_app.dart';
import 'package:clinician/application/hemonix/services/anemia_edge_service.dart';
import 'package:clinician/application/hemonix/services/anemia_online_service.dart';
import 'package:clinician/application/hemonix/services/anemia_analysis_service.dart';
import 'package:clinician/services/screening_patient_repository.dart';
import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_manager.dart';
import 'package:clinician/services/edge_device/edge_device_models.dart';
import 'package:clinician/services/edge_device/edge_device_exceptions.dart';
import 'package:clinician/services/edge_device/edge_image_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'clinician_navigation_test.dart' show loadNavigationFonts;

final _png = EdgeImageInput.fromBytes(base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='));
Map<String, dynamic> _payload() => {
      'classification': 'Mild Anemia',
      'class_index': 1,
      'confidence': 0.4,
      'probabilities': {
        'No Anemia': 0.2,
        'Mild Anemia': 0.4,
        'Moderate Anemia': 0.3,
        'Severe Anemia': 0.1
      },
      'disclaimer': 'Device prototype disclaimer',
      'record_id': 1,
    };

class _Hub {
  String? active = 'anemia';
  bool ready = true,
      locked = false,
      conflict = false,
      invalid = false,
      disconnect = false;
  bool failPrediction = false, failEnd = false, changeActiveOnStart = false;
  int selects = 0, predictions = 0, starts = 0, ends = 0;
  final paths = <String>[];
  Completer<void>? predictionGate;
  Map<String, dynamic> get status => {
        'active': active,
        'state': ready ? 'ready' : 'starting',
        'ready': ready,
        'message': ready ? 'Ready' : 'Loading anemia model',
        'modules': {'cervitriage': {}, 'ultrasound': {}, 'anemia': {}},
        'exam': locked ? {'exam_id': 'test-lock'} : null
      };
  late final manager = EdgeDeviceManager(
      client: EdgeDeviceClient(
    config: const EdgeDeviceConfig(
        baseUrl: 'http://dawa.local',
        modelPollInterval: Duration(milliseconds: 10)),
    httpClient: MockClient((request) async {
      expectSync(request.url.port, 80);
      paths.add(request.url.path);
      if (disconnect) throw http.ClientException('disconnected');
      switch (request.url.path) {
        case '/api/status':
          return http.Response(jsonEncode(status), 200);
        case '/api/select':
          if (conflict || locked)
            return http.Response('{"code":"exam_in_progress"}', 409);
          selects++;
          active = jsonDecode(request.body)['module'] as String;
          return http.Response(jsonEncode(status), 202);
        case '/api/exam/start':
          if (locked || conflict)
            return http.Response('{"code":"exam_in_progress"}', 409);
          starts++;
          locked = true;
          if (changeActiveOnStart) active = 'ultrasound';
          return http.Response('{"exam_id":"test-lock","ttl_s":120}', 201);
        case '/api/exam/end':
          if (failEnd) throw http.ClientException('release interrupted');
          ends++;
          locked = false;
          return http.Response('{"ended":true}', 200);
        case '/api/exam/heartbeat':
          return http.Response('{"ttl_s":120}', 200);
        case '/upload/anemia':
          expectSync(active, 'anemia');
          expectSync(ready, true);
          expectSync(locked, true);
          predictions++;
          await predictionGate?.future;
          if (failPrediction)
            throw http.ClientException('prediction interrupted');
          final multipart = latin1.decode(request.bodyBytes);
          expectSync(multipart, contains('name="image"'));
          expectSync(multipart, contains('image/png'));
          expectSync(multipart, isNot(contains('patient_id')));
          return http.Response(
              jsonEncode(invalid ? {'classification': 'Made up'} : _payload()),
              200);
        default:
          throw StateError('Unexpected device route ${request.url.path}');
      }
    }),
  ));
}

class _Repository implements AnemiaRepository {
  bool denySave = false;
  final patients = [
    const ScreeningPatient(id: 'patient-1', name: 'Test Patient'),
    const ScreeningPatient(id: 'patient-2', name: 'Second Patient')
  ];
  final saved = <AnemiaScreeningRecord>[];
  @override
  Future<List<ScreeningPatient>> loadPatients() async => patients;
  @override
  Future<List<AnemiaScreeningRecord>> loadRecords() async => saved;
  @override
  Future<AnemiaScreeningRecord?> loadRecord(String id) async {
    for (final record in saved) {
      if (record.id == id) return record;
    }
    return null;
  }

  @override
  Future<AnemiaScreeningRecord> saveReviewed(
      {required ScreeningPatient patient,
      required AnemiaResult result,
      required String notes,
      required bool reviewConfirmed}) async {
    if (denySave)
      throw const PostgrestException(message: 'Denied', code: '42501');
    final record = AnemiaScreeningRecord(
        id: 'record-1',
        patientId: patient.id,
        patientName: patient.name,
        createdAt: DateTime(2026, 11, 11),
        result: result,
        reviewNotes: notes);
    saved.add(record);
    return record;
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    for (final channel in [
      'com.llfbandit.app_links/events',
      'com.llfbandit.app_links/messages'
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
    await initSupabase();
    await FFAppState().initializePersistedState();
    await loadNavigationFonts();
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final weight in [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800
    ]) {
      GoogleFonts.dmSans(fontWeight: weight);
    }
    await GoogleFonts.pendingFonts();
  });

  Future<void> pumpWorkspace(
      WidgetTester tester, _Hub hub, _Repository repository,
      {Size size = const Size(1440, 1000),
      double scale = 1,
      bool collapsed = false,
      bool allowOnlineFallback = false,
      AnemiaOnlineService onlineService = const AnemiaOnlineService()}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    clinicianSidebarCollapsed.value = collapsed;
    final router = GoRouter(initialLocation: '/hemonix', routes: [
      GoRoute(
          path: '/hemonix',
          builder: (_, __) => ClinicalNavigationShell(
              deviceManager: hub.manager,
              child: HemonixApp(
                  allowOnlineFallback: allowOnlineFallback,
                  onlineService: onlineService,
                  deviceManager: hub.manager,
                  repository: repository,
                  pickImage: (_) async => _png))),
      GoRoute(
          name: 'Moms',
          path: '/moms',
          builder: (_, __) =>
              const Scaffold(body: Text('Patient registry destination'))),
    ]);
    addTearDown(() async {
      if (hub.predictionGate != null && !hub.predictionGate!.isCompleted)
        hub.predictionGate!.complete();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 20));
      hub.manager.dispose();
      router.dispose();
    });
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: FFAppState(),
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: ThemeData(
              fontFamily: 'NavigationQA',
              colorScheme: const ColorScheme.light(
                  primary: Color(0xFF223F91), surface: Colors.white)),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
        )));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/images/dawa_cross.png'),
        tester.element(find.byType(ClinicalNavigationShell))));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (const bool.fromEnvironment('CAPTURE_ANEMIA_FLOW')) {
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('../docs/qa/anemia-flow/$name.png'));
    }
  }

  for (final viewport in [
    'desktop',
    'laptop',
    'collapsed',
    'mobile',
    'large-text'
  ]) {
    testWidgets('anemia ordered flow reaches reviewed history at $viewport',
        (tester) async {
      final hub = _Hub();
      final repository = _Repository();
      final size = switch (viewport) {
        'laptop' => const Size(1024, 900),
        'mobile' => const Size(390, 844),
        'large-text' => const Size(390, 1000),
        _ => const Size(1440, 1000),
      };
      await pumpWorkspace(tester, hub, repository,
          size: size,
          scale: viewport == 'large-text' ? 2 : 1,
          collapsed: viewport == 'collapsed');
      final semantics = tester.ensureSemantics();
      expect(
          tester.getTopLeft(find.text('1. Select patient')).dy,
          lessThan(tester
              .getTopLeft(find.text('2. Prepare lower-eyelid image'))
              .dy));
      expect(find.bySemanticsLabel('Step 1, Patient, current'), findsOneWidget);
      expect(find.text('Select a patient above to continue.'), findsOneWidget);
      if (['desktop', 'laptop', 'collapsed'].contains(viewport)) {
        expect(tester.getTopLeft(find.text('2. Prepare lower-eyelid image')).dy,
            tester.getTopLeft(find.text('3. AI screening')).dy);
        expect(
            find.text('Start anemia screening').hitTestable(), findsOneWidget);
      }
      await capture(tester, 'initial-$viewport');
      await tapVisible(tester, find.byType(DropdownButtonFormField<String>));
      await tapVisible(tester, find.textContaining('Test Patient ·').last);
      expect(find.bySemanticsLabel('Step 2, Image, current'), findsOneWidget);
      await tapVisible(tester, find.text('Choose image'));
      expect(
          find.bySemanticsLabel('Step 3, Screening, current'), findsOneWidget);
      expect(hub.predictions, 0);
      await capture(tester, 'prepared-$viewport');
      await tapVisible(tester, find.text('Start anemia screening'));
      expect(hub.predictions, 1);
      expect(find.bySemanticsLabel('Step 4, Review & save, current'),
          findsOneWidget);
      expect(find.text('4. Clinician review'), findsOneWidget);
      expect(find.text('2. Prepare lower-eyelid image'), findsNothing);
      await capture(tester, 'review-$viewport');
      final save = find.widgetWithText(FilledButton, 'Save reviewed screening');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      final notes = find.widgetWithText(
          TextField, 'Clinician findings and follow-up notes');
      await tester.ensureVisible(notes);
      await tester.enterText(notes, 'Synthetic clinician review notes.');
      await tapVisible(tester, find.byType(CheckboxListTile));
      await tapVisible(tester, save);
      expect(repository.saved.single.patientId, 'patient-1');
      expect(find.bySemanticsLabel('Step 4, Review & save, complete'),
          findsOneWidget);
      await tapVisible(tester, find.text('View saved history'));
      expect(find.text('Saved reviewed screenings'), findsOneWidget);
      await tapVisible(tester, find.text('Open'));
      expect(find.text('Test Patient · Reviewed screening'), findsOneWidget);
      expect(hub.predictions, 1);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('anemia empty patient state opens the registry', (tester) async {
    final repository = _Repository()..patients.clear();
    await pumpWorkspace(tester, _Hub(), repository);
    expect(find.text('No patients available for Anemia screening'),
        findsOneWidget);
    await capture(tester, 'empty-patients-desktop');
    await tapVisible(tester, find.text('Open Patients'));
    expect(find.text('Patient registry destination'), findsOneWidget);
  });

  testWidgets('anemia offers a local retry while online fallback is disabled',
      (tester) async {
    final hub = _Hub()..disconnect = true;
    await pumpWorkspace(tester, hub, _Repository());
    await tapVisible(tester, find.byType(DropdownButtonFormField<String>));
    await tapVisible(tester, find.textContaining('Test Patient ·').last);
    await tapVisible(tester, find.text('Choose image'));
    final start = find.widgetWithText(FilledButton, 'Start anemia screening');
    expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
    expect(hub.predictions, 0);
    expect(find.textContaining('Online analysis is disabled.'), findsOneWidget);
    await capture(tester, 'offline-desktop');
  });

  for (final (mode, width, scale) in [
    ('offline', 1440.0, 1.0),
    ('offline', 1024.0, 1.0),
    ('offline', 390.0, 1.0),
    ('offline', 390.0, 2.0),
    ('edge failure', 1440.0, 1.0),
    ('online failure', 1440.0, 1.0),
  ]) {
    testWidgets(
        'anemia $mode fallback is explicit, single submission and recoverable at $width scale $scale',
        (tester) async {
      final hub = _Hub()
        ..disconnect = mode != 'edge failure'
        ..failPrediction = mode == 'edge failure';
      final repository = _Repository();
      var onlineCalls = 0;
      final gate = Completer<http.Response>();
      final online =
          AnemiaOnlineService(httpClient: MockClient((request) async {
        onlineCalls++;
        if (onlineCalls == 1)
          return http.Response('["/tmp/synthetic.png"]', 200);
        if (onlineCalls == 2)
          return http.Response('{"event_id":"test-event"}', 200);
        return gate.future;
      }));
      await pumpWorkspace(tester, hub, repository,
          allowOnlineFallback: true,
          onlineService: online,
          size: Size(width, 1000),
          scale: scale);
      expect(onlineCalls, 0);
      await tapVisible(tester, find.byType(DropdownButtonFormField<String>));
      await tapVisible(tester, find.textContaining('Test Patient ·').last);
      await tapVisible(tester, find.text('Choose image'));
      expect(onlineCalls, 0);
      if (mode != 'edge failure') {
        expect(find.text('Dawa device unavailable — analysis will run online.'),
            findsOneWidget);
      }
      final start = find.widgetWithText(FilledButton, 'Start anemia screening');
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();
      await tester.ensureVisible(start);
      await tester.pump();
      await tester.tap(start);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(onlineCalls, 3);
      expect(
          find.text('Device unavailable — analysing online'), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Screening image…'))
              .onPressed,
          isNull);
      gate.complete(http.Response(
          mode == 'online failure'
              ? 'RAW_PRIVATE_ERROR'
              : 'event: complete\ndata: [{"label":"Mild Anemia","confidences":[{"label":"No Anemia","confidence":0.2},{"label":"Mild Anemia","confidence":0.4},{"label":"Moderate Anemia","confidence":0.3},{"label":"Severe Anemia","confidence":0.1}]}]\n\n',
          mode == 'online failure' ? 503 : 200));
      await tester.pumpAndSettle();
      expect(onlineCalls, 3);
      expect(hub.predictions, mode == 'edge failure' ? 1 : 0);
      if (mode == 'online failure') {
        expect(find.textContaining('Online screening could not be completed.'),
            findsOneWidget);
        expect(find.text('RAW_PRIVATE_ERROR'), findsNothing);
        expect(
            tester
                .widget<TextButton>(
                    find.widgetWithText(TextButton, 'Retry screening'))
                .onPressed,
            isNotNull);
      } else {
        expect(find.textContaining('Analysed online (device unavailable)'),
            findsOneWidget);
        if (const bool.fromEnvironment('CAPTURE_ANEMIA_ONLINE')) {
          await tester.ensureVisible(
              find.textContaining('Analysed online (device unavailable)'));
          await tester.pumpAndSettle();
          await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                  '../coverage/anemia-online/$mode-${width.toInt()}-$scale-result.png'));
        }
        await tapVisible(tester, find.byType(CheckboxListTile));
        await tester.enterText(
            find.byWidgetPredicate((widget) =>
                widget is TextField &&
                widget.decoration?.labelText ==
                    'Clinician findings and follow-up notes'),
            'Synthetic clinician review');
        await tapVisible(tester, find.text('Save reviewed screening'));
        expect(repository.saved, hasLength(1));
        expect(repository.saved.single.result.isOnline, isTrue);
        expect(repository.saved.single.result.onlineServiceUrl,
            AnemiaOnlineConfig.baseUrl);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('completed or invalid edge output never starts online analysis',
      (tester) async {
    final hub = _Hub();
    var onlineCalls = 0;
    final service = AnemiaAnalysisService(hub.manager,
        online: AnemiaOnlineService(httpClient: MockClient((_) async {
      onlineCalls++;
      return http.Response('', 500);
    })));
    addTearDown(hub.manager.dispose);
    await hub.manager.prepareWorkflow(EdgeAIModel.anemia);
    final completed =
        await service.analyze(image: _png, examinationId: 'completed');
    expect(completed.isOnline, isFalse);
    hub.invalid = true;
    await expectLater(
        service.analyze(image: _png, examinationId: 'invalid'),
        throwsA(isA<EdgeDeviceException>().having((e) => e.failure,
            'validation', EdgeDeviceFailure.invalidResponse)));
    expect(onlineCalls, 0);
  });

  testWidgets(
      'online connection still waits for local readiness and uses edge with fallback enabled or disabled',
      (tester) async {
    final hub = _Hub()..ready = false;
    addTearDown(hub.manager.dispose);
    await hub.manager.refreshObservedReadiness(EdgeAIModel.anemia);
    expect(hub.manager.state, EdgeDeviceState.loadingModel);
    var calls = 0;
    final online = AnemiaOnlineService(httpClient: MockClient((_) async {
      calls++;
      return http.Response(
          switch (calls) {
            1 => '["/tmp/synthetic.png"]',
            2 => '{"event_id":"event"}',
            _ =>
              'event: complete\ndata: [{"label":"Mild Anemia","confidences":[{"label":"No Anemia","confidence":0.2},{"label":"Mild Anemia","confidence":0.4},{"label":"Moderate Anemia","confidence":0.3},{"label":"Severe Anemia","confidence":0.1}]}]\n\n'
          },
          200);
    }));
    final disabled = AnemiaAnalysisService(hub.manager,
        allowOnlineFallback: false, online: online);
    expect(disabled.canAnalyze, isTrue);
    hub.ready = true;
    final local =
        await disabled.analyze(image: _png, examinationId: 'disabled');
    expect(local.isOnline, isFalse);
    expect(calls, 0);
    final result = await AnemiaAnalysisService(hub.manager, online: online)
        .analyze(image: _png, examinationId: 'initializing');
    expect(result.isOnline, isFalse);
    expect(calls, 0);
    expect(hub.predictions, 2);
    expect(hub.starts, 2);
  });

  testWidgets('cancelled edge failure and exam conflict never upload online',
      (tester) async {
    final hub = _Hub()..failPrediction = true;
    await hub.manager.prepareWorkflow(EdgeAIModel.anemia);
    var calls = 0, cancelled = false;
    final service = AnemiaAnalysisService(hub.manager,
        online: AnemiaOnlineService(httpClient: MockClient((_) async {
      calls++;
      return http.Response('', 500);
    })));
    hub.conflict = true;
    await expectLater(service.analyze(image: _png, examinationId: 'conflict'),
        throwsA(isA<EdgeDeviceException>()));
    expect(calls, 0);
    hub.conflict = false;
    await hub.manager.refreshObservedReadiness(EdgeAIModel.anemia);
    hub.predictionGate = Completer<void>();
    final pending = service.analyze(
        image: _png, examinationId: 'cancelled', isCancelled: () => cancelled);
    final assertion =
        expectLater(pending, throwsA(isA<AnemiaAnalysisCancelled>()));
    await tester.pump();
    cancelled = true;
    hub.predictionGate!.complete();
    await assertion;
    expect(calls, 0);
    hub.manager.dispose();
  });

  testWidgets('anemia busy flow locks preparation until the result arrives',
      (tester) async {
    final hub = _Hub()..predictionGate = Completer<void>();
    await pumpWorkspace(tester, hub, _Repository());
    await tapVisible(tester, find.byType(DropdownButtonFormField<String>));
    await tapVisible(tester, find.textContaining('Test Patient ·').last);
    await tapVisible(tester, find.text('Choose image'));
    await tester.ensureVisible(find.text('Start anemia screening'));
    await tester.tap(find.text('Start anemia screening'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(hub.predictions, 1);
    expect(tester.widget<ClinicalTabBar>(find.byType(ClinicalTabBar)).enabled,
        isFalse);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Replace image'))
            .onPressed,
        isNull);
    await capture(tester, 'analysing-desktop');
    hub.predictionGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('4. Clinician review'), findsOneWidget);
  });

  testWidgets('anemia replacing the reviewed image returns to preparation',
      (tester) async {
    final hub = _Hub();
    await pumpWorkspace(tester, hub, _Repository());
    await tapVisible(tester, find.byType(DropdownButtonFormField<String>));
    await tapVisible(tester, find.textContaining('Test Patient ·').last);
    await tapVisible(tester, find.text('Choose image'));
    await tapVisible(tester, find.text('Start anemia screening'));
    await tapVisible(tester, find.text('Image and screening controls'));
    await tapVisible(tester, find.text('Replace image'));
    expect(find.text('4. Clinician review'), findsNothing);
    expect(find.textContaining('Selected: Test Patient'), findsOneWidget);
    expect(hub.predictions, 1);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Start anemia screening'))
            .onPressed,
        isNotNull);
  });

  test('malformed patient rows are skipped without invented identities', () {
    final patients = ScreeningPatient.parseRows([
      {'id': 'patient-1', 'name': 'Valid'},
      {'id': null, 'name': 'Invalid'},
      {'id': 'missing-name'},
      {'id': 123, 'name': 'Invalid'},
      {'id': 'patient-1', 'name': 'Duplicate'},
    ]);
    expect(patients.map((p) => p.id), ['patient-1']);
  });

  test('anemia outputs are validated and do not fabricate haemoglobin values',
      () {
    final result = AnemiaResult.fromDeviceJson(_payload(),
        examinationId: 'exam', deviceId: 'dawa.local');
    expect(result.lowConfidence, true);
    for (final change in <Map<String, dynamic>>[
      {'classification': 'Unknown'},
      {'confidence': 90},
      {'class_index': 2},
      {'disclaimer': ''},
      {
        'probabilities': {'No Anemia': 1.0}
      },
    ]) {
      expect(
          () => AnemiaResult.fromDeviceJson({..._payload(), ...change},
              examinationId: 'exam', deviceId: 'dawa.local'),
          throwsFormatException);
    }
    expect(_png.mimeType, 'image/png');
    expect(() => EdgeImageInput.fromBytes([1, 2, 3]), throwsFormatException);
  });

  test('anemia uses the hub route with readiness and lock, then releases it',
      () async {
    final hub = _Hub();
    await hub.manager.prepareWorkflow(EdgeAIModel.anemia);
    final result = await AnemiaEdgeService(hub.manager)
        .analyze(image: _png, examinationId: 'test-exam');
    expect(result.classification, 'Mild Anemia');
    expect(hub.predictions, 1);
    expect(hub.starts, 1);
    expect(hub.ends, 1);
    expect(hub.selects, 0);
    expect(hub.manager.activeExaminationId, isNull);
    hub.manager.dispose();
  });

  test(
      'invalid anemia responses are not shown as results and release a completed request',
      () async {
    final hub = _Hub()..invalid = true;
    await hub.manager.prepareWorkflow(EdgeAIModel.anemia);
    await expectLater(
        AnemiaEdgeService(hub.manager)
            .analyze(image: _png, examinationId: 'test-exam'),
        throwsA(isA<EdgeDeviceException>().having(
            (e) => e.failure, 'failure', EdgeDeviceFailure.invalidResponse)));
    expect(hub.ends, 1);
    expect(hub.manager.activeExaminationId, isNull);
    hub.manager.dispose();
  });

  for (final failure in ['connection lost', 'release failed', 'wrong model']) {
    test(
        'anemia handles $failure without replaying an uncertain image submission',
        () async {
      final hub = _Hub()
        ..failPrediction = failure == 'connection lost'
        ..failEnd = failure == 'release failed'
        ..changeActiveOnStart = failure == 'wrong model';
      await hub.manager.prepareWorkflow(EdgeAIModel.anemia);
      await expectLater(
          AnemiaEdgeService(hub.manager)
              .analyze(image: _png, examinationId: 'uncertain-exam'),
          throwsA(isA<EdgeDeviceException>()));
      expect(hub.manager.activeExaminationId, 'uncertain-exam');
      expect(hub.manager.state, EdgeDeviceState.error);
      expect(hub.predictions, failure == 'wrong model' ? 0 : 1);
      expect(hub.selects, 0);
      hub.failEnd = false;
      await hub.manager.completeExamination('uncertain-exam');
      hub.manager.dispose();
    });
  }

  testWidgets(
      'a completed warmup on another page still offers retry and never shows the wrong model ready',
      (tester) async {
    final hub = _Hub();
    await hub.manager.prepareWorkflow(EdgeAIModel.anemia);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EdgeWorkflowStatus(
                manager: hub.manager, model: EdgeAIModel.ultrasound))));
    expect(find.textContaining('in use by another screening'), findsOneWidget);
    expect(find.text('Ultrasound AI ready'), findsNothing);
    expect(find.text('Retry connection / Check again'), findsOneWidget);
    await hub.manager.beginExamination(
        model: EdgeAIModel.anemia, examinationId: 'other-exam');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EdgeWorkflowStatus(
                manager: hub.manager, model: EdgeAIModel.anemia))));
    expect(find.textContaining('in use by another screening'), findsOneWidget);
    expect(find.text('Anemia AI ready'), findsNothing);
    await hub.manager.completeExamination('other-exam');
    await tester.pumpWidget(const SizedBox());
    hub.manager.dispose();
  });

  testWidgets(
      'latest navigation prepares the correct model without overlapping switches',
      (tester) async {
    final hub = _Hub()..active = null;
    final first = hub.manager.prepareWorkflow(EdgeAIModel.cervicalCancer);
    await tester.pump();
    final second = hub.manager.prepareWorkflow(EdgeAIModel.ultrasound);
    final third = hub.manager.prepareWorkflow(EdgeAIModel.anemia);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
    await Future.wait([first, second, third]);
    expect(hub.active, 'anemia');
    expect(hub.manager.observedReadyModel, EdgeAIModel.anemia);
    expect(hub.selects, 2,
        reason: 'Superseded Ultrasound request must not select');
    hub.manager.dispose();
  });

  testWidgets('anemia never switches a model protected by another exam',
      (tester) async {
    final hub = _Hub()
      ..active = 'cervitriage'
      ..locked = true;
    await hub.manager.prepareWorkflow(EdgeAIModel.anemia);
    expect(hub.manager.state, EdgeDeviceState.busy);
    expect(hub.selects, 0);
    expect(hub.predictions, 0);
    hub.manager.dispose();
  });

  testWidgets('CaCx starts model preparation on entry, before image submission',
      (tester) async {
    final hub = _Hub()..active = null;
    await tester.pumpWidget(MaterialApp(
        home: CaCxApp(
            deviceManager: hub.manager, patientRepository: _Repository())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(hub.active, 'cervitriage');
    expect(hub.selects, 1);
    expect(hub.predictions, 0);
    expect(hub.starts, 0);
    // Routine readiness is intentionally represented by the shared app-bar
    // device indicator, not a persistent clinical-page banner.
    expect(find.text('Cervical AI ready'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    hub.manager.dispose();
  });

  for (final size in [
    const Size(390, 844),
    const Size(820, 900),
    const Size(1200, 1000)
  ]) {
    testWidgets(
        'anemia preparation is responsive at ${size.width} and inference waits for readiness',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final hub = _Hub()..ready = false;
      await tester.pumpWidget(MaterialApp(
          home: HemonixApp(
              allowOnlineFallback: false,
              deviceManager: hub.manager,
              repository: _Repository(),
              pickImage: (_) async => _png)));
      await tester.pump();
      // Model preparation remains observable from the global indicator; it no
      // longer consumes vertical space in the screening workflow.
      expect(find.text('Initializing Anemia AI'), findsNothing);
      final start = find.widgetWithText(FilledButton, 'Start anemia screening');
      await tester.scrollUntilVisible(start, 200,
          scrollable: find.byType(Scrollable).first);
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      expect(hub.predictions, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 20));
      hub.manager.dispose();
    });
  }

  testWidgets('anemia secondary navigation stays disabled during inference',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final hub = _Hub()..predictionGate = Completer<void>();
    await tester.pumpWidget(MaterialApp(
        home: HemonixApp(
            allowOnlineFallback: false,
            deviceManager: hub.manager,
            repository: _Repository(),
            pickImage: (_) async => _png)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Test Patient ·').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose image'));
    await tester.pumpAndSettle();
    final start = find.text('Start anemia screening');
    await tester.ensureVisible(start);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(hub.predictions, 1);
    expect(tester.widget<ClinicalTabBar>(find.byType(ClinicalTabBar)).enabled,
        isFalse);
    await tester.tap(find.descendant(
        of: find.byType(ClinicalTabBar), matching: find.text('History')));
    await tester.pump();
    expect(
        tester.widget<ClinicalTabBar>(find.byType(ClinicalTabBar)).activeIndex,
        0);
    hub.predictionGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('AI-estimated classification'), findsOneWidget);
    expect(find.text('Mild Anemia'), findsAtLeastNWidgets(1));
    expect(tester.widget<ClinicalTabBar>(find.byType(ClinicalTabBar)).enabled,
        isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    hub.manager.dispose();
  });

  testWidgets(
      'anemia review saves the actual selected patient and requires clinician notes',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final hub = _Hub();
    final repository = _Repository();
    await tester.pumpWidget(MaterialApp(
        home: HemonixApp(
            allowOnlineFallback: false,
            deviceManager: hub.manager,
            repository: repository,
            pickImage: (_) async => _png)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Test Patient ·').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose image'));
    await tester.pumpAndSettle();
    final start = find.text('Start anemia screening');
    await tester.ensureVisible(start);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.text('AI-estimated classification'), findsOneWidget);
    expect(find.text('Mild Anemia'), findsAtLeastNWidgets(1));
    expect(find.text('Device prototype disclaimer'), findsOneWidget);
    expect(find.textContaining('Low-confidence estimate'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'Save reviewed screening');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(
        find.widgetWithText(
            TextField, 'Clinician findings and follow-up notes'),
        'Clinician review recorded.');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    repository.denySave = true;
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.saved, isEmpty);
    expect(find.textContaining('You do not have permission to save'),
        findsAtLeastNWidgets(1));
    expect(find.text('AI-estimated classification'), findsOneWidget);
    expect(find.text('Mild Anemia'), findsAtLeastNWidgets(1));
    expect(
        tester
            .widget<TextField>(find.widgetWithText(
                TextField, 'Clinician findings and follow-up notes'))
            .controller!
            .text,
        'Clinician review recorded.');
    repository.denySave = false;
    ScaffoldMessenger.of(tester.element(find.byType(HemonixApp)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.saved.length, 1);
    expect(repository.saved.single.patientId, 'patient-1');
    expect(repository.saved.single.result.classification, 'Mild Anemia');
    expect(hub.predictions, 1);
    expect(find.text('Reviewed screening saved'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    hub.manager.dispose();
  });
}
