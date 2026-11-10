import 'dart:convert';

import 'package:http/http.dart' as http;

import '/services/edge_device/edge_device_exceptions.dart';
import '/services/edge_device/edge_device_manager.dart';
import '/services/edge_device/edge_device_models.dart';
import '../models/ultrasound_models.dart';

/// Ultrasound inference on the Dawa edge device: the hub must have selected
/// the `ultrasound` module and its health must confirm the model is loaded
/// (see [EdgeDeviceManager]) before an image is sent to `POST /predict`.
class UltrasoundEdgeService {
  const UltrasoundEdgeService({
    required this.deviceManager,
  });

  final EdgeDeviceManager deviceManager;

  bool supportsImageFormat(String mimeType) {
    return deviceManager.client.config.supportedImageMimeTypes
        .contains(mimeType.toLowerCase());
  }

  Future<EdgeDeviceModelStatus> prepareExamination({
    required String examinationId,
  }) {
    return deviceManager.beginExamination(
      model: EdgeAIModel.ultrasound,
      examinationId: examinationId,
    );
  }

  /// Returns a segmentation result only for a validated device response.
  /// [box] is `x0, y0, x1, y1` in image pixels; [pixelSpacingMm] is
  /// millimetres per pixel. Both are optional and never invented here.
  Future<UltrasoundAnalysisResult> analyzeImage({
    required String image,
    required String examinationId,
    int? gestationalAgeWeeks,
    List<double>? box,
    double? pixelSpacingMm,
  }) async {
    final requestId = deviceManager.activeRequestId;
    if (!{EdgeDeviceState.ready, EdgeDeviceState.examining}
            .contains(deviceManager.state) ||
        deviceManager.activeExaminationId != examinationId ||
        deviceManager.activeModel != EdgeAIModel.ultrasound ||
        requestId == null) {
      throw const EdgeDeviceException(
        failure: EdgeDeviceFailure.conflict,
        message:
            'Ultrasound inference requires confirmed readiness for this examination.',
      );
    }
    if (!deviceManager.client.config.ultrasoundInferenceEnabled) {
      throw const EdgeDeviceException(
        failure: EdgeDeviceFailure.disabled,
        message:
            'Ultrasound edge inference is disabled until the device integration is verified.',
      );
    }
    final decoded = _decodeImage(image);
    if (!supportsImageFormat(decoded.mimeType)) {
      throw EdgeDeviceException(
        failure: EdgeDeviceFailure.unsupported,
        message: '${decoded.mimeType} is not a configured edge image format.',
      );
    }

    if (deviceManager.state == EdgeDeviceState.ready) {
      await deviceManager.markExamining(examinationId);
    }
    try {
      final response = await deviceManager.client.predictUltrasound(
        imageBytes: decoded.bytes,
        filename: 'ultrasound.${decoded.extension}',
        mimeType: decoded.mimeType,
        box: box,
        pixelSpacingMm: pixelSpacingMm,
      );
      final payload = _decodeResponse(response);
      final UltrasoundSegmentation segmentation;
      try {
        segmentation = UltrasoundSegmentation.fromDeviceJson(payload);
      } on FormatException catch (error) {
        throw EdgeDeviceException(
          failure: EdgeDeviceFailure.invalidResponse,
          message: 'Invalid ultrasound response: ${error.message}',
        );
      }

      return UltrasoundAnalysisResult(
        imageUrl: image,
        findings: const [],
        overallAssessment: _describe(segmentation),
        overallLevel: null,
        recommendation: '',
        provider: UltrasoundAnalysisProvider.edgeDevice,
        examinationId: examinationId,
        modelId: deviceManager.client.config.ultrasoundModelId,
        deviceId: deviceManager.client.config.endpoint('/').host,
        segmentation: segmentation,
      );
    } on EdgeDeviceException {
      deviceManager.markExaminationError(examinationId);
      rethrow;
    }
  }

  static String _describe(UltrasoundSegmentation segmentation) {
    if (!segmentation.found) {
      return 'No abdominal segmentation was found in this image. '
          'No measurement is available.';
    }
    final pixels =
        'Abdominal circumference ${segmentation.circumferencePx!.toStringAsFixed(1)} px';
    return segmentation.isCalibrated
        ? '$pixels (${segmentation.circumferenceMm!.toStringAsFixed(1)} mm with the supplied pixel spacing).'
        : '$pixels. Pixel spacing is not calibrated, so no millimetre value is available.';
  }

  static _UltrasoundImage _decodeImage(String value) {
    final dataUri =
        RegExp(r'^data:(image/[a-zA-Z0-9.+-]+);base64,(.*)$').firstMatch(value);
    final mimeType = dataUri?.group(1) ?? 'image/jpeg';
    final encoded = dataUri?.group(2) ?? value;
    try {
      final bytes = base64Decode(encoded);
      final extension = mimeType.split('/').last.toLowerCase();
      return _UltrasoundImage(
        bytes: bytes,
        mimeType: mimeType,
        extension: extension == 'jpeg' ? 'jpg' : extension,
      );
    } on FormatException catch (error) {
      throw EdgeDeviceException(
        failure: EdgeDeviceFailure.invalidConfiguration,
        message: 'The selected Ultrasound image is invalid: ${error.message}',
      );
    }
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      if (value is Map<String, dynamic>) return value;
    } on FormatException catch (error) {
      throw EdgeDeviceException(
        failure: EdgeDeviceFailure.invalidResponse,
        message: 'Device returned invalid inference JSON: ${error.message}',
      );
    }
    throw const EdgeDeviceException(
      failure: EdgeDeviceFailure.invalidResponse,
      message: 'Device inference response must be a JSON object.',
    );
  }
}

class _UltrasoundImage {
  const _UltrasoundImage({
    required this.bytes,
    required this.mimeType,
    required this.extension,
  });

  final List<int> bytes;
  final String mimeType;
  final String extension;
}
