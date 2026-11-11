import '/backend/supabase/supabase_config.dart';
import '/services/screening_patient_repository.dart';
import '../models/ultrasound_models.dart';

abstract interface class UltrasoundRepository {
  Future<List<PregnantPatient>> loadPatients();
  Future<List<UltrasoundScanRecord>> loadScanRecords();
  Future<UltrasoundScanRecord> saveScanRecord({
    required PregnantPatient patient,
    required UltrasoundAnalysisResult analysis,
    required ScanType scanType,
  });
}

class SupabaseUltrasoundRepository implements UltrasoundRepository {
  const SupabaseUltrasoundRepository();

  @override
  Future<List<PregnantPatient>> loadPatients() async {
    _requireUserId();
    final rows = await runSupabaseRequest(
      () => supabaseClient
          .from('mother')
          .select('id,name,dateOfBirth,phone_number,first_encounter_id')
          .order('name'),
    );
    if (rows.isEmpty) return const [];

    final motherIds = rows
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final encounterRows = motherIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await runSupabaseRequest(
            () => supabaseClient
                .from('first_encounter')
                .select(
                  'mother_Id,gravidity,parity,estimated_due_date,lnmp',
                )
                .inFilter('mother_Id', motherIds),
          );
    final encounterByMotherId = <String, Map<String, dynamic>>{};
    for (final row in encounterRows) {
      encounterByMotherId.putIfAbsent(
        row['mother_Id']?.toString() ?? '',
        () => Map<String, dynamic>.from(row),
      );
    }

    final validIds = ScreeningPatient.parseRows(rows).map((p) => p.id).toSet();
    final seen = <String>{};
    return rows
        .where((row) =>
            validIds.contains(row['id']) &&
            row['name'] is String &&
            (row['name'] as String).trim().isNotEmpty &&
            seen.add(row['id'] as String))
        .map((rawRow) {
      final row = Map<String, dynamic>.from(rawRow);
      final id = row['id']?.toString() ?? '';
      final name = row['name']?.toString().trim() ?? '';
      if (id.isEmpty || name.isEmpty) {
        throw const FormatException(
          'A patient record is missing its ID or name.',
        );
      }

      final encounter = encounterByMotherId[id] ?? const {};
      final lmp = _date(encounter['lnmp']);
      final edd = _date(encounter['estimated_due_date']);
      final gestationalAge = _gestationalAge(lmp: lmp, edd: edd);
      return PregnantPatient(
        id: id,
        name: name,
        age: _ageFromDateOfBirth(_date(row['dateOfBirth'])),
        contact: row['phone_number']?.toString() ?? '',
        gestationalAgeWeeks: gestationalAge,
        lmp: lmp,
        edd: edd,
        scanStatus: ScanStatus.unscanned,
        riskLevel: RiskLevel.unknown,
        pregnancyStatus: _pregnancyStatus(gestationalAge),
        gravida: _gravida(encounter),
      );
    }).toList(growable: false);
  }

  @override
  Future<List<UltrasoundScanRecord>> loadScanRecords() async {
    final userId = _requireUserId();
    final rows = await runSupabaseRequest(
      () => supabaseClient
          .from('ultrasound_scan_records')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(100),
    );
    final encounterRows = await runSupabaseRequest(
      () => supabaseClient
          .from('encounter')
          .select('id,mother_id,us_obstetrics,date,date_performed,created_at')
          .not('us_obstetrics', 'is', null)
          .order('created_at', ascending: false)
          .limit(100),
    );
    if (rows.isEmpty && encounterRows.isEmpty) return const [];

    final patientIds = [...rows, ...encounterRows]
        .map((row) => row['patient_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: true);
    for (final encounter in encounterRows) {
      final patientId = encounter['mother_id']?.toString() ?? '';
      if (patientId.isNotEmpty && !patientIds.contains(patientId)) {
        patientIds.add(patientId);
      }
    }
    final patientRows = patientIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await runSupabaseRequest(
            () => supabaseClient
                .from('mother')
                .select('id,name')
                .inFilter('id', patientIds),
          );
    final patientNames = {
      for (final row in patientRows)
        row['id']?.toString() ?? '': row['name']?.toString() ?? '',
    };

    final savedRecords = rows.map((rawRow) {
      final row = Map<String, dynamic>.from(rawRow);
      final patientId = _requiredString(row, 'patient_id');
      final provider = _analysisProvider(row['analysis_provider']);
      final segmentation = row['segmentation'];
      final overallLevel = row['overall_level']?.toString() ??
          (segmentation is Map ? 'segmentation' : null);
      if (overallLevel == null) {
        throw const FormatException('Missing or invalid overall_level.');
      }
      return UltrasoundScanRecord(
        id: _requiredString(row, 'id'),
        patientId: patientId,
        patientName: patientNames[patientId] ?? 'Patient',
        date: _requiredDate(row, 'created_at'),
        scanType: row['workflow'] == 'ai_guided'
            ? ScanType.aiGuided
            : ScanType.manual,
        result: overallLevel,
        notes: _requiredString(row, 'overall_assessment'),
        aiAnalysis: row['recommendation']?.toString(),
        gestationalAgeWeeks: row['estimated_gestational_age'] as int?,
        measurements: _stringMap(row['measurements']),
        analysisProvider: provider,
        examinationId: row['examination_id']?.toString(),
        findings: _findings(row['findings']),
        modelId: row['model_id']?.toString(),
        modelVersion: row['model_version']?.toString(),
        deviceId: row['device_id']?.toString(),
        segmentation: segmentation is Map
            ? UltrasoundSegmentation.fromJson(
                Map<String, dynamic>.from(segmentation),
              )
            : null,
      );
    });
    final existingEncounters = encounterRows.where((row) {
      return row['us_obstetrics']?.toString().trim().isNotEmpty == true;
    }).map((row) {
      final patientId = row['mother_id']?.toString() ?? '';
      final date = _date(row['date_performed']) ??
          _date(row['date']) ??
          _date(row['created_at']);
      if (patientId.isEmpty || date == null) {
        throw const FormatException(
          'An existing ultrasound encounter is missing its patient or date.',
        );
      }
      return UltrasoundScanRecord(
        id: _requiredString(Map<String, dynamic>.from(row), 'id'),
        patientId: patientId,
        patientName: patientNames[patientId] ?? 'Patient',
        date: date,
        scanType: ScanType.unknown,
        result: 'recorded',
        notes: row['us_obstetrics'].toString(),
      );
    });
    final records = [...savedRecords, ...existingEncounters]
      ..sort((left, right) => right.date.compareTo(left.date));
    return records;
  }

  @override
  Future<UltrasoundScanRecord> saveScanRecord({
    required PregnantPatient patient,
    required UltrasoundAnalysisResult analysis,
    required ScanType scanType,
  }) async {
    final segmentation = analysis.segmentation;
    final isClassification = segmentation == null;
    if (analysis.error != null ||
        analysis.provider == UltrasoundAnalysisProvider.unavailable ||
        analysis.modelId?.trim().isNotEmpty != true ||
        (isClassification &&
            (analysis.findings.isEmpty ||
                analysis.overallLevel == null ||
                analysis.overallAssessment.trim().isEmpty ||
                analysis.recommendation.trim().isEmpty)) ||
        (!isClassification &&
            analysis.provider != UltrasoundAnalysisProvider.edgeDevice)) {
      throw StateError(
        'Only a validated, provenance-bearing analysis can be saved.',
      );
    }
    final userId = _requireUserId();
    final examinationId = analysis.examinationId;
    if (examinationId == null || examinationId.isEmpty) {
      throw StateError('A correlated examination ID is required to save.');
    }

    final inserted = await runSupabaseRequest(
      () => supabaseClient
          .from('ultrasound_scan_records')
          .insert({
            'patient_id': patient.id,
            'user_id': userId,
            'examination_id': examinationId,
            'workflow': scanType == ScanType.aiGuided ? 'ai_guided' : 'manual',
            'analysis_provider': analysis.provider.name,
            'model_id': analysis.modelId,
            'model_version': analysis.modelVersion,
            'device_id': analysis.deviceId,
            'overall_assessment': analysis.overallAssessment,
            'overall_level': analysis.overallLevel?.name,
            'recommendation': analysis.recommendation.trim().isEmpty
                ? null
                : analysis.recommendation,
            'segmentation': segmentation?.toJson(),
            'estimated_gestational_age': analysis.estimatedGestationalAge,
            'measurements': analysis.measurements,
            'findings': analysis.findings
                .map(
                  (finding) => {
                    'category': finding.category,
                    'finding': finding.finding,
                    'level': finding.level.name,
                    if (finding.note != null) 'note': finding.note,
                  },
                )
                .toList(growable: false),
          })
          .select()
          .single(),
    );
    final row = Map<String, dynamic>.from(inserted);
    return UltrasoundScanRecord(
      id: _requiredString(row, 'id'),
      patientId: patient.id,
      patientName: patient.name,
      date: _requiredDate(row, 'created_at'),
      scanType: scanType,
      result: analysis.overallLevel?.name ?? 'segmentation',
      notes: analysis.overallAssessment,
      aiAnalysis:
          analysis.recommendation.isEmpty ? null : analysis.recommendation,
      gestationalAgeWeeks: analysis.estimatedGestationalAge,
      measurements: analysis.measurements,
      analysisProvider: analysis.provider,
      examinationId: examinationId,
      findings: analysis.findings,
      modelId: analysis.modelId,
      modelVersion: analysis.modelVersion,
      deviceId: analysis.deviceId,
      segmentation: segmentation,
    );
  }

  String _requireUserId() {
    final id = supabaseClient.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      throw StateError('Sign in before accessing ultrasound patient records.');
    }
    return id;
  }

  static DateTime? _date(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static DateTime _requiredDate(Map<String, dynamic> row, String key) {
    final value = _date(row[key]);
    if (value == null) throw FormatException('Missing or invalid $key.');
    return value;
  }

  static String _requiredString(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Missing or invalid $key.');
    }
    return value;
  }

  static int? _ageFromDateOfBirth(DateTime? dateOfBirth) {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    var age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age >= 0 && age <= 120 ? age : null;
  }

  static int? _gestationalAge({DateTime? lmp, DateTime? edd}) {
    final now = DateTime.now();
    final days = lmp != null
        ? now.difference(lmp).inDays
        : edd != null
            ? 280 - edd.difference(now).inDays
            : -1;
    final weeks = days ~/ 7;
    return days >= 0 && weeks <= 45 ? weeks : null;
  }

  static PregnancyStatus _pregnancyStatus(int? weeks) {
    if (weeks == null) return PregnancyStatus.unknown;
    if (weeks < 14) return PregnancyStatus.firstTrimester;
    if (weeks < 28) return PregnancyStatus.secondTrimester;
    if (weeks <= 45) return PregnancyStatus.thirdTrimester;
    return PregnancyStatus.unknown;
  }

  static String? _gravida(Map<String, dynamic> encounter) {
    final gravidity = encounter['gravidity']?.toString();
    final parity = encounter['parity']?.toString();
    if (gravidity == null && parity == null) return null;
    return 'G${gravidity ?? '?'}P${parity ?? '?'}';
  }

  static UltrasoundAnalysisProvider _analysisProvider(dynamic value) {
    if (value is String) {
      for (final provider in UltrasoundAnalysisProvider.values) {
        if (provider.name == value) return provider;
      }
    }
    throw const FormatException('Stored analysis has an unknown provider.');
  }

  static Map<String, dynamic>? _stringMap(dynamic value) {
    if (value == null) return null;
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw const FormatException('Stored measurements are invalid.');
    }
    return Map<String, dynamic>.from(value);
  }

  static List<UltrasoundFinding> _findings(dynamic value) {
    if (value is! List) {
      throw const FormatException('Stored findings are invalid.');
    }
    return value.map((rawFinding) {
      if (rawFinding is! Map<String, dynamic> ||
          rawFinding['category'] is! String ||
          rawFinding['finding'] is! String ||
          rawFinding['level'] is! String) {
        throw const FormatException('Stored finding is invalid.');
      }
      return UltrasoundFinding(
        category: rawFinding['category'] as String,
        finding: rawFinding['finding'] as String,
        level: FindingLevel.values.byName(rawFinding['level'] as String),
        note: rawFinding['note'] as String?,
      );
    }).toList(growable: false);
  }
}
