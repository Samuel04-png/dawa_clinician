import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '/components/dawa_design_system.dart';

// ─── APP STATE ENUMS ──────────────────────────────────────────────────────────

enum AppState {
  splash,
  login,
  signup,
  otp,
  getStarted,
  dashboard,
  results,
  viaTest,
  terms
}

enum DashboardTab { home, patients, history, profile }

enum PatientStatus { normal, suspicious, pending, untested }

enum RiskLevel { low, medium, high }

enum SuspicionLevel { low, medium, high }

// ─── PATIENT MODEL ────────────────────────────────────────────────────────────

class Patient {
  final String id;
  final String name;
  final int age;
  final String contact;
  final DateTime? lastTestDate;
  final PatientStatus status;
  final RiskLevel riskLevel;
  final String? imageUrl;

  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.contact,
    this.lastTestDate,
    required this.status,
    required this.riskLevel,
    this.imageUrl,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      age: json['age'] ?? 0,
      contact: json['contact'] ?? '',
      lastTestDate: json['lastTestDate'] != null
          ? DateTime.parse(json['lastTestDate'])
          : null,
      status: PatientStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => PatientStatus.untested,
      ),
      riskLevel: RiskLevel.values.firstWhere(
        (e) => e.toString().split('.').last == json['riskLevel'],
        orElse: () => RiskLevel.low,
      ),
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'contact': contact,
        'lastTestDate': lastTestDate?.toIso8601String(),
        'status': status.toString().split('.').last,
        'riskLevel': riskLevel.toString().split('.').last,
        'imageUrl': imageUrl,
      };

  String get statusString {
    switch (status) {
      case PatientStatus.normal:
        return 'Normal';
      case PatientStatus.suspicious:
        return 'Suspicious';
      case PatientStatus.pending:
        return 'Pending';
      case PatientStatus.untested:
        return 'Untested';
    }
  }

  String get riskLevelString {
    switch (riskLevel) {
      case RiskLevel.low:
        return 'Low';
      case RiskLevel.medium:
        return 'Medium';
      case RiskLevel.high:
        return 'High';
    }
  }
}

// ─── VIA TEST RECORD ──────────────────────────────────────────────────────────

class VIATestRecord {
  final String id;
  final String patientId;
  final String patientName;
  final DateTime date;
  final String result;
  final String notes;
  final String? imageUri;
  final String? aiAnalysis;
  final Map<String, dynamic>? analysisJson;

  VIATestRecord({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.date,
    required this.result,
    required this.notes,
    this.imageUri,
    this.aiAnalysis,
    this.analysisJson,
  });

  factory VIATestRecord.fromJson(Map<String, dynamic> json) {
    return VIATestRecord(
      id: _stringValue(json['id']),
      patientId: _stringValue(json['patientId']),
      patientName: _stringValue(json['patientName']),
      date: _dateValue(json['date']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      result: _stringValue(json['result']),
      notes: _stringValue(json['notes']),
      imageUri: _stringValueOrNull(json['imageUri']),
      aiAnalysis: _stringValueOrNull(json['aiAnalysis']),
      analysisJson: _mapValue(json['analysisJson']) ??
          _mapValue(json['analysis_json']) ??
          _mapValue(json['analysis_result']) ??
          _mapValue(json['analysisResult']) ??
          _mapValue(json['analysis_payload']) ??
          _mapValue(json['analysisPayload']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'patientName': patientName,
        'date': date.toIso8601String(),
        'result': result,
        'notes': notes,
        'imageUri': imageUri,
        'aiAnalysis': aiAnalysis,
        'analysisJson': analysisJson,
      };

  AnalysisResult? get analysisResult {
    final payload = analysisJson;
    if (payload == null || payload.isEmpty) return null;
    return AnalysisResult.fromJson(payload);
  }
}

// ─── ANALYSIS RESULT ──────────────────────────────────────────────────────────

class PredictionBreakdownItem {
  const PredictionBreakdownItem({
    required this.label,
    required this.confidence,
    required this.riskLevel,
    required this.isTopPrediction,
  });

  final String label;
  final double confidence;
  final String? riskLevel;
  final bool isTopPrediction;

  factory PredictionBreakdownItem.fromJson(Map<String, dynamic> json) {
    return PredictionBreakdownItem(
      label: canonicalCacxDisplayLabel(
        _stringValueOrNull(json['label']) ??
            _stringValueOrNull(json['class']) ??
            _stringValueOrNull(json['classification']) ??
            _stringValueOrNull(json['prediction']) ??
            _stringValueOrNull(json['result']) ??
            _stringValueOrNull(json['diagnosis']) ??
            _stringValueOrNull(json['name']) ??
            '',
      ),
      confidence: normalizeCacxConfidence(
        json['confidence'] ??
            json['confidence_percent'] ??
            json['probability'] ??
            json['score'] ??
            json['value'] ??
            json['percent'] ??
            json['percentage'],
      ),
      riskLevel: normalizeCacxRiskLevel(
        _stringValueOrNull(json['riskLevel']) ??
            _stringValueOrNull(json['risk_level']) ??
            _stringValueOrNull(json['risk']) ??
            _stringValueOrNull(json['severity']) ??
            _stringValueOrNull(json['level']) ??
            _stringValueOrNull(json['label']),
      ),
      isTopPrediction: _boolValue(
        json['isTopPrediction'] ??
            json['is_top_prediction'] ??
            json['selected'] ??
            json['top'] ??
            json['top_prediction'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'confidence': confidence,
        'riskLevel': riskLevel,
        'isTopPrediction': isTopPrediction,
      };
}

class AnalysisResult {
  final String imageUrl;
  final String label;
  final double confidence;
  final SuspicionLevel suspicionLevel;
  final String recommendation;
  final Map<String, dynamic>? rawOutput;
  final List<PredictionBreakdownItem> predictionBreakdown;
  final String? error;

  AnalysisResult({
    required this.imageUrl,
    required this.label,
    required this.confidence,
    required this.suspicionLevel,
    required this.recommendation,
    this.rawOutput,
    this.predictionBreakdown = const [],
    this.error,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawOutput = _mapValue(json['rawOutput']) ??
        _mapValue(json['raw_output']) ??
        _mapValue(json['response']) ??
        _mapValue(json['result']);
    final predictionBreakdown = _predictionBreakdownFromJson(json, rawOutput);
    final topPrediction =
        predictionBreakdown.isNotEmpty ? predictionBreakdown.first : null;
    return AnalysisResult(
      imageUrl: _stringValueOrNull(json['imageUrl']) ??
          _stringValueOrNull(json['image_url']) ??
          '',
      label: canonicalCacxDisplayLabel(
        topPrediction?.label ??
            _stringValueOrNull(json['label']) ??
            _stringValueOrNull(json['diagnosis']) ??
            _stringValueOrNull(json['prediction']) ??
            _stringValueOrNull(json['result']) ??
            '',
      ),
      confidence: topPrediction?.confidence ??
          normalizeCacxConfidence(
            json['confidence'] ??
                json['confidence_percent'] ??
                json['probability'] ??
                json['score'],
          ),
      suspicionLevel: SuspicionLevel.values.firstWhere(
        (e) =>
            e.toString().split('.').last ==
            (normalizeCacxLabel(_stringValueOrNull(json['suspicionLevel']) ??
                _stringValueOrNull(json['suspicion_level']) ??
                'low')),
        orElse: () => SuspicionLevel.low,
      ),
      recommendation: _stringValueOrNull(json['recommendation']) ??
          _stringValueOrNull(json['analysis']) ??
          '',
      rawOutput: rawOutput,
      predictionBreakdown: predictionBreakdown,
      error: _stringValueOrNull(json['error']),
    );
  }

  Map<String, dynamic> toJson() => {
        'imageUrl': imageUrl,
        'label': label,
        'confidence': confidence,
        'suspicionLevel': suspicionLevel.toString().split('.').last,
        'recommendation': recommendation,
        'rawOutput': rawOutput,
        'predictionBreakdown':
            predictionBreakdown.map((item) => item.toJson()).toList(),
        'error': error,
      };

  String get suspicionLevelString {
    switch (suspicionLevel) {
      case SuspicionLevel.low:
        return 'Low';
      case SuspicionLevel.medium:
        return 'Medium';
      case SuspicionLevel.high:
        return 'High';
    }
  }

  Color get suspicionColor {
    switch (suspicionLevel) {
      case SuspicionLevel.high:
        return DawaTokens.statusDanger;
      case SuspicionLevel.medium:
        return DawaTokens.statusWarning;
      case SuspicionLevel.low:
        return DawaTokens.statusSuccess;
    }
  }
}

// ─── USER PROFILE ─────────────────────────────────────────────────────────────

String normalizeCacxLabel(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}

String canonicalCacxBaseLabel(String value) {
  final normalized = normalizeCacxLabel(value);
  if (normalized.isEmpty) return normalized;

  if (normalized.contains('normal') || normalized.contains('negative')) {
    return 'negative';
  }

  if (normalized.contains('cin1')) return 'cin1';
  if (normalized.contains('cin2')) return 'cin2';
  if (normalized.contains('cin3')) return 'cin3';

  if (normalized.contains('positive') || normalized.contains('cancer')) {
    return 'positive';
  }

  if (normalized.contains('other') ||
      normalized.contains('unknown') ||
      normalized.contains('inconclusive') ||
      normalized.contains('review')) {
    return 'unknown';
  }

  return normalized;
}

String canonicalCacxDisplayLabel(String value) {
  final key = canonicalCacxBaseLabel(value);
  switch (key) {
    case 'negative':
      return 'Normal / Negative VIA';
    case 'cin1':
      return 'CIN1';
    case 'cin2':
      return 'CIN2';
    case 'cin3':
      return 'CIN3';
    case 'positive':
      return 'Cancer';
    case 'unknown':
      return 'Other / Unknown';
    default:
      return value.trim().isEmpty ? 'Unknown' : value.trim();
  }
}

double normalizeCacxConfidence(dynamic value) {
  double parsed;
  if (value is num) {
    parsed = value.toDouble();
  } else if (value is String) {
    parsed = double.tryParse(value.trim()) ?? 0;
  } else {
    parsed = 0;
  }

  if (parsed <= 1 && parsed >= 0) {
    parsed *= 100;
  }

  return double.parse(parsed.clamp(0, 100).toStringAsFixed(1));
}

String? normalizeCacxRiskLevel(String? value) {
  final normalized = canonicalCacxBaseLabel(value ?? '');
  if (normalized.isEmpty) return null;

  if (normalized.contains('invalid') ||
      normalized.contains('poor') ||
      normalized.contains('unknown') ||
      normalized.contains('review')) {
    return 'review';
  }

  if (normalized.contains('normal') ||
      normalized.contains('negative') ||
      normalized.contains('low')) {
    return 'low';
  }

  if (normalized.contains('positive') ||
      normalized.contains('abnormal') ||
      normalized.contains('medium')) {
    return 'medium';
  }

  if (normalized.contains('suspicious') ||
      normalized.contains('cancer') ||
      normalized.contains('high') ||
      normalized.contains('cin2') ||
      normalized.contains('cin3')) {
    return 'high';
  }

  return 'review';
}

Map<String, dynamic>? _mapValue(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value
        .map((key, dynamic innerValue) => MapEntry(key.toString(), innerValue));
  }
  return null;
}

List<dynamic>? _listValue(dynamic value) {
  if (value is List<dynamic>) return value;
  if (value is List) return List<dynamic>.from(value);
  return null;
}

String _stringValue(dynamic value) => _stringValueOrNull(value) ?? '';

String? _stringValueOrNull(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return value.toString();
}

bool _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'selected';
  }
  return false;
}

DateTime? _dateValue(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return null;
}

class UserProfile {
  final String name;
  final String role;
  final String email;
  final String clinic;
  final int credits;

  UserProfile({
    required this.name,
    required this.role,
    required this.email,
    required this.clinic,
    required this.credits,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] ?? '',
        role: json['role'] ?? '',
        email: json['email'] ?? '',
        clinic: json['clinic'] ?? '',
        credits: json['credits'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role,
        'email': email,
        'clinic': clinic,
        'credits': credits,
      };
}

List<PredictionBreakdownItem> _predictionBreakdownFromJson(
  Map<String, dynamic> json,
  Map<String, dynamic>? rawOutput,
) {
  final explicit = _listValue(
        json['predictionBreakdown'] ??
            json['prediction_breakdown'] ??
            json['confidenceBreakdown'] ??
            json['confidence_breakdown'] ??
            json['classProbabilities'] ??
            json['class_probabilities'] ??
            json['probabilities'] ??
            json['scores'] ??
            json['predictions'] ??
            json['all_predictions'],
      ) ??
      _listValue(rawOutput?['predictionBreakdown']) ??
      _listValue(rawOutput?['prediction_breakdown']) ??
      _listValue(rawOutput?['confidenceBreakdown']) ??
      _listValue(rawOutput?['confidence_breakdown']) ??
      _listValue(rawOutput?['classProbabilities']) ??
      _listValue(rawOutput?['class_probabilities']) ??
      _listValue(rawOutput?['probabilities']) ??
      _listValue(rawOutput?['scores']) ??
      _listValue(rawOutput?['predictions']) ??
      _listValue(rawOutput?['all_predictions']);

  if (explicit != null) {
    final items = <PredictionBreakdownItem>[];
    for (final entry in explicit) {
      final parsed = _parsePredictionBreakdownEntry(entry);
      if (parsed != null) items.add(parsed);
    }
    return _finalizePredictionBreakdown(_mergePredictionBreakdownItems(items));
  }

  return _finalizePredictionBreakdown(
      _extractPredictionBreakdown(rawOutput ?? json));
}

List<PredictionBreakdownItem> _mergePredictionBreakdownItems(
  List<PredictionBreakdownItem> items,
) {
  final merged = <String, PredictionBreakdownItem>{};

  for (final item in items) {
    final canonicalLabel = canonicalCacxDisplayLabel(item.label);
    final key = canonicalCacxBaseLabel(canonicalLabel);
    final existing = merged[key];
    if (existing == null) {
      merged[key] = PredictionBreakdownItem(
        label: canonicalLabel,
        confidence: item.confidence.clamp(0, 100).toDouble(),
        riskLevel: item.riskLevel,
        isTopPrediction: item.isTopPrediction,
      );
      continue;
    }

    merged[key] = PredictionBreakdownItem(
      label: canonicalLabel,
      confidence: existing.confidence >= item.confidence
          ? existing.confidence
          : item.confidence.clamp(0, 100).toDouble(),
      riskLevel: _preferredRiskLevel(existing.riskLevel, item.riskLevel),
      isTopPrediction: existing.isTopPrediction || item.isTopPrediction,
    );
  }

  return merged.values.toList();
}

List<PredictionBreakdownItem> _extractPredictionBreakdown(dynamic source) {
  final itemsByClass = <String, PredictionBreakdownItem>{};

  void addItem({
    required String label,
    required dynamic confidence,
    String? riskLevel,
    bool isTopPrediction = false,
  }) {
    final cleanedLabel = label.trim();
    if (cleanedLabel.isEmpty) return;

    final normalizedLabel = canonicalCacxBaseLabel(cleanedLabel);
    final normalizedConfidence = normalizeCacxConfidence(confidence);
    final canonicalLabel = canonicalCacxDisplayLabel(cleanedLabel);
    final existing = itemsByClass[normalizedLabel];
    final mergedConfidence = existing == null
        ? normalizedConfidence
        : (existing.confidence >= normalizedConfidence
            ? existing.confidence
            : normalizedConfidence);
    final mergedRiskLevel = _preferredRiskLevel(
      existing?.riskLevel,
      normalizeCacxRiskLevel(riskLevel ?? cleanedLabel),
    );

    itemsByClass[normalizedLabel] = PredictionBreakdownItem(
      label: canonicalLabel,
      confidence: mergedConfidence,
      riskLevel: mergedRiskLevel,
      isTopPrediction: existing?.isTopPrediction == true || isTopPrediction,
    );
  }

  void parse(dynamic value) {
    if (value == null) return;
    if (value is String) {
      _parsePredictionText(value, addItem);
      return;
    }
    if (value is num || value is bool) return;
    if (value is List) {
      for (final entry in value) {
        parse(entry);
      }
      return;
    }

    final map = _mapValue(value);
    if (map == null) return;
    final lower = <String, dynamic>{
      for (final entry in map.entries) entry.key.toLowerCase(): entry.value,
    };

    final item = _parsePredictionBreakdownMap(lower);
    if (item != null) {
      addItem(
        label: item.label,
        confidence: item.confidence,
        riskLevel: item.riskLevel,
        isTopPrediction: item.isTopPrediction,
      );
    }

    final labels = _stringListFromKeys(lower, const {
      'labels',
      'classes',
      'class_names',
      'class_labels',
      'names',
      'options',
    });
    final scores = _dynamicListFromKeys(lower, const {
      'probabilities',
      'class_probabilities',
      'confidence_breakdown',
      'scores',
      'predictions',
      'all_predictions',
      'confidences',
      'values',
    });
    if (labels != null && scores != null && labels.isNotEmpty) {
      final length =
          labels.length < scores.length ? labels.length : scores.length;
      for (var i = 0; i < length; i++) {
        addItem(label: labels[i], confidence: scores[i]);
      }
    }

    final mapOfScores = _mapValue(lower['probabilities']) ??
        _mapValue(lower['class_probabilities']) ??
        _mapValue(lower['confidence_breakdown']) ??
        _mapValue(lower['scores']) ??
        _mapValue(lower['result']) ??
        _mapValue(lower['output']);
    if (mapOfScores != null) {
      final numericEntries = mapOfScores.entries.where((entry) {
        if (entry.value is num) return true;
        if (entry.value is String) {
          return double.tryParse(entry.value.toString().trim()) != null;
        }
        return false;
      }).toList();
      for (final entry in numericEntries) {
        addItem(label: entry.key.toString(), confidence: entry.value);
      }
    } else if (_looksLikeClassScoreMap(lower)) {
      for (final entry in lower.entries) {
        final confidence = entry.value;
        if (confidence is num || confidence is String) {
          addItem(label: entry.key.toString(), confidence: confidence);
        }
      }
    }

    for (final entry in lower.entries) {
      final key = entry.key;
      final child = entry.value;
      if (child is Map || child is List) {
        if (_isPredictionContainerKey(key)) {
          parse(child);
        }
      }
    }
  }

  parse(source);
  return itemsByClass.values.toList();
}

PredictionBreakdownItem? _parsePredictionBreakdownEntry(dynamic entry) {
  final map = _mapValue(entry);
  if (map == null) return null;
  final lower = <String, dynamic>{
    for (final item in map.entries) item.key.toLowerCase(): item.value,
  };
  final label = _stringValueOrNull(lower['label']) ??
      _stringValueOrNull(lower['class']) ??
      _stringValueOrNull(lower['classification']) ??
      _stringValueOrNull(lower['prediction']) ??
      _stringValueOrNull(lower['result']) ??
      _stringValueOrNull(lower['diagnosis']) ??
      _stringValueOrNull(lower['name']) ??
      '';
  final confidence = normalizeCacxConfidence(
    lower['confidence'] ??
        lower['confidence_percent'] ??
        lower['probability'] ??
        lower['score'] ??
        lower['value'] ??
        lower['percent'] ??
        lower['percentage'],
  );
  if (label.trim().isEmpty && confidence == 0) return null;
  return PredictionBreakdownItem(
    label: canonicalCacxDisplayLabel(label),
    confidence: confidence,
    riskLevel: normalizeCacxRiskLevel(
      _stringValueOrNull(lower['riskLevel']) ??
          _stringValueOrNull(lower['risk_level']) ??
          _stringValueOrNull(lower['risk']) ??
          label,
    ),
    isTopPrediction: _boolValue(
      lower['isTopPrediction'] ??
          lower['is_top_prediction'] ??
          lower['selected'] ??
          lower['top'] ??
          lower['top_prediction'],
    ),
  );
}

PredictionBreakdownItem? _parsePredictionBreakdownMap(
  Map<String, dynamic> lower,
) {
  final label = _stringValueOrNull(lower['label']) ??
      _stringValueOrNull(lower['class']) ??
      _stringValueOrNull(lower['classification']) ??
      _stringValueOrNull(lower['prediction']) ??
      _stringValueOrNull(lower['result']) ??
      _stringValueOrNull(lower['diagnosis']) ??
      _stringValueOrNull(lower['name']) ??
      '';
  final confidence = normalizeCacxConfidence(
    lower['confidence'] ??
        lower['confidence_percent'] ??
        lower['probability'] ??
        lower['score'] ??
        lower['value'] ??
        lower['percent'] ??
        lower['percentage'],
  );
  if (label.trim().isEmpty && confidence == 0) return null;
  if (label.trim().isEmpty) return null;
  return PredictionBreakdownItem(
    label: canonicalCacxDisplayLabel(label),
    confidence: confidence,
    riskLevel: normalizeCacxRiskLevel(
      _stringValueOrNull(lower['riskLevel']) ??
          _stringValueOrNull(lower['risk_level']) ??
          _stringValueOrNull(lower['risk']) ??
          label,
    ),
    isTopPrediction: _boolValue(
      lower['isTopPrediction'] ??
          lower['is_top_prediction'] ??
          lower['selected'] ??
          lower['top'] ??
          lower['top_prediction'],
    ),
  );
}

List<PredictionBreakdownItem> _finalizePredictionBreakdown(
  List<PredictionBreakdownItem> items,
) {
  if (items.isEmpty) return const [];

  items.sort((a, b) {
    final confidenceCompare = b.confidence.compareTo(a.confidence);
    if (confidenceCompare != 0) return confidenceCompare;
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  });

  final topIndex = items.indexWhere((item) => item.isTopPrediction);
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    items[i] = PredictionBreakdownItem(
      label: item.label,
      confidence: item.confidence,
      riskLevel: item.riskLevel,
      isTopPrediction: i == 0 || i == topIndex,
    );
  }
  return List<PredictionBreakdownItem>.unmodifiable(items);
}

String? _preferredRiskLevel(String? current, String? next) {
  final currentValue = current?.trim();
  final nextValue = next?.trim();
  if (nextValue == null || nextValue.isEmpty) return currentValue;
  if (currentValue == null || currentValue.isEmpty) return nextValue;
  if (currentValue == nextValue) return currentValue;

  const priority = {'high': 3, 'medium': 2, 'low': 1, 'review': 0};
  final currentPriority = priority[currentValue.toLowerCase()] ?? 0;
  final nextPriority = priority[nextValue.toLowerCase()] ?? 0;
  return nextPriority >= currentPriority ? nextValue : currentValue;
}

void _parsePredictionText(
  String text,
  void Function({
    required String label,
    required dynamic confidence,
    String? riskLevel,
    bool isTopPrediction,
  }) addItem,
) {
  for (final line in text.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.toLowerCase().startsWith('predicted:')) {
      final label = trimmed.split(':').last.trim();
      if (label.isNotEmpty) {
        addItem(label: label, confidence: 0, isTopPrediction: true);
      }
      continue;
    }
    final colonIndex = trimmed.indexOf(':');
    if (colonIndex <= 0) continue;
    final label = trimmed.substring(0, colonIndex).trim();
    final confidence =
        double.tryParse(trimmed.substring(colonIndex + 1).trim());
    if (confidence != null) {
      addItem(label: label, confidence: confidence);
    }
  }
}

bool _isPredictionContainerKey(String key) {
  const allowed = {
    'result',
    'results',
    'data',
    'output',
    'outputs',
    'payload',
    'response',
    'rawoutput',
    'raw_output',
    'predictionbreakdown',
    'prediction_breakdown',
    'confidencebreakdown',
    'confidence_breakdown',
    'classprobabilities',
    'class_probabilities',
    'probabilities',
    'scores',
    'predictions',
    'all_predictions',
    'confidences',
  };
  final normalized = key.toLowerCase();
  return allowed.contains(normalized) ||
      normalized.contains('probab') ||
      normalized.contains('predict') ||
      normalized.contains('confidence');
}

List<String>? _stringListFromKeys(
  Map<String, dynamic> map,
  Set<String> keys,
) {
  for (final entry in map.entries) {
    if (!keys.contains(entry.key)) continue;
    final list = _listValue(entry.value);
    if (list == null) continue;
    final values = <String>[];
    for (final item in list) {
      final text = _stringValueOrNull(item);
      if (text != null && text.isNotEmpty) {
        values.add(text);
      }
    }
    if (values.isNotEmpty) return values;
  }
  return null;
}

List<dynamic>? _dynamicListFromKeys(
  Map<String, dynamic> map,
  Set<String> keys,
) {
  for (final entry in map.entries) {
    if (!keys.contains(entry.key)) continue;
    final list = _listValue(entry.value);
    if (list != null && list.isNotEmpty) return list;
  }
  return null;
}

bool _looksLikeClassScoreMap(Map<String, dynamic> map) {
  if (map.length < 2) return false;

  const metadataKeys = {
    'id',
    'status',
    'status_code',
    'code',
    'timeout',
    'timeout_seconds',
    'message',
    'error',
    'label',
    'class',
    'classification',
    'prediction',
    'result',
    'diagnosis',
    'confidence',
    'confidence_percent',
    'probability',
    'score',
    'value',
    'percent',
    'percentage',
    'risk',
    'risk_level',
    'level',
  };

  final numericEntries = map.entries.where((entry) {
    if (metadataKeys.contains(entry.key.toLowerCase())) return false;
    if (entry.value is num) return true;
    if (entry.value is String) {
      return double.tryParse(entry.value.toString().trim()) != null;
    }
    return false;
  }).toList();

  return numericEntries.length >= 2;
}

List<PredictionBreakdownItem> extractPredictionBreakdown(dynamic source) {
  return List<PredictionBreakdownItem>.unmodifiable(
    _finalizePredictionBreakdown(_extractPredictionBreakdown(source)),
  );
}

// â”€â”€â”€ SCREENING DATA (charts) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class ScreeningData {
  final String month;
  final int normal;
  final int lowGrade;
  final int highGrade;

  ScreeningData({
    required this.month,
    required this.normal,
    required this.lowGrade,
    required this.highGrade,
  });
}

// ─── GRADIO SERVICE ───────────────────────────────────────────────────────────
//
// How the real model works (from app.py):
//   Backbone : kmunzwa/medsiglip-diagnosis  (SiglipModel – vision encoder)
//   Head     : classifier.pt  →  Linear(1152,128) → ReLU → Dropout → Linear(128,5)
//   Classes  : ["Negative", "CIN1", "CIN2", "CIN3", "Positive"]
//
// The Gradio Space outputs a plain-text Textbox string, exactly:
//
//    Predicted: CIN2
//
//    Probabilities:
//     Negative: 0.0123
//     CIN1: 0.0456
//     CIN2: 0.8921
//     CIN3: 0.0312
//     Positive: 0.0188
//
// We upload the image, call /call/predict, poll the SSE result, then parse
// that plain-text string to get the class and confidence.

class GradioService {
  static const String _baseUrl =
      'https://khanyitapiwa00-cervical-cancer-ai-demo.hf.space';

  // ── Public entry point ─────────────────────────────────────────────────────
  static Future<AnalysisResult> analyzeVIAImage(String base64Image) async {
    try {
      // 1. Decode base64 → raw bytes
      final rawBase64 =
          base64Image.contains(',') ? base64Image.split(',').last : base64Image;
      final imageBytes = base64Decode(rawBase64);

      // 2. Detect MIME type & extension
      String mimeType = 'image/jpeg';
      String extension = 'jpg';
      if (base64Image.startsWith('data:')) {
        mimeType = base64Image.split(';').first.replaceFirst('data:', '');
        final ext = mimeType.split('/').last;
        extension = ext == 'jpeg' ? 'jpg' : ext;
      }

      // 3. Upload → predict → poll
      final uploadedPath = await _uploadImage(imageBytes, mimeType, extension);
      debugPrint('[Gradio] uploaded: $uploadedPath');

      final eventId = await _submitPredict(uploadedPath);
      debugPrint('[Gradio] event_id: $eventId');

      final rawText = await _pollResult(eventId);
      debugPrint('[Gradio] raw text:\n$rawText');

      // 4. Parse the plain-text Textbox response
      return _parseGradioText(base64Image, rawText);
    } catch (e) {
      debugPrint('[Gradio] error: $e');
      return AnalysisResult(
        imageUrl: base64Image,
        label: 'Network Error',
        confidence: 0,
        suspicionLevel: SuspicionLevel.low,
        recommendation:
            'Unable to reach the AI model. Please check your internet connection and try again.',
        error: e.toString(),
      );
    }
  }

  // ── Step 1: Upload image via multipart/form-data ───────────────────────────
  static Future<String> _uploadImage(
      List<int> bytes, String mimeType, String extension) async {
    final boundary =
        '----GradioBoundary${DateTime.now().millisecondsSinceEpoch}';
    final filename = 'cervix.$extension';

    final body = <int>[];
    body.addAll(utf8.encode('--$boundary\r\n'));
    body.addAll(utf8.encode(
        'Content-Disposition: form-data; name="files"; filename="$filename"\r\n'));
    body.addAll(utf8.encode('Content-Type: $mimeType\r\n\r\n'));
    body.addAll(bytes);
    body.addAll(utf8.encode('\r\n--$boundary--\r\n'));

    final response = await http.post(
      Uri.parse('$_baseUrl/upload'),
      headers: {'Content-Type': 'multipart/form-data; boundary=$boundary'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Image upload failed (${response.statusCode}): ${response.body}');
    }

    // Returns JSON array: ["/tmp/gradio/abc/cervix.jpg"]
    final List<dynamic> paths = jsonDecode(response.body) as List<dynamic>;
    if (paths.isEmpty) throw Exception('Upload returned empty path list');
    return paths.first as String;
  }

  // ── Step 2: Submit prediction job ─────────────────────────────────────────
  static Future<String> _submitPredict(String uploadedPath) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/call/predict'),
      headers: {'Content-Type': 'application/json'},
      // Gradio Image(type="pil") accepts a file-path object
      body: jsonEncode({
        'data': [
          {'path': uploadedPath}
        ]
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Predict submit failed (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final eventId = json['event_id'] as String?;
    if (eventId == null || eventId.isEmpty) {
      throw Exception('No event_id in response: ${response.body}');
    }
    return eventId;
  }

  // ── Step 3: Poll SSE result ────────────────────────────────────────────────
  static Future<String> _pollResult(String eventId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/call/predict/$eventId'),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Result poll failed (${response.statusCode}): ${response.body}');
    }

    // SSE body looks like:
    //   event: complete
    //   data: ["\" Predicted: CIN2\\n\\n Probabilities:\\n ..."]
    //
    // We grab the last "data:" line (complete event overwrites process events).
    String? dataLine;
    for (final line in response.body.split('\n')) {
      if (line.startsWith('data:')) {
        dataLine = line.replaceFirst('data:', '').trim();
      }
    }

    if (dataLine == null || dataLine.isEmpty) {
      throw Exception('No data line in SSE response:\n${response.body}');
    }

    // The payload is a JSON array; element 0 is the Textbox string
    final dynamic decoded = jsonDecode(dataLine);
    if (decoded is List && decoded.isNotEmpty) {
      return decoded.first.toString();
    }
    return decoded.toString();
  }

  // ── Step 4: Parse the Textbox plain-text string from app.py ───────────────
  //
  // app.py builds the string exactly as:
  //   " Predicted: {CLASSES[predicted_class]}\n\n"
  //   " Probabilities:\n"
  //   "  {cls}: {prob:.4f}\n"   ← one line per class
  //
  static AnalysisResult _parseGradioText(String imageUrl, String text) {
    final breakdown = _extractPredictionBreakdown(text);
    final topPrediction = breakdown.isNotEmpty ? breakdown.first : null;

    String predictedClass = topPrediction?.label ?? '';
    final rawPredictedClass = predictedClass;
    double confidence = topPrediction?.confidence ?? 0.0;

    if (predictedClass.isEmpty) {
      for (final line in text.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.toLowerCase().contains('predicted:')) {
          predictedClass = trimmed
              .split(':')
              .last
              .trim()
              .replaceAll(RegExp(r'^[^\w]+'), '')
              .trim();
          break;
        }
      }
    }

    if (confidence == 0 && predictedClass.isNotEmpty) {
      final normalizedTarget = normalizeCacxLabel(
        rawPredictedClass.isNotEmpty ? rawPredictedClass : predictedClass,
      );
      for (final line in text.split('\n')) {
        final trimmed = line.trim();
        final colonIdx = trimmed.indexOf(':');
        if (colonIdx == -1) continue;
        final cls = canonicalCacxBaseLabel(
          trimmed.substring(0, colonIdx).trim(),
        );
        final prob = double.tryParse(trimmed.substring(colonIdx + 1).trim());
        if (cls == canonicalCacxBaseLabel(normalizedTarget) && prob != null) {
          confidence = normalizeCacxConfidence(prob);
          break;
        }
      }
    }

    debugPrint(
        '[Gradio] parsed -> class="${predictedClass}" confidence=${confidence.toStringAsFixed(1)}% breakdown=${breakdown.length}');

    if (predictedClass.isEmpty) {
      return AnalysisResult(
        imageUrl: imageUrl,
        label: 'Parse Error',
        confidence: 0,
        suspicionLevel: SuspicionLevel.low,
        recommendation:
            'The AI model returned an unrecognised response. Please try again.',
        error: 'Raw response:\n$text',
        predictionBreakdown: breakdown,
      );
    }

    return _buildResult(
      imageUrl,
      predictedClass,
      confidence,
      predictionBreakdown: breakdown,
    );
  }

  // ── Map class name → AnalysisResult ───────────────────────────────────────
  //
  // Covers every label the app.py CLASSES list can produce:
  //   ["Negative", "CIN1", "CIN2", "CIN3", "Positive"]
  //
  static AnalysisResult _buildResult(
    String imageUrl,
    String cls,
    double confidence, {
    List<PredictionBreakdownItem> predictionBreakdown = const [],
  }) {
    final key = canonicalCacxBaseLabel(cls);

    SuspicionLevel suspicion;
    String displayLabel;
    String recommendation;

    switch (key) {
      case 'positive':
        suspicion = SuspicionLevel.high;
        displayLabel = 'Positive - Cancer Suspected';
        recommendation =
            'Urgent oncology referral required. Initiate the cancer management '
            'pathway per Zambian MoH guidelines immediately - do not delay.';
        break;

      case 'cin3':
        suspicion = SuspicionLevel.high;
        displayLabel = 'CIN3 - Severe Dysplasia';
        recommendation = 'Refer for colposcopy and biopsy immediately. '
            '"See and Treat" with LEEP / CKC is strongly recommended '
            'if the patient is eligible.';
        break;

      case 'cin2':
        suspicion = SuspicionLevel.high;
        displayLabel = 'CIN2 - Moderate Dysplasia';
        recommendation = 'Refer for colposcopy and directed biopsy. '
            'Consider "See and Treat" if colposcopy is unavailable. '
            'Schedule follow-up in 6 months.';
        break;

      case 'cin1':
        suspicion = SuspicionLevel.medium;
        displayLabel = 'CIN1 - Mild Dysplasia';
        recommendation =
            'Repeat VIA in 12 months. Counsel patient on risk factors '
            '(HPV, smoking, multiple partners). '
            'Refer for HPV DNA triage testing if available in your facility.';
        break;

      case 'negative':
      default:
        suspicion = SuspicionLevel.low;
        displayLabel = 'Negative - No Abnormality Detected';
        recommendation =
            'No immediate action required. Schedule routine cervical '
            'screening in 3-5 years per Zambian MoH / WHO guidelines.';
    }

    return AnalysisResult(
      imageUrl: imageUrl,
      label: displayLabel,
      confidence: double.parse(confidence.toStringAsFixed(1)),
      suspicionLevel: suspicion,
      recommendation: recommendation,
      predictionBreakdown: predictionBreakdown,
    );
  }
}

// ─── IMAGE PICKER SERVICE ─────────────────────────────────────────────────────

class ImagePickerService {
  static final ImagePicker _picker = ImagePicker();

  static Future<String?> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final b64 = base64Encode(bytes);
        return 'data:image/jpeg;base64,$b64';
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
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final b64 = base64Encode(bytes);
        return 'data:image/jpeg;base64,$b64';
      }
    } catch (e) {
      debugPrint('Error capturing image: $e');
    }
    return null;
  }
}

// ─── MOCK DATA ────────────────────────────────────────────────────────────────

class MockData {
  static List<Patient> getPatients() {
    return List.generate(20, (index) {
      final names = [
        "Alice Mumba",
        "Beatrice Zulu",
        "Chipo Banda",
        "Dorothy Lungu",
        "Esther Phiri",
        "Florence Sakala",
        "Grace Mwape",
        "Hilda Tembo",
        "Ireen Mulenga",
        "Joyce Ngoma",
        "Kondwani Daka",
        "Lillian Chama",
        "Mary Soko",
        "Nancy Kaira",
        "Olive Mwanza",
        "Patricia Gondwe",
        "Queen Nyirenda",
        "Ruth Kangwa",
        "Sarah Mbewe",
        "Theresa Singogo",
      ];

      final status = (index == 0 || index == 2)
          ? PatientStatus.suspicious
          : index % 5 == 0
              ? PatientStatus.pending
              : PatientStatus.normal;

      final riskLevel =
          (index == 0 || index == 2) ? RiskLevel.high : RiskLevel.low;

      return Patient(
        id: 'DM-${1000 + index}',
        name: names[index],
        age: 25 + (index % 20),
        contact: '097${1000000 + (index * 111111)}',
        lastTestDate: DateTime.now().subtract(Duration(days: 30 - index)),
        status: status,
        riskLevel: riskLevel,
      );
    });
  }

  static List<VIATestRecord> getHistoryRecords() {
    return [
      VIATestRecord(
        id: '1',
        patientId: 'DM-1001',
        patientName: 'Beatrice Zulu',
        date: DateTime(2025, 11, 19),
        result: 'Normal',
        notes: 'Routine screening',
        aiAnalysis: 'Confidence: 94%',
      ),
      VIATestRecord(
        id: '2',
        patientId: 'DM-1002',
        patientName: 'Chipo Banda',
        date: DateTime(2025, 11, 18),
        result: 'Suspicious',
        notes: 'Requires follow-up',
        aiAnalysis: 'Confidence: 89%',
      ),
      VIATestRecord(
        id: '3',
        patientId: 'DM-1003',
        patientName: 'Dorothy Lungu',
        date: DateTime(2025, 11, 17),
        result: 'Normal',
        notes: 'Routine screening',
        aiAnalysis: 'Confidence: 92%',
      ),
      VIATestRecord(
        id: '4',
        patientId: 'DM-1004',
        patientName: 'Esther Phiri',
        date: DateTime(2025, 11, 16),
        result: 'Normal',
        notes: 'Routine screening',
        aiAnalysis: 'Confidence: 96%',
      ),
      VIATestRecord(
        id: '5',
        patientId: 'DM-1000',
        patientName: 'Alice Mumba',
        date: DateTime(2025, 11, 15),
        result: 'Normal',
        notes: 'Routine screening',
        aiAnalysis: 'Confidence: 91%',
      ),
    ];
  }

  static List<ScreeningData> getScreeningData() {
    return [
      ScreeningData(month: 'Jun', normal: 42, lowGrade: 5, highGrade: 2),
      ScreeningData(month: 'Jul', normal: 55, lowGrade: 8, highGrade: 1),
      ScreeningData(month: 'Aug', normal: 48, lowGrade: 6, highGrade: 3),
      ScreeningData(month: 'Sep', normal: 60, lowGrade: 10, highGrade: 2),
      ScreeningData(month: 'Oct', normal: 72, lowGrade: 12, highGrade: 4),
      ScreeningData(month: 'Nov', normal: 65, lowGrade: 8, highGrade: 3),
    ];
  }
}
