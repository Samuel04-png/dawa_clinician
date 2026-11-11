import 'package:flutter/material.dart';
import '/services/edge_device/edge_device_manager.dart';
import '/services/edge_device/edge_device_models.dart';
import 'edge_device_status_banner.dart';

/// A model-specific view of the shared device; another page's ready state must
/// never be presented as readiness for this screening.
class EdgeWorkflowStatus extends StatelessWidget {
  const EdgeWorkflowStatus(
      {super.key,
      required this.manager,
      required this.model,
      this.onRetry,
      this.examinationId});
  final String? examinationId;
  final EdgeDeviceManager manager;
  final EdgeAIModel model;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: manager,
      builder: (context, _) {
        final otherExam = manager.activeExaminationId != null &&
            (manager.activeModel != model ||
                manager.activeExaminationId != examinationId);
        final otherWorkflow = manager.isPreparingWorkflow &&
            manager.requestedWorkflow != null &&
            manager.requestedWorkflow != model;
        final wrongReady = manager.state == EdgeDeviceState.ready &&
            (manager.activeModel ?? manager.observedReadyModel) != model;
        final blocked = otherExam || otherWorkflow || wrongReady;
        final state = !manager.modelManagementEnabled
            ? EdgeDeviceState.unsupported
            : blocked
                ? EdgeDeviceState.busy
                : manager.state;
        final canRetry = !otherExam &&
            !otherWorkflow &&
            manager.activeExaminationId == null &&
            {
              EdgeDeviceState.disconnected,
              EdgeDeviceState.error,
              EdgeDeviceState.busy,
              EdgeDeviceState.connected,
              EdgeDeviceState.unverified
            }.contains(state);
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EdgeDeviceStatusBanner(
                  model: model,
                  state: state,
                  takingLongerThanExpected: manager.takingLongerThanExpected,
                  message: blocked
                      ? 'Another screening is using the device. Patient and examination preparation remain available.'
                      : !manager.modelManagementEnabled
                          ? 'Local model management is disabled for this installation.'
                          : manager.readinessMessage),
              if (canRetry)
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                        onPressed:
                            onRetry ?? () => manager.prepareWorkflow(model),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry connection / Check again'))),
            ]);
      });
}
