// Opt in explicitly on an idle board. No images or patient information are sent.
import 'dart:io';
import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_manager.dart';
import 'package:clinician/services/edge_device/edge_device_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'live hub initializes all workflows and enforces the app examination lifecycle',
      () async {
    HttpOverrides.global = null;
    final manager = EdgeDeviceManager(
        client: EdgeDeviceClient(config: EdgeDeviceConfig.fromEnvironment()));
    final initial = await manager.client.getHubStatus();
    final original = EdgeAIModel.fromWireValue(initial.active);
    expect(initial.hasExamination || initial.busy, false,
        reason: 'Run only on an idle board');
    try {
      for (final model in [
        EdgeAIModel.cervicalCancer,
        EdgeAIModel.anemia,
        EdgeAIModel.ultrasound
      ]) {
        final before = await manager.client.getHubStatus();
        expect(before.hasExamination || before.busy, false,
            reason: 'Do not interrupt another examination');
        final watch = Stopwatch()..start();
        await manager.prepareWorkflow(model);
        expect(manager.state, EdgeDeviceState.ready,
            reason: manager.readinessMessage);
        expect(manager.observedReadyModel, model);
        expect(
            (await manager.client.getHubStatus()).isReadyFor(model.wireValue),
            true);
        final examinationId = 'nonclinical-integration-${model.wireValue}';
        await manager.beginExamination(
            model: model, examinationId: examinationId);
        expect((await manager.client.getHubStatus()).hasExamination, true);
        await manager.markExamining(examinationId);
        // Lifecycle check only; no prediction is submitted.
        manager.finishInference(examinationId);
        await manager.completeExamination(examinationId);
        expect((await manager.client.getHubStatus()).hasExamination, false);
        // ignore: avoid_print
        print(
            'LIVE PASS ${model.wireValue}: initialized and lock released in ${watch.elapsed.inSeconds}s; no image submitted');
      }
    } finally {
      final id = manager.activeExaminationId;
      if (id != null) await manager.completeExamination(id);
      final status = await manager.client.getHubStatus();
      if (original != null &&
          !status.hasExamination &&
          !status.busy &&
          status.active != original.wireValue) {
        await manager.prepareWorkflow(original);
      }
      manager.dispose();
    }
  },
      skip: !const bool.fromEnvironment('RUN_LIVE_EDGE_DEVICE_CHECKS'),
      timeout: const Timeout(Duration(minutes: 8)));
}
