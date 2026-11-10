import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'edge_device_client.dart';
import 'edge_device_exceptions.dart';
import 'edge_device_models.dart';

/// Tracks which edge AI module the clinician's current examination owns.
///
/// Flow: hub `GET /api/status` -> `POST /api/select` -> poll status until the
/// requested module is `ready` AND its own `/health` affirms the model is
/// loaded. The device offers no examination reservation or completion
/// endpoint, so the lock here is local to this app instance; completing an
/// examination only releases it locally and never stops the module.
class EdgeDeviceManager extends ChangeNotifier {
  EdgeDeviceManager({
    required this.client,
    bool? modelManagementEnabled,
  }) : modelManagementEnabled =
            modelManagementEnabled ?? client.config.modelManagementEnabled;

  static final EdgeDeviceManager shared = EdgeDeviceManager(
    client: EdgeDeviceClient(),
  );

  final EdgeDeviceClient client;
  final bool modelManagementEnabled;

  EdgeDeviceState _state = EdgeDeviceState.disconnected;
  EdgeAIModel? _activeModel;
  String? _activeExaminationId;
  String? _activeRequestId;
  Future<EdgeDeviceModelStatus>? _activationFuture;
  EdgeAIModel? _pendingModel;
  String? _pendingExaminationId;
  EdgeAIModel? _observedReadyModel;
  String? _readinessMessage;
  int _readinessGeneration = 0;

  EdgeDeviceState get state => _state;
  EdgeAIModel? get activeModel => _activeModel;
  String? get activeExaminationId => _activeExaminationId;
  String? get activeRequestId => _activeRequestId;
  EdgeAIModel? get observedReadyModel => _observedReadyModel;
  String? get readinessMessage => _readinessMessage;

  /// Inspect the current model without selecting or reserving a module.
  Future<void> refreshObservedReadiness(EdgeAIModel model) async {
    if (!modelManagementEnabled || _activeExaminationId != null) return;
    final generation = ++_readinessGeneration;
    bool current() =>
        generation == _readinessGeneration && _activeExaminationId == null;

    _observedReadyModel = null;
    _readinessMessage = null;
    _setState(EdgeDeviceState.connecting);
    try {
      final problem = client.config.configurationProblem(
        isWeb: kIsWeb,
        pageUri: kIsWeb ? Uri.base : null,
      );
      if (problem != null) {
        throw EdgeDeviceException(
          failure: EdgeDeviceFailure.invalidConfiguration,
          message: problem,
        );
      }
      final hub = await client.getHubStatus();
      if (!current()) return;
      final moduleId = client.config.modelId(model);
      if (hub.active != moduleId || hub.state != EdgeHubModuleState.ready) {
        _readinessMessage = hub.active == moduleId &&
                hub.state == EdgeHubModuleState.starting
            ? 'The requested module is starting; readiness is not yet confirmed.'
            : 'The requested model is not currently confirmed ready.';
        _setState(
            hub.active == moduleId && hub.state == EdgeHubModuleState.starting
                ? EdgeDeviceState.loadingModel
                : EdgeDeviceState.unverified);
        return;
      }
      final health = await client.getModuleHealth(model);
      if (!current()) return;
      if (!health.inferenceReady) {
        _readinessMessage =
            'The module has not confirmed that its model is loaded.';
        _setState(EdgeDeviceState.unverified);
        return;
      }
      final confirmedHub = await client.getHubStatus();
      if (!current()) return;
      if (confirmedHub.active != moduleId ||
          confirmedHub.state != EdgeHubModuleState.ready) {
        _readinessMessage =
            'The active module changed during the readiness check.';
        _setState(EdgeDeviceState.unverified);
        return;
      }
      _observedReadyModel = model;
      _readinessMessage = 'Hub and module health confirmed readiness.';
      _setState(EdgeDeviceState.ready);
    } on EdgeDeviceException catch (error) {
      if (!current()) return;
      _readinessMessage = error.message;
      _log('Readiness check failed: ${error.failure.name}');
      _setState(EdgeDeviceState.unverified);
    }
  }

  Future<EdgeDeviceModelStatus> beginExamination({
    required EdgeAIModel model,
    required String examinationId,
    String? requestId,
  }) async {
    final cleanExaminationId = examinationId.trim();
    if (cleanExaminationId.isEmpty) {
      throw const EdgeDeviceException(
        failure: EdgeDeviceFailure.invalidConfiguration,
        message: 'An examination ID is required before model activation.',
      );
    }
    if (requestId != null && requestId.trim().isEmpty) {
      throw const EdgeDeviceException(
        failure: EdgeDeviceFailure.invalidConfiguration,
        message: 'A non-empty request ID is required for model activation.',
      );
    }
    if (!modelManagementEnabled) {
      _setState(EdgeDeviceState.unsupported);
      throw const EdgeDeviceException(
        failure: EdgeDeviceFailure.disabled,
        message:
            'Edge-device model management is disabled until the device API is verified.',
      );
    }

    final pending = _activationFuture;
    if (pending != null) {
      if (_pendingModel == model &&
          _pendingExaminationId == cleanExaminationId) {
        return pending;
      }
      _setState(EdgeDeviceState.busy);
      throw const EdgeDeviceException(
        failure: EdgeDeviceFailure.conflict,
        message: 'A different examination is already being prepared.',
      );
    }

    if (_activeExaminationId != null) {
      if (_activeExaminationId == cleanExaminationId &&
          _activeModel == model &&
          _state == EdgeDeviceState.ready) {
        return EdgeDeviceModelStatus(
          state: EdgeDeviceModelState.ready,
          activeModelId: client.config.modelId(model),
          examinationId: cleanExaminationId,
          requestId: _activeRequestId,
        );
      }
      _setState(EdgeDeviceState.busy);
      throw const EdgeDeviceException(
        failure: EdgeDeviceFailure.conflict,
        message:
            'Another examination is active; a model switch is not permitted.',
      );
    }

    final generatedRequestId = requestId ?? _newRequestId();
    _readinessGeneration++;
    _observedReadyModel = null;
    _readinessMessage = null;
    _pendingModel = model;
    _pendingExaminationId = cleanExaminationId;
    _activeExaminationId = cleanExaminationId;
    _activeModel = model;
    _activeRequestId = generatedRequestId;

    final activation = _activate(
      model: model,
      examinationId: cleanExaminationId,
      requestId: generatedRequestId,
    );
    _activationFuture = activation;
    try {
      return await activation;
    } finally {
      _activationFuture = null;
      _pendingModel = null;
      _pendingExaminationId = null;
    }
  }

  Future<void> markExamining(String examinationId) async {
    if (_state != EdgeDeviceState.ready ||
        _activeExaminationId != examinationId) {
      throw const EdgeDeviceException(
        failure: EdgeDeviceFailure.conflict,
        message: 'The requested model is not ready for this examination.',
      );
    }
    _setState(EdgeDeviceState.examining);
  }

  void markExaminationError(String examinationId) {
    if (_activeExaminationId != examinationId) {
      throw const EdgeDeviceException(
        failure: EdgeDeviceFailure.conflict,
        message: 'The error does not match the active device examination.',
      );
    }
    _setState(EdgeDeviceState.error);
  }

  /// Releases the local examination lock. The device has no completion
  /// endpoint and the module is deliberately left running.
  Future<void> completeExamination(String examinationId) async {
    if (_activeExaminationId != examinationId ||
        _activeModel == null ||
        _activeRequestId == null) {
      throw const EdgeDeviceException(
        failure: EdgeDeviceFailure.conflict,
        message: 'The examination does not match the active device session.',
      );
    }
    _clearActiveExamination();
    _setState(EdgeDeviceState.connected);
  }

  Future<EdgeDeviceModelStatus> reconcileActiveExamination() async {
    final examinationId = _activeExaminationId;
    final requestId = _activeRequestId;
    final model = _activeModel;
    if (examinationId == null ||
        requestId == null ||
        model == null ||
        !{
          EdgeDeviceState.error,
          EdgeDeviceState.loadingModel,
          EdgeDeviceState.busy,
          EdgeDeviceState.unsupported,
        }.contains(_state)) {
      throw const EdgeDeviceException(
        failure: EdgeDeviceFailure.conflict,
        message: 'There is no unresolved examination to reconcile.',
      );
    }

    final moduleId = client.config.modelId(model);
    try {
      final hub = await client.getHubStatus();
      if (hub.active == moduleId &&
          (hub.state == EdgeHubModuleState.starting ||
              hub.state == EdgeHubModuleState.notReady)) {
        _setState(EdgeDeviceState.loadingModel);
        return EdgeDeviceModelStatus(
          state: EdgeDeviceModelState.loading,
          activeModelId: moduleId,
          examinationId: examinationId,
          requestId: requestId,
          message: hub.message,
        );
      }
      if (hub.active == moduleId && hub.state == EdgeHubModuleState.ready) {
        final health = await client.getModuleHealth(model);
        if (health.inferenceReady) {
          _setState(EdgeDeviceState.ready);
          return EdgeDeviceModelStatus(
            state: EdgeDeviceModelState.ready,
            activeModelId: moduleId,
            examinationId: examinationId,
            requestId: requestId,
          );
        }
      }
      _setState(
        hub.active != null && hub.active != moduleId
            ? EdgeDeviceState.busy
            : EdgeDeviceState.error,
      );
    } on EdgeDeviceException {
      _setState(EdgeDeviceState.error);
      rethrow;
    }
    throw const EdgeDeviceException(
      failure: EdgeDeviceFailure.invalidResponse,
      message:
          'Device status did not confirm this examination. The local lock remains active.',
    );
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('[Device] $message');
  }

  Future<EdgeDeviceModelStatus> _activate({
    required EdgeAIModel model,
    required String examinationId,
    required String requestId,
  }) async {
    final moduleId = client.config.modelId(model);
    var selectSent = false;
    try {
      _setState(EdgeDeviceState.connecting);
      _log('Configured ${client.config.diagnosticSummary()}');
      final problem = client.config.configurationProblem(
        isWeb: kIsWeb,
        pageUri: kIsWeb ? Uri.base : null,
      );
      if (problem != null) {
        _log('Configuration problem: $problem');
        throw EdgeDeviceException(
          failure: EdgeDeviceFailure.invalidConfiguration,
          message: problem,
        );
      }
      _log('Checking hub status at '
          '${client.config.hubEndpoint(client.config.hubStatusPath)}');
      final hub = await client.getHubStatus();
      _log('Hub active=${hub.active} state=${hub.state.name}');
      _setState(EdgeDeviceState.connected);

      if (hub.moduleIds.isNotEmpty && !hub.moduleIds.contains(moduleId)) {
        _setState(EdgeDeviceState.unsupported);
        throw EdgeDeviceException(
          failure: EdgeDeviceFailure.unsupported,
          message: 'The edge device hub does not offer module $moduleId.',
        );
      }

      _setState(EdgeDeviceState.loadingModel);
      if (hub.active == moduleId &&
          (hub.state == EdgeHubModuleState.ready ||
              hub.state == EdgeHubModuleState.starting ||
              hub.state == EdgeHubModuleState.notReady)) {
        _log(
            '$moduleId already active; checking readiness without /api/select');
        await _waitUntilReady(hub, model: model);
      } else {
        selectSent = true;
        _log('Selecting $moduleId');
        final selected = await client.selectModel(model);
        _log('Waiting for model (hub state=${selected.state.name})');
        await _waitUntilReady(selected, model: model);
      }
      _log('Model ready: $moduleId');
      _observedReadyModel = model;
      _setState(EdgeDeviceState.ready);
      return EdgeDeviceModelStatus(
        state: EdgeDeviceModelState.ready,
        activeModelId: moduleId,
        examinationId: examinationId,
        requestId: requestId,
      );
    } on EdgeDeviceException catch (error) {
      _readinessMessage = error.message;
      if (selectSent && error.failure == EdgeDeviceFailure.timeout) {
        // The select request may have been accepted; do not release the lock.
        _setState(EdgeDeviceState.error);
        rethrow;
      }

      if (error.failure == EdgeDeviceFailure.busy ||
          error.failure == EdgeDeviceFailure.conflict) {
        _setState(EdgeDeviceState.busy);
      } else if (error.failure == EdgeDeviceFailure.unsupported) {
        _setState(EdgeDeviceState.unsupported);
      } else {
        _setState(EdgeDeviceState.error);
      }
      if (!selectSent ||
          error.failure == EdgeDeviceFailure.busy ||
          error.failure == EdgeDeviceFailure.unsupported ||
          error.failure == EdgeDeviceFailure.modelInitialization) {
        _clearActiveExamination();
      }
      rethrow;
    } catch (_) {
      _setState(EdgeDeviceState.error);
      if (!selectSent) _clearActiveExamination();
      rethrow;
    }
  }

  /// Waits until the hub reports [model]'s module as the active, ready module
  /// and the module's own health affirms its model is loaded.
  Future<void> _waitUntilReady(
    EdgeHubStatus initial, {
    required EdgeAIModel model,
  }) async {
    final config = client.config;
    final moduleId = config.modelId(model);
    final deadline = DateTime.now().add(config.modelReadyTimeout);
    EdgeHubStatus? status = initial;
    String? healthMessage;

    while (true) {
      final hub = status ?? await client.getHubStatus();
      status = null;

      if (hub.active != moduleId) {
        throw EdgeDeviceException(
          failure: EdgeDeviceFailure.busy,
          message: hub.active == null
              ? 'The device stopped the requested module.'
              : 'The device is running ${hub.active} instead of $moduleId.',
        );
      }
      switch (hub.state) {
        case EdgeHubModuleState.error:
          throw EdgeDeviceException(
            failure: EdgeDeviceFailure.modelInitialization,
            message: hub.message.isEmpty
                ? 'The edge module failed to start.'
                : hub.message,
          );
        case EdgeHubModuleState.stopped:
          throw const EdgeDeviceException(
            failure: EdgeDeviceFailure.busy,
            message: 'The device stopped the requested module.',
          );
        case EdgeHubModuleState.starting:
        case EdgeHubModuleState.notReady:
          healthMessage = hub.message;
        case EdgeHubModuleState.ready:
          try {
            final health = await client.getModuleHealth(model);
            if (health.inferenceReady) return;
            healthMessage = health.message;
          } on EdgeDeviceException catch (error) {
            if (error.failure == EdgeDeviceFailure.invalidResponse) rethrow;
            healthMessage = error.message;
          }
      }

      if (!DateTime.now().isBefore(deadline)) {
        throw EdgeDeviceException(
          failure: EdgeDeviceFailure.timeout,
          message: (healthMessage?.isNotEmpty ?? false)
              ? 'Timed out waiting for the requested module: $healthMessage'
              : 'Timed out waiting for the requested module to be ready.',
        );
      }
      await Future<void>.delayed(config.modelPollInterval);
    }
  }

  void _clearActiveExamination() {
    _activeExaminationId = null;
    _activeModel = null;
    _activeRequestId = null;
  }

  void _setState(EdgeDeviceState state) {
    _state = state;
    notifyListeners();
  }

  String _newRequestId() => const Uuid().v4();

  @override
  void dispose() {
    client.close();
    super.dispose();
  }
}
