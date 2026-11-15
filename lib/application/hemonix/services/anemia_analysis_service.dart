import '/services/offline_connectivity_service.dart';
import '/services/edge_device/edge_device_exceptions.dart';
import '/services/edge_device/edge_device_manager.dart';
import '/services/edge_device/edge_device_models.dart';
import '/services/edge_device/edge_image_input.dart';
import '../models/anemia_result.dart';
import 'anemia_edge_service.dart';
import 'anemia_online_service.dart';

bool anemiaAllowsOnlineFailure(EdgeDeviceException error) =>
    switch (error.failure) {
      EdgeDeviceFailure.connection ||
      EdgeDeviceFailure.timeout ||
      EdgeDeviceFailure.modelInitialization =>
        true,
      EdgeDeviceFailure.http =>
        error.statusCode != null && error.statusCode! >= 500,
      _ => false,
    };

/// One edge attempt followed by at most one online attempt. Completed results,
/// invalid images/results, permission failures and device conflicts never fall back.
class AnemiaAnalysisService {
  const AnemiaAnalysisService(this.manager,
      {this.allowOnlineFallback = AnemiaOnlineConfig.allowFallback,
      this.online = const AnemiaOnlineService()});
  final EdgeDeviceManager manager;
  final bool allowOnlineFallback;
  final AnemiaOnlineService online;

  bool get edgeReady =>
      manager.state == EdgeDeviceState.ready &&
      manager.observedReadyModel == EdgeAIModel.anemia;
  bool get offline =>
      OfflineConnectivityService.statusNotifier.value?.internetAvailable ==
      false;
  bool get canAnalyze =>
      manager.activeExaminationId == null &&
      manager.state != EdgeDeviceState.busy;

  Future<AnemiaResult> analyze(
      {required EdgeImageInput image,
      required String examinationId,
      void Function()? onOnline,
      bool Function()? isCancelled}) async {
    if (examinationId.trim().isEmpty)
      throw const FormatException('Missing examination reference');
    if (isCancelled?.call() == true) throw const AnemiaAnalysisCancelled();
    if (!canAnalyze) {
      throw const EdgeDeviceException(
          failure: EdgeDeviceFailure.conflict,
          message:
              'Wait for the current device examination to finish, then try again.');
    }
    if (!edgeReady) {
      await manager.prepareWorkflow(EdgeAIModel.anemia);
    }
    if (!edgeReady) {
      final failure = manager.preparationFailure;
      if (failure != null && !anemiaAllowsOnlineFailure(failure)) throw failure;
      if (!allowOnlineFallback)
        throw failure ??
            const EdgeDeviceException(
                failure: EdgeDeviceFailure.connection,
                message: 'The local Dawa device is unavailable.');
    }
    if (edgeReady) {
      try {
        return await AnemiaEdgeService(manager)
            .analyze(image: image, examinationId: examinationId);
      } on EdgeDeviceException catch (error) {
        if (offline ||
            !allowOnlineFallback ||
            !anemiaAllowsOnlineFailure(error)) rethrow;
      }
    }
    if (isCancelled?.call() == true) throw const AnemiaAnalysisCancelled();
    if (offline)
      throw const EdgeDeviceException(
          failure: EdgeDeviceFailure.connection,
          message:
              'Connect to the local Dawa device to screen without internet.');
    onOnline?.call();
    return online.analyze(
        image: image,
        examinationId: examinationId,
        timeout: manager.client.config.inferenceTimeout,
        isCancelled: isCancelled);
  }
}
