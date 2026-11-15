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
        radiologyAnalysis:
            'Sample radiology workflow note; demonstration only.',
        needsReview: false,
      ),
      CtScanRecord(
        patientName: 'Olive Mwanza',
        patientId: 'DM-1014',
        recordId: 'CT-5402',
        date: DateTime(2026, 5, 13),
        result: 'Needs review',
        notes: 'Contrast follow-up recommended by reporting clinician.',
        radiologyAnalysis: 'Sample review workflow note; demonstration only.',
        needsReview: true,
      ),
      CtScanRecord(
        patientName: 'Ruth Kangwa',
        patientId: 'DM-1017',
        recordId: 'CT-5403',
        date: DateTime(2026, 5, 10),
        result: 'Report completed',
        notes: 'Routine scan archived.',
        radiologyAnalysis: 'Sample archive workflow note; demonstration only.',
        needsReview: false,
      ),
    ];
  }
}
