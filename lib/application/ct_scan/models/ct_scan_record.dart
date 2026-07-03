import '/application/shared/clinical_tools/clinical_tool_models.dart';

class CtScanRecord {
  const CtScanRecord({
    required this.patientName,
    required this.patientId,
    required this.recordId,
    required this.date,
    required this.result,
    required this.notes,
    required this.radiologyAnalysis,
    required this.needsReview,
  });

  final String patientName;
  final String patientId;
  final String recordId;
  final DateTime date;
  final String result;
  final String notes;
  final String radiologyAnalysis;
  final bool needsReview;

  ClinicalToolRecord toClinicalToolRecord() {
    return ClinicalToolRecord(
      patientName: patientName,
      patientId: patientId,
      recordId: recordId,
      date: date,
      result: result,
      notes: notes,
      analysis: radiologyAnalysis,
      needsReview: needsReview,
      metadata: {'modality': 'CT'},
    );
  }
}
