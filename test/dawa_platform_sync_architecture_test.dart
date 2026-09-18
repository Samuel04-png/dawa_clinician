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
  final serviceSyncMigration = File(
    'supabase/migrations/202609160001_add_clinician_service_catalog.sql',
  );
  final serviceSyncSender = File(
    'supabase/functions/process-service-catalog-outbox/index.ts',
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

  test('clinician owns the authoritative service catalog and sync outbox', () {
    final sql = serviceSyncMigration.readAsStringSync();

    expect(sql, contains('create table if not exists public.clinician_services'));
    expect(sql, contains('source_updated_at'));
    expect(sql, contains('current_clinician_is_admin()'));
    expect(sql, contains('service_catalog_sync_outbox'));
    expect(sql, contains('enqueue_service_catalog_sync_job'));
    expect(sql, contains('(is_paid and price > 0) or (not is_paid and price = 0)'));
    expect(sql, contains("status in ('pending', 'retrying')"));
    expect(sql, contains('attempt_count = 0'));
  });

  test('service catalog sender posts to the DawaMom receiver with retry safeguards', () {
    final source = serviceSyncSender.readAsStringSync();

    expect(source, contains('receive-service-catalog-sync'));
    expect(source, contains('x-dawa-sync-secret'));
    expect(source, contains('claim_service_catalog_sync_jobs'));
    expect(source, contains('retryDelayMs'));
    expect(source, contains('permanently_failed'));
  });

  test('service catalog UI uses the existing admin authorization boundary', () {
    final profile = File('lib/profile/profile_widget.dart').readAsStringSync();
    final screen = File(
      'lib/features/services/presentation/clinician_service_catalog_admin_widget.dart',
    ).readAsStringSync();

    expect(profile, contains("rpc('current_clinician_is_admin')"));
    expect(profile, contains('Services & Pricing'));
    expect(screen, contains("rpc('current_clinician_is_admin')"));
    expect(screen, contains('context.goNamed(ProfileWidget.routeName)'));
  });

  test('service edits coalesce pending work and preserve newest timestamps', () {
    final sql = serviceSyncMigration.readAsStringSync();

    expect(sql, contains("o.status in ('pending', 'retrying')"));
    expect(sql, contains('set payload = jsonb_strip_nulls'));
    expect(sql, contains('source_updated_at'));
    expect(sql, contains('next_attempt_at = now()'));
    expect(sql, contains('attempt_count = 0'));
    expect(sql, contains("status in ('pending', 'processing', 'completed', 'retrying'"));
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
