import 'package:intl/intl.dart';

// The deployed booking RPC uses Africa/Lusaka, which is UTC+02 year-round.
DateTime appointmentClinicTime(DateTime instant) {
  final value = instant.toUtc().add(const Duration(hours: 2));
  return DateTime(value.year, value.month, value.day, value.hour, value.minute,
      value.second);
}

DateTime appointmentUtc(DateTime civil) =>
    DateTime.utc(civil.year, civil.month, civil.day, civil.hour, civil.minute)
        .subtract(const Duration(hours: 2));
DateTime appointmentDay(DateTime civil) =>
    DateTime(civil.year, civil.month, civil.day);

enum AppointmentView {
  today('Today'),
  upcoming('Upcoming'),
  requests('Requests'),
  history('History');

  const AppointmentView(this.label);
  final String label;
}

class AppointmentEntry {
  const AppointmentEntry(
      {required this.id,
      required this.legacy,
      required this.source,
      required this.patientId,
      required this.patientName,
      required this.patientIdentifier,
      required this.status,
      required this.startsAt,
      this.endTime = '',
      this.type = '',
      this.reason = '',
      this.notes = '',
      this.version,
      this.firstEncounterId,
      this.performedBy,
      this.encounterId,
      this.encounterStatus,
      this.integrationStatus = '',
      this.patientUnavailable = false});
  final String id,
      source,
      patientId,
      patientName,
      patientIdentifier,
      status,
      endTime,
      type,
      reason,
      notes,
      integrationStatus;
  final bool legacy, patientUnavailable;
  final DateTime? startsAt;
  final String? version,
      firstEncounterId,
      performedBy,
      encounterId,
      encounterStatus;
  String get key => '${legacy ? 'encounter' : 'booking'}/$id';
  bool get imported => source == 'dawa_mom';
  String get sourceLabel => imported
      ? 'Dawa Mom'
      : source == 'clinician'
          ? 'Clinic'
          : source;
  String get displayName => patientName.trim().isNotEmpty
      ? patientName.trim()
      : patientUnavailable
          ? 'Linked patient unavailable'
          : patientId.isEmpty
              ? 'Patient link missing'
              : 'Name not recorded';
  String get identifier => patientIdentifier.isNotEmpty
      ? 'ID $patientIdentifier'
      : patientId.isNotEmpty
          ? 'Record $patientId'
          : 'Appointment $id';
  String get statusLabel => status.isEmpty
      ? 'Status unavailable'
      : status == 'canceled'
          ? 'Cancelled'
          : '${status[0].toUpperCase()}${status.substring(1)}';
  bool get pending => status == 'pending';
  bool get active => ['confirmed', 'rescheduled', 'scheduled'].contains(status);
  bool get closed =>
      ['completed', 'cancelled', 'canceled', 'declined'].contains(status);
  bool get hasCompletedEncounter =>
      encounterId != null &&
      encounterStatus == 'completed' &&
      performedBy != null;
  bool get canReschedule => pending || active;
  bool get canCancel => active;
  bool pastDated(DateTime clinicNow) =>
      startsAt != null &&
      appointmentDay(startsAt!).isBefore(appointmentDay(clinicNow));
  String get timeLabel => startsAt == null
      ? 'Time unavailable'
      : '${DateFormat('HH:mm').format(startsAt!)}${endTime.isEmpty ? '' : '–$endTime'}';

  bool inView(AppointmentView view, DateTime clinicNow) {
    final today = appointmentDay(clinicNow);
    final day = startsAt == null ? null : appointmentDay(startsAt!);
    return switch (view) {
      AppointmentView.today => day == today,
      AppointmentView.upcoming => active && day != null && day.isAfter(today),
      AppointmentView.requests => pending,
      AppointmentView.history => closed || day == null || day.isBefore(today),
    };
  }
}

class AppointmentChangedException implements Exception {
  const AppointmentChangedException();
}

bool appointmentMatches(AppointmentEntry entry, String query, String source,
    String status, DateTime? date) {
  final text = query.trim().toLowerCase();
  return (source == 'all' || entry.source == source) &&
      (status == 'all' || entry.status == status) &&
      (date == null ||
          entry.startsAt != null &&
              appointmentDay(entry.startsAt!) == appointmentDay(date)) &&
      (text.isEmpty ||
          [
            entry.patientName,
            entry.patientIdentifier,
            entry.patientId,
            entry.id
          ].any((v) => v.toLowerCase().contains(text)));
}
