import '../models/hemonix_record.dart';

class HemonixRepository {
  const HemonixRepository();

  List<HemonixRecord> getRecentRecords() {
    return [
      HemonixRecord(
        patientName: 'Beatrice Zulu',
        patientId: 'DM-1001',
        recordId: 'HB-3110',
        date: DateTime(2026, 5, 18),
        hemoglobin: 'Hb 12.1 g/dL',
        notes: 'Result within expected range.',
        analysis: 'Anaemia risk low; confidence 93%.',
        needsReview: false,
      ),
      HemonixRecord(
        patientName: 'Grace Mwape',
        patientId: 'DM-1006',
        recordId: 'HB-3111',
        date: DateTime(2026, 5, 15),
        hemoglobin: 'Hb 8.7 g/dL',
        notes: 'Moderate anaemia; treatment plan required.',
        analysis: 'Needs review - anaemia risk high; confidence 90%.',
        needsReview: true,
      ),
      HemonixRecord(
        patientName: 'Mary Soko',
        patientId: 'DM-1012',
        recordId: 'HB-3112',
        date: DateTime(2026, 5, 11),
        hemoglobin: 'Hb 11.4 g/dL',
        notes: 'Routine antenatal haemoglobin check.',
        analysis: 'Borderline but stable; confidence 86%.',
        needsReview: false,
      ),
    ];
  }
}
