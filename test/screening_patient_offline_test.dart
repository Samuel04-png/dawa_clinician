import 'dart:async';
import 'package:clinician/services/screening_patient_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var uid = 'clinician-a';
  var offline = false;
  var requests = 0;
  Object? failure;
  late SupabaseScreeningPatientRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    uid = 'clinician-a';
    offline = false;
    requests = 0;
    failure = null;
    repository = SupabaseScreeningPatientRepository(
      userId: () => uid,
      isOffline: () async => offline,
      fetchRows: () async {
        requests++;
        if (failure != null) throw failure!;
        return [
          {'id': 'patient-a', 'name': 'Test Patient'}
        ];
      },
    );
  });

  test(
      'online patient list survives offline repository reopen without a request',
      () async {
    await repository.loadPatients();
    offline = true;
    final reopened = SupabaseScreeningPatientRepository(
      userId: () => uid,
      isOffline: () async => true,
      fetchRows: () async => throw StateError('Must not request network'),
    );
    expect((await reopened.loadPatients()).single.id, 'patient-a');
    expect(requests, 1);
  });

  test('another clinician cannot use the cached patient list', () async {
    await repository.loadPatients();
    offline = true;
    uid = 'clinician-b';
    await expectLater(repository.loadPatients(), throwsStateError);
  });

  test('first offline use requires an online patient download', () async {
    offline = true;
    await expectLater(repository.loadPatients(), throwsStateError);
    expect(requests, 0);
  });

  test('an outage during a request falls back to the cached list', () async {
    await repository.loadPatients();
    repository = SupabaseScreeningPatientRepository(
      userId: () => uid,
      isOffline: () async => ++requests > 2,
      fetchRows: () async => throw TimeoutException('Network unavailable'),
    );
    expect((await repository.loadPatients()).single.id, 'patient-a');
  });

  test('permission errors do not fall back to cached records', () async {
    await repository.loadPatients();
    failure = const PostgrestException(message: 'Denied', code: '42501');
    await expectLater(
        repository.loadPatients(), throwsA(isA<PostgrestException>()));
  });
}
