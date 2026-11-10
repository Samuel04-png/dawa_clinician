enum EdgeAIModel {
  cervicalCancer('cervitriage'),
  ultrasound('ultrasound');

  const EdgeAIModel(this.wireValue);

  final String wireValue;

  static EdgeAIModel? fromWireValue(String? value) {
    for (final model in values) {
      if (model.wireValue == value) return model;
    }
    return null;
  }
}

enum EdgeDeviceState {
  disconnected,
  connecting,
  connected,
  checkingCapabilities,
  loadingModel,
  ready,
  examining,
  busy,
  error,
  unverified,
  unsupported,
}

enum EdgeDeviceModelState {
  loading,
  ready,
  busy,
  error,
  unsupported,
  completed,
}

/// Hub module lifecycle as reported by `GET /api/status` (`state`).
enum EdgeHubModuleState { stopped, starting, notReady, ready, error }

/// Parsed `GET /api/status` response of the Dawa hub (dawa/main.py).
class EdgeHubStatus {
  const EdgeHubStatus({
    required this.state,
    this.active,
    this.message = '',
    this.moduleIds = const {},
  });

  factory EdgeHubStatus.fromJson(Map<String, dynamic> json) {
    final stateValue = json['state'];
    final state = switch (stateValue) {
      'stopped' => EdgeHubModuleState.stopped,
      'starting' => EdgeHubModuleState.starting,
      'not_ready' => EdgeHubModuleState.notReady,
      'ready' => EdgeHubModuleState.ready,
      'error' => EdgeHubModuleState.error,
      _ => throw FormatException('Unknown hub state: $stateValue'),
    };
    final active = json['active'];
    final message = json['message'];
    final modules = json['modules'];
    if (active != null && active is! String ||
        message != null && message is! String ||
        modules != null && modules is! Map) {
      throw const FormatException('Hub status contains invalid field types.');
    }
    return EdgeHubStatus(
      state: state,
      active: active as String?,
      message: (message as String?) ?? '',
      moduleIds: Set<String>.unmodifiable(
        (modules as Map? ?? const {}).keys.map((key) => key.toString()),
      ),
    );
  }

  final EdgeHubModuleState state;
  final String? active;
  final String message;
  final Set<String> moduleIds;
}

/// Parsed module `GET /health`. HTTP 200 only proves the server is reachable;
/// [modelLoaded] requires the module's own affirmative readiness field.
class EdgeModuleHealth {
  const EdgeModuleHealth({
    required this.status,
    required this.modelLoaded,
    this.message,
  });

  factory EdgeModuleHealth.fromJson(
    Map<String, dynamic> json, {
    required String readyField,
  }) {
    final status = json['status'];
    final message = json['message'];
    if (status is! String || message != null && message is! String) {
      throw const FormatException('Module health has invalid field types.');
    }
    return EdgeModuleHealth(
      status: status,
      modelLoaded: json[readyField] == true,
      message: message as String?,
    );
  }

  final String status;
  final bool modelLoaded;
  final String? message;

  bool get serverReachable => true;
  bool get inferenceReady => modelLoaded && status == 'ok';
}

class EdgeDeviceModelStatus {
  const EdgeDeviceModelStatus({
    required this.state,
    this.activeModelId,
    this.examinationId,
    this.requestId,
    this.message,
  });

  final EdgeDeviceModelState state;
  final String? activeModelId;
  final String? examinationId;
  final String? requestId;
  final String? message;

  EdgeAIModel? get activeModel => EdgeAIModel.fromWireValue(activeModelId);
}
