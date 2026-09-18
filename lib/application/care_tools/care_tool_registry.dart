import 'package:flutter/material.dart';

import '/application/bp_monitor/bp_monitor_widget.dart';
import '/application/cacx/cacx_widget.dart' show CaCxApp;
import '/application/ct_scan/ct_scan_module.dart';
import '/application/hemonix/hemonix_module.dart';
import '/application/shared/clinical_tools/clinical_tool_models.dart';
import '/application/ultrasound/ultrasound.dart' show UltrasoundApp;
import '/components/dawa_design_system.dart';

List<ClinicalToolSummary> getCareToolSummaries() {
  return [
    _summaryFromRecords(
      key: 'cervical-cancer',
      title: 'CaCx Screening',
      description: 'Cervical cancer VIA screening',
      icon: Icons.favorite_border,
      color: DawaTokens.brandPrimary,
      recordLabel: 'Patients',
      records: _cervicalCancerRecords,
      builder: (_) => const CaCxApp(),
    ),
    HemonixModule.summary(),
    CtScanModule.summary(),
    _summaryFromRecords(
      key: 'bp-monitor',
      title: 'BP Monitor',
      description: 'Blood pressure monitoring & risk review',
      icon: Icons.monitor_heart_outlined,
      color: DawaTokens.statusDanger,
      recordLabel: 'Readings',
      records: _bpRecords,
      builder: (_) => const BpMonitorApp(),
    ),
    _summaryFromRecords(
      key: 'ultrasound',
      title: 'Ultrasound',
      description: 'Scan reports & fetal monitoring',
      icon: Icons.sensors_rounded,
      color: DawaTokens.brandPrimary,
      recordLabel: 'Scans',
      records: _ultrasoundRecords,
      builder: (_) => const UltrasoundApp(),
    ),
  ];
}

ClinicalToolSummary _summaryFromRecords({
  required String key,
  required String title,
  required String description,
  required IconData icon,
  required Color color,
  required String recordLabel,
  required List<ClinicalToolRecord> records,
  required WidgetBuilder builder,
}) {
  final recent = records.isEmpty
      ? null
      : records.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
  final needsReview = records.where((record) => record.needsReview).length;

  return ClinicalToolSummary(
    key: key,
    title: title,
    description: description,
    icon: icon,
    color: color,
    records: records.length,
    completed: records.length - needsReview,
    needsReview: needsReview,
    recentPatient: recent?.patientName ?? 'No records yet',
    recentResult: recent?.result ?? 'No recent result',
    recentDate: recent?.date ?? DateTime(1970),
    recordLabel: recordLabel,
    builder: builder,
  );
}

final _cervicalCancerRecords = [
  ClinicalToolRecord(
    patientName: 'Alice Mumba',
    patientId: 'DM-1000',
    recordId: 'CACX-2401',
    date: DateTime(2026, 5, 18),
    result: 'Negative',
    notes: 'Routine VIA screening completed.',
    analysis: 'AI confidence 94% - low-risk visual pattern.',
    needsReview: false,
  ),
  ClinicalToolRecord(
    patientName: 'Chipo Banda',
    patientId: 'DM-1002',
    recordId: 'CACX-2402',
    date: DateTime(2026, 5, 17),
    result: 'CIN2 suspected',
    notes: 'Dense acetowhite area; needs colposcopy review.',
    analysis: 'AI confidence 89% - high-risk markers detected.',
    needsReview: true,
  ),
  ClinicalToolRecord(
    patientName: 'Dorothy Lungu',
    patientId: 'DM-1003',
    recordId: 'CACX-2403',
    date: DateTime(2026, 5, 14),
    result: 'Negative',
    notes: 'Routine follow-up in three years.',
    analysis: 'AI confidence 92% - no abnormality detected.',
    needsReview: false,
  ),
];

final _bpRecords = [
  ClinicalToolRecord(
    patientName: 'Esther Phiri',
    patientId: 'DM-1031',
    recordId: 'BP-2201',
    date: DateTime(2026, 5, 18),
    result: '128/78 mmHg',
    notes: 'Age 42, diabetes. Above high-risk target; repeat planned.',
    analysis:
        'BP interpretation: caution due diabetes context; review if repeated.',
    needsReview: true,
  ),
  ClinicalToolRecord(
    patientName: 'Agnes Banda',
    patientId: 'DM-1028',
    recordId: 'BP-2202',
    date: DateTime(2026, 5, 17),
    result: '118/72 mmHg',
    notes: 'Age 29, no chronic disease recorded.',
    analysis: 'BP interpretation: normal range for routine monitoring.',
    needsReview: false,
  ),
  ClinicalToolRecord(
    patientName: 'Rita Mulenga',
    patientId: 'DM-1044',
    recordId: 'BP-2203',
    date: DateTime(2026, 5, 14),
    result: '146/94 mmHg',
    notes: 'Age 67 with heart disease; repeat and clinician review.',
    analysis:
        'BP interpretation: hypertension range with older adult cardiovascular risk.',
    needsReview: true,
  ),
];

final _ultrasoundRecords = [
  ClinicalToolRecord(
    patientName: 'Lillian Chama',
    patientId: 'DM-1204',
    recordId: 'US-7741',
    date: DateTime(2026, 5, 18),
    result: 'Completed scan',
    notes: 'Single live intrauterine pregnancy, 28 weeks.',
    analysis: 'Measurements consistent; confidence 91%.',
    needsReview: false,
  ),
  ClinicalToolRecord(
    patientName: 'Sarah Mbewe',
    patientId: 'DM-1218',
    recordId: 'US-7742',
    date: DateTime(2026, 5, 16),
    result: 'Needs review',
    notes: 'Growth measurements below expected range.',
    analysis: 'AI flagged asymmetric growth; confidence 84%.',
    needsReview: true,
  ),
  ClinicalToolRecord(
    patientName: 'Nancy Kaira',
    patientId: 'DM-1214',
    recordId: 'US-7743',
    date: DateTime(2026, 5, 12),
    result: 'Completed scan',
    notes: 'Placenta anterior, normal fluid estimate.',
    analysis: 'Routine report generated; confidence 88%.',
    needsReview: false,
  ),
];
