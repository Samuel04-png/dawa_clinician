import 'dart:async';
import 'package:clinician/components/clinical_image_frame.dart';
import 'dart:convert';

import 'package:clinician/application/ultrasound/models/ultrasound_models.dart';
import 'package:clinician/application/ultrasound/repositories/ultrasound_repository.dart';
import 'package:clinician/application/ultrasound/screens/ultrasound_app.dart';
import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'clinician_navigation_test.dart' show loadNavigationFonts;

final _image = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=');

class _Picker extends ImagePickerPlatform {
  bool cancel = false;
  @override
  Future<XFile?> getImageFromSource(
          {required ImageSource source,
          ImagePickerOptions options = const ImagePickerOptions()}) async =>
      cancel
          ? null
          : XFile.fromData(_image,
              name: 'synthetic.png', mimeType: 'image/png');
}

class _Repository implements UltrasoundRepository {
  final patient = PregnantPatient(
      id: 'synthetic-patient',
      name: 'Synthetic QA Patient',
      age: 29,
      contact: '',
      scanStatus: ScanStatus.unscanned,
      riskLevel: RiskLevel.unknown,
      pregnancyStatus: PregnancyStatus.secondTrimester,
      gestationalAgeWeeks: 24);
  bool failSave = false;
  final saved = <UltrasoundAnalysisResult>[];
  final records = <UltrasoundScanRecord>[];
  @override
  Future<List<PregnantPatient>> loadPatients() async => [patient];
  @override
  Future<List<UltrasoundScanRecord>> loadScanRecords() async =>
      List.of(records);
  @override
  Future<UltrasoundScanRecord> saveScanRecord(
      {required PregnantPatient patient,
      required UltrasoundAnalysisResult analysis,
      required ScanType scanType}) async {
    if (failSave) throw StateError('synthetic save rejection');
    saved.add(analysis);
    final row = UltrasoundScanRecord(
        id: 'synthetic-scan',
        patientId: patient.id,
        patientName: patient.name,
        date: DateTime.utc(2026, 11, 14),
        scanType: scanType,
        result: analysis.overallAssessment,
        notes: '',
        imageUri: analysis.imageUrl,
        segmentation: analysis.segmentation,
        examinationId: analysis.examinationId,
        modelId: analysis.modelId,
        analysisProvider: analysis.provider);
    records.add(row);
    return row;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadNavigationFonts();
  });
  for (final mode in [
    UltrasoundLaunchMode.manualScan,
    UltrasoundLaunchMode.aiGuidedScan
  ]) {
    for (final width in [1440.0, 1024.0, 390.0]) {
      testWidgets(
          '${mode.name} image analysis and save retain provenance at ${width.toInt()}px',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final priorPicker = ImagePickerPlatform.instance;
        ImagePickerPlatform.instance = _Picker();
        addTearDown(() => ImagePickerPlatform.instance = priorPicker);
        final repository = _Repository();
        final prediction = Completer<http.Response>();
        var predicts = 0, ends = 0;
        final manager = EdgeDeviceManager(
            client: EdgeDeviceClient(
                config: const EdgeDeviceConfig(baseUrl: 'http://dawa.local'),
                httpClient: MockClient((request) async {
                  switch (request.url.path) {
                    case '/api/status':
                      return http.Response(
                          '{"active":"ultrasound","state":"ready","ready":true}',
                          200);
                    case '/health':
                      return http.Response('{"status":"ok","ready":true}', 200);
                    case '/api/exam/start':
                      return http.Response(
                          '{"exam_id":"synthetic-device-lock","ttl_s":120}',
                          201);
                    case '/api/exam/end':
                      ends++;
                      return http.Response('{"ended":true}', 200);
                    case '/upload/ultrasound':
                      predicts++;
                      return prediction.future;
                    default:
                      throw StateError(
                          'Unexpected mock endpoint: ${request.url.path}');
                  }
                })));
        addTearDown(manager.dispose);
        await tester.pumpWidget(MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                fontFamily: 'NavigationQA',
                colorSchemeSeed: const Color(0xFF223F91)),
            home: UltrasoundApp(
                repository: repository,
                edgeDeviceManager: manager,
                initialPatient: repository.patient,
                initialMode: mode)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        final upload = find.text(mode == UltrasoundLaunchMode.manualScan
            ? 'Upload Image'
            : 'Choose image');
        await tester.ensureVisible(upload.first);
        await tester.runAsync(() async {
          await tester.tap(upload.first);
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<ClinicalImageFrame>(find.byType(ClinicalImageFrame))
                .bytes,
            _image);
        final analyze = find.text('Analyze Ultrasound Image');
        await tester.ensureVisible(analyze);
        await tester.tap(analyze);
        await tester.pump();
        expect(predicts, 1);
        final button =
            find.widgetWithText(TextButton, 'Analyze Ultrasound Image');
        expect(tester.widget<TextButton>(button).onPressed, isNull);
        prediction.complete(http.Response(
            jsonEncode({
              'found': true,
              'image_size': [1, 1],
              'area_px': 1.0,
              'circumference_px': 3.5,
              'ellipse': {
                'cx': 0.5,
                'cy': 0.5,
                'axis1_px': 1.0,
                'axis2_px': 1.0,
                'angle_deg': 0.0
              },
              'iou_score': 0.9,
              'timings_ms': {'total': 4.0}
            }),
            200));
        await tester.pumpAndSettle();
        expect(
            find.text('AI estimate — clinician must review'), findsOneWidget);
        expect(find.textContaining('3.5 px'), findsWidgets);
        expect(find.text('Urgent review'), findsNothing);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_PHASE13')) {
          await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                  '../coverage/phase13/ultrasound-${mode.name}-${width.toInt()}.png'));
        }
        final save = find.text('Save Scan Record');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(repository.saved, hasLength(1));
        expect(repository.saved.single.provider,
            UltrasoundAnalysisProvider.edgeDevice);
        expect(repository.saved.single.segmentation!.circumferenceMm, isNull);
        expect(repository.saved.single.examinationId, isNotEmpty);
        expect(predicts, 1);
        expect(ends, 1);
        expect(manager.activeExaminationId, isNull);
        expect(find.text('Scan record saved.'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
