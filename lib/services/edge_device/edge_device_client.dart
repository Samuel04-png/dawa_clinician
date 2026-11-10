import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'edge_device_config.dart';
import 'edge_device_exceptions.dart';
import 'edge_device_models.dart';

/// Shared HTTP client for the Dawa edge device.
///
/// Hub (dawa/main.py, default port 8080): `GET /api/status`, `POST /api/select`.
/// Modules (default ports 8085 cervitriage, 8086 ultrasound):
/// `GET /health`, `POST /predict`.
/// Legacy CaCx deployments keep `POST /upload/cervical` on the base URL.
/// This client never calls `/api/stop`.
class EdgeDeviceClient {
  EdgeDeviceClient({
    EdgeDeviceConfig? config,
    http.Client? httpClient,
  })  : config = config ?? EdgeDeviceConfig.fromEnvironment(),
        _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null;

  final EdgeDeviceConfig config;
  final http.Client _httpClient;
  final bool _ownsHttpClient;

  /// Reachability is distinct from model readiness. The hub's `/health` can
  /// return 503 when no module is selected, even though `/api/status` works.
  Future<int> checkHealth() async {
    final uri = config.modelManagementEnabled
        ? _resolve(() => config.hubEndpoint(config.hubStatusPath))
        : _resolve(() => config.endpoint(config.healthPath));
    final response = await _get(uri, timeout: config.requestTimeout);
    _ensureSuccess(response);
    return response.statusCode;
  }

  Future<EdgeHubStatus> getHubStatus() async {
    _ensureModelManagementEnabled();
    final response = await _get(
      _resolve(() => config.hubEndpoint(config.hubStatusPath)),
      timeout: config.requestTimeout,
    );
    _ensureSuccess(response);
    return _parseHubStatus(response.body);
  }

  /// Asks the hub to start [model]'s module (`POST /api/select`). The hub
  /// answers 202 immediately; readiness must be polled separately.
  Future<EdgeHubStatus> selectModel(EdgeAIModel model) async {
    _ensureModelManagementEnabled();
    final response = await _postJson(
      _resolve(() => config.hubEndpoint(config.hubSelectPath)),
      {'module': config.modelId(model)},
      timeout: config.modelRequestTimeout,
    );
    _ensureSuccess(response);
    return _parseHubStatus(response.body);
  }

  /// Takes the device-side examination lock (`POST /api/exam/start`).
  /// Request `{"module","device"}`; 201 `{"exam_id","ttl_s"}` (the same device
  /// and module get the same id back with `"resumed":true`). While it is held
  /// the hub answers `/api/select` and `/api/stop` with 409 `exam_in_progress`.
  Future<String> startExam(EdgeAIModel model, {required String device}) async {
    _ensureModelManagementEnabled();
    final response = await _postJson(
      _resolve(() => config.hubEndpoint('/api/exam/start')),
      {'module': config.modelId(model), 'device': device},
      timeout: config.modelRequestTimeout,
    );
    _ensureSuccess(response);
    final id = _decodeObject(response.body)['exam_id'];
    if (id is! String || id.isEmpty) {
      throw const EdgeDeviceException(
        failure: EdgeDeviceFailure.invalidResponse,
        message: 'Device did not return an exam_id.',
      );
    }
    return id;
  }

  /// Keeps the lock alive (`POST /api/exam/heartbeat`). The device expires it
  /// after its TTL (120 s); 404 `exam_not_found` means the lock was lost.
  Future<void> examHeartbeat(String examId) async {
    _ensureModelManagementEnabled();
    final response = await _postJson(
      _resolve(() => config.hubEndpoint('/api/exam/heartbeat')),
      {'exam_id': examId},
      timeout: config.requestTimeout,
    );
    _ensureSuccess(response);
  }

  /// Releases the lock (`POST /api/exam/end`). Safe to call twice.
  Future<void> endExam(String examId) async {
    _ensureModelManagementEnabled();
    final response = await _postJson(
      _resolve(() => config.hubEndpoint('/api/exam/end')),
      {'exam_id': examId},
      timeout: config.requestTimeout,
    );
    _ensureSuccess(response);
  }

  /// Module `GET /health`. HTTP 200 alone is not readiness; see
  /// [EdgeModuleHealth.inferenceReady].
  Future<EdgeModuleHealth> getModuleHealth(EdgeAIModel model) async {
    _ensureModelManagementEnabled();
    final response = await _get(
      _resolve(() => config.moduleEndpoint(model, config.moduleHealthPath)),
      timeout: config.requestTimeout,
    );
    _ensureSuccess(response);
    try {
      return EdgeModuleHealth.fromJson(
        _decodeObject(response.body),
        readyField: config.healthReadyField(model),
      );
    } on FormatException catch (error) {
      throw EdgeDeviceException(
        failure: EdgeDeviceFailure.invalidResponse,
        message: error.message,
      );
    }
  }

  /// Cervitriage `POST /predict`. HTTP 422 (gatekeeper rejection) is returned
  /// to the caller as a normal outcome rather than thrown.
  Future<http.Response> predictCervical({
    required List<int> imageBytes,
    required String filename,
    required String mimeType,
  }) {
    _ensureModelManagementEnabled();
    return _postMultipart(
      _resolve(() => config.moduleEndpoint(
            EdgeAIModel.cervicalCancer,
            config.predictPath,
          )),
      fields: const {},
      imageBytes: imageBytes,
      filename: filename,
      mimeType: mimeType,
      acceptedStatusCodes: const {422},
      timeout: config.inferenceTimeout,
    );
  }

  /// Ultrasound `POST /predict` (`image`, optional `box` as `x0,y0,x1,y1`
  /// pixels, optional positive `pixel_spacing_mm`).
  Future<http.Response> predictUltrasound({
    required List<int> imageBytes,
    required String filename,
    required String mimeType,
    List<double>? box,
    double? pixelSpacingMm,
  }) async {
    if (!config.ultrasoundInferenceEnabled) {
      throw const EdgeDeviceException(
        failure: EdgeDeviceFailure.disabled,
        message:
            'Ultrasound edge inference is disabled until the device integration is verified.',
      );
    }
    _ensureModelManagementEnabled();
    if (box != null && box.length != 4) {
      throw const EdgeDeviceException(
        failure: EdgeDeviceFailure.invalidConfiguration,
        message: 'box must contain exactly x0, y0, x1, y1.',
      );
    }
    if (pixelSpacingMm != null &&
        (!pixelSpacingMm.isFinite || pixelSpacingMm <= 0)) {
      throw const EdgeDeviceException(
        failure: EdgeDeviceFailure.invalidConfiguration,
        message: 'pixel_spacing_mm must be a positive number.',
      );
    }
    return await _postMultipart(
      _resolve(() => config.moduleEndpoint(
            EdgeAIModel.ultrasound,
            config.predictPath,
          )),
      fields: {
        if (box != null) 'box': box.join(','),
        if (pixelSpacingMm != null) 'pixel_spacing_mm': '$pixelSpacingMm',
      },
      imageBytes: imageBytes,
      filename: filename,
      mimeType: mimeType,
      timeout: config.inferenceTimeout,
    );
  }

  /// Legacy CaCx upload (`/upload/cervical` on the base URL).
  Future<http.Response> uploadCervicalImage({
    required List<int> imageBytes,
    required String filename,
    required String mimeType,
    required String patientId,
  }) {
    return _postMultipart(
      _resolve(() => config.endpoint(config.cervicalUploadPath)),
      fields: {
        'patient_id': patientId,
        'examination_type': 'cervical',
      },
      imageBytes: imageBytes,
      filename: filename,
      mimeType: mimeType,
    );
  }

  void close() {
    if (_ownsHttpClient) _httpClient.close();
  }

  void _ensureModelManagementEnabled() {
    if (!config.modelManagementEnabled) {
      throw const EdgeDeviceException(
        failure: EdgeDeviceFailure.disabled,
        message:
            'Edge-device model management is disabled until the device API is verified.',
      );
    }
  }

  EdgeHubStatus _parseHubStatus(String body) {
    try {
      return EdgeHubStatus.fromJson(_decodeObject(body));
    } on FormatException catch (error) {
      throw EdgeDeviceException(
        failure: EdgeDeviceFailure.invalidResponse,
        message: error.message,
      );
    }
  }

  Future<http.Response> _postMultipart(
    Uri uri, {
    required Map<String, String> fields,
    required List<int> imageBytes,
    required String filename,
    required String mimeType,
    Set<int> acceptedStatusCodes = const {},
    Duration? timeout,
  }) async {
    final limit = timeout ?? config.uploadTimeout;
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_versionHeaders)
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ),
      );
    try {
      final streamed = await _httpClient.send(request).timeout(limit);
      final response = await http.Response.fromStream(streamed).timeout(limit);
      if (!acceptedStatusCodes.contains(response.statusCode)) {
        _ensureSuccess(response);
      }
      return response;
    } on TimeoutException catch (error) {
      throw EdgeDeviceException(
        failure: EdgeDeviceFailure.timeout,
        message: error.message ?? 'Timed out uploading image to device.',
      );
    } on EdgeDeviceException {
      rethrow;
    } on http.ClientException catch (error) {
      throw EdgeDeviceException(
        failure: EdgeDeviceFailure.connection,
        message: 'Could not upload image to edge device: $error',
      );
    }
  }

  Future<http.Response> _get(
    Uri uri, {
    required Duration timeout,
  }) async {
    try {
      return await _httpClient
          .get(uri, headers: _versionHeaders)
          .timeout(timeout);
    } on TimeoutException catch (error) {
      throw EdgeDeviceException(
        failure: EdgeDeviceFailure.timeout,
        message: error.message ?? 'Timed out contacting edge device.',
      );
    } on http.ClientException catch (error) {
      throw EdgeDeviceException(
        failure: EdgeDeviceFailure.connection,
        message: 'Could not contact edge device: $error',
      );
    }
  }

  Future<http.Response> _postJson(
    Uri uri,
    Map<String, Object?> body, {
    required Duration timeout,
  }) async {
    try {
      return await _httpClient
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              ..._versionHeaders,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException catch (error) {
      throw EdgeDeviceException(
        failure: EdgeDeviceFailure.timeout,
        message: error.message ?? 'Timed out contacting edge device.',
      );
    } on http.ClientException catch (error) {
      throw EdgeDeviceException(
        failure: EdgeDeviceFailure.connection,
        message: 'Could not contact edge device: $error',
      );
    }
  }

  Map<String, String> get _versionHeaders => config.apiVersion.trim().isEmpty
      ? const {}
      : {'x-api-version': config.apiVersion.trim()};

  Uri _resolve(Uri Function() build) {
    try {
      return build();
    } on FormatException catch (error) {
      throw EdgeDeviceException(
        failure: EdgeDeviceFailure.invalidConfiguration,
        message: error.message,
      );
    }
  }

  Map<String, dynamic> _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException catch (error) {
      throw EdgeDeviceException(
        failure: EdgeDeviceFailure.invalidResponse,
        message: 'Device returned invalid JSON: ${error.message}',
      );
    }
    throw const EdgeDeviceException(
      failure: EdgeDeviceFailure.invalidResponse,
      message: 'Device response must be a JSON object.',
    );
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final failure = switch (response.statusCode) {
      401 || 403 => EdgeDeviceFailure.unauthorized,
      404 || 405 || 501 => EdgeDeviceFailure.unsupported,
      409 || 423 => EdgeDeviceFailure.busy,
      503 => EdgeDeviceFailure.modelInitialization,
      _ => EdgeDeviceFailure.http,
    };
    throw EdgeDeviceException(
      failure: failure,
      message: _describeError(response),
      statusCode: response.statusCode,
    );
  }

  String _describeError(http.Response response) {
    if (response.body.isEmpty) {
      return 'Edge device returned HTTP ${response.statusCode}.';
    }
    try {
      final decoded = jsonDecode(response.body);
      final code = decoded is Map ? decoded['code'] : null;
      final detail = decoded is Map ? decoded['error'] : null;
      if (response.statusCode == 409 && code is String) {
        return switch (code) {
          'exam_in_progress' =>
            'Another examination is in progress on the device (exam_in_progress).',
          'busy' =>
            'The device is processing an image (busy). Try again shortly.',
          'switch_in_progress' => 'A device switch is already in progress.',
          _ => detail is String ? detail : code,
        };
      }
      if (detail is String && detail.isNotEmpty) return detail;
    } on FormatException {
      // Fall through to the raw body.
    }
    return response.body;
  }
}
