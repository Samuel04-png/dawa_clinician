import 'package:clinician/application/ultrasound/models/ultrasound_models.dart';
import 'package:clinician/application/ultrasound/repositories/ultrasound_repository.dart';
import 'package:clinician/application/ultrasound/screens/ultrasound_app.dart';
import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('shows an honest empty patient state without sample records',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: UltrasoundApp(
            repository: _EmptyUltrasoundRepository(),
            edgeDeviceManager: EdgeDeviceManager(
                client: EdgeDeviceClient(
                    config: const EdgeDeviceConfig(
                        baseUrl: 'http://localhost',
                        modelManagementEnabled: false)))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Patients').last);
    await tester.pumpAndSettle();

    expect(find.text('No patient records are available.'), findsOneWidget);
    expect(
      find.text(
        'Demonstration data only. Sample patients, scan history, and records are not clinical records.',
      ),
      findsNothing,
    );
    expect(find.textContaining('Sample Patient'), findsNothing);
  });

  testWidgets(
      'opening the workflow selects Ultrasound before patient selection',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selects = 0;
    final manager = EdgeDeviceManager(
        client: EdgeDeviceClient(
      config: const EdgeDeviceConfig(baseUrl: 'http://dawa.local'),
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/select') selects++;
        return http.Response(
            selects == 0
                ? '{"active":null,"state":"stopped","ready":false}'
                : '{"active":"ultrasound","state":"starting","ready":false,"message":"Loading encoder"}',
            request.url.path == '/api/select' ? 202 : 200);
      }),
    ));
    await tester.pumpWidget(MaterialApp(
        home: UltrasoundApp(
            repository: _EmptyUltrasoundRepository(),
            edgeDeviceManager: manager)));
    await tester.pump();
    expect(selects, 1);
    expect(manager.activeExaminationId, isNull);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Initializing Ultrasound AI'), findsOneWidget);
    expect(find.text('Loading encoder'), findsOneWidget);
    await tester.tap(find.text('Patients').last);
    await tester.pump();
    expect(find.text('No patient records are available.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    manager.dispose();
  });

  testWidgets('image preparation remains available while ultrasound loads',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var ready = false;
    final patient = PregnantPatient(
      id: 'test',
      name: 'Test',
      age: 30,
      contact: '',
      scanStatus: ScanStatus.unscanned,
      riskLevel: RiskLevel.unknown,
      pregnancyStatus: PregnancyStatus.unknown,
    );
    final manager = EdgeDeviceManager(
      client: EdgeDeviceClient(
        config: const EdgeDeviceConfig(
          baseUrl: 'http://localhost',
          modelManagementEnabled: true,
          ultrasoundInferenceEnabled: true,
        ),
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/exam/start') {
            return http.Response('{"exam_id":"test-lock","ttl_s":120}', 201);
          }
          return http.Response(
              ready
                  ? '{"active":"ultrasound","state":"ready","ready":true,"modules":{"ultrasound":{}}}'
                  : '{"active":"ultrasound","state":"starting","ready":false}',
              200);
        }),
      ),
    );
    addTearDown(manager.dispose);
    await tester.pumpWidget(MaterialApp(
      home: UltrasoundApp(
        repository: _PatientUltrasoundRepository(patient),
        edgeDeviceManager: manager,
        initialPatient: patient,
        initialMode: UltrasoundLaunchMode.manualScan,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    final upload = find.widgetWithText(OutlinedButton, 'Upload Image');
    expect(upload, findsOneWidget);
    expect(tester.widget<OutlinedButton>(upload).onPressed, isNotNull);
    expect(manager.observedReadyModel, isNull);
    ready = true;
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(upload).onPressed, isNotNull);
    await manager.completeExamination(manager.activeExaminationId!);
  });
}

class _PatientUltrasoundRepository extends _EmptyUltrasoundRepository {
  _PatientUltrasoundRepository(this.patient);
  final PregnantPatient patient;

  @override
  Future<List<PregnantPatient>> loadPatients() async => [patient];
}

class _EmptyUltrasoundRepository implements UltrasoundRepository {
  @override
  Future<List<PregnantPatient>> loadPatients() async => const [];

  @override
  Future<List<UltrasoundScanRecord>> loadScanRecords() async => const [];

  @override
  Future<UltrasoundScanRecord> saveScanRecord({
    required PregnantPatient patient,
    required UltrasoundAnalysisResult analysis,
    required ScanType scanType,
  }) {
    throw UnimplementedError('The empty-state test does not save records.');
  }
}
