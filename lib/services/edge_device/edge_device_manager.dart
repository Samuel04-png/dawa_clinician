import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'edge_device_client.dart';
import 'edge_device_exceptions.dart';
import 'edge_device_models.dart';

/// Tracks which edge AI module the clinician's current examination owns.
///
/// Flow: hub `GET /api/status` -> `POST /api/select` -> poll status until the
/// requested module has matching `active`, `ready:true` and `state:ready`.
/// The hub confirms readiness after the module warm-up. Once ready, the app takes the device-side examination lock
/// (`/api/exam/start`), keeps it alive with a heartbeat every 30 s, and
/// releases it (`/api/exam/end`) when the examination completes. Completing an
/// examination never stops the module.
class EdgeDeviceManager extends ChangeNotifier {
  EdgeDeviceManager({
    required this.client,
    bool? modelManagementEnabled,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        modelManagementEnabled =
            modelManagementEnabled ?? client.config.modelManagementEnabled;

  static final EdgeDeviceManager shared = EdgeDeviceManager(
    client: EdgeDeviceClient(),
  );

  final DateTime Function() _now;
  final EdgeDeviceClient client;
  final bool modelManagementEnabled;

  EdgeDeviceState _state = EdgeDeviceState.disconnected;
  EdgeAIModel? _activeModel;
  String? _activeExaminationId;
  String? _activeRequestId;
  String? _deviceExamId;
  Timer? _heartbeatTimer;
  Future<EdgeDeviceModelStatus>? _activationFuture;
  EdgeAIModel? _pendingModel;
  String? _pendingExaminationId;
  EdgeAIModel? _observedReadyModel;
  String? _readinessMessage;
  int _readinessGeneration = 0;

  Future<void>? _workflowPreparation;
  bool _disposed = false;
  bool _workflowCancelled = false;
  bool _takingLonger = false;
  final Set<EdgeAIModel> _previouslyLoaded = {};
  bool get takingLongerThanExpected => _takingLonger;

  int _workflowRequest = 0;
  EdgeAIModel? _requestedWorkflow;
  EdgeAIModel? get requestedWorkflow => _requestedWorkflow;
  bool get isPreparingWorkflow =>
      _workflowPreparation != null && !_workflowCancelled;

  /// Serializes switches and discards work from superseded navigation.
  /// Preparation never takes a device examination lock.
  Future<void> prepareWorkflow(EdgeAIModel model) {
    if (_disposed || !modelManagementEnabled) return Future<void>.value();
    if (_activeExaminationId != null) return Future<void>.value();
    if (_requestedWorkflow == model &&
        !_workflowCancelled &&
        _workflowPreparation != null) return _workflowPreparation!;
    final request = ++_workflowRequest;
    _requestedWorkflow = model;
    _readinessGeneration++;
    _workflowCancelled = false;
    final previous = _workflowPreparation;
    final preparation = () async {
      if (previous != null) await previous;
      if (_disposed || request != _workflowRequest) return;
      final generation = _readinessGeneration;
      await _prepareWorkflow(
          model,
          () =>
              !_disposed &&
              request == _workflowRequest &&
              generation == _readinessGeneration);
    }();
    _workflowPreparation = preparation;
    return preparation.whenComplete(() {
      if (request == _workflowRequest) {
        _workflowPreparation = null;
      }
    });
  }

  void cancelWorkflowPreparation(EdgeAIModel model) {
    if (_requestedWorkflow != model) return;
    _workflowCancelled = true;
    _requestedWorkflow = null;
    _workflowRequest++;
    _readinessGeneration++;
    _observedReadyModel = null;
    _takingLonger = false;
  }

  Future<void> _prepareWorkflow(
      EdgeAIModel model, bool Function() current) async {
    if (!modelManagementEnabled) return;
    final started = _now();
    _observedReadyModel = null;
    _readinessMessage = null;
    _takingLonger = false;
    _setState(EdgeDeviceState.connecting);
    try {
      final problem = client.config.configurationProblem(
          isWeb: kIsWeb, pageUri: kIsWeb ? Uri.base : null);
      if (problem != null) {
        throw EdgeDeviceException(
            failure: EdgeDeviceFailure.invalidConfiguration, message: problem);
      }
      var hub = await client.getHubStatus();
      if (!current()) return;
      final module = client.config.modelId(model);
      if (hub.hasExamination || hub.busy) {
        throw const EdgeDeviceException(
            failure: EdgeDeviceFailure.busy,
            message:
                'Another examination is using the device. Prepare the patient and retry when it finishes.');
      }
      // Let an accepted switch finish before asking the hub for another one.
      while (hub.active != null &&
          hub.active != module &&
          hub.state == EdgeHubModuleState.starting) {
        if (_now().difference(started) >= client.config.modelReadyTimeout) {
          throw const EdgeDeviceException(
              failure: EdgeDeviceFailure.timeout,
              message:
                  'The previous model switch is still in progress. Check again.');
        }
        _readinessMessage = hub.message;
        _setState(EdgeDeviceState.loadingModel);
        await Future<void>.delayed(client.config.modelPollInterval);
        if (!current()) return;
        hub = await client.getHubStatus();
        if (!current()) return;
        if (hub.hasExamination || hub.busy) {
          throw const EdgeDeviceException(
              failure: EdgeDeviceFailure.busy,
              message:
                  'Another examination is using the device. Retry when it finishes.');
        }
      }
      if (hub.active != module ||
          hub.state == EdgeHubModuleState.error ||
          hub.state == EdgeHubModuleState.stopped) {
        _setState(EdgeDeviceState.loadingModel);
        hub = await client.selectModel(model);
        if (!current()) return;
        _readinessMessage = hub.message.isEmpty ? null : hub.message;
        _setState(EdgeDeviceState.loadingModel);
        if (!current()) return;
        // A selection response acknowledges the request. Only GET status
        // can confirm readiness, even if the acknowledgement says ready.
        await Future<void>.delayed(client.config.modelPollInterval);
        if (!current()) return;
        hub = await client.getHubStatus();
      }
      if (!current()) return;
      _setState(EdgeDeviceState.loadingModel);
      await _waitUntilReady(hub,
          model: model, current: current, startedAt: started);
      if (!current()) return;
      _observedReadyModel = model;
      _takingLonger = false;
      _setState(EdgeDeviceState.ready);
    } on EdgeDeviceException catch (error) {
      if (!current()) return;
      _readinessMessage = error.message;
      _setState(switch (error.failure) {
        EdgeDeviceFailure.busy ||
        EdgeDeviceFailure.conflict =>
          EdgeDeviceState.busy,
        EdgeDeviceFailure.connection => EdgeDeviceState.disconnected,
        _ => EdgeDeviceState.error,
      });
    }
  }

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
      if (!hub.isReadyFor(moduleId)) {
        _readinessMessage = hub.message.isNotEmpty
            ? hub.message
            : hub.active == moduleId && hub.state == EdgeHubModuleState.starting
                ? 'The requested module is starting; readiness is not yet confirmed.'
                : 'The requested model is not currently confirmed ready.';
        _setState(
            hub.active == moduleId && hub.state == EdgeHubModuleState.starting
                ? EdgeDeviceState.loadingModel
                : EdgeDeviceState.unverified);
        return;
      }
      final confirmedHub = await client.getHubStatus();
      if (!current()) return;
      if (!confirmedHub.isReadyFor(moduleId)) {
        _readinessMessage =
            'The active module changed during the readiness check.';
        _setState(EdgeDeviceState.unverified);
        return;
      }
      _observedReadyModel = model;
      _readinessMessage = 'The device hub confirmed model readiness.';
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

    final warming = _workflowPreparation;
    if (warming != null) {
      if (_requestedWorkflow != model) {
        throw const EdgeDeviceException(
            failure: EdgeDeviceFailure.conflict,
            message:
                'Another model is being prepared. Try again after it finishes.');
      }
      await warming;
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
    final model = _activeModel!;
    final hub = await client.getHubStatus();
    if (_activeExaminationId != examinationId ||
        !hub.isReadyFor(client.config.modelId(model))) {
      _readinessMessage =
          'The selected AI model is no longer ready. Check the device session.';
      _setState(EdgeDeviceState.error);
      throw EdgeDeviceException(
          failure: EdgeDeviceFailure.conflict, message: _readinessMessage!);
    }
    _setState(EdgeDeviceState.examining);
  }

  void finishInference(String examinationId) {
    if (_activeExaminationId != examinationId ||
        _state != EdgeDeviceState.examining) {
      throw const EdgeDeviceException(
          failure: EdgeDeviceFailure.conflict,
          message: 'The inference does not match the active examination.');
    }
    _setState(EdgeDeviceState.ready);
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

  /// Releases the device and local examination locks, leaving the module running.
  Future<void> completeExamination(String examinationId) async {
    if (_activeExaminationId != examinationId ||
        _activeModel == null ||
        _activeRequestId == null) {
      throw const EdgeDeviceException(
        failure: EdgeDeviceFailure.conflict,
        message: 'The examination does not match the active device session.',
      );
    }
    await _releaseDeviceExam();
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
      var hub = await client.getHubStatus();
      if (hub.active == moduleId &&
          (hub.state == EdgeHubModuleState.starting ||
              hub.state == EdgeHubModuleState.notReady ||
              hub.state == EdgeHubModuleState.ready && !hub.ready)) {
        _setState(EdgeDeviceState.loadingModel);
        // An explicit Check Again resumes monitoring, without replaying select.
        await _waitUntilReady(hub, model: model);
        hub = await client.getHubStatus();
      }
      if (hub.isReadyFor(moduleId)) {
        {
          // Reconciliation can follow a timed-out select or a lost lock.
          // Resume or reacquire the device lock before allowing an upload.
          _deviceExamId =
              await client.startExam(model, device: _deviceLabel(requestId));
          _startHeartbeat();
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
    final started = _now();
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
        await _waitUntilReady(hub, model: model, startedAt: started);
      } else {
        selectSent = true;
        _log('Selecting $moduleId');
        final selected = await client.selectModel(model);
        _readinessMessage = selected.message.isEmpty ? null : selected.message;
        _setState(EdgeDeviceState.loadingModel);
        _log('Waiting for model (hub state=${selected.state.name})');
        await Future<void>.delayed(client.config.modelPollInterval);
        await _waitUntilReady(await client.getHubStatus(),
            model: model, startedAt: started);
      }
      _log('Model ready: $moduleId');
      _deviceExamId =
          await client.startExam(model, device: _deviceLabel(requestId));
      _log('Device examination lock taken');
      _startHeartbeat();
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
    bool Function()? current,
    DateTime? startedAt,
  }) async {
    final config = client.config;
    final moduleId = config.modelId(model);
    final started = startedAt ?? _now();
    final deadline = started.add(config.modelReadyTimeout);
    // Only Ultrasound has engineer-confirmed expected loading durations.
    final usual = model == EdgeAIModel.ultrasound
        ? (_previouslyLoaded.contains(model)
            ? const Duration(seconds: 30)
            : const Duration(seconds: 60))
        : null;
    _takingLonger = false;
    EdgeHubStatus? status = initial;
    String? healthMessage;

    while (!_disposed && (current?.call() ?? true)) {
      final hub = status ?? await client.getHubStatus();
      if (_disposed || !(current?.call() ?? true)) return;
      _readinessMessage = hub.message.isEmpty ? null : hub.message;
      _takingLonger = usual != null && _now().difference(started) >= usual;
      _setState(EdgeDeviceState.loadingModel);
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
          if (hub.isReadyFor(moduleId)) {
            _takingLonger = false;
            _previouslyLoaded.add(model);
            return;
          }
          healthMessage = hub.message;
      }

      if (!_now().isBefore(deadline)) {
        throw EdgeDeviceException(
          failure: EdgeDeviceFailure.timeout,
          message: healthMessage.isNotEmpty
              ? 'Timed out waiting for the requested module: $healthMessage'
              : 'Timed out waiting for the requested module to be ready.',
        );
      }
      await Future<void>.delayed(config.modelPollInterval);
    }
  }

  String _deviceLabel(String requestId) =>
      'app-${requestId.length > 8 ? requestId.substring(0, 8) : requestId}';

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    final id = _deviceExamId;
    if (id == null) return;
    _heartbeatTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_deviceExamId != id) {
        timer.cancel();
        return;
      }
      try {
        await client.examHeartbeat(id);
      } on EdgeDeviceException catch (error) {
        if (error.statusCode == 404 && _deviceExamId == id) {
          timer.cancel();
          _deviceExamId = null;
          _readinessMessage = 'The device examination lock was lost.';
          _setState(EdgeDeviceState.error);
        }
        if (_deviceExamId == id) {
          _readinessMessage = 'Connection to the device was interrupted. '
              'Check the device session before continuing AI analysis.';
          _setState(EdgeDeviceState.error);
        }
        // Reconciliation is required before accepting another image.
      } catch (_) {}
    });
  }

  Future<void> _releaseDeviceExam() async {
    final id = _deviceExamId;
    if (id == null) return;
    try {
      await client.endExam(id);
    } on EdgeDeviceException catch (error) {
      if (error.statusCode != 404) {
        _readinessMessage =
            'Could not confirm the examination has ended. Check the device session.';
        _setState(EdgeDeviceState.error);
        rethrow;
      }
    }
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _deviceExamId = null;
  }

  void _clearActiveExamination() {
    _activeExaminationId = null;
    _activeModel = null;
    _activeRequestId = null;
  }

  void _setState(EdgeDeviceState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  String _newRequestId() => const Uuid().v4();

  @override
  void dispose() {
    _disposed = true;
    _readinessGeneration++;
    _heartbeatTimer?.cancel();
    client.close();
    super.dispose();
  }
}
