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
  recorded,
  normal,
  abnormal,
  pending,
  unscanned,
}

enum RiskLevel {
  low,
  medium,
  high,
  unknown,
}

class PregnantPatient {
  final String id;
  final String name;
  final int? age;
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
      age: json['age'] as int?,
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
        orElse: () => RiskLevel.unknown,
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
      case ScanStatus.recorded:
        return 'Recorded';
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
      case ScanStatus.recorded:
        return DawaTokens.brandPrimary;
    }
  }
}

// ─── SCAN RECORD ─────────────────────────────────────────────────────────────

enum ScanType {
  manual,
  aiGuided,
  unknown,
}

enum UltrasoundAnalysisProvider {
  cloud,
  edgeDevice,
  unavailable,
}

UltrasoundAnalysisProvider? _analysisProviderFromJson(dynamic value) {
  if (value is! String) return null;
  for (final provider in UltrasoundAnalysisProvider.values) {
    if (provider.name == value) return provider;
  }
  return null;
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
  final UltrasoundAnalysisProvider? analysisProvider;
  final String? examinationId;
  final List<UltrasoundFinding> findings;
  final String? modelId;
  final String? modelVersion;
  final String? deviceId;
  final UltrasoundSegmentation? segmentation;

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
    this.analysisProvider,
    this.examinationId,
    this.findings = const [],
    this.modelId,
    this.modelVersion,
    this.deviceId,
    this.segmentation,
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
      analysisProvider: _analysisProviderFromJson(json['analysisProvider']),
      examinationId: json['examinationId'],
      findings: (json['findings'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => UltrasoundFinding(
              category: item['category'] as String,
              finding: item['finding'] as String,
              level: FindingLevel.values.byName(item['level'] as String),
              note: item['note'] as String?,
            ),
          )
          .toList(growable: false),
      modelId: json['modelId'],
      modelVersion: json['modelVersion'],
      deviceId: json['deviceId'],
      segmentation: json['segmentation'] is Map<String, dynamic>
          ? UltrasoundSegmentation.fromJson(
              json['segmentation'] as Map<String, dynamic>,
            )
          : null,
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
      'analysisProvider': analysisProvider?.name,
      'examinationId': examinationId,
      'findings': findings
          .map(
            (finding) => {
              'category': finding.category,
              'finding': finding.finding,
              'level': finding.level.name,
              if (finding.note != null) 'note': finding.note,
            },
          )
          .toList(growable: false),
      'modelId': modelId,
      'modelVersion': modelVersion,
      'deviceId': deviceId,
      if (segmentation != null) 'segmentation': segmentation!.toJson(),
    };
  }

  String get scanTypeString {
    switch (scanType) {
      case ScanType.manual:
        return 'Manual';
      case ScanType.aiGuided:
        return 'AI Guided';
      case ScanType.unknown:
        return 'Clinical record';
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

// ─── EDGE SEGMENTATION RESULT ────────────────────────────────────────────────

class UltrasoundEllipse {
  const UltrasoundEllipse({
    required this.cx,
    required this.cy,
    required this.axis1Px,
    required this.axis2Px,
    required this.angleDeg,
  });

  factory UltrasoundEllipse.fromJson(Map<String, dynamic> json) {
    double number(String key) {
      final value = json[key];
      if (value is! num || !value.isFinite) {
        throw FormatException('ellipse.$key must be a finite number.');
      }
      return value.toDouble();
    }

    final axis1 = number('axis1_px');
    final axis2 = number('axis2_px');
    if (axis1 <= 0 || axis2 <= 0) {
      throw const FormatException('ellipse axes must be positive.');
    }
    return UltrasoundEllipse(
      cx: number('cx'),
      cy: number('cy'),
      axis1Px: axis1,
      axis2Px: axis2,
      angleDeg: number('angle_deg'),
    );
  }

  final double cx;
  final double cy;
  final double axis1Px;
  final double axis2Px;
  final double angleDeg;

  Map<String, dynamic> toJson() => {
        'cx': cx,
        'cy': cy,
        'axis1_px': axis1Px,
        'axis2_px': axis2Px,
        'angle_deg': angleDeg,
      };
}

/// Fetal-abdomen segmentation measurement from the edge ultrasound module
/// (`POST /predict` on port 8086). Pixel values are the primary measurement;
/// millimetre values exist only when the device was given a pixel spacing.
class UltrasoundSegmentation {
  const UltrasoundSegmentation({
    required this.found,
    required this.imageWidth,
    required this.imageHeight,
    this.areaPx,
    this.circumferencePx,
    this.circumferenceMm,
    this.areaMm2,
    this.ellipse,
    this.iouScore,
    this.overlay,
    this.timingsMs = const {},
    this.recordId,
  });

  /// Strictly validates the device response; throws [FormatException].
  factory UltrasoundSegmentation.fromDeviceJson(Map<String, dynamic> json) {
    final found = json['found'];
    if (found is! bool) {
      throw const FormatException('Response is missing a boolean "found".');
    }
    final size = json['image_size'];
    if (size is! List ||
        size.length != 2 ||
        size.any((v) => v is! int || v <= 0)) {
      throw const FormatException('image_size must be two positive integers.');
    }
    final timings = json['timings_ms'];
    if (timings is! Map ||
        timings.values.any((v) => v != null && (v is! num || !v.isFinite))) {
      throw const FormatException('timings_ms must be a map of numbers.');
    }
    final recordId = json['record_id'];
    if (recordId != null && recordId is! int) {
      throw const FormatException('record_id must be an integer.');
    }
    final overlay = json['overlay'];
    if (overlay != null &&
        (overlay is! String || !overlay.startsWith('data:image/'))) {
      throw const FormatException('overlay must be an image data URI.');
    }
    final iou = json['iou_score'];
    if (iou != null && (iou is! num || !iou.isFinite)) {
      throw const FormatException('iou_score must be a number.');
    }

    double? positive(String key, {required bool required}) {
      final value = json[key];
      if (value == null) {
        if (required) throw FormatException('$key is required when found.');
        return null;
      }
      if (value is! num || !value.isFinite || value <= 0) {
        throw FormatException('$key must be a positive number.');
      }
      return value.toDouble();
    }

    UltrasoundEllipse? ellipse;
    double? area;
    double? circumference;
    double? circumferenceMm;
    double? areaMm2;
    if (found) {
      area = positive('area_px', required: true);
      circumference = positive('circumference_px', required: true);
      circumferenceMm = positive('circumference_mm', required: false);
      areaMm2 = positive('area_mm2', required: false);
      if ((circumferenceMm == null) != (areaMm2 == null)) {
        throw const FormatException(
          'circumference_mm and area_mm2 must be reported together.',
        );
      }
      final ellipseValue = json['ellipse'];
      if (ellipseValue is! Map) {
        throw const FormatException('ellipse is required when found.');
      }
      ellipse = UltrasoundEllipse.fromJson(
        Map<String, dynamic>.from(ellipseValue),
      );
    }

    return UltrasoundSegmentation(
      found: found,
      imageWidth: size[0] as int,
      imageHeight: size[1] as int,
      areaPx: area,
      circumferencePx: circumference,
      circumferenceMm: circumferenceMm,
      areaMm2: areaMm2,
      ellipse: ellipse,
      iouScore: (iou as num?)?.toDouble(),
      overlay: overlay as String?,
      timingsMs: {
        for (final entry in timings.entries)
          if (entry.value is num)
            entry.key.toString(): (entry.value as num).toDouble(),
      },
      recordId: recordId as int?,
    );
  }

  /// Reads the persisted form written by [toJson].
  factory UltrasoundSegmentation.fromJson(Map<String, dynamic> json) {
    final size = json['image_size'] as List?;
    return UltrasoundSegmentation(
      found: json['found'] == true,
      imageWidth: (size?[0] as num?)?.toInt() ?? 0,
      imageHeight: (size?[1] as num?)?.toInt() ?? 0,
      areaPx: (json['area_px'] as num?)?.toDouble(),
      circumferencePx: (json['circumference_px'] as num?)?.toDouble(),
      circumferenceMm: (json['circumference_mm'] as num?)?.toDouble(),
      areaMm2: (json['area_mm2'] as num?)?.toDouble(),
      ellipse: json['ellipse'] is Map
          ? UltrasoundEllipse.fromJson(
              Map<String, dynamic>.from(json['ellipse'] as Map),
            )
          : null,
      iouScore: (json['iou_score'] as num?)?.toDouble(),
      timingsMs: {
        for (final entry in (json['timings_ms'] as Map? ?? const {}).entries)
          if (entry.value is num)
            entry.key.toString(): (entry.value as num).toDouble(),
      },
      recordId: (json['record_id'] as num?)?.toInt(),
    );
  }

  final bool found;
  final int imageWidth;
  final int imageHeight;
  final double? areaPx;
  final double? circumferencePx;
  final double? circumferenceMm;
  final double? areaMm2;
  final UltrasoundEllipse? ellipse;
  final double? iouScore;
  final String? overlay;
  final Map<String, double> timingsMs;
  final int? recordId;

  bool get isCalibrated => circumferenceMm != null;

  /// Persisted form. The overlay image is deliberately not stored.
  Map<String, dynamic> toJson() => {
        'found': found,
        'image_size': [imageWidth, imageHeight],
        if (areaPx != null) 'area_px': areaPx,
        if (circumferencePx != null) 'circumference_px': circumferencePx,
        if (circumferenceMm != null) 'circumference_mm': circumferenceMm,
        if (areaMm2 != null) 'area_mm2': areaMm2,
        if (ellipse != null) 'ellipse': ellipse!.toJson(),
        if (iouScore != null) 'iou_score': iouScore,
        'timings_ms': timingsMs,
        if (recordId != null) 'record_id': recordId,
      };
}

class UltrasoundAnalysisResult {
  final String imageUrl;
  final List<UltrasoundFinding> findings;
  final String overallAssessment;
  final FindingLevel? overallLevel;
  final String recommendation;
  final int? estimatedGestationalAge;
  final Map<String, String>? measurements; // BPD, HC, AC, FL
  final String? error;
  final UltrasoundAnalysisProvider provider;
  final String? examinationId;
  final String? modelId;
  final String? modelVersion;
  final String? deviceId;

  /// Set for edge-device segmentation outcomes. These carry measurements and
  /// geometry only; no risk level, findings or recommendation is derived.
  final UltrasoundSegmentation? segmentation;

  UltrasoundAnalysisResult({
    required this.imageUrl,
    required this.findings,
    required this.overallAssessment,
    required this.overallLevel,
    required this.recommendation,
    this.estimatedGestationalAge,
    this.measurements,
    this.error,
    this.provider = UltrasoundAnalysisProvider.cloud,
    this.examinationId,
    this.modelId,
    this.modelVersion,
    this.deviceId,
    this.segmentation,
  });

  Color get levelColor {
    switch (overallLevel) {
      case null:
        return DawaTokens.brandPrimary;
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
      case null:
        return 'Segmentation';
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
