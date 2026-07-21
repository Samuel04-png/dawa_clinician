import 'package:clinician/features/appointments/data/clinician_appointment_repository.dart';
import 'package:clinician/features/appointments/domain/clinician_appointment.dart';
import 'package:clinician/features/appointments/presentation/appointment_assessment_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAppointmentRepository extends ClinicianAppointmentRepository {
  int saveCalls = 0;
  int completeCalls = 0;

  @override
  Future<AppointmentAssessmentDraft?> getAssessmentDraft(
    String appointmentId,
  ) async =>
      null;

  @override
  Future<Map<String, dynamic>> saveAssessmentDraft({
    required String appointmentId,
    required Map<String, dynamic> assessment,
  }) async {
    saveCalls += 1;
    return {
      'assessment_version': 1,
      'last_edited_at': '2026-07-21T12:00:00Z',
    };
  }

  @override
  Future<Map<String, dynamic>> completeAssessment({
    required String appointmentId,
    required Map<String, dynamic> assessment,
  }) async {
    completeCalls += 1;
    return {'ok': true};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('assessment is responsive and blocks incomplete completion',
      (tester) async {
    final repository = _FakeAppointmentRepository();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: AppointmentAssessmentPage(
          appointment: _appointment(),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maternal vitals'), findsOneWidget);
    expect(find.text('Pregnancy and baby assessment'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final complete = find.text('Review and complete');
    await tester.ensureVisible(complete);
    await tester.tap(complete);
    await tester.pump();

    expect(
      find.textContaining('blood pressure or mark it as not measured'),
      findsOneWidget,
    );
    expect(repository.completeCalls, 0);

    final save = find.text('Save draft');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.saveCalls, 1);
    expect(find.textContaining('Draft saved'), findsOneWidget);

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

  testWidgets('pregnancy context uses accurate non-missing states',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    for (final state in <String, String>{
      'pregnant': 'Pregnancy is reported, but source dates are not available.',
      'not_pregnant': 'Not currently pregnant',
      'not_provided': 'Pregnancy status not provided',
      'prefer_not_to_say': 'Patient preferred not to say',
    }.entries) {
      await tester.pumpWidget(
        MaterialApp(
          home: AppointmentAssessmentPage(
            key: ValueKey(state.key),
            appointment: _appointment(
              pregnancyStatus: state.key,
              includePregnancyDates: false,
            ),
            repository: _FakeAppointmentRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(state.value), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });
}

ClinicianAppointment _appointment({
  String pregnancyStatus = 'pregnant',
  bool includePregnancyDates = true,
}) =>
    ClinicianAppointment(
      id: 'dawa_mom_test',
      sourceAppointmentId: '00000000-0000-4000-8000-000000000001',
      patientRecordId: 'patient_test',
      patientName: 'Tariro Munzwa',
      clinicName: 'Dawa Mom Clinic',
      status: 'confirmed',
      appointmentDate: DateTime(2026, 7, 22),
      startTime: '14:00',
      endTime: '14:30',
      appointmentType: 'maternal_health',
      reason: 'Pregnancy confirmation',
      notes: '',
      integrationStatus: 'received',
      integrationErrorCode: '',
      receivedAt: DateTime(2026, 7, 20),
      assessmentStatus: 'not_started',
      pregnancyStatus: pregnancyStatus,
      pregnancyLnmp: includePregnancyDates ? DateTime(2026, 2, 1) : null,
      pregnancyEstimatedDueDate:
          includePregnancyDates ? DateTime(2026, 11, 8) : null,
      pregnancyProvenance: 'patient',
    );
