import '/backend/supabase/supabase_config.dart';

import '../domain/clinician_appointment.dart';

class ClinicianAppointmentRepository {
  const ClinicianAppointmentRepository();

  Stream<List<ClinicianAppointment>> watchDawaMomAppointments() {
    return supabaseClient
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('source_project', 'dawa_mom')
        .order('appointment_date')
        .asyncMap(_hydrateAppointments);
  }

  Stream<List<ClinicianNotification>> watchNotifications() {
    return supabaseClient
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
    await runSupabaseRequest(
      () => supabaseClient.rpc(
        'update_dawa_mom_appointment_status',
        params: {
          'p_appointment_id': appointmentId,
          'p_status': status,
          'p_appointment_date': appointmentDate == null
              ? null
              : _dateOnly(appointmentDate),
          'p_start_time': startTime,
          'p_end_time': endTime,
          'p_patient_safe_message': patientSafeMessage,
        },
      ),
    );
  }

  Future<void> markNotificationRead(String notificationId) async {
    if (notificationId.isEmpty) return;
    await runSupabaseRequest(
      () => supabaseClient
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', notificationId),
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
      final patientRows = await runSupabaseRequest(
        () => supabaseClient
            .from('mother')
            .select('id,name')
            .inFilter('id', patientIds),
      );
      for (final dynamic rawRow in patientRows) {
        final row = Map<String, dynamic>.from(rawRow as Map);
        patientNames[row['id']?.toString() ?? ''] =
            row['name']?.toString() ?? '';
      }
    }

    if (clinicIds.isNotEmpty) {
      final clinicRows = await runSupabaseRequest(
        () => supabaseClient
            .from('clinic')
            .select('id,name')
            .inFilter('id', clinicIds),
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
