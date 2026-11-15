import 'dart:convert';
import 'package:clinician/application/cacx/cacx_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = 'dawa_pending_cacx_screenings_v1';
  setUp(() => SharedPreferences.setMockInitialValues({
        key: jsonEncode([
          {
            'payload': {
              'user_id': 'clinician-a',
              'patient_id': 'patient-a',
              'primary_result': 'Normal'
            }
          },
          {
            'payload': {
              'user_id': 'clinician-b',
              'patient_id': 'patient-b',
              'primary_result': 'Normal'
            }
          },
        ])
      }));

  test('reconnect syncs only the signed-in clinician and retains others',
      () async {
    final uploaded = <Map<String, dynamic>>[];
    await CacxScreeningResultsRepository.syncPending(
        userId: 'clinician-a', upload: (row) async => uploaded.add(row));
    expect(uploaded.single['patient_id'], 'patient-a');
    expect(uploaded.single['id'], isNotNull);
    expect(await CacxScreeningResultsRepository.pendingCount(), 1);
    await CacxScreeningResultsRepository.syncPending(
        userId: 'clinician-a', upload: (_) async => fail('Already synced'));
  });

  test('failed upload retains the result and retries with the same id',
      () async {
    String? firstId;
    await CacxScreeningResultsRepository.syncPending(
        userId: 'clinician-a',
        upload: (row) async {
          firstId = row['id'] as String;
          throw StateError('No internet');
        });
    expect(await CacxScreeningResultsRepository.pendingCount(), 2);
    await CacxScreeningResultsRepository.syncPending(
        userId: 'clinician-a',
        upload: (row) async => expect(row['id'], firstId));
    expect(await CacxScreeningResultsRepository.pendingCount(), 1);
  });
}
