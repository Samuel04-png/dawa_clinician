import 'package:clinician/application/cacx/cacx_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AnalysisResult merges duplicate class aliases and sorts by confidence',
      () {
    final result = AnalysisResult.fromJson({
      'label': 'Normal',
      'confidence': 92.6,
      'suspicionLevel': 'low',
      'recommendation': 'Routine follow-up',
      'predictionBreakdown': [
        {
          'label': 'Normal',
          'confidence': 92.6,
          'isTopPrediction': true,
        },
        {
          'label': 'Negative',
          'score': 0.926,
        },
        {
          'label': 'CIN3',
          'confidence': 7.4,
        },
        {
          'label': 'Cancer',
          'confidence_percent': 0.0,
        },
        {
          'label': 'CIN2',
          'confidence': 0,
        },
      ],
    });

    expect(result.label, 'Normal / Negative VIA');
    expect(result.predictionBreakdown, hasLength(4));
    expect(result.predictionBreakdown.first.label, 'Normal / Negative VIA');
    expect(result.predictionBreakdown.first.confidence, 92.6);
    expect(
      result.predictionBreakdown.where(
        (item) => item.label == 'Normal / Negative VIA',
      ),
      hasLength(1),
    );
    expect(result.predictionBreakdown[1].label, 'CIN3');
    expect(result.predictionBreakdown[1].confidence, 7.4);
  });

  test('normalizeCacxConfidence handles raw fractions and percentages', () {
    expect(normalizeCacxConfidence(0.926), 92.6);
    expect(normalizeCacxConfidence('7.4'), 7.4);
    expect(normalizeCacxConfidence(92.6), 92.6);
    expect(normalizeCacxConfidence(null), 0);
  });
}
