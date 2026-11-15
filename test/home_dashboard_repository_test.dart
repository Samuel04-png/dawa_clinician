import 'dart:convert';
import 'package:clinician/application/home/data/home_dashboard_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Future<SupabaseClient> client(http.Response Function(http.Request) handle,
      {bool signedIn = true}) async {
    final result = SupabaseClient('http://localhost', 'public-test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      final response = handle(request);
      return http.Response(response.body, response.statusCode,
          request: request, headers: {'content-type': 'application/json'});
    }));
    addTearDown(result.dispose);
    if (signedIn) {
      await result.auth.setInitialSession(jsonEncode({
        'access_token': 'test-token',
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
        'expires_in': 3600,
        'user': {
          'id': '00000000-0000-4000-a000-000000000001',
          'aud': 'authenticated',
          'email': 'test@example.invalid',
          'created_at': '2026-11-01T00:00:00Z'
        },
      }));
    }
    return result;
  }

  test(
      'registry query retains search fields and resolves legacy first encounter links in batches',
      () async {
    final requests = <http.Request>[];
    final database = await client((request) {
      requests.add(request);
      expect(request.headers['Authorization'], 'Bearer test-token');
      if (request.url.path.endsWith('/mother')) {
        expect(request.url.queryParameters['select'], equals('*'));
        return http.Response(
            jsonEncode([
              {
                'id': 'one',
                'name': 'Same name',
                'nrc': '123/45/6',
                'clinic_name': 'Clinic',
                'phone_number': '0970000000'
              },
              {
                'id': 'two',
                'name': 'Same name',
                'first_encounter_id': 'first_encounter/existing'
              },
              {
                'id': 'removed',
                'name': 'Deleted',
                'source_deleted_at': '2026-11-01T00:00:00Z'
              },
            ]),
            200);
      }
      expect(request.url.path, endsWith('/first_encounter'));
      final filter = request.url.queryParameters['mother_Id']!;
      expect(filter, contains('mother/one'));
      expect(filter, contains('one'));
      expect(filter, isNot(contains('two')));
      expect(filter, isNot(contains('removed')));
      return http.Response('[{"id":"resolved","mother_Id":"mother/one"}]', 200);
    });
    final patients = await SupabaseHomeDashboardRepository(
            client: database, includeRegistryFields: true)
        .loadPatients();
    expect(requests.length, 2);
    expect(patients.length, 2);
    expect(
        patients.firstWhere((p) => p.id == 'one').firstEncounterId, 'resolved');
    expect(
        patients.firstWhere((p) => p.id == 'two').firstEncounterId, 'existing');
    expect(patients.firstWhere((p) => p.id == 'one').searchValues,
        contains('123/45/6'));
  });

  test(
      'failed legacy association lookup keeps registry unavailable instead of asserting incomplete relationships',
      () async {
    final database = await client((request) => request.url.path
            .endsWith('/mother')
        ? http.Response('[{"id":"one","name":"Patient"}]', 200)
        : http.Response('{"code":"42501","message":"permission denied"}', 403));
    expect(
        SupabaseHomeDashboardRepository(
                client: database, includeRegistryFields: true)
            .loadPatients(),
        throwsA(isA<PostgrestException>()));
  });

  test(
      'deployed mother rows without optional search columns still load, including malformed fields',
      () {
    final records = dashboardPatients([
      {'id': 'one', 'name': 'Existing patient', 'mother_id': 'DM-1'},
      {
        'id': 'two',
        'name': {'unexpected': 'value'},
        'mother_id': ['invalid'],
        'phone_number': 123,
        'dateOfBirth': 'invalid'
      },
      {'name': 'Unidentifiable row'},
      {'id': 'three', 'name': 'Another valid patient'},
    ]);
    expect(records.map((p) => p.id), ['one', 'three', 'two']);
    final malformed = records.firstWhere((p) => p.id == 'two');
    expect(malformed.displayName, 'Name not recorded');
    expect(malformed.identifier, isEmpty);
    expect(malformed.missingFields, ['name', 'date of birth', 'phone number']);
  });

  test('registration completeness follows required fields, not first encounter',
      () {
    final complete = DashboardPatient.fromRow({
      'id': 'a',
      'name': 'Patient',
      'phone_number': '0970000000',
      'dateOfBirth': '1990-01-01'
    });
    expect(complete.missingFields, isEmpty);
    expect(complete.firstEncounterId, isNull);
    final incomplete = DashboardPatient.fromRow(
        {'id': 'b', 'name': 'Patient', 'occupation': '', 'nrc': ''});
    expect(incomplete.missingFields, ['date of birth', 'phone number']);
  });

  test(
      'recent sorting uses timestamps and deduplicates IDs without merging names',
      () {
    final records = dashboardPatients([
      {'id': 'one', 'name': 'Same name', 'updated_at': '2026-11-01T00:00:00Z'},
      {'id': 'two', 'name': 'Same name', 'updated_at': '2026-11-03T00:00:00Z'},
      {
        'id': 'one',
        'name': 'Updated name',
        'updated_at': '2026-11-04T00:00:00Z'
      },
      {
        'id': 'deleted',
        'name': 'Removed',
        'source_deleted_at': '2026-11-05T00:00:00Z'
      },
    ]);
    expect(records.map((p) => p.id), ['one', 'two']);
    expect(records.first.name, 'Updated name');
  });

  test('a later deletion cannot resurrect an earlier copy of the same ID', () {
    expect(
        dashboardPatients([
          {
            'id': 'one',
            'name': 'Patient',
            'updated_at': '2026-11-01T00:00:00Z'
          },
          {
            'id': 'one',
            'name': 'Patient',
            'source_deleted_at': '2026-11-03T00:00:00Z'
          },
        ]),
        isEmpty);
  });

  test('greeting and day boundaries follow local time', () {
    expect(dashboardGreeting(DateTime(2026, 11, 12, 9)), 'Good morning');
    expect(dashboardGreeting(DateTime(2026, 11, 12, 12)), 'Good afternoon');
    expect(dashboardGreeting(DateTime(2026, 11, 12, 17)), 'Good evening');
    final midnight = DateTime(2026, 11, 12);
    expect(sameLocalDay(midnight.toUtc(), midnight), true);
    expect(
        sameLocalDay(midnight.subtract(const Duration(seconds: 1)), midnight),
        false);
    expect(
        legacyAppointmentStart(
            {'date': midnight.toUtc().toIso8601String(), 'time': '09:45'}),
        DateTime(2026, 11, 12, 9, 45));
    expect(
        () => legacyAppointmentStart({'date': 'bad'}), throwsFormatException);
  });

  test('patient pagination counts more than the default response limit',
      () async {
    final offsets = <int>[];
    final transport = await client((request) {
      expect(request.url.path, '/rest/v1/mother');
      final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
      offsets.add(offset);
      return http.Response(
          jsonEncode(List.generate(
              offset == 0 ? 500 : 1,
              (i) => {
                    'id': 'patient-${offset + i}',
                    'name': 'Patient ${offset + i}'
                  })),
          200);
    });
    final records =
        await SupabaseHomeDashboardRepository(client: transport).loadPatients();
    expect(records.length, 501);
    expect(offsets, [0, 500]);
  });

  test(
      'failed patient request propagates permission failure without empty fallback',
      () async {
    final transport = await client(
        (_) => http.Response('{"message":"Denied","code":"42501"}', 403));
    await expectLater(
        SupabaseHomeDashboardRepository(client: transport).loadPatients(),
        throwsA(isA<PostgrestException>()));
  });

  test('unsigned requests never retrieve patient data', () async {
    var requests = 0;
    final transport = await client((_) {
      requests++;
      return http.Response('[]', 200);
    }, signedIn: false);
    await expectLater(
        SupabaseHomeDashboardRepository(client: transport).loadPatients(),
        throwsA(isA<AuthException>()));
    expect(requests, 0);
  });

  test(
      'schedule combines real sources, filters clinician and local bounds, and sorts time',
      () async {
    final day = DateTime(2026, 11, 12);
    final transport = await client((request) {
      final query = request.url.queryParameters;
      if (request.url.path.endsWith('/encounter')) {
        expect(query['or'], contains('doctor/doctor-1'));
        expect(request.url.queryParametersAll['date'],
            contains('gte.${day.toUtc().toIso8601String()}'));
        return http.Response(
            jsonEncode([
              {
                'id': 'legacy-1',
                'mother_id': 'mother/p-1',
                'date': day.toUtc().toIso8601String(),
                'time': '10:30',
                'status': 'scheduled'
              }
            ]),
            200);
      }
      if (request.url.path.endsWith('/appointments')) {
        expect(query['appointment_date'], 'eq.2026-11-12');
        expect(query['source_project'], 'eq.dawa_mom');
        return http.Response(
            jsonEncode([
              {
                'id': 'imported-1',
                'patient_record_id': 'p-1',
                'appointment_date': '2026-11-12',
                'start_time': '08:00',
                'end_time': '08:30',
                'status': 'confirmed'
              }
            ]),
            200);
      }
      if (request.url.path.endsWith('/mother'))
        return http.Response('[{"id":"p-1","name":"Patient"}]', 200);
      throw StateError('Unexpected request');
    });
    final rows = await SupabaseHomeDashboardRepository(client: transport)
        .loadSchedule('doctor-1', day);
    expect(rows.map((r) => r.id), ['imported-1', 'legacy-1']);
    expect(rows.last.startsAt.hour, 10);
    expect(rows.first.patientName, 'Patient');
  });

  test('a failed imported feed cannot become a partial successful count',
      () async {
    final transport = await client((request) =>
        request.url.path.endsWith('/appointments')
            ? http.Response('{"message":"Denied","code":"42501"}', 403)
            : http.Response('[]', 200));
    await expectLater(
        SupabaseHomeDashboardRepository(client: transport)
            .loadSchedule('doctor-1', DateTime(2026, 11, 12)),
        throwsA(isA<PostgrestException>()));
  });
}
