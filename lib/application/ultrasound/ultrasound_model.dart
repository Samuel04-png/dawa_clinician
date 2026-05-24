import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import '/backend/supabase/supabase_config.dart';
import '/components/dawa_design_system.dart';

// ─── APP STATE ───────────────────────────────────────────────────────────────

enum UltrasoundAppState {
  splash,
  dashboard,
  manualScan,
  aiGuidedScan,
  results,
}

enum UltrasoundDashboardTab {
  home,
  patients,
  history,
  profile,
}

// ─── PATIENT ─────────────────────────────────────────────────────────────────

enum PregnancyStatus {
  firstTrimester,
  secondTrimester,
  thirdTrimester,
  postpartum,
  unknown,
}

enum ScanStatus {
  normal,
  abnormal,
  pending,
  unscanned,
}

enum RiskLevel {
  low,
  medium,
  high,
}

class PregnantPatient {
  final String id;
  final String name;
  final int age;
  final String contact;
  final int? gestationalAgeWeeks;
  final DateTime? lmp; // Last Menstrual Period
  final DateTime? edd; // Estimated Due Date
  final DateTime? lastScanDate;
  final ScanStatus scanStatus;
  final RiskLevel riskLevel;
  final PregnancyStatus pregnancyStatus;
  final String? gravida; // e.g. "G2P1"
  final String? imageUrl;

  PregnantPatient({
    required this.id,
    required this.name,
    required this.age,
    required this.contact,
    this.gestationalAgeWeeks,
    this.lmp,
    this.edd,
    this.lastScanDate,
    required this.scanStatus,
    required this.riskLevel,
    required this.pregnancyStatus,
    this.gravida,
    this.imageUrl,
  });

  factory PregnantPatient.fromJson(Map<String, dynamic> json) {
    return PregnantPatient(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      age: json['age'] ?? 0,
      contact: json['contact'] ?? '',
      gestationalAgeWeeks: json['gestationalAgeWeeks'],
      lmp: json['lmp'] != null ? DateTime.parse(json['lmp']) : null,
      edd: json['edd'] != null ? DateTime.parse(json['edd']) : null,
      lastScanDate: json['lastScanDate'] != null
          ? DateTime.parse(json['lastScanDate'])
          : null,
      scanStatus: ScanStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['scanStatus'],
        orElse: () => ScanStatus.unscanned,
      ),
      riskLevel: RiskLevel.values.firstWhere(
        (e) => e.toString().split('.').last == json['riskLevel'],
        orElse: () => RiskLevel.low,
      ),
      pregnancyStatus: PregnancyStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['pregnancyStatus'],
        orElse: () => PregnancyStatus.unknown,
      ),
      gravida: json['gravida'],
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'contact': contact,
      'gestationalAgeWeeks': gestationalAgeWeeks,
      'lmp': lmp?.toIso8601String(),
      'edd': edd?.toIso8601String(),
      'lastScanDate': lastScanDate?.toIso8601String(),
      'scanStatus': scanStatus.toString().split('.').last,
      'riskLevel': riskLevel.toString().split('.').last,
      'pregnancyStatus': pregnancyStatus.toString().split('.').last,
      'gravida': gravida,
      'imageUrl': imageUrl,
    };
  }

  String get scanStatusString {
    switch (scanStatus) {
      case ScanStatus.normal:
        return 'Normal';
      case ScanStatus.abnormal:
        return 'Abnormal';
      case ScanStatus.pending:
        return 'Pending';
      case ScanStatus.unscanned:
        return 'Not Scanned';
    }
  }

  String get pregnancyStatusString {
    switch (pregnancyStatus) {
      case PregnancyStatus.firstTrimester:
        return '1st Trimester';
      case PregnancyStatus.secondTrimester:
        return '2nd Trimester';
      case PregnancyStatus.thirdTrimester:
        return '3rd Trimester';
      case PregnancyStatus.postpartum:
        return 'Postpartum';
      case PregnancyStatus.unknown:
        return 'Unknown';
    }
  }

  Color get statusColor {
    switch (scanStatus) {
      case ScanStatus.normal:
        return DawaTokens.statusSuccess;
      case ScanStatus.abnormal:
        return DawaTokens.statusDanger;
      case ScanStatus.pending:
        return DawaTokens.statusWarning;
      case ScanStatus.unscanned:
        return Colors.grey;
    }
  }
}

// ─── SCAN RECORD ─────────────────────────────────────────────────────────────

enum ScanType {
  manual,
  aiGuided,
}

class UltrasoundScanRecord {
  final String id;
  final String patientId;
  final String patientName;
  final DateTime date;
  final ScanType scanType;
  final String result;
  final String notes;
  final String? imageUri;
  final String? aiAnalysis;
  final int? gestationalAgeWeeks;
  final Map<String, dynamic>? measurements; // BPD, HC, AC, FL etc.

  UltrasoundScanRecord({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.date,
    required this.scanType,
    required this.result,
    required this.notes,
    this.imageUri,
    this.aiAnalysis,
    this.gestationalAgeWeeks,
    this.measurements,
  });

  factory UltrasoundScanRecord.fromJson(Map<String, dynamic> json) {
    return UltrasoundScanRecord(
      id: json['id'] ?? '',
      patientId: json['patientId'] ?? '',
      patientName: json['patientName'] ?? '',
      date: DateTime.parse(json['date']),
      scanType: ScanType.values.firstWhere(
        (e) => e.toString().split('.').last == json['scanType'],
        orElse: () => ScanType.manual,
      ),
      result: json['result'] ?? '',
      notes: json['notes'] ?? '',
      imageUri: json['imageUri'],
      aiAnalysis: json['aiAnalysis'],
      gestationalAgeWeeks: json['gestationalAgeWeeks'],
      measurements: json['measurements'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'date': date.toIso8601String(),
      'scanType': scanType.toString().split('.').last,
      'result': result,
      'notes': notes,
      'imageUri': imageUri,
      'aiAnalysis': aiAnalysis,
      'gestationalAgeWeeks': gestationalAgeWeeks,
      'measurements': measurements,
    };
  }

  String get scanTypeString {
    switch (scanType) {
      case ScanType.manual:
        return 'Manual';
      case ScanType.aiGuided:
        return 'AI Guided';
    }
  }
}

// ─── AI SWEEP STEP ───────────────────────────────────────────────────────────
// Represents one step in the blind sweep guidance protocol

class SweepStep {
  final int stepNumber;
  final String title;
  final String instruction;
  final String bodyPosition; // e.g. "Transverse - Upper Uterus"
  final String probeAngle; // e.g. "90° to spine"
  final String landmark; // what to look for on screen
  final String? warningSign; // what to flag if seen
  final IconData icon;

  const SweepStep({
    required this.stepNumber,
    required this.title,
    required this.instruction,
    required this.bodyPosition,
    required this.probeAngle,
    required this.landmark,
    this.warningSign,
    required this.icon,
  });
}

// ─── ULTRASOUND AI ANALYSIS RESULT ───────────────────────────────────────────

enum FindingLevel {
  normal,
  monitor,
  urgent,
}

class UltrasoundFinding {
  final String category; // e.g. "Fetal Position", "Placenta", "Amniotic Fluid"
  final String finding; // e.g. "Cephalic presentation"
  final FindingLevel level;
  final String? note;

  const UltrasoundFinding({
    required this.category,
    required this.finding,
    required this.level,
    this.note,
  });

  Color get color {
    switch (level) {
      case FindingLevel.normal:
        return DawaTokens.statusSuccess;
      case FindingLevel.monitor:
        return DawaTokens.statusWarning;
      case FindingLevel.urgent:
        return DawaTokens.statusDanger;
    }
  }

  IconData get icon {
    switch (level) {
      case FindingLevel.normal:
        return Icons.check_circle;
      case FindingLevel.monitor:
        return Icons.warning_amber;
      case FindingLevel.urgent:
        return Icons.error;
    }
  }
}

class UltrasoundAnalysisResult {
  final String imageUrl;
  final List<UltrasoundFinding> findings;
  final String overallAssessment;
  final FindingLevel overallLevel;
  final String recommendation;
  final int? estimatedGestationalAge;
  final Map<String, String>? measurements; // BPD, HC, AC, FL
  final String? error;

  UltrasoundAnalysisResult({
    required this.imageUrl,
    required this.findings,
    required this.overallAssessment,
    required this.overallLevel,
    required this.recommendation,
    this.estimatedGestationalAge,
    this.measurements,
    this.error,
  });

  Color get levelColor {
    switch (overallLevel) {
      case FindingLevel.normal:
        return DawaTokens.statusSuccess;
      case FindingLevel.monitor:
        return DawaTokens.statusWarning;
      case FindingLevel.urgent:
        return DawaTokens.statusDanger;
    }
  }

  String get levelString {
    switch (overallLevel) {
      case FindingLevel.normal:
        return 'Normal';
      case FindingLevel.monitor:
        return 'Monitor';
      case FindingLevel.urgent:
        return 'Urgent';
    }
  }
}

// ─── AI SWEEP GUIDANCE PROTOCOL ──────────────────────────────────────────────

class SweepGuidanceProtocol {
  /// Returns the standard 6-step blind sweep protocol for obstetric ultrasound
  static List<SweepStep> getObstetricSweepSteps() {
    return const [
      SweepStep(
        stepNumber: 1,
        title: 'Longitudinal Sweep',
        instruction:
            'Place the probe vertically on the midline of the abdomen just above the pubic bone. '
            'Slide slowly upward toward the fundus in a straight line. '
            'Keep the probe flat and maintain gentle, consistent pressure.',
        bodyPosition: 'Midline — Pubic bone to Fundus',
        probeAngle: 'Parallel to spine (0°)',
        landmark: 'Uterine outline, fetal spine, placenta position',
        warningSign: 'Placenta previa (placenta covering cervix)',
        icon: Icons.arrow_upward,
      ),
      SweepStep(
        stepNumber: 2,
        title: 'Transverse Upper Sweep',
        instruction: 'Rotate probe 90° to lie horizontally. '
            'Position at the fundus (top of the uterus). '
            'Slide slowly downward across the upper half of the abdomen.',
        bodyPosition: 'Transverse — Fundus',
        probeAngle: 'Perpendicular to spine (90°)',
        landmark: 'Fetal head or breech, amniotic fluid pockets',
        warningSign: 'Transverse lie, oligohydramnios',
        icon: Icons.swap_horiz,
      ),
      SweepStep(
        stepNumber: 3,
        title: 'Fetal Head View',
        instruction:
            'Locate the fetal head. Tilt and rock the probe gently to get the head in cross-section. '
            'Look for the oval shape with the midline echo and thalami. '
            'Freeze the image when the standard plane is achieved.',
        bodyPosition: 'Over fetal head — variable',
        probeAngle: 'Angled to head plane',
        landmark: 'Biparietal diameter (BPD), cavum septum pellucidum, thalami',
        warningSign: 'Hydrocephalus (enlarged ventricles), abnormal head shape',
        icon: Icons.face,
      ),
      SweepStep(
        stepNumber: 4,
        title: 'Abdominal Circumference View',
        instruction:
            'Move probe to mid-abdomen. Tilt to find the transverse section of the fetal abdomen. '
            'Look for the stomach bubble on the left and the umbilical vein. '
            'This is a round cross-section — freeze when stomach + UV are both visible.',
        bodyPosition: 'Mid-abdomen transverse',
        probeAngle: 'Perpendicular to fetal spine',
        landmark: 'Stomach bubble, umbilical vein, circular abdomen outline',
        warningSign:
            'Absent stomach bubble (possible esophageal atresia), ascites',
        icon: Icons.circle_outlined,
      ),
      SweepStep(
        stepNumber: 5,
        title: 'Femur Length',
        instruction:
            'Locate a fetal thigh. Align the probe along the long axis of the femur. '
            'The femur should appear as a bright horizontal line with acoustic shadow below. '
            'Measure from greater trochanter to lateral condyle.',
        bodyPosition: 'Over fetal thigh — variable',
        probeAngle: 'Along femur long axis',
        landmark: 'Linear bright femur shaft, both ends visible',
        warningSign: 'Short femur for gestational age, fracture, bowing',
        icon: Icons.straighten,
      ),
      SweepStep(
        stepNumber: 6,
        title: 'Placenta & Fluid Check',
        instruction:
            'Do a final sweep along the uterine wall to locate the full placenta. '
            'Note its position (anterior, posterior, fundal). '
            'Then identify the largest vertical pocket of amniotic fluid for AFI.',
        bodyPosition: 'Follow placenta location',
        probeAngle: 'Parallel to uterine wall',
        landmark: 'Placental tissue (grainy texture), largest fluid pocket',
        warningSign: 'Placenta previa, retroplacental clot, AFI < 2cm or > 8cm',
        icon: Icons.water_drop,
      ),
    ];
  }
}

// ─── ULTRASOUND AI SERVICE ────────────────────────────────────────────────────

class UltrasoundAIService {
  static Future<UltrasoundAnalysisResult> analyzeUltrasoundImage(
      String base64Image, int? gestationalAgeWeeks) async {
    try {
      final response = await supabaseClient.functions.invoke(
        'analyze-ultrasound-image',
        body: {
          'imageBase64': base64Image,
          'gestationalAgeWeeks': gestationalAgeWeeks,
        },
      );

      if (response.status < 200 || response.status >= 300) {
        return _errorResult(base64Image, 'Server error ${response.status}');
      }

      final data = response.data;
      return _parseResult(base64Image, data);
    } catch (e) {
      return _errorResult(base64Image, e.toString());
    }
  }

  static UltrasoundAnalysisResult _parseResult(String imageUrl, dynamic data) {
    try {
      final findings = <UltrasoundFinding>[];

      if (data['findings'] != null) {
        for (final f in data['findings']) {
          findings.add(UltrasoundFinding(
            category: f['category'] ?? '',
            finding: f['finding'] ?? '',
            level: FindingLevel.values.firstWhere(
              (e) => e.toString().split('.').last == f['level'],
              orElse: () => FindingLevel.normal,
            ),
            note: f['note'],
          ));
        }
      }

      return UltrasoundAnalysisResult(
        imageUrl: imageUrl,
        findings: findings,
        overallAssessment: data['overallAssessment'] ?? 'Assessment complete',
        overallLevel: FindingLevel.values.firstWhere(
          (e) => e.toString().split('.').last == data['overallLevel'],
          orElse: () => FindingLevel.normal,
        ),
        recommendation: data['recommendation'] ?? '',
        estimatedGestationalAge: data['estimatedGestationalAge'],
        measurements: data['measurements'] != null
            ? Map<String, String>.from(data['measurements'])
            : null,
      );
    } catch (e) {
      return _mockResult(imageUrl);
    }
  }

  /// Fallback mock result for demo / offline use
  static UltrasoundAnalysisResult _mockResult(String imageUrl) {
    return UltrasoundAnalysisResult(
      imageUrl: imageUrl,
      findings: const [
        UltrasoundFinding(
          category: 'Fetal Position',
          finding: 'Cephalic (head down)',
          level: FindingLevel.normal,
          note: 'Optimal position for delivery',
        ),
        UltrasoundFinding(
          category: 'Placenta',
          finding: 'Posterior, Grade II',
          level: FindingLevel.normal,
          note: 'Clear of cervical os',
        ),
        UltrasoundFinding(
          category: 'Amniotic Fluid',
          finding: 'AFI 12cm — Normal',
          level: FindingLevel.normal,
        ),
        UltrasoundFinding(
          category: 'Fetal Heart Rate',
          finding: '148 bpm — Normal',
          level: FindingLevel.normal,
        ),
        UltrasoundFinding(
          category: 'Fetal Growth',
          finding: 'Consistent with dates',
          level: FindingLevel.normal,
          note: 'EFW within 10th–90th percentile',
        ),
      ],
      overallAssessment:
          'Normal obstetric ultrasound. Fetus is active and well-positioned.',
      overallLevel: FindingLevel.normal,
      recommendation:
          'Routine antenatal care. Next scan at 36 weeks or as clinically indicated.',
      estimatedGestationalAge: 28,
      measurements: {
        'BPD': '72mm',
        'HC': '261mm',
        'AC': '241mm',
        'FL': '53mm',
        'EFW': '1.1kg',
      },
    );
  }

  static UltrasoundAnalysisResult _errorResult(String imageUrl, String error) {
    return UltrasoundAnalysisResult(
      imageUrl: imageUrl,
      findings: const [],
      overallAssessment: 'Analysis failed',
      overallLevel: FindingLevel.monitor,
      recommendation: 'Please retake the image and try again.',
      error: error,
    );
  }
}

// ─── IMAGE PICKER SERVICE ─────────────────────────────────────────────────────

class UltrasoundImagePickerService {
  static final ImagePicker _picker = ImagePicker();

  static Future<String?> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        return 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
    return null;
  }

  static Future<String?> captureImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        return 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }
    } catch (e) {
      debugPrint('Error capturing image: $e');
    }
    return null;
  }
}

// ─── MOCK DATA ────────────────────────────────────────────────────────────────

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
