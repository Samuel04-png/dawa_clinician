import '/services/screening_patient_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/backend/supabase/supabase_config.dart';
import '/features/appointments/data/clinician_appointment_repository.dart';

class DashboardClinician {
  const DashboardClinician({required this.id, required this.profileComplete});
  final String id;
  final bool profileComplete;
}

class DashboardPatient {
  const DashboardPatient(
      {required this.id,
      required this.name,
      this.identifier = '',
      this.firstEncounterId,
      this.activityAt,
      this.missingFields = const [],
      this.dateOfBirth,
      this.createdAt,
      this.searchValues = const [],
      this.phone = '',
      this.imported = false});
  final String id, name, identifier;
  final String? firstEncounterId;
  final DateTime? activityAt;
  final List<String> missingFields;
  final DateTime? dateOfBirth, createdAt;
  final List<String> searchValues;
  final String phone;
  final bool imported;
  String get displayName =>
      name.trim().isEmpty ? 'Name not recorded' : name.trim();

  factory DashboardPatient.fromRow(Map<String, dynamic> row) {
    final missing = <String>[];
    final name = patientText(row['name']);
    final dob = DateTime.tryParse(row['dateOfBirth']?.toString() ?? '');
    if (name.isEmpty) missing.add('name');
    if (dob == null) missing.add('date of birth');
    if (patientText(row['phone_number']).isEmpty) missing.add('phone number');
    return DashboardPatient(
      id: row['id'].toString(),
      name: name,
      identifier: patientText(row['mother_id']),
      firstEncounterId: referenceId(patientText(row['first_encounter_id'])),
      activityAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
          DateTime.tryParse(row['created_at']?.toString() ?? ''),
      missingFields: missing,
      dateOfBirth: dob,
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
      phone: patientText(row['phone_number']),
      imported: row['source_project'] == 'dawa_mom' ||
          row['registration_source'] == 'dawa_mom',
      searchValues: [
        'phone_number',
        'nrc',
        'village',
        'clinic_name',
        'address',
        'occupation',
        'source_mother_id',
        'source_user_id'
      ].map((field) => patientText(row[field])).toList(),
    );
  }
}

String patientText(Object? value) => value is String ? value.trim() : '';

String? referenceId(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text.split('/').last;
}

class DashboardAppointment {
  const DashboardAppointment(
      {required this.id,
      required this.patientId,
      required this.patientName,
      required this.startsAt,
      required this.status,
      required this.type,
      this.imported = false});
  final String id, patientId, patientName, status, type;
  final DateTime startsAt;
  final bool imported;
}

DateTime legacyAppointmentStart(Map<String, dynamic> row) {
  final date = DateTime.tryParse(row['date']?.toString() ?? '')?.toLocal();
  if (date == null)
    throw const FormatException('An appointment has no valid date.');
  final time = row['time']?.toString().trim() ?? '';
  if (time.isEmpty) return date;
  final parts = time.split(':');
  final hour = int.tryParse(parts.first);
  final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    throw const FormatException('An appointment has no valid time.');
  }
  return DateTime(date.year, date.month, date.day, hour, minute);
}

bool sameLocalDay(DateTime left, DateTime right) {
  final a = left.toLocal(), b = right.toLocal();
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String dashboardGreeting(DateTime now) {
  final hour = now.toLocal().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// Each record ID is retained independently of name or demographic similarity.
List<DashboardPatient> dashboardPatients(Iterable<Map<String, dynamic>> rows) {
  final byId = <String, Map<String, dynamic>>{};
  final versions = <String, int>{};
  for (final row in rows) {
    final id = patientText(row['id']);
    if (id.isEmpty) continue;
    final dates = ['updated_at', 'created_at', 'source_deleted_at'].map(
        (field) =>
            DateTime.tryParse(row[field]?.toString() ?? '')
                ?.millisecondsSinceEpoch ??
            0);
    final version = dates.reduce((a, b) => a > b ? a : b);
    if (!byId.containsKey(id) || version >= versions[id]!) {
      byId[id] = row;
      versions[id] = version;
    }
  }
  final result = byId.values
      .where((row) => row['source_deleted_at'] == null)
      .map(DashboardPatient.fromRow)
      .toList();
  result.sort((a, b) {
    final order = (b.activityAt?.millisecondsSinceEpoch ?? 0)
        .compareTo(a.activityAt?.millisecondsSinceEpoch ?? 0);
    return order == 0 ? a.id.compareTo(b.id) : order;
  });
  return result;
}

abstract interface class HomeDashboardRepository {
  Future<DashboardClinician?> loadClinician();
  Future<List<DashboardPatient>> loadPatients();
  Future<List<DashboardAppointment>> loadSchedule(String doctorId, DateTime day,
      {int lookbackDays = 0});
}

class SupabaseHomeDashboardRepository implements HomeDashboardRepository {
  const SupabaseHomeDashboardRepository(
      {this.client, this.includeRegistryFields = false});
  final bool includeRegistryFields;
  final SupabaseClient? client;
  SupabaseClient get _client => client ?? supabaseClient;
  Future<T> _request<T>(Future<T> Function() request) => client == null
      ? runSupabaseRequest(request)
      : request().timeout(supabaseRequestTimeout);
  String _userId() {
    final id = _client.auth.currentUser?.id;
    if (id == null)
      throw const AuthException('Sign in to view your dashboard.');
    return id;
  }

  void _checkSession(String userId) {
    if (_userId() != userId)
      throw const AuthException('The signed-in account changed.');
  }

  @override
  Future<DashboardClinician?> loadClinician() async {
    final user = _userId();
    final rows = await _request(() => _client
        .from('doctor')
        .select('id,clinic_name,start_time,end_time,name,phone_number')
        .or('user_Id.eq.user/$user,user_Id.eq.$user')
        .limit(1));
    _checkSession(user);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return DashboardClinician(
        id: row['id'].toString(),
        profileComplete: [
          'clinic_name',
          'start_time',
          'end_time',
          'name',
          'phone_number'
        ].every((field) => (row[field]?.toString() ?? '').trim().isNotEmpty));
  }

  @override
  Future<List<DashboardPatient>> loadPatients() async {
    final user = _userId();
    final rows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      // Uses the current authenticated session and the same mother table as
      // Patients. Server RLS defines visibility. Never use a service-role client.
      final page = await _request(() => _client
          .from('mother')
          .select(includeRegistryFields
              ? '*'
              : 'id,name,mother_id,first_encounter_id,dateOfBirth,phone_number,created_at,updated_at,source_deleted_at')
          .order('id')
          .range(offset, offset + 499));
      _checkSession(user);
      rows.addAll(page);
      if (page.length < 500) break;
      offset += page.length;
    }
    await SupabaseScreeningPatientRepository.cachePatients(user, rows);
    if (includeRegistryFields) {
      // Legacy registry rows sometimes omit first_encounter_id even though a
      // first_encounter points back to the patient. Resolve those associations
      // in batches instead of starting one stream for every visible row.
      final missingLinks = dashboardPatients(rows)
          .where((patient) => patient.firstEncounterId == null)
          .map((patient) => patient.id)
          .toList();
      final links = <String, String>{};
      for (var start = 0; start < missingLinks.length; start += 100) {
        final ids = missingLinks.skip(start).take(100);
        var linkOffset = 0;
        while (true) {
          final page = await _request(() => _client
              .from('first_encounter')
              .select('id,mother_Id')
              .inFilter('mother_Id', [
                for (final id in ids) ...[id, 'mother/$id']
              ])
              .order('id')
              .range(linkOffset, linkOffset + 499));
          _checkSession(user);
          for (final link in page) {
            final patientId = referenceId(link['mother_Id']);
            if (patientId != null)
              links.putIfAbsent(patientId, () => link['id'].toString());
          }
          if (page.length < 500) break;
          linkOffset += page.length;
        }
      }
      for (final row in rows) {
        if (referenceId(patientText(row['first_encounter_id'])) == null &&
            links.containsKey(row['id'])) {
          row['first_encounter_id'] = links[row['id']];
        }
      }
    }
    return dashboardPatients(rows);
  }

  Future<List<DateTime>> loadCalendarDays(String doctorId) async {
    final user = _userId();
    final days = <DateTime>[];
    for (final table in ['encounter', 'appointments']) {
      var offset = 0;
      while (true) {
        final page = await _request(() {
          if (table == 'encounter') {
            return _client
                .from(table)
                .select('id,date')
                .or('doctor_id.eq.doctor/$doctorId,doctor_id.eq.$doctorId')
                .eq('status', 'scheduled')
                .order('id')
                .range(offset, offset + 499);
          }
          return _client
              .from(table)
              .select('id,appointment_date')
              .eq('source_project', 'dawa_mom')
              .inFilter('status', ['pending', 'confirmed', 'rescheduled'])
              .order('id')
              .range(offset, offset + 499);
        });
        _checkSession(user);
        for (final row in page) {
          final date = DateTime.tryParse(
              row[table == 'encounter' ? 'date' : 'appointment_date']
                      ?.toString() ??
                  '');
          if (date != null)
            days.add(table == 'encounter' ? date.toLocal() : date);
        }
        if (page.length < 500) break;
        offset += page.length;
      }
    }
    return days;
  }

  @override
  Future<List<DashboardAppointment>> loadSchedule(String doctorId, DateTime day,
      {int lookbackDays = 0}) async {
    final user = _userId();
    final local = day.toLocal();
    final start = DateTime(local.year, local.month, local.day - lookbackDays);
    final end = DateTime(local.year, local.month, local.day + 1);
    final legacy = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await _request(() => _client
          .from('encounter')
          .select('id,mother_id,date,time,status')
          .or('doctor_id.eq.doctor/$doctorId,doctor_id.eq.$doctorId')
          .eq('status', 'scheduled')
          .gte('date', start.toUtc().toIso8601String())
          .lt('date', end.toUtc().toIso8601String())
          .order('id')
          .range(offset, offset + 499));
      _checkSession(user);
      legacy.addAll(page);
      if (page.length < 500) break;
      offset += page.length;
    }
    final imported = await ClinicianAppointmentRepository(client: client)
        .loadAppointmentsForDate(local, lookbackDays: lookbackDays);
    _checkSession(user);
    final ids = legacy
        .map((row) => referenceId(row['mother_id']))
        .whereType<String>()
        .toSet()
        .toList();
    final names = <String, String>{};
    for (var offset = 0; offset < ids.length; offset += 100) {
      final batch = ids.skip(offset).take(100).toList();
      final rows = await _request(
          () => _client.from('mother').select('id,name').inFilter('id', batch));
      for (final row in rows) {
        names[row['id'].toString()] = row['name']?.toString() ?? '';
      }
    }
    _checkSession(user);
    final appointments = <DashboardAppointment>[];
    for (final row in legacy) {
      final date = legacyAppointmentStart(row);
      final patientId = referenceId(row['mother_id']) ?? '';
      appointments.add(DashboardAppointment(
          id: row['id'].toString(),
          patientId: patientId,
          patientName: names[patientId] ?? 'Patient record unavailable',
          startsAt: date.toLocal(),
          status: 'scheduled',
          type: 'Patient visit'));
    }
    for (final appointment in imported) {
      if (appointment.scheduledStart.isBefore(start) ||
          !appointment.scheduledStart.isBefore(end) ||
          !['pending', 'confirmed', 'rescheduled'].contains(appointment.status))
        continue;
      appointments.add(DashboardAppointment(
          id: appointment.id,
          patientId: appointment.patientRecordId,
          patientName: appointment.patientName,
          startsAt: appointment.scheduledStart,
          status: appointment.status,
          type: appointment.appointmentType.isEmpty
              ? 'Patient visit'
              : appointment.appointmentType,
          imported: true));
    }
    appointments.sort((a, b) => lookbackDays > 0
        ? b.startsAt.compareTo(a.startsAt)
        : a.startsAt.compareTo(b.startsAt));
    return appointments;
  }
}
