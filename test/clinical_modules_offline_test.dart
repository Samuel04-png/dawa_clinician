import 'dart:convert';
import 'package:clinician/services/clinical_offline_store.dart';
import 'package:clinician/services/offline_connectivity_service.dart';
import 'package:clinician/application/hemonix/repository/anemia_repository.dart';
import 'package:clinician/application/hemonix/models/anemia_result.dart';
import 'package:clinician/application/ultrasound/repositories/ultrasound_repository.dart';
import 'package:clinician/application/ultrasound/models/ultrasound_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uid = '00000000-0000-4000-a000-000000000013';
  var networkCalls = 0;
  var failUpload = false;
  void connection(bool online) =>
      OfflineConnectivityService.statusNotifier.value =
          OfflineConnectivitySnapshot(
              internetAvailable: online,
              supabaseReachable: online,
              deviceReachable: true,
              checkedAt: DateTime.now());
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
        anonKey: 'test-key',
        authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          networkCalls++;
          final name = request.url.path.split('/').last;
          Object body = [];
          var status = 200;
          if (name == 'mother' || name == 'list_anemia_patients')
            body = [
              {
                'id': 'patient-1',
                'name': 'Test Patient',
                'clinic_id': 'clinic-1'
              }
            ];
          if (name == 'save_anemia_screening_review') {
            final p = jsonDecode(request.body) as Map<String, dynamic>;
            body = {
              'id': 'saved-anemia',
              'patient_id': p['p_patient_id'],
              'user_id': uid,
              'clinic_id': 'clinic-1',
              'created_at': '2026-11-14T10:00:00Z',
              'result': p['p_result'],
              'examination_id': p['p_examination_id'],
              'device_id': p['p_device_id'],
              'model_id': 'anemia',
              'review_status': 'reviewed',
              'review_notes': p['p_review_notes']
            };
            if (failUpload) {
              status = 503;
              body = {'code': 'unavailable', 'message': 'Outage'};
            }
          }
          if (name == 'ultrasound_scan_records' && request.method == 'POST') {
            body = {
              ...jsonDecode(request.body) as Map<String, dynamic>,
              'id': 'saved-ultrasound',
              'created_at': '2026-11-14T10:00:00Z'
            };
          }
          return http.Response(jsonEncode(body), status,
              headers: {'content-type': 'application/json'}, request: request);
        }));
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    connection(true);
    failUpload = false;
    await Supabase.instance.client.auth.setInitialSession(jsonEncode({
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
    }));
    networkCalls = 0;
  });
  tearDownAll(() async {
    OfflineConnectivityService.statusNotifier.value = null;
    await Supabase.instance.dispose();
  });

  test(
      'anemia and ultrasound load cached patients, save reviewed edge results offline and sync on reconnect',
      () async {
    const anemia = SupabaseAnemiaRepository();
    const ultrasound = SupabaseUltrasoundRepository();
    await anemia.loadPatients();
    await ultrasound.loadPatients();
    connection(false);
    networkCalls = 0;
    final ap = (await anemia.loadPatients()).single;
    final up = (await ultrasound.loadPatients()).single;
    expect(ap.id, up.id);
    final result = AnemiaResult.fromDeviceJson({
      'classification': 'Mild Anemia',
      'class_index': 1,
      'confidence': .4,
      'probabilities': {
        'No Anemia': .2,
        'Mild Anemia': .4,
        'Moderate Anemia': .3,
        'Severe Anemia': .1
      },
      'disclaimer': 'Device prototype disclaimer'
    }, examinationId: 'anemia-exam', deviceId: 'edge-1');
    await anemia.saveReviewed(
        patient: ap,
        result: result,
        notes: 'Reviewed offline',
        reviewConfirmed: true);
    final us = UltrasoundAnalysisResult(
        imageUrl: '',
        findings: [
          const UltrasoundFinding(
              category: 'QA', finding: 'Test', level: FindingLevel.normal)
        ],
        overallAssessment: 'Test assessment',
        overallLevel: FindingLevel.normal,
        recommendation: 'Review',
        provider: UltrasoundAnalysisProvider.edgeDevice,
        examinationId: 'ultrasound-exam',
        modelId: 'ultrasound',
        deviceId: 'edge-1');
    await ultrasound.saveScanRecord(
        patient: up, analysis: us, scanType: ScanType.manual);
    expect((await anemia.loadRecords()).single.reviewNotes, 'Reviewed offline');
    expect((await ultrasound.loadScanRecords()).single.examinationId,
        'ultrasound-exam');
    expect(networkCalls, 0);
    expect(await ClinicalOfflineStore.cached(uid, 'outbox'), hasLength(2));
    connection(true);
    failUpload = true;
    await ClinicalOfflineStore.sync();
    expect(await ClinicalOfflineStore.cached(uid, 'outbox'), hasLength(1));
    failUpload = false;
    await ClinicalOfflineStore.sync();
    expect(await ClinicalOfflineStore.cached(uid, 'outbox'), isEmpty);
  });

  test('anemia never substitutes general patients for authorized assignments',
      () async {
    connection(false);
    await ClinicalOfflineStore.save(uid, 'ultrasound-patients', [
      {'id': 'patient-1', 'name': 'Test'}
    ]);
    await expectLater(
        const SupabaseAnemiaRepository().loadPatients(), throwsStateError);
    expect(networkCalls, 0);
  });

  test(
      'offline cache is isolated by clinician and missing history stays usable',
      () async {
    connection(false);
    await ClinicalOfflineStore.save('another-clinician', 'anemia-patients', [
      {'id': 'private', 'name': 'Private'}
    ]);
    await expectLater(
        const SupabaseAnemiaRepository().loadPatients(), throwsStateError);
    expect(
        await const SupabaseUltrasoundRepository().loadScanRecords(), isEmpty);
    expect(networkCalls, 0);
  });
}
