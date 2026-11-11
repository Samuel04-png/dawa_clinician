import 'dart:convert';
import 'package:clinician/application/cacx/cacx_widget.dart';
import 'package:clinician/components/edge_workflow_status.dart';
import 'package:clinician/application/hemonix/models/anemia_result.dart';
import 'package:clinician/application/hemonix/repository/anemia_repository.dart';
import 'package:clinician/application/hemonix/screens/hemonix_app.dart';
import 'package:clinician/application/hemonix/services/anemia_edge_service.dart';
import 'package:clinician/services/screening_patient_repository.dart';
import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_manager.dart';
import 'package:clinician/services/edge_device/edge_device_models.dart';
import 'package:clinician/services/edge_device/edge_device_exceptions.dart';
import 'package:clinician/services/edge_device/edge_image_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

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
    expect(find.text('Device busy'), findsOneWidget);
    expect(find.text('Ultrasound AI ready'), findsNothing);
    expect(find.text('Retry connection / Check again'), findsOneWidget);
    await hub.manager.beginExamination(
        model: EdgeAIModel.anemia, examinationId: 'other-exam');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EdgeWorkflowStatus(
                manager: hub.manager, model: EdgeAIModel.anemia))));
    expect(find.text('Device busy'), findsOneWidget);
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
    expect(find.text('Cervical AI ready'), findsOneWidget);
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
              deviceManager: hub.manager,
              repository: _Repository(),
              pickImage: (_) async => _png)));
      await tester.pump();
      expect(find.text('Initializing Anemia AI'), findsOneWidget);
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
            deviceManager: hub.manager,
            repository: repository,
            pickImage: (_) async => _png)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Patient · patient-1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose image'));
    await tester.pumpAndSettle();
    final start = find.text('Start anemia screening');
    await tester.ensureVisible(start);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.text('AI estimate: Mild Anemia'), findsOneWidget);
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
    expect(find.text('AI estimate: Mild Anemia'), findsOneWidget);
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
