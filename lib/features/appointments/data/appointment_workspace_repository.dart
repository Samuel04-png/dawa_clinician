import 'package:supabase_flutter/supabase_flutter.dart';
import '/application/home/data/home_dashboard_repository.dart';
import '/backend/supabase/supabase_config.dart';
import '../domain/appointment_entry.dart';
import 'clinician_appointment_repository.dart';

class AppointmentWorkspaceRepository extends ClinicianAppointmentRepository {
  const AppointmentWorkspaceRepository({super.client});
  SupabaseClient get database => client ?? supabaseClient;
  Future<T> request<T>(Future<T> Function() run) => client == null
      ? runSupabaseRequest(run)
      : run().timeout(supabaseRequestTimeout);
  String get userId =>
      database.auth.currentUser?.id ??
      (throw const AuthException('Sign in to manage appointments.'));
  void checkUser(String id) {
    if (userId != id)
      throw const AuthException('The signed-in account changed.');
  }

  Future<DashboardClinician?> loadClinician() =>
      SupabaseHomeDashboardRepository(client: client).loadClinician();

  Future<List<DashboardPatient>> loadSchedulingPatients() =>
      SupabaseHomeDashboardRepository(client: client).loadPatients();

  Future<List<AppointmentEntry>> loadAppointments(String doctorId) async {
    final user = userId;
    final bookings = <Map<String, dynamic>>[],
        encounters = <Map<String, dynamic>>[];
    for (final legacy in [false, true]) {
      var offset = 0;
      while (true) {
        final query = database
            .from(legacy ? 'encounter' : 'appointments')
            .select(legacy
                ? 'id,mother_id,doctor_id,date,time,status,updated_at,performed_by,appointment_id'
                : '*');
        final scoped = legacy
            ? query.or('doctor_id.eq.$doctorId,doctor_id.eq.doctor/$doctorId')
            : query.or(
                'assigned_doctor_id.eq.$doctorId,and(source_project.eq.clinician,doctor_id.in.($doctorId,doctor/$doctorId))');
        final page =
            await request(() => scoped.order('id').range(offset, offset + 499));
        checkUser(user);
        (legacy ? encounters : bookings).addAll(page);
        if (page.length < 500) break;
        offset += page.length;
      }
    }
    final patientIds = <String>{
      for (final row in bookings)
        if (referenceId(row['patient_record_id'] ??
                row['mother_id'] ??
                row['mother_Id'])
            case final String id)
          id,
      for (final row in encounters)
        if (referenceId(row['mother_id']) case final String id) id,
    }.toList();
    final patients = <String, Map<String, dynamic>>{};
    for (var offset = 0; offset < patientIds.length; offset += 100) {
      final page = await request(() => database
          .from('mother')
          .select('id,name,mother_id,first_encounter_id,source_deleted_at')
          .inFilter('id', patientIds.skip(offset).take(100).toList()));
      checkUser(user);
      for (final row in page)
        if (row['source_deleted_at'] == null)
          patients[patientText(row['id'])] = row;
    }
    final linkedEncounters = <String, Map<String, dynamic>>{};
    for (final row in encounters) {
      final appointment = referenceId(row['appointment_id']);
      if (appointment != null) linkedEncounters[appointment] = row;
    }
    final result = <AppointmentEntry>[];
    for (final legacy in [false, true]) {
      for (final row in legacy ? encounters : bookings) {
        final id = patientText(row['id']);
        if (id.isEmpty) continue;
        // An imported appointment and its assessment encounter form one booking.
        if (legacy &&
            linkedEncounters.containsKey(referenceId(row['appointment_id'])) &&
            bookings.any((b) => b['id'] == referenceId(row['appointment_id'])))
          continue;
        final patientId = referenceId(legacy
                ? row['mother_id']
                : row['patient_record_id'] ??
                    row['mother_id'] ??
                    row['mother_Id']) ??
            '';
        final patient = patients[patientId];
        DateTime? startsAt;
        if (legacy) {
          final date = DateTime.tryParse(patientText(row['date']));
          if (date != null) {
            final civil = appointmentClinicTime(date);
            startsAt =
                _withTime(civil, patientText(row['time']), fallback: civil);
          }
        } else {
          final date = DateTime.tryParse(patientText(row['appointment_date']));
          if (date != null)
            startsAt = _withTime(date, patientText(row['start_time']));
          else if (DateTime.tryParse(patientText(row['date']))
              case final DateTime instant) {
            final civil = appointmentClinicTime(instant);
            startsAt =
                _withTime(civil, patientText(row['time']), fallback: civil);
          }
        }
        final associated = legacy ? row : linkedEncounters[id];
        result.add(AppointmentEntry(
            id: id,
            legacy: legacy,
            source: legacy
                ? 'clinician'
                : patientText(row['source_project']).isEmpty
                    ? 'other'
                    : patientText(row['source_project']),
            patientId: patientId,
            patientName: patientText(patient?['name']),
            patientIdentifier: patientText(patient?['mother_id']),
            patientUnavailable: patientId.isNotEmpty && patient == null,
            status: patientText(row['status']).toLowerCase(),
            startsAt: startsAt,
            endTime: _validTime(patientText(row['end_time'])) ?? '',
            type:
                legacy ? 'Patient visit' : patientText(row['appointment_type']),
            reason: patientText(row['reason']),
            notes: patientText(row['notes']),
            version: row['updated_at'] is String
                ? row['updated_at'] as String
                : null,
            firstEncounterId: referenceId(patient?['first_encounter_id']),
            performedBy: referenceId(associated?['performed_by']),
            encounterId: associated?['id']?.toString(),
            encounterStatus: associated?['status']?.toString(),
            integrationStatus: patientText(row['integration_status'])));
      }
    }
    result.sort((a, b) {
      if (a.startsAt == null)
        return b.startsAt == null ? a.key.compareTo(b.key) : 1;
      if (b.startsAt == null) return -1;
      final order = a.startsAt!.compareTo(b.startsAt!);
      return order == 0 ? a.key.compareTo(b.key) : order;
    });
    return result;
  }

  Future<void> changeAppointment(
      AppointmentEntry entry, String doctorId, String status,
      {DateTime? start, String? endTime}) async {
    final user = userId;
    if (entry.version == null) throw const AppointmentChangedException();
    final allowed = switch (entry.status) {
      'pending' => ['confirmed', 'declined', 'rescheduled'],
      'confirmed' || 'rescheduled' => ['rescheduled', 'cancelled', 'completed'],
      'scheduled' => ['rescheduled', 'canceled'],
      _ => <String>[],
    };
    if (!allowed.contains(status)) throw const AppointmentChangedException();
    if (status == 'rescheduled' && start == null)
      throw const FormatException('A new time is required.');
    if (entry.imported) {
      await request(() {
        checkUser(user);
        return database.rpc('update_dawa_mom_appointment_if_current', params: {
          'p_appointment_id': entry.id,
          'p_expected_updated_at': entry.version,
          'p_expected_status': entry.status,
          'p_status': status,
          'p_appointment_date': start == null ? null : _date(start),
          'p_start_time': start == null ? null : _time(start),
          'p_end_time': endTime,
        });
      });
    } else {
      final payload = <String, dynamic>{
        'status': entry.legacy && status == 'rescheduled' ? 'scheduled' : status
      };
      if (start != null) {
        payload.addAll({
          'date': appointmentUtc(start).toIso8601String(),
          'time': _time(start)
        });
        if (entry.legacy)
          payload['next_visit'] = appointmentUtc(start).toIso8601String();
        else
          payload.addAll({
            'appointment_date': _date(start),
            'start_time': _time(start),
            'end_time': endTime
          });
      }
      final rows = await request(() {
        checkUser(user);
        return database
            .from(entry.legacy ? 'encounter' : 'appointments')
            .update(payload)
            .eq('id', entry.id)
            .eq('status', entry.status)
            .eq('updated_at', entry.version!)
            .or('doctor_id.eq.$doctorId,doctor_id.eq.doctor/$doctorId')
            .select('id');
      });
      if (rows.length != 1) throw const AppointmentChangedException();
    }
    checkUser(user);
  }

  static String _date(DateTime v) =>
      '${v.year.toString().padLeft(4, '0')}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
  static String _time(DateTime v) =>
      '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
  static String? _validTime(String value) {
    final match =
        RegExp(r'^(\d{2}):(\d{2})(?::\d{2}(?:\.\d+)?)?$').firstMatch(value);
    if (match == null || int.parse(match[1]!) > 23 || int.parse(match[2]!) > 59)
      return null;
    return '${match[1]}:${match[2]}';
  }

  static DateTime? _withTime(DateTime date, String text, {DateTime? fallback}) {
    if (text.isEmpty) return fallback;
    final time = _validTime(text);
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day,
        int.parse(time.substring(0, 2)), int.parse(time.substring(3, 5)));
  }
}
