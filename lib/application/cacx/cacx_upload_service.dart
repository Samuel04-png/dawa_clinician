import 'dart:async';
import 'dart:convert';

import '/backend/supabase/supabase_config.dart';
import 'cacx_model.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class CervicalDeviceConfig {
  const CervicalDeviceConfig._();

  static const deviceBaseUrl = String.fromEnvironment(
    'CERVICAL_DEVICE_BASE_URL',
    defaultValue: 'http://192.168.137.239:8083',
  );

  static String get normalizedDeviceBaseUrl =>
      deviceBaseUrl.replaceFirst(RegExp(r'/+$'), '');

  static String get healthUrl => '$normalizedDeviceBaseUrl/health';

  static String get imagePostUrl => '$normalizedDeviceBaseUrl/upload/cervical';

  static const timeoutSeconds = int.fromEnvironment(
    'CERVICAL_IMAGE_TIMEOUT_SECONDS',
    defaultValue: 120,
  );

  static const healthTimeoutSeconds = int.fromEnvironment(
    'CERVICAL_HEALTH_TIMEOUT_SECONDS',
    defaultValue: 5,
  );

  static const retryIntervalSeconds = int.fromEnvironment(
    'CERVICAL_DEVICE_RETRY_INTERVAL_SECONDS',
    defaultValue: 5,
  );
}

class CacxRiskMapper {
  const CacxRiskMapper._();

  static const _normalLabels = {
    'normal',
    'negative',
    'healthy',
  };

  static const _lowLabels = {
    'low risk',
    'lowrisk',
  };

  static const _borderlineLabels = {
    'borderline',
    'suspicious',
    'cin1',
    'inconclusive',
  };

  static const _highLabels = {
    'cin2',
    'cin3',
    'cancer',
    'high risk',
    'highrisk',
    'positive',
  };

  static String riskLevelFor(String label) {
    final key = _normalize(label);

    if (_normalLabels.contains(key)) return 'normal';
    if (_lowLabels.contains(key)) return 'low';
    if (_borderlineLabels.contains(key)) return 'borderline';
    if (_highLabels.contains(key)) return 'high';
    if (key == 'error' || key == 'unknown' || key.isEmpty) return 'unknown';

    return 'unknown';
  }

  static bool requiresSecondOpinion(String label) {
    final risk = riskLevelFor(label);
    return risk != 'normal' && risk != 'low';
  }

  static SuspicionLevel suspicionForRisk(String riskLevel) {
    switch (riskLevel) {
      case 'normal':
      case 'low':
        return SuspicionLevel.low;
      case 'high':
        return SuspicionLevel.high;
      case 'borderline':
      case 'unknown':
      default:
        return SuspicionLevel.medium;
    }
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}

class CervicalDeviceInterpretation {
  const CervicalDeviceInterpretation({
    required this.label,
    required this.confidence,
    required this.rawResponse,
    required this.riskLevel,
    required this.deviceStatus,
    required this.deviceEndpoint,
    this.error,
  });

  factory CervicalDeviceInterpretation.failure({
    required String label,
    required String message,
    required Map<String, dynamic> rawResponse,
    required String deviceStatus,
    String? deviceEndpoint,
  }) {
    return CervicalDeviceInterpretation(
      label: label,
      confidence: 0,
      rawResponse: rawResponse,
      riskLevel: 'unknown',
      deviceStatus: deviceStatus,
      deviceEndpoint: deviceEndpoint ?? CervicalDeviceConfig.imagePostUrl,
      error: message,
    );
  }

  final String label;
  final double confidence;
  final Map<String, dynamic> rawResponse;
  final String riskLevel;
  final String deviceStatus;
  final String deviceEndpoint;
  final String? error;

  bool get failed => error != null;
  bool get requiresSecondOpinion =>
      failed || CacxRiskMapper.requiresSecondOpinion(label);

  AnalysisResult toAnalysisResult(String imageUrl) {
    final suspicion = CacxRiskMapper.suspicionForRisk(riskLevel);
    final recommendation = failed
        ? 'The device did not return a usable interpretation. Route this case for second opinion or repeat the device upload.'
        : 'Primary device AI interpretation: $label. Device completed the diagnosis pathway.';

    return AnalysisResult(
      imageUrl: imageUrl,
      label: 'Device AI: $label',
      confidence: confidence,
      suspicionLevel: suspicion,
      recommendation: recommendation,
      rawOutput: rawResponse,
      error: error,
    );
  }
}

class CervicalDeviceService {
  const CervicalDeviceService._();

  static Future<CervicalDeviceInterpretation> analyzeImage(
    String base64Image,
    String? patientId, {
    Duration? timeout,
  }) async {
    return _sendImage(base64Image, patientId).timeout(
      timeout ?? const Duration(seconds: CervicalDeviceConfig.timeoutSeconds),
    );
  }

  static Future<void> checkHealth() async {
    final response = await http
        .get(Uri.parse(CervicalDeviceConfig.healthUrl))
        .timeout(
          const Duration(seconds: CervicalDeviceConfig.healthTimeoutSeconds),
        );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CervicalDeviceHttpException(response.statusCode, response.body);
    }
  }

  static Future<CervicalDeviceInterpretation> _sendImage(
    String base64Image,
    String? patientId,
  ) async {
    final decoded = _decodeBase64Image(base64Image);
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(CervicalDeviceConfig.imagePostUrl),
    )
      ..fields['patient_id'] = patientId?.trim().isNotEmpty == true
          ? patientId!.trim()
          : 'unassigned'
      ..fields['examination_type'] = 'cervical'
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          decoded.bytes,
          filename: 'cervical.${decoded.extension}',
          contentType: MediaType.parse(decoded.mimeType),
        ),
      );

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      throw CervicalDeviceHttpException(
        streamedResponse.statusCode,
        responseBody,
      );
    }

    return _parseDeviceResponse(responseBody);
  }

  static CervicalDeviceInterpretation _parseDeviceResponse(String body) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      decoded = body;
    }

    final rawResponse = _normalizeRawResponse(decoded, body);
    final errorText = _findStringByKeys(decoded, const {
      'error',
      'message',
      'error_message',
    });
    final extractedLabel = errorText == null
        ? _findStringByKeys(decoded, const {
            'result',
            'label',
            'prediction',
            'class',
            'classification',
            'diagnosis',
            'interpretation',
            'risk',
            'risk_level',
            'status',
          })
        : 'Error';
    final label = _cleanLabel(extractedLabel ?? body);
    final confidence = _findConfidence(decoded);
    final riskLevel = CacxRiskMapper.riskLevelFor(label);

    return CervicalDeviceInterpretation(
      label: label.isEmpty ? 'Unknown' : label,
      confidence: confidence,
      rawResponse: rawResponse,
      riskLevel: riskLevel,
      deviceStatus: errorText == null ? 'success' : 'failed',
      deviceEndpoint: CervicalDeviceConfig.imagePostUrl,
      error: errorText,
    );
  }

  static _DecodedImage _decodeBase64Image(String base64Image) {
    final rawBase64 =
        base64Image.contains(',') ? base64Image.split(',').last : base64Image;
    final bytes = base64Decode(rawBase64);

    var mimeType = 'image/jpeg';
    var extension = 'jpg';
    if (base64Image.startsWith('data:')) {
      mimeType = base64Image.split(';').first.replaceFirst('data:', '');
      final ext = mimeType.split('/').last.toLowerCase();
      extension = ext == 'jpeg' ? 'jpg' : ext;
    }

    return _DecodedImage(
        bytes: bytes, mimeType: mimeType, extension: extension);
  }

  static Map<String, dynamic> _normalizeRawResponse(
    dynamic decoded,
    String body,
  ) {
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    if (decoded is List) return {'data': decoded};
    return {'text': body};
  }

  static String _cleanLabel(String value) {
    final trimmed = value.trim();
    final normalized = trimmed.toLowerCase();
    if (normalized == 'ok' ||
        normalized == 'success' ||
        normalized == 'complete' ||
        normalized == 'completed') {
      return 'Unknown';
    }
    return trimmed;
  }

  static String? _findStringByKeys(dynamic value, Set<String> keys) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase();
        final candidate = entry.value;
        if (keys.contains(key) && candidate != null) {
          if (candidate is String) return candidate;
          if (candidate is num || candidate is bool)
            return candidate.toString();
        }
      }
      for (final entry in value.entries) {
        final nested = _findStringByKeys(entry.value, keys);
        if (nested != null && nested.trim().isNotEmpty) return nested;
      }
    }
    if (value is List) {
      for (final item in value) {
        final nested = _findStringByKeys(item, keys);
        if (nested != null && nested.trim().isNotEmpty) return nested;
      }
    }
    if (value is String && keys.contains('text')) return value;
    return null;
  }

  static double _findConfidence(dynamic value) {
    final raw = _findNumberByKeys(value, const {
      'confidence',
      'confidence_percent',
      'probability',
      'score',
    });
    if (raw == null) return 0;
    final confidence = raw <= 1 ? raw * 100 : raw;
    return double.parse(confidence.clamp(0, 100).toStringAsFixed(1));
  }

  static double? _findNumberByKeys(dynamic value, Set<String> keys) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase();
        final candidate = entry.value;
        if (!keys.contains(key)) continue;
        if (candidate is num) return candidate.toDouble();
        if (candidate is String) return double.tryParse(candidate);
      }
      for (final entry in value.entries) {
        final nested = _findNumberByKeys(entry.value, keys);
        if (nested != null) return nested;
      }
    }
    if (value is List) {
      for (final item in value) {
        final nested = _findNumberByKeys(item, keys);
        if (nested != null) return nested;
      }
    }
    return null;
  }
}

class CacxScreeningResultsRepository {
  const CacxScreeningResultsRepository._();

  static const table = 'cacx_screening_results';

  static String buildImagePath({
    required String? userId,
    required String? patientId,
  }) {
    final cleanUserId = _pathPart(userId, fallback: 'anonymous');
    final cleanPatientId = _pathPart(patientId, fallback: 'unassigned');
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    return 'cacx/$cleanUserId/$cleanPatientId/$timestamp.jpg';
  }

  static Future<String?> insertPrimaryResult({
    required String? patientId,
    required String? userId,
    required String imagePath,
    required CervicalDeviceInterpretation primary,
    required bool secondOpinionRequired,
    required String secondOpinionStatus,
  }) async {
    final payload = <String, dynamic>{
      'patient_id': patientId,
      'user_id': userId,
      'image_path': imagePath,
      'primary_source': 'arduino_device',
      'primary_result': primary.label,
      'primary_confidence': primary.confidence,
      'primary_raw_response': primary.rawResponse,
      'second_opinion_required': secondOpinionRequired,
      'second_opinion_status': secondOpinionStatus,
      'second_opinion_source': secondOpinionRequired ? 'gradio_server' : null,
      'risk_level': primary.riskLevel,
      'device_endpoint': primary.deviceEndpoint,
      'device_status': primary.deviceStatus,
      'device_error': primary.error,
    };

    try {
      final response = await runSupabaseRequest(
        () => supabaseClient.from(table).insert(payload).select('id').single(),
      );
      return response['id']?.toString();
    } catch (error) {
      debugPrint('[CaCx Supabase] primary save failed: $error');
      return null;
    }
  }

  static Future<void> updateSecondOpinion({
    required String? recordId,
    required AnalysisResult result,
    required String status,
  }) async {
    if (recordId == null || recordId.isEmpty) return;

    final payload = <String, dynamic>{
      'second_opinion_status': status,
      'second_opinion_source': 'gradio_server',
      'second_opinion_result': result.label,
      'second_opinion_confidence': result.confidence,
      'second_opinion_raw_response': result.toJson(),
    };

    try {
      await runSupabaseRequest(
        () => supabaseClient.from(table).update(payload).eq('id', recordId),
      );
    } catch (error) {
      debugPrint('[CaCx Supabase] second opinion save failed: $error');
    }
  }

  static String _pathPart(String? value, {required String fallback}) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return fallback;
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
  }
}

class CervicalDeviceHttpException implements Exception {
  const CervicalDeviceHttpException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'Device HTTP $statusCode: $body';
}

class _DecodedImage {
  const _DecodedImage({
    required this.bytes,
    required this.mimeType,
    required this.extension,
  });

  final List<int> bytes;
  final String mimeType;
  final String extension;
}
