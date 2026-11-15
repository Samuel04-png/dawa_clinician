import 'dart:convert';
import 'package:clinician/features/appointments/data/appointment_workspace_repository.dart';
import 'package:clinician/features/appointments/domain/appointment_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Future<SupabaseClient> database(http.Response Function(http.Request) handle,
      {bool signedIn = true}) async {
    final client = SupabaseClient('http://localhost', 'public-test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      final response = handle(request);
      return http.Response(response.body, response.statusCode,
          request: request, headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    if (signedIn)
      await client.auth.setInitialSession(jsonEncode({
        'access_token': 'test-token',
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
        'user': {
          'id': '00000000-0000-4000-a000-000000000001',
          'aud': 'authenticated',
          'created_at': '2026-11-01T00:00:00Z'
        },
      }));
    return client;
  }

  AppointmentEntry entry({bool legacy = false, String status = 'pending'}) =>
      AppointmentEntry(
          id: 'one',
          legacy: legacy,
          source: legacy ? 'clinician' : 'dawa_mom',
          patientId: 'patient-1',
          patientName: 'Test fixture',
          patientIdentifier: 'TEST-1',
          status: status,
          startsAt: DateTime(2026, 11, 12, 9),
          version: '2026-11-01T07:00:00Z');

  test(
      'views use clinic civil dates and preserve past pending and actual terminal statuses',
      () {
    final now = appointmentClinicTime(DateTime.utc(2026, 11, 11, 22, 30));
    expect(now, DateTime(2026, 11, 12, 0, 30));
    expect(appointmentUtc(now), DateTime.utc(2026, 11, 11, 22, 30));
    expect(entry().inView(AppointmentView.today, now), true);
    expect(entry().inView(AppointmentView.requests, now), true);
    expect(
        entry(status: 'confirmed')
            .inView(AppointmentView.upcoming, DateTime(2026, 11, 11)),
        true);
    final old = AppointmentEntry(
        id: 'old',
        legacy: false,
        source: 'dawa_mom',
        patientId: 'p',
        patientName: '',
        patientIdentifier: '',
        status: 'pending',
        startsAt: DateTime(2026, 10, 15));
    expect(old.inView(AppointmentView.history, now), true);
    expect(old.inView(AppointmentView.requests, now), true);
    expect(old.pastDated(now), true);
    expect(old.statusLabel, 'Pending');
    expect(old.canCancel, false);
    expect(entry(status: 'cancelled').canReschedule, false);
    expect(entry(status: 'declined').closed, true);
  });

  test('patient search combines with source status and date filters', () {
    final appointment = entry();
    expect(
        appointmentMatches(appointment, 'TEST-1', 'dawa_mom', 'pending',
            DateTime(2026, 11, 12)),
        true);
    expect(
        appointmentMatches(
            appointment, 'test fixture', 'clinician', 'all', null),
        false);
    expect(
        appointmentMatches(
            appointment, 'test fixture', 'all', 'confirmed', null),
        false);
    expect(
        appointmentMatches(appointment, 'unknown', 'all', 'all', null), false);
  });

  test(
      'loads both authorized sources, resolves names and avoids duplicate assessment encounters',
      () async {
    final client = await database((request) {
      expect(request.headers['Authorization'], 'Bearer test-token');
      if (request.url.path.endsWith('/appointments')) {
        expect(request.url.queryParameters['or'],
            contains('assigned_doctor_id.eq.doctor-1'));
        return http.Response(
            jsonEncode([
              {
                'id': 'booking',
                'source_project': 'dawa_mom',
                'patient_record_id': 'p1',
                'status': 'pending',
                'appointment_date': '2026-10-15',
                'start_time': '15:30:00',
                'end_time': '16:00:00',
                'updated_at': '2026-11-01T07:00:00Z'
              },
              {
                'id': 'broken-link',
                'source_project': 'dawa_mom',
                'patient_record_id': 'inaccessible',
                'status': 'confirmed',
                'appointment_date': '2026-11-12',
                'start_time': '09:00:00'
              },
              {
                'id': 'invalid',
                'source_project': 'dawa_mom',
                'patient_record_id': 'p1',
                'status': 'pending',
                'appointment_date': 'invalid',
                'start_time': '99:70'
              },
            ]),
            200);
      }
      if (request.url.path.endsWith('/encounter')) {
        expect(request.url.queryParameters['or'], contains('doctor/doctor-1'));
        return http.Response(
            jsonEncode([
              {
                'id': 'assessment',
                'appointment_id': 'booking',
                'mother_id': 'mother/p1',
                'date': '2026-10-15T13:30:00Z',
                'time': '15:30',
                'status': 'scheduled',
                'performed_by': 'doctor/doctor-1'
              },
              {
                'id': 'legacy',
                'mother_id': 'mother/p2',
                'date': '2026-11-11T22:30:00Z',
                'time': '00:30',
                'status': 'scheduled'
              },
            ]),
            200);
      }
      expect(request.url.path, endsWith('/mother'));
      return http.Response(
          '[{"id":"p1","name":"Clinical fixture","mother_id":"TEST-1"},{"id":"p2","name":null,"mother_id":"TEST-2"}]',
          200);
    });
    final records = await AppointmentWorkspaceRepository(client: client)
        .loadAppointments('doctor-1');
    expect(records.length, 4);
    expect(records.where((a) => a.id == 'assessment'), isEmpty);
    expect(
        records.firstWhere((a) => a.id == 'booking').encounterId, 'assessment');
    expect(records.firstWhere((a) => a.id == 'booking').patientName,
        'Clinical fixture');
    expect(records.firstWhere((a) => a.id == 'legacy').startsAt,
        DateTime(2026, 11, 12, 0, 30));
    expect(records.firstWhere((a) => a.id == 'legacy').displayName,
        'Name not recorded');
    expect(records.firstWhere((a) => a.id == 'broken-link').displayName,
        'Linked patient unavailable');
    expect(records.firstWhere((a) => a.id == 'invalid').startsAt, isNull);
  });

  test(
      'unauthenticated load never sends a request and source errors never become an empty success',
      () async {
    var requests = 0;
    final unsigned = await database((_) {
      requests++;
      return http.Response('[]', 200);
    }, signedIn: false);
    await expectLater(
        AppointmentWorkspaceRepository(client: unsigned)
            .loadAppointments('doctor-1'),
        throwsA(isA<AuthException>()));
    expect(requests, 0);
    final denied = await database((_) =>
        http.Response('{"code":"42501","message":"permission denied"}', 403));
    await expectLater(
        AppointmentWorkspaceRepository(client: denied)
            .loadAppointments('doctor-1'),
        throwsA(isA<PostgrestException>()));
  });

  test(
      'Dawa Mom actions call guarded existing workflow with the displayed version',
      () async {
    final client = await database((request) {
      expect(request.url.path,
          '/rest/v1/rpc/update_dawa_mom_appointment_if_current');
      final payload = jsonDecode(request.body) as Map;
      expect(payload['p_appointment_id'], 'one');
      expect(payload['p_expected_status'], 'pending');
      expect(payload['p_expected_updated_at'], '2026-11-01T07:00:00Z');
      expect(payload['p_status'], 'confirmed');
      return http.Response('{"ok":true}', 200);
    });
    await AppointmentWorkspaceRepository(client: client)
        .changeAppointment(entry(), 'doctor-1', 'confirmed');
  });

  test(
      'legacy changes use atomic version and status conditions and detect zero-row conflicts',
      () async {
    final client = await database((request) {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/rest/v1/encounter');
      expect(request.url.queryParameters['status'], 'eq.scheduled');
      expect(
          request.url.queryParameters['updated_at'], 'eq.2026-11-01T07:00:00Z');
      expect(request.url.queryParameters['or'], contains('doctor/doctor-1'));
      expect(jsonDecode(request.body)['status'], 'canceled');
      return http.Response('[]', 200);
    });
    await expectLater(
        AppointmentWorkspaceRepository(client: client).changeAppointment(
            entry(legacy: true, status: 'scheduled'), 'doctor-1', 'canceled'),
        throwsA(isA<AppointmentChangedException>()));
  });

  test('invalid or terminal transitions do not send mutation requests',
      () async {
    var requests = 0;
    final client = await database((_) {
      requests++;
      return http.Response('[]', 200);
    });
    await expectLater(
        AppointmentWorkspaceRepository(client: client).changeAppointment(
            entry(status: 'completed'), 'doctor-1', 'confirmed'),
        throwsA(isA<AppointmentChangedException>()));
    expect(requests, 0);
  });

  test(
      'reschedule keeps Lusaka date and time and converts legacy instants to UTC',
      () async {
    final client = await database((request) {
      final payload = jsonDecode(request.body);
      expect(payload['date'], '2026-11-12T22:30:00.000Z');
      expect(payload['time'], '00:30');
      expect(payload['status'], 'scheduled');
      return http.Response('[{"id":"one"}]', 200);
    });
    await AppointmentWorkspaceRepository(client: client).changeAppointment(
        entry(legacy: true, status: 'scheduled'), 'doctor-1', 'rescheduled',
        start: DateTime(2026, 11, 13, 0, 30));
  });
}
