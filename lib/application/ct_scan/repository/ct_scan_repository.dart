import '../models/ct_scan_record.dart';

class CtScanRepository {
  const CtScanRepository();

  List<CtScanRecord> getRecentRecords() {
    return [
      CtScanRecord(
        patientName: 'Patricia Gondwe',
        patientId: 'DM-1015',
        recordId: 'CT-5401',
        date: DateTime(2026, 5, 18),
        result: 'Report completed',
        notes: 'No acute intracranial finding reported.',
        radiologyAnalysis: 'Radiology workflow complete; confidence 87%.',
        needsReview: false,
      ),
      CtScanRecord(
        patientName: 'Olive Mwanza',
        patientId: 'DM-1014',
        recordId: 'CT-5402',
        date: DateTime(2026, 5, 13),
        result: 'Needs review',
        notes: 'Contrast follow-up recommended by reporting clinician.',
        radiologyAnalysis: 'Potential abnormality flagged; confidence 82%.',
        needsReview: true,
      ),
      CtScanRecord(
        patientName: 'Ruth Kangwa',
        patientId: 'DM-1017',
        recordId: 'CT-5403',
        date: DateTime(2026, 5, 10),
        result: 'Report completed',
        notes: 'Routine scan archived.',
        radiologyAnalysis: 'No urgent flag; confidence 89%.',
        needsReview: false,
      ),
    ];
  }
}
