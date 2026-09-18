import '/application/shared/clinical_tools/clinical_tool_models.dart';

class HemonixRecord {
  const HemonixRecord({
    required this.patientName,
    required this.patientId,
    required this.recordId,
    required this.date,
    required this.hemoglobin,
    required this.notes,
    required this.analysis,
    required this.needsReview,
  });

  final String patientName;
  final String patientId;
  final String recordId;
  final DateTime date;
  final String hemoglobin;
  final String notes;
  final String analysis;
  final bool needsReview;

  ClinicalToolRecord toClinicalToolRecord() {
    return ClinicalToolRecord(
      patientName: patientName,
      patientId: patientId,
      recordId: recordId,
      date: date,
      result: hemoglobin,
      notes: notes,
      analysis: analysis,
      needsReview: needsReview,
      metadata: {'hemoglobin': hemoglobin},
    );
  }
}
