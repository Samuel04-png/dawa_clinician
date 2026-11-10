// Read-only edge-device probe using the app's own client.
// Usage: dart run tool/edge_device_readonly_check.dart http://<host>
// Sends GET requests only: no module selection, no inference, no stop.
import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_exceptions.dart';
import 'package:clinician/services/edge_device/edge_device_models.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run tool/edge_device_readonly_check.dart http://<host>');
    return;
  }
  final client = EdgeDeviceClient(
    config: EdgeDeviceConfig(
      baseUrl: args.first,
      modelManagementEnabled: true,
    ),
  );
  try {
    print('hub /health -> HTTP ${await client.checkHealth()}');
    final status = await client.getHubStatus();
    print('hub status: active=${status.active} state=${status.state} '
        'modules=${status.moduleIds}');
    for (final model in EdgeAIModel.values) {
      try {
        final health = await client.getModuleHealth(model);
        print('${model.wireValue} health: reachable=${health.serverReachable} '
            'modelLoaded=${health.modelLoaded} '
            'inferenceReady=${health.inferenceReady}');
      } on EdgeDeviceException catch (error) {
        print('${model.wireValue} health: ${error.failure.name} '
            '(${error.message})');
      }
    }
  } on EdgeDeviceException catch (error) {
    print('FAILED: ${error.failure.name}: ${error.message}');
  } finally {
    client.close();
  }
}
