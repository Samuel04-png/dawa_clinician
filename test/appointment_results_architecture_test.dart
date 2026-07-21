import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final assessmentMigration = File(
    'supabase/migrations/202607210001_add_appointment_assessments_and_results.sql',
  );
  final pregnancyViewMigration = File(
    'supabase/migrations/202607210002_refresh_patients_view_for_pregnancy_sync.sql',
  );
  final patientReceiver = File(
    'supabase/functions/sync-dawa-mom-patient/index.ts',
  );

  test('completion is guarded, assigned, validated, and transactional', () {
    final sql = assessmentMigration.readAsStringSync();

    expect(sql.trimLeft(), startsWith('-- Appointment-linked'));
    expect(sql, contains('\nbegin;'));
    expect(sql, contains('guard_assessed_appointment_completion'));
    expect(sql, contains('Complete the clinical assessment before closing'));
    expect(sql, contains('dawa_mom_assessment_validation_errors'));
    expect(sql, contains('Appointment is assigned to another clinician'));
    expect(sql, contains('Encounter patient does not match the appointment'));
    expect(sql, contains("assessment_status = 'completed'"));
    expect(sql, contains("set status = 'completed'"));
    expect(sql, contains("'appointment.results_available'"));
    expect(sql.trimRight(), endsWith('commit;'));
  });

  test('patient summaries and audit data remain server controlled', () {
    final sql = assessmentMigration.readAsStringSync();

    expect(sql,
        contains('patient_appointment_summaries enable row level security'));
    expect(
        sql, contains('clinical_assessment_audit enable row level security'));
    expect(
      sql,
      contains(
        'revoke insert, update, delete on table public.patient_appointment_summaries from authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'revoke all on table public.clinical_assessment_audit from anon, authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'Clinician-only assessment text is never placed here',
      ),
    );
    expect(sql, isNot(contains('disable row level security')));
  });

  test('pregnancy sync exposes and stores provenance-preserving fields', () {
    final viewSql = pregnancyViewMigration.readAsStringSync();
    final receiver = patientReceiver.readAsStringSync();

    for (final field in [
      'source_pregnancy_status',
      'source_pregnancy_lnmp',
      'source_pregnancy_estimated_due_date',
      'source_pregnancy_updated_at',
      'source_pregnancy_provenance',
    ]) {
      expect(viewSql, contains(field));
      expect(receiver, contains(field));
    }
    expect(receiver, contains("source_pregnancy_provenance: 'patient'"));
  });
}
