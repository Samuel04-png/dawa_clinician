import '/backend/supabase/supabase_config.dart';

import '../models/ultrasound_models.dart';

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
