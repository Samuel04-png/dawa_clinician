// Explicitly opt in on an idle device. This test NEVER sends an image.
import 'dart:convert';
import 'dart:io';
import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_manager.dart';
import 'package:clinician/services/edge_device/edge_device_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _ReadinessTransport extends http.BaseClient {
  final http.Client inner = http.Client();
  final acknowledgements = <int>[];
  var polls = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'GET' && request.url.path == '/api/status') polls++;
    if (request.url.path.startsWith('/upload/') ||
        request.url.path == '/predict')
      throw StateError('Image inference is not approved for this test.');
    final response = await inner.send(request);
    if (request.url.path == '/api/select')
      acknowledgements.add(response.statusCode);
    return response;
  }

  @override
  void close() => inner.close();
}

void main() {
  test(
      'physical device automatically selects anemia, confirms hub readiness, and restores prior model without inference',
      () async {
    HttpOverrides.global = null;
    final transport = _ReadinessTransport();
    final manager = EdgeDeviceManager(
        client: EdgeDeviceClient(
            config: EdgeDeviceConfig.fromEnvironment(), httpClient: transport));
    final before = await manager.client.getHubStatus();
    final original = EdgeAIModel.fromWireValue(before.active);
    if (before.busy || before.hasExamination) {
      manager.dispose();
      transport.close();
      markTestSkipped(
          'Device is occupied; no model selection or image submission attempted.');
      return;
    }
    var anemiaReadyVerified = false;
    try {
      await manager.prepareWorkflow(EdgeAIModel.anemia);
      final ready = await manager.client.getHubStatus();
      expect(ready.active, 'anemia');
      expect(ready.ready, true);
      expect(ready.state, EdgeHubModuleState.ready);
      expect(manager.observedReadyModel, EdgeAIModel.anemia);
      if (transport.acknowledgements.isEmpty)
        await manager.client.selectModel(EdgeAIModel.anemia);
      expect(transport.acknowledgements.first, 202);
      expect((await manager.client.getHubStatus()).isReadyFor('anemia'), true);
      anemiaReadyVerified = true;
      expect(transport.polls, greaterThanOrEqualTo(2));
      print(
          'PHYSICAL DEVICE PASS: automatic anemia selection and hub-confirmed readiness; no image inference performed');
    } finally {
      final now = await manager.client.getHubStatus();
      if (original != null &&
          now.active != original.wireValue &&
          !now.busy &&
          !now.hasExamination) {
        await manager.prepareWorkflow(original);
        expect(
            (await manager.client.getHubStatus())
                .isReadyFor(original.wireValue),
            true);
      }
      final path = Platform.environment['ANEMIA_VERIFICATION_CONFIG_FILE'];
      if (path != null)
        File('${File(path).parent.path}/device-live-report.json')
            .writeAsStringSync(jsonEncode({
          'anemia_initialization_verified': anemiaReadyVerified,
          'select_acknowledgements': transport.acknowledgements,
          'status_polls': transport.polls,
          'physical_device_inference_verified': false,
          'image_submitted': false,
        }));
      manager.dispose();
      transport.close();
    }
  },
      skip: !const bool.fromEnvironment('RUN_LIVE_ANEMIA_DEVICE_INIT_TESTS'),
      timeout: const Timeout(Duration(minutes: 7)));
}
