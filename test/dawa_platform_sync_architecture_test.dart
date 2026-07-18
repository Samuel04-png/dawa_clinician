import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/202607170001_add_dawa_platform_sync.sql',
  );
  final appointmentReceiver = File(
    'supabase/functions/receive-dawa-mom-appointment/index.ts',
  );
  final patientReceiver = File(
    'supabase/functions/sync-dawa-mom-patient/index.ts',
  );
  final repository = File(
    'lib/features/appointments/data/clinician_appointment_repository.dart',
  );

  test('migration preserves legacy ids and adds stable integration mappings',
      () {
    final sql = migration.readAsStringSync();

    expect(sql, contains('add column if not exists integration_id uuid'));
    expect(sql, contains('source_appointment_id uuid'));
    expect(sql, contains('integration_processed_events'));
    expect(sql, contains('integration_outbox'));
    expect(sql, contains('notifications'));
    expect(
        sql, contains('alter policy "authenticated users can manage doctors"'));
    expect(sql, contains('guard_clinic_directory_write'));
    expect(
      sql,
      contains('before insert or update or delete on public.doctor'),
    );
    expect(
      sql,
      contains('before insert or update or delete on public.appointments'),
    );
    expect(sql, isNot(contains('disable row level security')));
  });

  test('appointment receiver is authenticated and transactionally idempotent',
      () {
    final sql = migration.readAsStringSync();
    final source = appointmentReceiver.readAsStringSync();

    expect(sql, contains('pg_advisory_xact_lock'));
    expect(sql, contains('for update'));
    expect(sql, contains('Appointment time is no longer available'));
    expect(sql, contains('integration_processed_events_source_event_unique'));
    expect(source, contains('x-dawa-sync-secret'));
    expect(source, contains('receive_dawa_mom_appointment'));
    expect(source, contains('cancel_dawa_mom_appointment'));
  });

  test('patient receiver reuses stable source mapping and replay ledger', () {
    final source = patientReceiver.readAsStringSync();

    expect(source, contains("const destinationTable = 'patients'"));
    expect(source, contains('source_mother_id'));
    expect(source, contains('findProcessedEvent'));
    expect(source, contains('recordProcessedEvent'));
    expect(source, contains('DAWA_CLINICIAN_SYNC_SECRET'));
    expect(source, contains('stale_after_conflict_noop'));
  });

  test('clinician appointment changes go through the guarded RPC', () {
    final source = repository.readAsStringSync();

    expect(source, contains(".from('appointments')"));
    expect(source, contains('.stream(primaryKey:'),
        reason: 'appointments should arrive through the scoped realtime query');
    expect(source, contains('update_dawa_mom_appointment_status'));
    expect(source, isNot(contains(".from('appointments').update")));
  });

  test('Flutter client does not contain cross-project server credentials', () {
    final forbidden = <String>[
      'SUPABASE_SERVICE_ROLE_KEY',
      'DAWA_CLINICIAN_SYNC_SECRET',
      'DAWA_MOM_SYNC_SECRET',
    ];
    final dartSources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) =>
            file.path.endsWith('.dart') &&
            !file.uri.pathSegments.last.startsWith('._'));

    for (final source in dartSources) {
      final text = source.readAsStringSync();
      for (final secretName in forbidden) {
        expect(text, isNot(contains(secretName)),
            reason: '${source.path} must not reference $secretName');
      }
    }
  });
}
