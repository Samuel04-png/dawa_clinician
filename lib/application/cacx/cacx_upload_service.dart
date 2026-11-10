import 'dart:async';
import 'dart:convert';

import '/backend/supabase/supabase_config.dart';
import '/services/edge_device/edge_device_client.dart';
import '/services/edge_device/edge_device_config.dart';
import '/services/edge_device/edge_device_exceptions.dart';
import '/services/edge_device/edge_device_manager.dart';
import '/services/edge_device/edge_device_models.dart';
import 'package:uuid/uuid.dart';
import 'cacx_model.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CervicalDeviceConfig {
  const CervicalDeviceConfig._();

  static String get deviceBaseUrl {
    return EdgeDeviceConfig.fromEnvironment().baseUrl;
  }

  static String get normalizedDeviceBaseUrl =>
      deviceBaseUrl.replaceFirst(RegExp(r'/+$'), '');

  static String get healthUrl {
    final config = EdgeDeviceConfig.fromEnvironment();
    return config.endpoint(config.healthPath).toString();
  }

  static String get imagePostUrl {
    final config = EdgeDeviceConfig.fromEnvironment();
    if (config.modelManagementEnabled) {
      return config
          .moduleEndpoint(EdgeAIModel.cervicalCancer, config.predictPath)
          .toString();
    }
    return config.endpoint(config.cervicalUploadPath).toString();
  }

  static int get timeoutSeconds {
    final config = EdgeDeviceConfig.fromEnvironment();
    if (!config.modelManagementEnabled) return config.uploadTimeout.inSeconds;
    // Separate phases: connect, select, model readiness, then inference.
    return (config.requestTimeout +
            config.modelRequestTimeout +
            config.modelReadyTimeout +
            config.inferenceTimeout)
        .inSeconds;
  }

  static int get healthTimeoutSeconds =>
      EdgeDeviceConfig.fromEnvironment().requestTimeout.inSeconds;

  static const retryIntervalSeconds = int.fromEnvironment(
    'CERVICAL_DEVICE_RETRY_INTERVAL_SECONDS',
    defaultValue: 5,
  );
}

class PiDeviceConfig {
  const PiDeviceConfig._();

  static String get baseUrl => EdgeDeviceConfig.fromEnvironment().baseUrl;

  static String get normalizedBaseUrl =>
      baseUrl.replaceFirst(RegExp(r'/+$'), '');

  static String get healthUrl => CervicalDeviceConfig.healthUrl;

  static String uploadUrlFor(String examinationType) {
    final cleanType = examinationType
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_\-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    final config = EdgeDeviceConfig.fromEnvironment();
    return config.endpoint('/upload/$cleanType').toString();
  }
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

  CervicalDeviceInterpretation withError(String message) {
    return CervicalDeviceInterpretation(
      label: label,
      confidence: confidence,
      rawResponse: rawResponse,
      riskLevel: riskLevel,
      deviceStatus: 'failed',
      deviceEndpoint: deviceEndpoint,
      error: message,
    );
  }

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

  static EdgeDeviceManager get _deviceManager => EdgeDeviceManager.shared;
  static EdgeDeviceClient get _deviceClient => _deviceManager.client;

  static Future<CervicalDeviceInterpretation> analyzeImage(
    String base64Image,
    String? patientId, {
    Duration? timeout,
    @visibleForTesting EdgeDeviceManager? deviceManager,
  }) async {
    return _sendImage(
      base64Image,
      patientId,
      deviceManager: deviceManager,
    ).timeout(
      timeout ?? Duration(seconds: CervicalDeviceConfig.timeoutSeconds),
    );
  }

  static Future<void> checkHealth() async {
    try {
      await _deviceClient.checkHealth();
    } on EdgeDeviceException catch (error) {
      if (error.failure == EdgeDeviceFailure.timeout) {
        throw TimeoutException(error.message);
      }
      if (error.statusCode != null) {
        throw CervicalDeviceHttpException(error.statusCode!, error.message);
      }
      rethrow;
    }
  }

  static Future<CervicalDeviceInterpretation> _sendImage(
    String base64Image,
    String? patientId, {
    EdgeDeviceManager? deviceManager,
  }) async {
    final manager = deviceManager ?? _deviceManager;
    final client = manager.client;
    final decoded = _decodeBase64Image(base64Image);
    final normalizedPatientId = patientId?.trim();
    final examinationId = const Uuid().v4();
    var modelSessionReady = false;
    try {
      if (manager.modelManagementEnabled) {
        await manager.beginExamination(
          model: EdgeAIModel.cervicalCancer,
          examinationId: examinationId,
        );
        await manager.markExamining(examinationId);
        modelSessionReady = true;
      }

      if (modelSessionReady) {
        try {
          if (kDebugMode) {
            debugPrint('[Device] Sending cervical image to '
                '${client.config.moduleEndpoint(EdgeAIModel.cervicalCancer, client.config.predictPath)}');
          }
          final response = await client.predictCervical(
            imageBytes: decoded.bytes,
            filename: 'cervical.${decoded.extension}',
            mimeType: decoded.mimeType,
          );
          if (kDebugMode) {
            debugPrint(
                '[Device] Cervical inference response: HTTP ${response.statusCode}');
          }
          return _parseCervitriageResponse(
            response.statusCode,
            response.body,
            deviceEndpoint: client.config
                .moduleEndpoint(
                  EdgeAIModel.cervicalCancer,
                  client.config.predictPath,
                )
                .toString(),
          );
        } finally {
          await manager.completeExamination(examinationId);
        }
      }

      final response = await client.uploadCervicalImage(
        imageBytes: decoded.bytes,
        filename: 'cervical.${decoded.extension}',
        mimeType: decoded.mimeType,
        patientId: normalizedPatientId?.isNotEmpty == true
            ? normalizedPatientId!
            : 'unassigned',
      );
      return _parseDeviceResponse(
        response.body,
        deviceEndpoint: client.config
            .endpoint(
              client.config.cervicalUploadPath,
            )
            .toString(),
      );
    } on EdgeDeviceException catch (error) {
      if (error.failure == EdgeDeviceFailure.timeout) {
        throw TimeoutException(error.message);
      }
      if (error.statusCode != null) {
        throw CervicalDeviceHttpException(error.statusCode!, error.message);
      }
      rethrow;
    }
  }

  /// Parses cervitriage `POST /predict`: `classification`, `confidence`
  /// (0-1), `probabilities`, `gatekeeper_flagged`, `message`, `timings_ms`,
  /// `record_id`. HTTP 422 is a gatekeeper rejection, not a connection failure.
  @visibleForTesting
  static CervicalDeviceInterpretation parseCervitriageResponse(
    int statusCode,
    String body, {
    required String deviceEndpoint,
  }) =>
      _parseCervitriageResponse(
        statusCode,
        body,
        deviceEndpoint: deviceEndpoint,
      );

  static CervicalDeviceInterpretation _parseCervitriageResponse(
    int statusCode,
    String body, {
    required String deviceEndpoint,
  }) {
    Map<String, dynamic> raw;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      raw = decoded;
    } on FormatException {
      return CervicalDeviceInterpretation.failure(
        label: 'Error',
        message: 'The device returned an invalid prediction response.',
        rawResponse: {'text': body},
        deviceStatus: 'failed',
        deviceEndpoint: deviceEndpoint,
      );
    }

    if (statusCode == 422 || raw['gatekeeper_flagged'] == true) {
      final message = raw['message'];
      return CervicalDeviceInterpretation.failure(
        label: 'Image rejected',
        message: message is String && message.trim().isNotEmpty
            ? message
            : 'The device rejected the image as not suitable for cervical screening.',
        rawResponse: raw,
        deviceStatus: 'rejected',
        deviceEndpoint: deviceEndpoint,
      );
    }

    final classification = raw['classification'];
    final confidence = raw['confidence'];
    final gatekeeper = raw['gatekeeper_flagged'];
    final probabilities = raw['probabilities'];
    if (classification is! String ||
        classification.trim().isEmpty ||
        CacxRiskMapper.riskLevelFor(classification) == 'unknown' ||
        (gatekeeper != null && gatekeeper is! bool) ||
        (probabilities != null &&
            (probabilities is! Map ||
                probabilities.values.any((value) =>
                    value is! num ||
                    !value.isFinite ||
                    value < 0 ||
                    value > 1))) ||
        confidence is! num ||
        !confidence.isFinite ||
        confidence < 0 ||
        confidence > 1) {
      return CervicalDeviceInterpretation.failure(
        label: 'Error',
        message:
            'The device prediction did not include a valid classification and confidence.',
        rawResponse: raw,
        deviceStatus: 'failed',
        deviceEndpoint: deviceEndpoint,
      );
    }

    final label = classification.trim();
    return CervicalDeviceInterpretation(
      label: label,
      confidence: double.parse((confidence * 100).toStringAsFixed(1)),
      rawResponse: raw,
      riskLevel: CacxRiskMapper.riskLevelFor(label),
      deviceStatus: 'success',
      deviceEndpoint: deviceEndpoint,
    );
  }

  static CervicalDeviceInterpretation _parseDeviceResponse(
    String body, {
    required String deviceEndpoint,
  }) {
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
    final label = _cleanLabel(
      extractedLabel ?? (decoded is String ? decoded : ''),
    );
    final confidence = _findConfidence(decoded);
    final riskLevel = CacxRiskMapper.riskLevelFor(label);
    final hasResult = label.isNotEmpty && label != 'Unknown';

    return CervicalDeviceInterpretation(
      label: hasResult ? label : 'Unknown',
      confidence: confidence,
      rawResponse: rawResponse,
      riskLevel: hasResult ? riskLevel : 'unknown',
      deviceStatus: errorText == null && hasResult ? 'success' : 'failed',
      deviceEndpoint: deviceEndpoint,
      error: errorText ??
          (hasResult ? null : 'The device response did not contain a result.'),
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
  static const _pendingQueueKey = 'dawa_pending_cacx_screenings_v1';

  /// The current database constraint has no separate rejection value. Retain
  /// the rejection label and response, but persist it as a failed attempt.
  @visibleForTesting
  static String persistedDeviceStatus(CervicalDeviceInterpretation primary) =>
      primary.deviceStatus == 'rejected' ? 'failed' : primary.deviceStatus;

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
    final payload = _primaryPayload(
      patientId: patientId,
      userId: userId,
      imagePath: imagePath,
      primary: primary,
      secondOpinionRequired: secondOpinionRequired,
      secondOpinionStatus: secondOpinionStatus,
    );

    try {
      final response = await runSupabaseRequest(
        () => supabaseClient.from(table).insert(payload).select('id').single(),
      );
      return response['id']?.toString();
    } catch (error) {
      debugPrint('[CaCx Supabase] primary save failed: $error');
      await _enqueuePendingInsert(payload);
      return null;
    }
  }

  static Future<void> enqueuePrimaryResult({
    required String? patientId,
    required String? userId,
    required String imagePath,
    required CervicalDeviceInterpretation primary,
    required bool secondOpinionRequired,
    required String secondOpinionStatus,
  }) async {
    await _enqueuePendingInsert(
      _primaryPayload(
        patientId: patientId,
        userId: userId,
        imagePath: imagePath,
        primary: primary,
        secondOpinionRequired: secondOpinionRequired,
        secondOpinionStatus: secondOpinionStatus,
      ),
    );
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

  static Future<bool> updatePrimaryResult({
    required String? recordId,
    required CervicalDeviceInterpretation primary,
  }) async {
    if (recordId == null || recordId.isEmpty) return false;

    final payload = <String, dynamic>{
      'primary_source': 'arduino_device',
      'primary_result': primary.label,
      'primary_confidence': primary.confidence,
      'primary_raw_response': primary.rawResponse,
      'risk_level': primary.riskLevel,
      'device_endpoint': primary.deviceEndpoint,
      'device_status': persistedDeviceStatus(primary),
      'device_error': primary.error,
    };

    try {
      final response = await runSupabaseRequest(
        () => supabaseClient
            .from(table)
            .update(payload)
            .eq('id', recordId)
            .select('id')
            .maybeSingle(),
      );
      return response != null;
    } catch (error) {
      debugPrint('[CaCx Supabase] primary update failed: $error');
      return false;
    }
  }

  static String _pathPart(String? value, {required String fallback}) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return fallback;
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
  }

  static Map<String, dynamic> _primaryPayload({
    required String? patientId,
    required String? userId,
    required String imagePath,
    required CervicalDeviceInterpretation primary,
    required bool secondOpinionRequired,
    required String secondOpinionStatus,
  }) {
    return <String, dynamic>{
      'patient_id': patientId,
      'user_id': userId,
      'image_path': imagePath,
      'primary_source': 'arduino_device',
      'primary_result': primary.label,
      'primary_confidence': primary.confidence,
      'primary_raw_response': primary.rawResponse,
      'second_opinion_required': secondOpinionRequired,
      'second_opinion_status': secondOpinionStatus,
      'second_opinion_source': null,
      'risk_level': primary.riskLevel,
      'device_endpoint': primary.deviceEndpoint,
      'device_status': persistedDeviceStatus(primary),
      'device_error': primary.error,
    };
  }

  static Future<void> syncPending() async {
    final pending = await _readPending();
    if (pending.isEmpty) {
      return;
    }

    final remaining = <Map<String, dynamic>>[];
    for (final item in pending) {
      final payload = _mapValue(item['payload']);
      if (payload == null) {
        continue;
      }
      try {
        await runSupabaseRequest(
          () =>
              supabaseClient.from(table).insert(payload).select('id').single(),
        );
      } catch (error) {
        debugPrint('[CaCx Supabase] pending sync failed: $error');
        remaining.add(item);
      }
    }
    await _writePending(remaining);
  }

  static Future<int> pendingCount() async => (await _readPending()).length;

  static Future<void> _enqueuePendingInsert(
    Map<String, dynamic> payload,
  ) async {
    final pending = await _readPending();
    pending.add({
      'type': 'insert_primary',
      'queued_at': DateTime.now().toUtc().toIso8601String(),
      'payload': payload,
    });
    await _writePending(pending);
  }

  static Future<List<Map<String, dynamic>>> _readPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingQueueKey);
    if (raw == null || raw.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Map<String, dynamic>>[];
      }
      return decoded
          .whereType<Map>()
          .map((item) => item.map(
                (key, value) => MapEntry(key.toString(), value),
              ))
          .toList();
    } catch (error) {
      debugPrint('[CaCx Supabase] pending queue read failed: $error');
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> _writePending(
    List<Map<String, dynamic>> pending,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingQueueKey, jsonEncode(pending));
  }

  static Map<String, dynamic>? _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, dynamic item) => MapEntry(key.toString(), item));
    }
    return null;
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
