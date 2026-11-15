import '/backend/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/clinician_appointment.dart';

class ClinicianAppointmentRepository {
  const ClinicianAppointmentRepository({this.client});
  final SupabaseClient? client;
  SupabaseClient get _client => client ?? supabaseClient;
  Future<T> _request<T>(Future<T> Function() request) => client == null
      ? runSupabaseRequest(request)
      : request().timeout(supabaseRequestTimeout);

  Stream<List<ClinicianAppointment>> watchDawaMomAppointments() {
    return _client
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('source_project', 'dawa_mom')
        .order('appointment_date')
        .asyncMap(_hydrateAppointments);
  }

  Future<List<ClinicianAppointment>> loadAppointmentsForDate(DateTime day,
      {int lookbackDays = 0}) async {
    final rows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await _request(() {
        final base = _client
            .from('appointments')
            .select()
            .eq('source_project', 'dawa_mom');
        final query = lookbackDays == 0
            ? base.eq('appointment_date', _dateOnly(day))
            : base
                .gte(
                    'appointment_date',
                    _dateOnly(
                        DateTime(day.year, day.month, day.day - lookbackDays)))
                .lte('appointment_date', _dateOnly(day));
        return query
            .inFilter('status', ['pending', 'confirmed', 'rescheduled'])
            .order('id')
            .range(offset, offset + 499);
      });
      rows.addAll(page);
      if (page.length < 500) break;
      offset += page.length;
    }
    for (final row in rows) {
      final time = row['start_time']?.toString() ?? '';
      final parts = time.split(':');
      final hour = int.tryParse(parts.first);
      final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
      if (DateTime.tryParse(row['appointment_date']?.toString() ?? '') ==
              null ||
          hour == null ||
          minute == null ||
          hour < 0 ||
          hour > 23 ||
          minute < 0 ||
          minute > 59) {
        throw const FormatException(
            'An appointment has an invalid date or time.');
      }
    }
    return _hydrateAppointments(rows);
  }

  Stream<List<ClinicianNotification>> watchNotifications() {
    if (_client.auth.currentUser == null) return Stream.value(const []);
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .map(
                (row) => ClinicianNotification.fromRow(
                  Map<String, dynamic>.from(row),
                ),
              )
              .toList(growable: false),
        );
  }

  Future<void> updateStatus({
    required String appointmentId,
    required String status,
    DateTime? appointmentDate,
    String? startTime,
    String? endTime,
    String? patientSafeMessage,
  }) async {
    await _request(
      () => _client.rpc(
        'update_dawa_mom_appointment_status',
        params: {
          'p_appointment_id': appointmentId,
          'p_status': status,
          'p_appointment_date':
              appointmentDate == null ? null : _dateOnly(appointmentDate),
          'p_start_time': startTime,
          'p_end_time': endTime,
          'p_patient_safe_message': patientSafeMessage,
        },
      ),
    );
  }

  Future<void> markNotificationRead(String notificationId) async {
    if (notificationId.isEmpty) return;
    await _request(
      () => _client.from('notifications').update({
        'is_read': true,
        'read_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', notificationId),
    );
  }

  Future<List<ClinicianAppointment>> _hydrateAppointments(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return const [];

    final patientIds = rows
        .map((row) => row['patient_record_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final clinicIds = rows
        .map((row) => row['clinic_record_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final patientNames = <String, String>{};
    final clinicNames = <String, String>{};

    if (patientIds.isNotEmpty) {
      final patientRows = await _request(
        () =>
            _client.from('mother').select('id,name').inFilter('id', patientIds),
      );
      for (final dynamic rawRow in patientRows) {
        final row = Map<String, dynamic>.from(rawRow as Map);
        patientNames[row['id']?.toString() ?? ''] =
            row['name']?.toString() ?? '';
      }
    }

    if (clinicIds.isNotEmpty) {
      final clinicRows = await _request(
        () =>
            _client.from('clinic').select('id,name').inFilter('id', clinicIds),
      );
      for (final dynamic rawRow in clinicRows) {
        final row = Map<String, dynamic>.from(rawRow as Map);
        clinicNames[row['id']?.toString() ?? ''] =
            row['name']?.toString() ?? '';
      }
    }

    final appointments = rows.map((rawRow) {
      final row = Map<String, dynamic>.from(rawRow);
      final patientId = row['patient_record_id']?.toString() ?? '';
      final clinicId = row['clinic_record_id']?.toString() ?? '';
      return ClinicianAppointment.fromRow(
        row,
        patientName: _displayName(patientNames[patientId], 'Patient'),
        clinicName: _displayName(clinicNames[clinicId], 'Clinic'),
      );
    }).toList(growable: false);
    appointments.sort(
      (left, right) => left.scheduledStart.compareTo(right.scheduledStart),
    );
    return appointments;
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _displayName(String? value, String fallback) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }
}
