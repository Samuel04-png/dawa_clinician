import 'package:flutter/material.dart';

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

enum UltrasoundLaunchMode {
  dashboard,
  chooseScanWorkflow,
  manualScan,
  aiGuidedScan,
  uploadImage,
  captureImage,
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
