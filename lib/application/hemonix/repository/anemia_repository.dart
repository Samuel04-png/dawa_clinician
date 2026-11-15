import '/services/clinical_offline_store.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/backend/supabase/supabase_config.dart';
import '/services/screening_patient_repository.dart';
import '../models/anemia_result.dart';

abstract interface class AnemiaRepository
    implements ScreeningPatientRepository {
  Future<List<AnemiaScreeningRecord>> loadRecords();
  Future<AnemiaScreeningRecord?> loadRecord(String id);
  Future<AnemiaScreeningRecord> saveReviewed(
      {required ScreeningPatient patient,
      required AnemiaResult result,
      required String notes,
      required bool reviewConfirmed});
}

class SupabaseAnemiaRepository implements AnemiaRepository {
  const SupabaseAnemiaRepository({this.client});

  /// Injection also permits a fresh authenticated client to reopen a saved exam.
  final SupabaseClient? client;
  SupabaseClient get _client => client ?? supabaseClient;
  Future<T> _request<T>(Future<T> Function() operation) => client == null
      ? runSupabaseRequest(operation)
      : operation().timeout(supabaseRequestTimeout);

  String _userId() {
    final id = client == null
        ? ClinicalOfflineStore.userId
        : _client.auth.currentUser?.id;
    if (id == null || id.isEmpty)
      throw StateError('Sign in to access anemia screening records.');
    return id;
  }

  @override
  Future<List<ScreeningPatient>> loadPatients() async {
    final uid = _userId();
    // Cache only the explicit server-authorized anemia assignments, including clinic ID.
    final rows =
        await ClinicalOfflineStore.read(uid, 'anemia-patients', () async {
      final rows = await _request(() => _client.rpc('list_anemia_patients'));
      if (rows is! List)
        throw const FormatException('Invalid screening patient list.');
      return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
    }, identity: _userId);
    return ScreeningPatient.parseRows(rows);
  }

  AnemiaScreeningRecord _parse(Map<String, dynamic> row, String userId) {
    final id = row['id'];
    final patientId = row['patient_id'];
    final clinicId = row['clinic_id'];
    final date = DateTime.tryParse(row['created_at']?.toString() ?? '');
    final raw = row['result'];
    if (id is! String ||
        id.isEmpty ||
        patientId is! String ||
        patientId.isEmpty ||
        clinicId is! String ||
        clinicId.isEmpty ||
        row['user_id'] != userId ||
        row['model_id'] != 'anemia' ||
        row['review_status'] != 'reviewed' ||
        row['review_notes'] is! String ||
        (row['review_notes'] as String).trim().isEmpty ||
        date == null ||
        raw is! Map<String, dynamic>) {
      throw const FormatException(
          'Invalid saved screening provenance or review.');
    }
    final patient = row['mother'];
    return AnemiaScreeningRecord(
        id: id,
        patientId: patientId,
        patientName: patient is Map && patient['name'] is String
            ? patient['name'] as String
            : 'Patient record',
        createdAt: date,
        result: AnemiaResult.fromDeviceJson(raw,
            examinationId: row['examination_id'] as String,
            deviceId: row['device_id'] as String),
        reviewNotes: row['review_notes'] as String,
        userId: userId,
        clinicId: clinicId,
        modelId: 'anemia');
  }

  @override
  Future<List<AnemiaScreeningRecord>> loadRecords() async {
    final userId = _userId();
    final rows = await ClinicalOfflineStore.read(
        userId,
        'anemia-history',
        () => _request(() => _client
            .from('anemia_screening_records')
            .select('*,mother(name)')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(100)),
        emptyOffline: true,
        identity: _userId);
    final records = <AnemiaScreeningRecord>[];
    var skipped = 0;
    for (final row in rows) {
      try {
        records.add(_parse(row, userId));
      } on FormatException {
        skipped++;
      } on TypeError {
        skipped++;
      }
    }
    if (skipped > 0)
      debugPrint('[Anemia] Skipped $skipped invalid screening records.');
    return records;
  }

  @override
  Future<AnemiaScreeningRecord?> loadRecord(String id) async {
    final userId = _userId();
    if (ClinicalOfflineStore.offline) {
      final rows =
          await ClinicalOfflineStore.cached(userId, 'anemia-history') ?? [];
      final matches = rows.where((r) => r['id'] == id);
      return matches.isEmpty ? null : _parse(matches.first, userId);
    }
    final row = await _request(() => _client
        .from('anemia_screening_records')
        .select('*,mother(name)')
        .eq('id', id)
        .eq('user_id', userId)
        .maybeSingle());
    return row == null ? null : _parse(row, userId);
  }

  @override
  Future<AnemiaScreeningRecord> saveReviewed(
      {required ScreeningPatient patient,
      required AnemiaResult result,
      required String notes,
      required bool reviewConfirmed}) async {
    final userId = _userId();
    if (!reviewConfirmed || notes.trim().isEmpty)
      throw StateError(
          'Confirm clinician review and add review notes before saving.');
    // Revalidate even when constructed by another caller rather than inference.
    final validated = AnemiaResult.fromDeviceJson(result.toDeviceJson(),
        examinationId: result.examinationId, deviceId: result.deviceId);
    final params = <String, dynamic>{
      'p_patient_id': patient.id,
      'p_examination_id': validated.examinationId,
      'p_device_id': validated.deviceId,
      'p_result': validated.toDeviceJson(),
      'p_review_notes': notes.trim(),
      'p_review_confirmed': reviewConfirmed,
    };
    final patients =
        await ClinicalOfflineStore.cached(userId, 'anemia-patients') ?? [];
    final assignments = patients.where((p) => p['id'] == patient.id);
    final clinic = assignments.isEmpty ? null : assignments.first['clinic_id'];
    if (ClinicalOfflineStore.offline && clinic == null) {
      throw StateError(
          'Download your authorized anemia patient assignments before offline screening.');
    }
    final row = await ClinicalOfflineStore.persist(
        uid: userId,
        kind: 'anemia',
        id: validated.examinationId,
        payload: params,
        localRow: {
          'id': const Uuid().v4(),
          'patient_id': patient.id,
          'user_id': userId,
          'clinic_id': clinic,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'result': validated.toDeviceJson(),
          'examination_id': validated.examinationId,
          'device_id': validated.deviceId,
          'model_id': 'anemia',
          'review_status': 'reviewed',
          'review_notes': notes.trim(),
          'mother': {'name': patient.name}
        },
        identity: _userId,
        validateLocal: () {
          if (clinic == null)
            throw StateError(
                'Download authorized anemia patient assignments before going offline.');
        },
        upload: () => _request(() => _client
            .rpc('save_anemia_screening_review', params: params)
            .single()));
    await ClinicalOfflineStore.remember(userId, 'anemia-history', {
      ...row,
      'mother': {'name': patient.name}
    });
    final saved = _parse(row, userId);
    if (saved.patientId != patient.id ||
        saved.result.examinationId != result.examinationId ||
        saved.result.deviceId != result.deviceId)
      throw const FormatException(
          'Saved examination correlation does not match.');
    return AnemiaScreeningRecord(
        id: saved.id,
        patientId: saved.patientId,
        patientName: patient.name,
        createdAt: saved.createdAt,
        result: saved.result,
        reviewNotes: saved.reviewNotes,
        userId: saved.userId,
        clinicId: saved.clinicId,
        modelId: saved.modelId);
  }
}
