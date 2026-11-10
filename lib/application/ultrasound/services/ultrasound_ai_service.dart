import '/backend/supabase/supabase_config.dart';

import '../models/ultrasound_models.dart';

class UltrasoundAIService {
  static UltrasoundAnalysisResult unavailableResult(
    String image,
    String error,
  ) {
    return _errorResult(image, error);
  }

  static Future<UltrasoundAnalysisResult> analyzeUltrasoundImage(
    String base64Image,
    int? gestationalAgeWeeks,
    String examinationId,
  ) async {
    try {
      final response = await supabaseClient.functions.invoke(
        'analyze-ultrasound-image',
        body: {
          'imageBase64': base64Image,
          'gestationalAgeWeeks': gestationalAgeWeeks,
          'examinationId': examinationId,
        },
      );

      if (response.status < 200 || response.status >= 300) {
        return _errorResult(base64Image, 'Server error ${response.status}');
      }

      final data = response.data;
      return parseResponse(
        base64Image,
        data,
        expectedExaminationId: examinationId,
      );
    } catch (e) {
      return _errorResult(base64Image, e.toString());
    }
  }

  static UltrasoundAnalysisResult parseResponse(
    String imageUrl,
    dynamic data, {
    String? expectedExaminationId,
    String? expectedModelId,
  }) {
    if (data is! Map<String, dynamic>) {
      return _errorResult(
          imageUrl, 'The analysis service returned an invalid response.');
    }

    final assessment = data['overallAssessment'];
    final recommendation = data['recommendation'];
    final providerValue = data['analysisProvider'];
    if (providerValue is! String) {
      return _errorResult(
        imageUrl,
        'The analysis response did not identify its provider.',
      );
    }
    if (providerValue == 'unavailable') {
      final error = data['error'];
      return _errorResult(
        imageUrl,
        error is String
            ? error
            : 'No cloud AI model was available to analyze this image.',
      );
    }
    final serviceError = data['error'];
    if (serviceError is String && serviceError.isNotEmpty) {
      return _errorResult(imageUrl, serviceError);
    }
    final provider = switch (providerValue) {
      'gemini' => UltrasoundAnalysisProvider.cloud,
      'edgeDevice' => UltrasoundAnalysisProvider.edgeDevice,
      _ => UltrasoundAnalysisProvider.unavailable,
    };
    if (provider == UltrasoundAnalysisProvider.unavailable) {
      return _errorResult(
        imageUrl,
        'The analysis service did not identify a validated analysis provider.',
      );
    }

    final findingsValue = data['findings'];
    final overallLevelValue = data['overallLevel'];
    if (findingsValue is! List ||
        findingsValue.isEmpty ||
        assessment is! String ||
        assessment.trim().isEmpty ||
        overallLevelValue is! String ||
        recommendation is! String ||
        recommendation.trim().isEmpty) {
      return _errorResult(
          imageUrl, 'The analysis service returned incomplete findings.');
    }

    final overallLevel = _findingLevel(overallLevelValue);
    if (overallLevel == null) {
      return _errorResult(imageUrl,
          'The analysis service returned an unknown assessment level.');
    }

    final findings = <UltrasoundFinding>[];
    for (final item in findingsValue) {
      if (item is! Map<String, dynamic> ||
          item['category'] is! String ||
          (item['category'] as String).trim().isEmpty ||
          item['finding'] is! String ||
          (item['finding'] as String).trim().isEmpty ||
          item['level'] is! String) {
        return _errorResult(
            imageUrl, 'The analysis service returned an invalid finding.');
      }
      final level = _findingLevel(item['level'] as String);
      if (level == null) {
        return _errorResult(imageUrl,
            'The analysis service returned an unknown finding level.');
      }
      final note = item['note'];
      if (note != null && note is! String) {
        return _errorResult(
            imageUrl, 'The analysis service returned an invalid finding note.');
      }
      findings.add(
        UltrasoundFinding(
          category: item['category'] as String,
          finding: item['finding'] as String,
          level: level,
          note: note as String?,
        ),
      );
    }

    final estimatedGestationalAge = data['estimatedGestationalAge'];
    if (estimatedGestationalAge != null && estimatedGestationalAge is! int) {
      return _errorResult(imageUrl,
          'The analysis service returned an invalid gestational age.');
    }

    final measurementsValue = data['measurements'];
    Map<String, String>? measurements;
    if (measurementsValue != null) {
      if (measurementsValue is! Map ||
          measurementsValue.keys.any((key) => key is! String) ||
          measurementsValue.values.any((value) => value is! String)) {
        return _errorResult(
            imageUrl, 'The analysis service returned invalid measurements.');
      }
      measurements = Map<String, String>.from(measurementsValue);
    }
    final responseExaminationId = data['examinationId'];
    if (responseExaminationId is! String ||
        responseExaminationId.trim().isEmpty ||
        (expectedExaminationId != null &&
            responseExaminationId != expectedExaminationId)) {
      return _errorResult(
        imageUrl,
        'The analysis response did not match this examination.',
      );
    }
    final modelId = data['modelId'];
    if (modelId is! String ||
        modelId.trim().isEmpty ||
        (expectedModelId != null && modelId != expectedModelId)) {
      return _errorResult(
        imageUrl,
        'The analysis response omitted or mismatched model provenance.',
      );
    }
    final modelVersion = data['modelVersion'];
    if (modelVersion != null && modelVersion is! String) {
      return _errorResult(
        imageUrl,
        'The analysis response returned invalid model version provenance.',
      );
    }
    final deviceId = data['deviceId'];
    if (deviceId != null && deviceId is! String) {
      return _errorResult(
        imageUrl,
        'The analysis response returned invalid device provenance.',
      );
    }

    return UltrasoundAnalysisResult(
      imageUrl: imageUrl,
      findings: findings,
      overallAssessment: assessment,
      overallLevel: overallLevel,
      recommendation: recommendation,
      estimatedGestationalAge: estimatedGestationalAge as int?,
      measurements: measurements,
      provider: provider,
      examinationId: responseExaminationId,
      modelId: modelId,
      modelVersion: modelVersion as String?,
      deviceId: deviceId as String?,
    );
  }

  static FindingLevel? _findingLevel(String value) {
    for (final level in FindingLevel.values) {
      if (level.name == value) return level;
    }
    return null;
  }

  static UltrasoundAnalysisResult _errorResult(String imageUrl, String error) {
    return UltrasoundAnalysisResult(
      imageUrl: imageUrl,
      findings: const [],
      overallAssessment: 'Analysis unavailable',
      overallLevel: null,
      recommendation: 'Please retake the image and try again.',
      error: error,
      provider: UltrasoundAnalysisProvider.unavailable,
    );
  }
}

// ─── IMAGE PICKER SERVICE ─────────────────────────────────────────────────────
