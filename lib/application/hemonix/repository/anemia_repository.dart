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
    final id = _client.auth.currentUser?.id;
    if (id == null)
      throw StateError('Sign in to access anemia screening records.');
    return id;
  }

  @override
  Future<List<ScreeningPatient>> loadPatients() async {
    _userId();
    // Patient existence under the broad legacy mother policy is not permission
    // to screen. This RPC returns only explicit clinician/clinic assignments.
    final rows = await _request(() => _client.rpc('list_anemia_patients'));
    if (rows is! List)
      throw const FormatException('Invalid screening patient list.');
    return ScreeningPatient.parseRows(
        rows.map((row) => Map<String, dynamic>.from(row as Map)));
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
    final rows = await _request(() => _client
        .from('anemia_screening_records')
        .select('*,mother(name)')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100));
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
    final row = await _request(
        () => _client.rpc('save_anemia_screening_review', params: {
              'p_patient_id': patient.id,
              'p_examination_id': validated.examinationId,
              'p_device_id': validated.deviceId,
              'p_result': validated.toDeviceJson(),
              'p_review_notes': notes.trim(),
              'p_review_confirmed': reviewConfirmed,
            }).single());
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
