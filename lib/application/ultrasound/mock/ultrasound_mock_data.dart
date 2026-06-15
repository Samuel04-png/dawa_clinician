import '../models/ultrasound_models.dart';

class UltrasoundMockData {
  static List<PregnantPatient> getPatients() {
    final names = [
      'Amina Banda',
      'Brenda Mwale',
      'Catherine Zulu',
      'Diana Phiri',
      'Esther Lungu',
      'Faith Sakala',
      'Grace Tembo',
      'Hannah Mbewe',
      'Irene Ngoma',
      'Janet Daka',
      'Kunda Mulenga',
      'Lina Kaira',
      'Mercy Gondwe',
      'Naomi Soko',
      'Olive Chama',
    ];

    final gravidas = [
      'G1P0',
      'G2P1',
      'G3P2',
      'G1P0',
      'G4P3',
      'G2P1',
      'G1P0',
      'G3P2',
      'G2P1',
      'G1P0',
      'G5P4',
      'G2P1',
      'G1P0',
      'G3P2',
      'G2P1'
    ];

    return List.generate(names.length, (i) {
      final ga = 12 + (i * 2) % 28; // gestational age 12–40 weeks
      final status = ga < 14
          ? PregnancyStatus.firstTrimester
          : ga < 28
              ? PregnancyStatus.secondTrimester
              : PregnancyStatus.thirdTrimester;

      final scanSt = i == 1 || i == 5
          ? ScanStatus.abnormal
          : i % 4 == 0
              ? ScanStatus.pending
              : ScanStatus.normal;

      return PregnantPatient(
        id: 'OB-${2000 + i}',
        name: names[i],
        age: 18 + (i * 3 % 20),
        contact: '096${2000000 + (i * 222222)}',
        gestationalAgeWeeks: ga,
        lmp: DateTime.now().subtract(Duration(days: ga * 7)),
        edd: DateTime.now().add(Duration(days: (40 - ga) * 7)),
        lastScanDate: DateTime.now().subtract(Duration(days: i * 5)),
        scanStatus: scanSt,
        riskLevel:
            scanSt == ScanStatus.abnormal ? RiskLevel.high : RiskLevel.low,
        pregnancyStatus: status,
        gravida: gravidas[i],
      );
    });
  }

  static List<UltrasoundScanRecord> getScanHistory() {
    return [
      UltrasoundScanRecord(
        id: 'S001',
        patientId: 'OB-2001',
        patientName: 'Brenda Mwale',
        date: DateTime(2025, 11, 18),
        scanType: ScanType.aiGuided,
        result: 'Normal',
        notes: 'AI-guided sweep completed. All parameters within normal range.',
        aiAnalysis: 'EGA 22wks, Cephalic, AFI 11cm',
        gestationalAgeWeeks: 22,
        measurements: {'BPD': '55mm', 'FL': '38mm', 'AC': '185mm'},
      ),
      UltrasoundScanRecord(
        id: 'S002',
        patientId: 'OB-2005',
        patientName: 'Faith Sakala',
        date: DateTime(2025, 11, 17),
        scanType: ScanType.manual,
        result: 'Abnormal',
        notes: 'Low-lying placenta observed. Refer for specialist review.',
        aiAnalysis: 'Placenta previa suspected',
        gestationalAgeWeeks: 30,
      ),
      UltrasoundScanRecord(
        id: 'S003',
        patientId: 'OB-2002',
        patientName: 'Catherine Zulu',
        date: DateTime(2025, 11, 16),
        scanType: ScanType.aiGuided,
        result: 'Normal',
        notes: 'All six sweep steps completed.',
        aiAnalysis: 'EGA 18wks, Normal anatomy survey',
        gestationalAgeWeeks: 18,
      ),
      UltrasoundScanRecord(
        id: 'S004',
        patientId: 'OB-2000',
        patientName: 'Amina Banda',
        date: DateTime(2025, 11, 15),
        scanType: ScanType.manual,
        result: 'Normal',
        notes: 'Routine dating scan.',
        aiAnalysis: 'EGA 12wks, NT 1.8mm',
        gestationalAgeWeeks: 12,
        measurements: {'CRL': '58mm', 'NT': '1.8mm'},
      ),
      UltrasoundScanRecord(
        id: 'S005',
        patientId: 'OB-2003',
        patientName: 'Diana Phiri',
        date: DateTime(2025, 11, 14),
        scanType: ScanType.aiGuided,
        result: 'Normal',
        notes: 'Growth scan within normal parameters.',
        aiAnalysis: 'EGA 34wks, EFW 2.2kg',
        gestationalAgeWeeks: 34,
        measurements: {
          'BPD': '85mm',
          'HC': '307mm',
          'AC': '297mm',
          'FL': '65mm'
        },
      ),
    ];
  }

  static List<UltrasoundScanRecord> getScanData() {
    return getScanHistory();
  }
}
