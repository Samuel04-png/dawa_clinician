// Explicitly opt in with ANEMIA_VERIFICATION_CONFIG_FILE pointing to a private
// fixture configuration outside the repo. Never supply credentials in dart-defines.
// Uses synthetic patients and MOCKED inference, not a clinical/device result.
import 'dart:convert';
import 'dart:io';
import 'package:clinician/application/hemonix/models/anemia_result.dart';
import 'package:clinician/application/hemonix/repository/anemia_repository.dart';
import 'package:clinician/application/hemonix/screens/hemonix_app.dart';
import 'package:clinician/backend/supabase/supabase_config.dart';
import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_manager.dart';
import 'package:clinician/services/screening_patient_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _enabled = bool.fromEnvironment('RUN_LIVE_ANEMIA_STORAGE_TESTS');
Map<String, dynamic> _config() {
  final path = Platform.environment['ANEMIA_VERIFICATION_CONFIG_FILE'];
  if (path == null)
    throw StateError('Private synthetic fixture configuration required.');
  final data =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  if (!(data['patient_id'] as String).startsWith('TEST_ANEMIA_'))
    throw StateError('Only synthetic fixture patients are permitted.');
  return data;
}

Future<SupabaseClient> _signIn(String file, {http.Client? transport}) async {
  final credentials =
      jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>;
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: transport ?? http.Client());
  try {
    await client.auth.signInWithPassword(
        email: credentials['email'] as String,
        password: credentials['password'] as String);
  } catch (_) {
    await client.dispose();
    throw StateError('Synthetic verification account sign-in failed.');
  }
  return client;
}

AnemiaResult _result(String id) => AnemiaResult.fromDeviceJson({
      'classification': 'Mild Anemia',
      'class_index': 1,
      'confidence': 0.4,
      'probabilities': {
        'No Anemia': 0.2,
        'Mild Anemia': 0.4,
        'Moderate Anemia': 0.3,
        'Severe Anemia': 0.1
      },
      'disclaimer':
          'SYNTHETIC MOCK INFERENCE FIXTURE. No clinical or physical-device inference was performed.',
      'record_id': 'synthetic-mock',
    }, examinationId: id, deviceId: 'mock://anemia-storage-verification');

class _DropOneSaveResponse extends http.BaseClient {
  final http.Client inner = http.Client();
  bool dropNextSave = true;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await inner.send(request);
    if (dropNextSave &&
        request.url.path.endsWith('/rpc/save_anemia_screening_review') &&
        response.statusCode < 300) {
      dropNextSave = false;
      await response.stream.drain<void>();
      throw http.ClientException(
          'Simulated response interruption after server commit');
    }
    return response;
  }

  @override
  void close() => inner.close();
}

void main() {
  test(
      'authenticated synthetic save, duplicate/interrupted save, reopen, privileges and cross-account isolation',
      () async {
    HttpOverrides.global = null;
    final config = _config();
    final authorized =
        await _signIn(config['authorized_credentials_file'] as String);
    final unauthorized =
        await _signIn(config['unauthorized_credentials_file'] as String);
    final anonymous = SupabaseClient(supabaseUrl, supabaseAnonKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    final report = <String, bool>{
      'physical_device_inference_verified': false,
      'inference_is_mocked': true
    };
    try {
      final repo = SupabaseAnemiaRepository(client: authorized);
      final otherRepo = SupabaseAnemiaRepository(client: unauthorized);
      final permitted = await repo.loadPatients();
      final patient =
          permitted.singleWhere((p) => p.id == config['patient_id']);
      expect(
          permitted.any((p) =>
              p.id == config['other_patient_id'] ||
              p.id == config['unassigned_patient_id']),
          false);
      expect((await otherRepo.loadPatients()).any((p) => p.id == patient.id),
          false);
      report['authorized_patient_list_is_scoped'] = true;
      final result = _result('anemia-verification-${config['run_id']}');
      await expectLater(
          repo.saveReviewed(
              patient: patient,
              result: result,
              notes: 'Synthetic notes',
              reviewConfirmed: false),
          throwsStateError);
      await expectLater(
          repo.saveReviewed(
              patient: patient,
              result: result,
              notes: ' ',
              reviewConfirmed: true),
          throwsStateError);
      await expectLater(
          authorized.rpc('save_anemia_screening_review', params: {
            'p_patient_id': patient.id,
            'p_examination_id': 'no-review-${config['run_id']}',
            'p_device_id': result.deviceId,
            'p_result': result.toDeviceJson(),
            'p_review_notes': 'Synthetic notes',
            'p_review_confirmed': false,
          }),
          throwsA(isA<PostgrestException>()));
      report['review_and_notes_required'] = true;
      final saves = await Future.wait([
        repo.saveReviewed(
            patient: patient,
            result: result,
            notes: 'Synthetic reviewed mocked result',
            reviewConfirmed: true),
        repo.saveReviewed(
            patient: patient,
            result: result,
            notes: 'Synthetic reviewed mocked result',
            reviewConfirmed: true),
      ]);
      final saved = saves.first;
      expect(saves[1].id, saved.id);
      expect(saved.patientId, patient.id);
      expect(saved.userId, authorized.auth.currentUser!.id);
      expect(saved.clinicId, config['clinic_id']);
      expect(saved.modelId, 'anemia');
      expect(saved.result.examinationId, result.examinationId);
      expect(saved.result.deviceId, result.deviceId);
      expect(saved.result.toDeviceJson(), result.toDeviceJson());
      report['authenticated_save_and_complete_provenance'] = true;
      report['concurrent_duplicate_is_idempotent'] = true;
      await expectLater(
          repo.saveReviewed(
              patient: patient,
              result: _result(result.examinationId),
              notes: 'Different duplicate notes',
              reviewConfirmed: true),
          throwsA(isA<PostgrestException>()));
      report['conflicting_duplicate_rejected'] = true;
      await expectLater(
          repo.saveReviewed(
              patient: ScreeningPatient(
                  id: config['unassigned_patient_id'] as String,
                  name: 'SYNTHETIC'),
              result: _result('forbidden-${config['run_id']}'),
              notes: 'Synthetic review',
              reviewConfirmed: true),
          throwsA(isA<PostgrestException>()));
      await expectLater(
          otherRepo.saveReviewed(
              patient: patient,
              result: _result('unauthorized-${config['run_id']}'),
              notes: 'Synthetic review',
              reviewConfirmed: true),
          throwsA(isA<PostgrestException>()));
      expect(await otherRepo.loadRecord(saved.id), isNull);
      await expectLater(
          unauthorized.from('anemia_screening_records').update(
              {'review_notes': 'Unauthorized modification'}).eq('id', saved.id),
          throwsA(isA<PostgrestException>()));
      await expectLater(
          unauthorized
              .from('anemia_screening_records')
              .delete()
              .eq('id', saved.id),
          throwsA(isA<PostgrestException>()));
      await expectLater(
          anonymous.from('anemia_screening_records').select('id').limit(1),
          throwsA(isA<PostgrestException>()));
      await expectLater(
          unauthorized.rpc('grant_anemia_patient_access', params: {
            'p_user_id': unauthorized.auth.currentUser!.id,
            'p_clinic_id': config['clinic_id'],
            'p_patient_id': patient.id
          }),
          throwsA(isA<PostgrestException>()));
      report['unauthorized_account_cannot_read_write_or_self_grant'] = true;
      report['anonymous_access_denied'] = true;
      final transport = _DropOneSaveResponse();
      final interruptedClient = await _signIn(
          config['authorized_credentials_file'] as String,
          transport: transport);
      AnemiaScreeningRecord recovered;
      try {
        final interruptedRepo =
            SupabaseAnemiaRepository(client: interruptedClient);
        final interruptedResult =
            _result('anemia-interrupted-${config['run_id']}');
        var failed = false;
        try {
          await interruptedRepo.saveReviewed(
              patient: patient,
              result: interruptedResult,
              notes: 'Synthetic interrupted-save review',
              reviewConfirmed: true);
        } catch (_) {
          failed = true;
        }
        expect(failed, true);
        recovered = await interruptedRepo.saveReviewed(
            patient: patient,
            result: interruptedResult,
            notes: 'Synthetic interrupted-save review',
            reviewConfirmed: true);
        final duplicates = await authorized
            .from('anemia_screening_records')
            .select('id')
            .eq('examination_id', interruptedResult.examinationId);
        expect(duplicates.length, 1);
        report['interrupted_save_retry_recovers_exactly_one_record'] = true;
      } finally {
        await interruptedClient.dispose();
      }
      final fresh =
          await _signIn(config['authorized_credentials_file'] as String);
      try {
        final reopened =
            await SupabaseAnemiaRepository(client: fresh).loadRecord(saved.id);
        expect(reopened, isNotNull);
        expect(reopened!.result.toDeviceJson(), result.toDeviceJson());
        expect(reopened.patientId, patient.id);
        expect(reopened.userId, fresh.auth.currentUser!.id);
        report['fresh_authenticated_flutter_client_reopens_record'] = true;
      } finally {
        await fresh.dispose();
      }
      final artifact = File(
          '${File(Platform.environment['ANEMIA_VERIFICATION_CONFIG_FILE']!).parent.path}/storage-live-report.json');
      artifact.writeAsStringSync(jsonEncode({
        ...report,
        'saved_record_id': saved.id,
        'interrupted_record_id': recovered.id,
        'interrupted_examination_id': recovered.result.examinationId
      }));
      // No account identifiers, credentials, images or patient details in test output.
      for (final entry in report.entries) {
        if (entry.value && entry.key != 'inference_is_mocked') {
          print('SUPABASE PASS: ${entry.key}');
        }
      }
    } finally {
      await authorized.dispose();
      await unauthorized.dispose();
      await anonymous.dispose();
    }
  }, skip: !_enabled, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets(
      'fresh application history reopens a saved synthetic screening via authenticated Supabase',
      (tester) async {
    HttpOverrides.global = null;
    final fontCache = Directory('/tmp/dawa-anemia-verification/font-cache')
      ..createSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => fontCache.path);

    final config = _config();
    final client = await tester.runAsync(
        () => _signIn(config['authorized_credentials_file'] as String));
    await tester.runAsync(
        () => SupabaseAnemiaRepository(client: client!).loadRecords());
    final report = jsonDecode(File(
            '${File(Platform.environment['ANEMIA_VERIFICATION_CONFIG_FILE']!).parent.path}/storage-live-report.json')
        .readAsStringSync()) as Map<String, dynamic>;
    final manager = EdgeDeviceManager(
        client: EdgeDeviceClient(
            config: const EdgeDeviceConfig(baseUrl: 'http://localhost'),
            httpClient: MockClient((_) async => http.Response(
                '{"active":"anemia","state":"ready","ready":true}', 200))));
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    try {
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
            home: HemonixApp(
                deviceManager: manager,
                repository: SupabaseAnemiaRepository(client: client!))));
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pump();
      await tester.tap(find.byTooltip('Screening history'));
      await tester.pump();
      for (var i = 0; i < 60 && find.byType(ListTile).evaluate().isEmpty; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 250)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(ListTile), findsAtLeastNWidgets(1));
      await tester.runAsync(() async {
        await tester.tap(find.byType(ListTile).first);
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      for (var i = 0;
          i < 60 && find.byType(AlertDialog).evaluate().isEmpty;
          i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 250)));
        await tester.pump();
      }
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Examination: ${report['interrupted_examination_id']}'),
          findsOneWidget);
      expect(find.text('AI estimate: Mild Anemia'), findsOneWidget);
      expect(find.textContaining('SYNTHETIC MOCK INFERENCE FIXTURE'),
          findsOneWidget);
      report['fresh_application_history_reopen_verified'] = true;
      File('${File(Platform.environment['ANEMIA_VERIFICATION_CONFIG_FILE']!).parent.path}/storage-live-report.json')
          .writeAsStringSync(jsonEncode(report));
      print(
          'SUPABASE/UI PASS: fresh application reopened reviewed synthetic screening through authenticated client');
    } finally {
      await tester.pumpWidget(const SizedBox());
      manager.dispose();
      await tester.runAsync(() => client?.dispose() ?? Future<void>.value());
    }
  }, skip: !_enabled, timeout: const Timeout(Duration(minutes: 2)));
}
