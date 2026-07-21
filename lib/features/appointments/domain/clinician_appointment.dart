class ClinicianAppointment {
  const ClinicianAppointment({
    required this.id,
    required this.sourceAppointmentId,
    required this.patientRecordId,
    required this.patientName,
    required this.clinicName,
    required this.status,
    required this.appointmentDate,
    required this.startTime,
    required this.endTime,
    required this.appointmentType,
    required this.reason,
    required this.notes,
    required this.integrationStatus,
    required this.integrationErrorCode,
    required this.receivedAt,
    required this.assessmentStatus,
    required this.pregnancyStatus,
    required this.pregnancyLnmp,
    required this.pregnancyEstimatedDueDate,
    required this.pregnancyProvenance,
  });

  final String id;
  final String sourceAppointmentId;
  final String patientRecordId;
  final String patientName;
  final String clinicName;
  final String status;
  final DateTime appointmentDate;
  final String startTime;
  final String endTime;
  final String appointmentType;
  final String reason;
  final String notes;
  final String integrationStatus;
  final String integrationErrorCode;
  final DateTime? receivedAt;
  final String assessmentStatus;
  final String pregnancyStatus;
  final DateTime? pregnancyLnmp;
  final DateTime? pregnancyEstimatedDueDate;
  final String pregnancyProvenance;

  DateTime get scheduledStart =>
      _combineDateAndTime(appointmentDate, startTime);

  DateTime get scheduledEnd => _combineDateAndTime(appointmentDate, endTime);

  bool get isPending => status == 'pending';

  bool get canReschedule =>
      status == 'pending' || status == 'confirmed' || status == 'rescheduled';

  bool get canComplete => status == 'confirmed' || status == 'rescheduled';

  bool get hasAssessmentDraft =>
      assessmentStatus == 'in_progress' ||
      assessmentStatus == 'ready_for_review';

  bool get canCancel =>
      status == 'pending' || status == 'confirmed' || status == 'rescheduled';

  static ClinicianAppointment fromRow(
    Map<String, dynamic> row, {
    required String patientName,
    required String clinicName,
    String assessmentStatus = 'not_started',
    String pregnancyStatus = 'not_provided',
    DateTime? pregnancyLnmp,
    DateTime? pregnancyEstimatedDueDate,
    String pregnancyProvenance = '',
  }) {
    return ClinicianAppointment(
      id: row['id']?.toString() ?? '',
      sourceAppointmentId: row['source_appointment_id']?.toString() ?? '',
      patientRecordId: row['patient_record_id']?.toString() ?? '',
      patientName: patientName,
      clinicName: clinicName,
      status: (row['status']?.toString() ?? 'pending').toLowerCase(),
      appointmentDate: DateTime.tryParse(
            row['appointment_date']?.toString() ?? '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      startTime: _normalizeTime(row['start_time']),
      endTime: _normalizeTime(row['end_time']),
      appointmentType: row['appointment_type']?.toString() ?? '',
      reason: row['reason']?.toString() ?? '',
      notes: row['notes']?.toString() ?? '',
      integrationStatus: row['integration_status']?.toString() ?? '',
      integrationErrorCode: row['integration_error_code']?.toString() ?? '',
      receivedAt: DateTime.tryParse(row['received_at']?.toString() ?? ''),
      assessmentStatus: assessmentStatus,
      pregnancyStatus: pregnancyStatus,
      pregnancyLnmp: pregnancyLnmp,
      pregnancyEstimatedDueDate: pregnancyEstimatedDueDate,
      pregnancyProvenance: pregnancyProvenance,
    );
  }

  static DateTime _combineDateAndTime(DateTime date, String time) {
    final parts = time.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  static String _normalizeTime(dynamic value) {
    final text = value?.toString() ?? '';
    return text.length >= 5 ? text.substring(0, 5) : text;
  }
}

class AppointmentAssessmentDraft {
  const AppointmentAssessmentDraft({
    required this.appointmentId,
    required this.encounterId,
    required this.status,
    required this.version,
    required this.payload,
    required this.lastEditedAt,
  });

  final String appointmentId;
  final String encounterId;
  final String status;
  final int version;
  final Map<String, dynamic> payload;
  final DateTime? lastEditedAt;

  static AppointmentAssessmentDraft? fromRow(Map<String, dynamic>? row) {
    if (row == null) return null;
    final rawPayload = row['assessment_payload'];
    return AppointmentAssessmentDraft(
      appointmentId: row['appointment_id']?.toString() ?? '',
      encounterId: row['id']?.toString() ?? '',
      status: row['assessment_status']?.toString() ?? 'not_started',
      version: int.tryParse(row['assessment_version']?.toString() ?? '') ?? 0,
      payload: rawPayload is Map
          ? Map<String, dynamic>.from(rawPayload)
          : <String, dynamic>{},
      lastEditedAt: DateTime.tryParse(row['last_edited_at']?.toString() ?? ''),
    );
  }
}

class ClinicianNotification {
  const ClinicianNotification({
    required this.id,
    required this.appointmentId,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String appointmentId;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  static ClinicianNotification fromRow(Map<String, dynamic> row) {
    return ClinicianNotification(
      id: row['id']?.toString() ?? '',
      appointmentId: row['appointment_id']?.toString() ?? '',
      type: row['type']?.toString() ?? '',
      title: row['title']?.toString() ?? 'Notification',
      body: row['body']?.toString() ?? '',
      isRead: row['is_read'] == true,
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
