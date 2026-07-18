import 'package:clinician/features/appointments/domain/clinician_appointment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps an imported Dawa Mom appointment and its sync state', () {
    final appointment = ClinicianAppointment.fromRow(
      {
        'id': 'dawa_mom_appointment',
        'source_appointment_id': '8d4b52ce-0497-4cca-aeb3-0da3e2e9f8af',
        'patient_record_id': 'dawa_mom_patient',
        'status': 'pending',
        'appointment_date': '2099-07-20',
        'start_time': '09:00:00',
        'end_time': '09:30:00',
        'appointment_type': 'maternal_health',
        'reason': 'Routine appointment',
        'integration_status': 'received',
        'received_at': '2026-07-17T10:00:00Z',
      },
      patientName: 'Test Patient',
      clinicName: 'Test Clinic',
    );

    expect(appointment.patientName, 'Test Patient');
    expect(appointment.scheduledStart, DateTime(2099, 7, 20, 9));
    expect(appointment.scheduledEnd, DateTime(2099, 7, 20, 9, 30));
    expect(appointment.isPending, isTrue);
    expect(appointment.canReschedule, isTrue);
    expect(appointment.canComplete, isFalse);
    expect(appointment.integrationStatus, 'received');
  });

  test('terminal appointments expose no further clinician actions', () {
    final appointment = ClinicianAppointment.fromRow(
      {
        'id': 'dawa_mom_appointment',
        'status': 'completed',
        'appointment_date': '2099-07-20',
        'start_time': '09:00',
        'end_time': '09:30',
        'integration_status': 'synced',
      },
      patientName: 'Test Patient',
      clinicName: 'Test Clinic',
    );

    expect(appointment.isPending, isFalse);
    expect(appointment.canReschedule, isFalse);
    expect(appointment.canComplete, isFalse);
    expect(appointment.canCancel, isFalse);
  });

  test('maps recipient notification read state', () {
    final notification = ClinicianNotification.fromRow({
      'id': 'notification-id',
      'appointment_id': 'appointment-id',
      'type': 'appointment_booked',
      'title': 'New appointment request',
      'body': 'A patient requested an appointment.',
      'is_read': false,
      'created_at': '2026-07-17T10:00:00Z',
    });

    expect(notification.type, 'appointment_booked');
    expect(notification.isRead, isFalse);
  });
}
