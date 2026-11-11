import 'dart:convert';
import '/services/edge_device/edge_device_manager.dart';
import '/services/edge_device/edge_device_models.dart';
import '/services/edge_device/edge_device_exceptions.dart';
import '/services/edge_device/edge_image_input.dart';
import '../models/anemia_result.dart';

class AnemiaEdgeService {
  const AnemiaEdgeService(this.manager);
  final EdgeDeviceManager manager;

  Future<AnemiaResult> analyze(
      {required EdgeImageInput image, required String examinationId}) async {
    if (manager.observedReadyModel != EdgeAIModel.anemia ||
        manager.state != EdgeDeviceState.ready ||
        manager.activeExaminationId != null) {
      throw const EdgeDeviceException(
          failure: EdgeDeviceFailure.conflict,
          message:
              'Wait until Anemia AI is ready and the device is available.');
    }
    var receivedResponse = false;
    try {
      await manager.beginExamination(
          model: EdgeAIModel.anemia, examinationId: examinationId);
      await manager.markExamining(examinationId);
      final response = await manager.client.predictAnemia(
          imageBytes: image.bytes,
          filename: 'anemia.${image.extension}',
          mimeType: image.mimeType);
      receivedResponse = true;
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>)
        throw const FormatException('Invalid anemia response.');
      return AnemiaResult.fromDeviceJson(json,
          examinationId: examinationId,
          deviceId: manager.client.config.hubEndpoint('/').host);
    } on FormatException {
      throw const EdgeDeviceException(
          failure: EdgeDeviceFailure.invalidResponse,
          message:
              'The device response could not be validated. No screening result is available.');
    } on EdgeDeviceException {
      if (manager.activeExaminationId == examinationId)
        manager.markExaminationError(examinationId);
      rethrow;
    } finally {
      if (receivedResponse && manager.activeExaminationId == examinationId) {
        await manager.completeExamination(examinationId);
        // The model remains running. Reconfirm it without another selection.
        await manager.refreshObservedReadiness(EdgeAIModel.anemia);
      }
    }
  }
}
