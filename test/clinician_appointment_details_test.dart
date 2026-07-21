import 'package:clinician/features/appointments/domain/clinician_appointment.dart';
import 'package:clinician/features/appointments/presentation/clinician_appointment_details_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('appointment details remain clean across supported widths',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ClinicianAppointmentDetailsPage(
          appointment: _appointment(),
          onStatus: (_) async => false,
          onReschedule: () async => false,
          onAssess: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Appointment details'), findsOneWidget);
    expect(find.text('Tariro Munzwa'), findsWidgets);
    expect(find.text('Consultation overview'), findsOneWidget);
    expect(find.text('Patient context'), findsOneWidget);
    expect(find.text('Visit information'), findsOneWidget);
    expect(find.text('Patient-provided'), findsOneWidget);
    expect(find.text('Dawa Mom sync'), findsOneWidget);
    expect(find.text('Manage appointment'), findsOneWidget);
    expect(find.text('Continue assessment'), findsOneWidget);
    expect(find.textContaining('00000000-0000'), findsNothing);
    expect(tester.takeException(), isNull);

    for (final size in [
      const Size(768, 1024),
      const Size(1024, 768),
      const Size(1366, 900),
      const Size(1440, 900),
    ]) {
      tester.view.physicalSize = size;
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('pending appointment presents focused confirmation actions',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    String? requestedStatus;

    await tester.pumpWidget(
      MaterialApp(
        home: ClinicianAppointmentDetailsPage(
          appointment: _appointment(
            status: 'pending',
            assessmentStatus: 'not_started',
            pregnancyStatus: 'not_provided',
            pregnancyProvenance: '',
          ),
          onStatus: (status) async {
            requestedStatus = status;
            return false;
          },
          onReschedule: () async => false,
          onAssess: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pending confirmation'), findsOneWidget);
    expect(find.text('Pregnancy status not provided'), findsOneWidget);
    expect(find.text('Source not recorded'), findsOneWidget);
    expect(find.text('Confirm appointment'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.text('Start consultation'), findsNothing);

    await tester.ensureVisible(find.text('Confirm appointment'));
    await tester.tap(find.text('Confirm appointment'));
    await tester.pumpAndSettle();
    expect(requestedStatus, 'confirmed');
    expect(tester.takeException(), isNull);
  });
}

ClinicianAppointment _appointment({
  String status = 'confirmed',
  String assessmentStatus = 'in_progress',
  String pregnancyStatus = 'pregnant',
  String pregnancyProvenance = 'patient',
}) =>
    ClinicianAppointment(
      id: 'internal-clinician-appointment-id',
      sourceAppointmentId: '00000000-0000-4000-8000-000000000001',
      patientRecordId: '00000000-0000-4000-8000-000000000002',
      patientName: 'Tariro Munzwa',
      clinicName: 'Dawa Maternal Health Centre',
      status: status,
      appointmentDate: DateTime(2026, 7, 22),
      startTime: '14:00',
      endTime: '14:30',
      appointmentType: 'maternal_health',
      reason: 'Pregnancy confirmation and antenatal consultation',
      notes: 'Patient would like to discuss the next steps in her care.',
      integrationStatus: 'received',
      integrationErrorCode: '',
      receivedAt: DateTime(2026, 7, 20),
      assessmentStatus: assessmentStatus,
      pregnancyStatus: pregnancyStatus,
      pregnancyLnmp:
          pregnancyStatus == 'pregnant' ? DateTime(2026, 2, 1) : null,
      pregnancyEstimatedDueDate:
          pregnancyStatus == 'pregnant' ? DateTime(2026, 11, 8) : null,
      pregnancyProvenance: pregnancyProvenance,
    );
