import 'package:flutter/material.dart';
import '/services/edge_device/edge_device_manager.dart';
import '/services/edge_device/edge_device_models.dart';
import 'navigation_design_system.dart';

/// A model-specific view of the shared device; another page's ready state must
/// never be presented as readiness for this screening.
class EdgeWorkflowStatus extends StatelessWidget {
  const EdgeWorkflowStatus(
      {super.key,
      required this.manager,
      required this.model,
      this.onRetry,
      this.examinationId,
      this.compact = false,
      this.isRelevant = true});
  final String? examinationId;
  final EdgeDeviceManager manager;
  final EdgeAIModel model;
  final VoidCallback? onRetry;

  /// Routine hub state belongs in the shared app-bar control. A workspace
  /// opts in only after a clinician has begun preparing an examination.
  final bool isRelevant;
  final bool compact;

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
        // Preparation remains visible alongside acquisition without exposing
        // transport errors or conflating connectivity with model readiness.
        if (!isRelevant) {
          return const SizedBox.shrink();
        }
        final status = Text(
          'Hub: ${manager.hubConnected == true ? 'connected' : manager.hubConnected == false ? 'not connected' : 'checking'} · Model: ${blocked ? 'in use by another screening' : switch (state) {
              EdgeDeviceState.ready => 'ready',
              EdgeDeviceState.loadingModel => 'starting',
              EdgeDeviceState.examining => 'analysis in progress',
              EdgeDeviceState.error => 'unavailable — retry connection',
              EdgeDeviceState.disconnected => 'not ready',
              EdgeDeviceState.unsupported => 'unavailable on this installation',
              _ => 'preparing',
            }}',
          style: NavigationTokens.detailStyle,
        );
        final retry = TextButton.icon(
            onPressed: onRetry ?? () => manager.prepareWorkflow(model),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry connection / Check again'));
        if (compact)
          return Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [status, if (canRetry) retry]);
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              status,
              if (canRetry)
                Align(alignment: Alignment.centerRight, child: retry),
            ]);
      });
}
