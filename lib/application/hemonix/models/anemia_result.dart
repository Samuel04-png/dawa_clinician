/// Validated output of George's deployed lower-eyelid prototype.
/// This classifier does not measure haemoglobin concentration.
class AnemiaResult {
  const AnemiaResult(
      {required this.classification,
      required this.confidence,
      required this.probabilities,
      required this.disclaimer,
      required this.examinationId,
      required this.deviceId,
      this.deviceRecordId});

  static const classes = [
    'No Anemia',
    'Mild Anemia',
    'Moderate Anemia',
    'Severe Anemia'
  ];
  static const prototypeNotice =
      'Prototype screening model with limited validation (57.7% reported validation accuracy). '
      'The fine-tuned backbone is pending. This is an AI estimate, not a diagnosis or a haemoglobin measurement. '
      'A clinician must review the result and confirm findings using an appropriate clinical assessment.';

  factory AnemiaResult.fromDeviceJson(Map<String, dynamic> json,
      {required String examinationId, required String deviceId}) {
    final classification = json['classification'];
    final confidence = json['confidence'];
    final index = json['class_index'];
    final rawProbabilities = json['probabilities'];
    final disclaimer = json['disclaimer'];
    if (classification is! String ||
        !classes.contains(classification) ||
        confidence is! num ||
        !confidence.isFinite ||
        confidence < 0 ||
        confidence > 1 ||
        index is! int ||
        index < 0 ||
        index >= classes.length ||
        classes[index] != classification ||
        rawProbabilities is! Map ||
        rawProbabilities.length != classes.length ||
        disclaimer is! String ||
        disclaimer.trim().isEmpty ||
        examinationId.trim().isEmpty ||
        deviceId.trim().isEmpty) {
      throw const FormatException(
          'The device returned an invalid anemia screening result.');
    }
    final probabilities = <String, double>{};
    for (final label in classes) {
      final value = rawProbabilities[label];
      if (value is! num || !value.isFinite || value < 0 || value > 1) {
        throw const FormatException(
            'The device returned invalid anemia probabilities.');
      }
      probabilities[label] = value.toDouble();
    }
    final total = probabilities.values.reduce((a, b) => a + b);
    if ((total - 1).abs() > 0.02 ||
        (probabilities[classification]! - confidence).abs() > 0.02 ||
        probabilities.values.any((v) => v > confidence + 0.02)) {
      throw const FormatException(
          'The anemia classification and probabilities do not agree.');
    }
    return AnemiaResult(
        classification: classification,
        confidence: confidence.toDouble(),
        probabilities: Map.unmodifiable(probabilities),
        disclaimer: disclaimer,
        examinationId: examinationId,
        deviceId: deviceId,
        deviceRecordId: json['record_id'] is num || json['record_id'] is String
            ? json['record_id'].toString()
            : null);
  }

  final String classification;
  final double confidence;
  final Map<String, double> probabilities;
  final String disclaimer;
  final String examinationId;
  final String deviceId;
  final String? deviceRecordId;
  Map<String, dynamic> toDeviceJson() => {
        'classification': classification,
        'class_index': classes.indexOf(classification),
        'confidence': confidence,
        'probabilities': probabilities,
        'disclaimer': disclaimer,
        'record_id': deviceRecordId,
      };
  bool get lowConfidence => confidence < 0.5;
}

class AnemiaScreeningRecord {
  const AnemiaScreeningRecord(
      {required this.id,
      required this.patientId,
      required this.patientName,
      required this.createdAt,
      required this.result,
      required this.reviewNotes,
      this.userId,
      this.clinicId,
      this.modelId = 'anemia'});
  final String id;
  final String patientId;
  final String patientName;
  final DateTime createdAt;
  final AnemiaResult result;
  final String reviewNotes;
  final String? userId;
  final String? clinicId;
  final String modelId;
}
