import 'dart:convert';

import 'package:clinician/application/ultrasound/models/ultrasound_models.dart';
import 'package:clinician/application/ultrasound/repositories/ultrasound_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uid = '00000000-0000-4000-a000-000000000013';
  const repository = SupabaseUltrasoundRepository();
  var tables = <String, List<Map<String, dynamic>>>{};
  final requests = <http.Request>[];
  var fail = false;

  Future<void> signIn() => Supabase.instance.client.auth
      .setInitialSession(jsonEncode({
        'access_token': 'synthetic-token',
        'refresh_token': 'synthetic-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
        'user': {
          'id': uid,
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z'
        }
      }))
      .then((_) {});

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    for (final channel in [
      'com.llfbandit.app_links/events',
      'com.llfbandit.app_links/messages'
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
    await Supabase.initialize(
        url: 'http://127.0.0.1:54321',
        anonKey: 'synthetic-public-key',
        authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          final name = request.url.path.split('/').last;
          Object? body;
          if (request.method == 'POST' && name == 'ultrasound_scan_records') {
            body = {
              'id': 'saved-scan',
              'created_at': '2026-11-01T10:00:00Z',
              ...jsonDecode(request.body) as Map<String, dynamic>
            };
          } else {
            body = tables[name] ?? [];
          }
          return http.Response(
              jsonEncode(fail ? {'message': 'synthetic unavailable'} : body),
              fail ? 500 : 200,
              headers: {'content-type': 'application/json'},
              request: request);
        }));
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() async {
    tables = {};
    requests.clear();
    fail = false;
    await signIn();
    requests.clear();
  });

  PregnantPatient patient() => PregnantPatient(
      id: 'patient-one',
      name: 'Synthetic QA',
      age: 30,
      contact: '',
      scanStatus: ScanStatus.unscanned,
      riskLevel: RiskLevel.unknown,
      pregnancyStatus: PregnancyStatus.unknown);

  UltrasoundAnalysisResult analysis(
          {String? error,
          String? model = 'ultrasound',
          String? exam = 'exam-one',
          UltrasoundAnalysisProvider provider =
              UltrasoundAnalysisProvider.edgeDevice,
          UltrasoundSegmentation? segmentation}) =>
      UltrasoundAnalysisResult(
          imageUrl: '',
          findings: segmentation == null
              ? [
                  const UltrasoundFinding(
                      category: 'QA',
                      finding: 'Synthetic finding',
                      level: FindingLevel.normal)
                ]
              : [],
          overallAssessment: segmentation == null ? 'Synthetic assessment' : '',
          overallLevel: segmentation == null ? FindingLevel.normal : null,
          recommendation: segmentation == null ? 'Clinician review' : '',
          measurements: {'HC': '101 mm'},
          estimatedGestationalAge: 20,
          provider: provider,
          examinationId: exam,
          modelId: model,
          modelVersion: 'qa-v1',
          deviceId: 'synthetic-device',
          error: error,
          segmentation: segmentation);

  Map<String, dynamic> savedRow() => {
        'id': 'scan-one',
        'patient_id': 'patient-one',
        'created_at': '2026-11-03T10:00:00Z',
        'workflow': 'ai_guided',
        'analysis_provider': 'edgeDevice',
        'overall_level': 'normal',
        'overall_assessment': 'Synthetic saved assessment',
        'recommendation': 'Review',
        'estimated_gestational_age': 20,
        'measurements': {'HC': '101 mm'},
        'findings': [
          {
            'category': 'QA',
            'finding': 'Synthetic finding',
            'level': 'normal',
            'note': 'QA note'
          }
        ],
        'examination_id': 'exam-one',
        'model_id': 'ultrasound',
        'model_version': 'qa-v1',
        'device_id': 'synthetic-device'
      };

  test('unsigned users cannot read patients or scan history', () async {
    await Supabase.instance.client.auth.signOut();
    requests.clear();
    await expectLater(repository.loadPatients(), throwsStateError);
    await expectLater(repository.loadScanRecords(), throwsStateError);
    expect(requests, isEmpty);
  });

  test(
      'patient loading preserves real pregnancy context and rejects incomplete identities',
      () async {
    final now = DateTime.now();
    tables['mother'] = [
      {
        'id': 'patient-one',
        'name': 'Synthetic QA',
        'dateOfBirth': '1996-01-01',
        'phone_number': '000000'
      },
      {'id': 'patient-two', 'name': 'Synthetic QA', 'dateOfBirth': 'invalid'},
      {
        'id': 'patient-three',
        'name': 'Third QA',
        'dateOfBirth': now.add(const Duration(days: 100)).toIso8601String()
      },
      {'id': 'patient-one', 'name': 'Duplicate ID'},
      {'id': 'missing-name', 'name': ''},
      {'name': 'Missing ID'}
    ];
    tables['first_encounter'] = [
      {
        'mother_Id': 'patient-one',
        'lnmp': now.subtract(const Duration(days: 140)).toIso8601String(),
        'gravidity': 2,
        'parity': 1
      },
      {
        'mother_Id': 'patient-two',
        'estimated_due_date':
            now.add(const Duration(days: 210)).toIso8601String()
      },
      {
        'mother_Id': 'patient-three',
        'lnmp': now.subtract(const Duration(days: 224)).toIso8601String()
      }
    ];
    final patients = await repository.loadPatients();
    expect(patients.map((p) => p.id),
        ['patient-one', 'patient-two', 'patient-three']);
    expect(patients[0].gestationalAgeWeeks, 20);
    expect(patients[0].pregnancyStatus, PregnancyStatus.secondTrimester);
    expect(patients[0].gravida, 'G2P1');
    expect(patients[1].age, isNull);
    expect(patients[1].pregnancyStatus, PregnancyStatus.firstTrimester);
    expect(patients[2].age, isNull);
    expect(patients[2].pregnancyStatus, PregnancyStatus.thirdTrimester);
    expect(requests.last.url.queryParameters['mother_Id'],
        contains('patient-one'));
  });

  test(
      'missing pregnancy dates remain unknown and empty patients cause no join request',
      () async {
    expect(await repository.loadPatients(), isEmpty);
    expect(
        requests.where((r) => r.url.path.endsWith('first_encounter')), isEmpty);
    tables['mother'] = [
      {'id': 'patient-one', 'name': 'Synthetic QA'}
    ];
    final result = (await repository.loadPatients()).single;
    expect(result.pregnancyStatus, PregnancyStatus.unknown);
    expect(result.gestationalAgeWeeks, isNull);
    expect(result.gravida, isNull);
  });

  test(
      'saved and legacy scans retain provenance, patient links and descending dates',
      () async {
    tables['ultrasound_scan_records'] = [savedRow()];
    tables['encounter'] = [
      {
        'id': 'legacy-one',
        'mother_id': 'patient-two',
        'us_obstetrics': 'Legacy ultrasound note',
        'date_performed': '2026-11-04'
      }
    ];
    tables['mother'] = [
      {'id': 'patient-one', 'name': 'First QA'},
      {'id': 'patient-two', 'name': 'Second QA'}
    ];
    final records = await repository.loadScanRecords();
    expect(records.map((r) => r.id), ['legacy-one', 'scan-one']);
    expect(records.first.patientName, 'Second QA');
    expect(records.first.scanType, ScanType.unknown);
    expect(
        records.last.analysisProvider, UltrasoundAnalysisProvider.edgeDevice);
    expect(records.last.findings.single.note, 'QA note');
    expect(records.last.measurements, {'HC': '101 mm'});
    expect(requests.first.url.queryParameters['user_id'], 'eq.$uid');
  });

  for (final invalid in <String, Object?>{
    'analysis_provider': 'invented',
    'created_at': 'invalid',
    'id': null,
    'patient_id': null,
    'overall_assessment': null,
    'overall_level': null,
    'measurements': 42,
    'findings': 'invalid'
  }.entries) {
    test('stored scans reject invalid ${invalid.key}', () async {
      tables['ultrasound_scan_records'] = [
        {...savedRow(), invalid.key: invalid.value}
      ];
      await expectLater(repository.loadScanRecords(), throwsFormatException);
    });
  }

  test('malformed stored finding and legacy date are rejected', () async {
    tables['ultrasound_scan_records'] = [
      {
        ...savedRow(),
        'findings': [
          {'category': 3}
        ]
      }
    ];
    await expectLater(repository.loadScanRecords(), throwsFormatException);
    tables['ultrasound_scan_records'] = [];
    tables['encounter'] = [
      {'id': 'legacy', 'mother_id': 'patient-one', 'us_obstetrics': 'QA'}
    ];
    await expectLater(repository.loadScanRecords(), throwsFormatException);
  });

  test('classification save writes authenticated patient and model provenance',
      () async {
    final result = await repository.saveScanRecord(
        patient: patient(), analysis: analysis(), scanType: ScanType.aiGuided);
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['patient_id'], 'patient-one');
    expect(body['user_id'], uid);
    expect(body['model_id'], 'ultrasound');
    expect(body['examination_id'], 'exam-one');
    expect(body['analysis_provider'], 'edgeDevice');
    expect(result.id, 'saved-scan');
    expect(result.patientName, 'Synthetic QA');
    expect(result.findings.single.finding, 'Synthetic finding');
  });

  test(
      'uncalibrated segmentation round trips without invented risk or millimetres',
      () async {
    final segmentation = UltrasoundSegmentation.fromDeviceJson({
      'found': false,
      'image_size': [400, 300],
      'timings_ms': {'inference': 2}
    });
    final result = await repository.saveScanRecord(
        patient: patient(),
        analysis: analysis(segmentation: segmentation),
        scanType: ScanType.manual);
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['overall_level'], isNull);
    expect(body['recommendation'], isNull);
    expect(body['findings'], isEmpty);
    expect(result.result, 'segmentation');
    tables['ultrasound_scan_records'] = [
      {
        ...savedRow(),
        'overall_level': null,
        'segmentation': body['segmentation']
      }
    ];
    final reopened = (await repository.loadScanRecords()).single;
    expect(reopened.segmentation!.imageWidth, 400);
    expect(reopened.segmentation!.circumferenceMm, isNull);
  });

  test('failed, uncorrelated and unprovenanced analyses never write', () async {
    for (final value in [
      analysis(error: 'failed'),
      analysis(model: ''),
      analysis(exam: null),
      analysis(provider: UltrasoundAnalysisProvider.unavailable)
    ]) {
      await expectLater(
          repository.saveScanRecord(
              patient: patient(), analysis: value, scanType: ScanType.manual),
          throwsStateError);
    }
    expect(requests, isEmpty);
  });

  test('database failure propagates and is not reported as a saved scan',
      () async {
    fail = true;
    await expectLater(
        repository.saveScanRecord(
            patient: patient(),
            analysis: analysis(),
            scanType: ScanType.manual),
        throwsA(isA<PostgrestException>()));
  });
}
