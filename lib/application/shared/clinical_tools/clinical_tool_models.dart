import 'package:flutter/material.dart';

class ClinicalToolAction {
  const ClinicalToolAction({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
}

class ClinicalToolConfig {
  const ClinicalToolConfig({
    required this.key,
    required this.title,
    required this.description,
    required this.recordName,
    required this.resultsLabel,
    required this.recordLabel,
    required this.icon,
    required this.color,
    required this.actions,
    this.recordBadgeFor,
    this.followUpColorFor,
  });

  final String key;
  final String title;
  final String description;
  final String recordName;
  final String resultsLabel;
  final String recordLabel;
  final IconData icon;
  final Color color;
  final List<ClinicalToolAction> actions;
  final ClinicalToolBadge? Function(ClinicalToolRecord record)? recordBadgeFor;
  final Color Function(ClinicalToolRecord record)? followUpColorFor;
}

class ClinicalToolRecord {
  const ClinicalToolRecord({
    required this.patientName,
    required this.patientId,
    required this.recordId,
    required this.date,
    required this.result,
    required this.notes,
    required this.analysis,
    required this.needsReview,
    this.metadata = const {},
  });

  final String patientName;
  final String patientId;
  final String recordId;
  final DateTime date;
  final String result;
  final String notes;
  final String analysis;
  final bool needsReview;
  final Map<String, Object?> metadata;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;

    final haystack = [
      patientName,
      patientId,
      recordId,
      result,
      notes,
      analysis,
      needsReview ? 'needs review' : 'completed',
      ...metadata.values.whereType<String>(),
    ].join(' ').toLowerCase();

    return haystack.contains(normalized);
  }
}

class ClinicalToolBadge {
  const ClinicalToolBadge({
    required this.status,
    required this.label,
  });

  final String status;
  final String label;
}

class ClinicalToolSummary {
  const ClinicalToolSummary({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.records,
    required this.completed,
    required this.needsReview,
    required this.recentPatient,
    required this.recentResult,
    required this.recentDate,
    required this.recordLabel,
    required this.builder,
  });

  final String key;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int records;
  final int completed;
  final int needsReview;
  final String recentPatient;
  final String recentResult;
  final DateTime recentDate;
  final String recordLabel;
  final WidgetBuilder builder;
}

enum ClinicalToolDashboardTab { overview, records, results, search }

enum ClinicalToolResultsFilter { all, completed, needsReview }

ClinicalToolSummary buildClinicalToolSummary({
  required ClinicalToolConfig config,
  required List<ClinicalToolRecord> records,
  required WidgetBuilder builder,
  String? title,
  String? description,
}) {
  final recent = records.isEmpty
      ? null
      : records.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
  final needsReview = records.where((record) => record.needsReview).length;

  return ClinicalToolSummary(
    key: config.key,
    title: title ?? config.title,
    description: description ?? config.description,
    icon: config.icon,
    color: config.color,
    records: records.length,
    completed: records.length - needsReview,
    needsReview: needsReview,
    recentPatient: recent?.patientName ?? 'No records yet',
    recentResult: recent?.result ?? 'No recent result',
    recentDate: recent?.date ?? DateTime(1970),
    recordLabel: config.recordLabel,
    builder: builder,
  );
}

String clinicalToolFormatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
