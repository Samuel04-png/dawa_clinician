import 'edge_device_models.dart';

/// Shared configuration for the Dawa edge device (hub + cervitriage +
/// ultrasound modules). Defaults mirror the supplied device source
/// (dawa/dawa.yaml and each module's config.yaml). Every value can be
/// overridden with a --dart-define; see docs/environment-variables.md.
class EdgeDeviceConfig {
  const EdgeDeviceConfig({
    required this.baseUrl,
    this.baseUrlExplicit = true,
    this.modelManagementEnabled = false,
    this.ultrasoundInferenceEnabled = false,
    this.apiVersion = '',
    this.healthPath = '/health',
    this.cervicalUploadPath = '/upload/cervical',
    this.hubPort = 80,
    this.cervicalPort = 8085,
    this.ultrasoundPort = 8086,
    this.hubSelectPath = '/api/select',
    this.hubStatusPath = '/api/status',
    this.moduleHealthPath = '/health',
    this.predictPath = '/predict',
    this.cervicalModelId = 'cervitriage',
    this.ultrasoundModelId = 'ultrasound',
    this.cervicalHealthReadyField = 'ready',
    this.ultrasoundHealthReadyField = 'ready',
    this.supportedImageMimeTypes = const {'image/jpeg', 'image/png'},
    this.requestTimeout = const Duration(seconds: 5),
    this.uploadTimeout = const Duration(seconds: 120),
    this.inferenceTimeout = const Duration(seconds: 120),
    this.modelRequestTimeout = const Duration(seconds: 30),
    this.modelReadyTimeout = const Duration(seconds: 300),
    this.modelPollInterval = const Duration(seconds: 1),
    this.moduleHealthGrace = const Duration(seconds: 10),
  });

  factory EdgeDeviceConfig.fromEnvironment() {
    const sharedUrl = String.fromEnvironment(
      'EDGE_DEVICE_BASE_URL',
      defaultValue: '',
    );
    const piUrl = String.fromEnvironment(
      'PI_DEVICE_BASE_URL',
      defaultValue: 'http://dawa.local',
    );
    const cervicalUrl = String.fromEnvironment(
      'CERVICAL_DEVICE_BASE_URL',
      defaultValue: '',
    );
    const edgeRequestTimeoutSeconds = int.fromEnvironment(
      'EDGE_DEVICE_REQUEST_TIMEOUT_SECONDS',
      defaultValue: -1,
    );
    const cervicalHealthTimeoutSeconds = int.fromEnvironment(
      'CERVICAL_HEALTH_TIMEOUT_SECONDS',
      defaultValue: 5,
    );
    const edgeUploadTimeoutSeconds = int.fromEnvironment(
      'EDGE_DEVICE_UPLOAD_TIMEOUT_SECONDS',
      defaultValue: -1,
    );
    const cervicalUploadTimeoutSeconds = int.fromEnvironment(
      'CERVICAL_IMAGE_TIMEOUT_SECONDS',
      defaultValue: 120,
    );
    const mimeTypes = String.fromEnvironment(
      'EDGE_DEVICE_SUPPORTED_IMAGE_MIME_TYPES',
      defaultValue: 'image/jpeg,image/png',
    );

    final uploadTimeout = Duration(
      seconds: edgeUploadTimeoutSeconds >= 0
          ? edgeUploadTimeoutSeconds
          : cervicalUploadTimeoutSeconds,
    );
    const inferenceTimeoutSeconds = int.fromEnvironment(
      'EDGE_DEVICE_INFERENCE_TIMEOUT_SECONDS',
      defaultValue: -1,
    );

    return EdgeDeviceConfig(
      baseUrlExplicit: sharedUrl.trim().isNotEmpty ||
          cervicalUrl.trim().isNotEmpty ||
          const String.fromEnvironment('PI_DEVICE_BASE_URL').trim().isNotEmpty,
      baseUrl: sharedUrl.trim().isNotEmpty
          ? sharedUrl.trim()
          : cervicalUrl.trim().isNotEmpty
              ? cervicalUrl.trim()
              : piUrl.trim(),
      modelManagementEnabled: const bool.fromEnvironment(
        'EDGE_DEVICE_MODEL_MANAGEMENT_ENABLED',
        defaultValue: false,
      ),
      ultrasoundInferenceEnabled: const bool.fromEnvironment(
        'EDGE_DEVICE_ULTRASOUND_INFERENCE_ENABLED',
        defaultValue: false,
      ),
      apiVersion: const String.fromEnvironment(
        'EDGE_DEVICE_API_VERSION',
        defaultValue: '',
      ),
      healthPath: const String.fromEnvironment(
        'EDGE_DEVICE_HEALTH_PATH',
        defaultValue: '/health',
      ),
      cervicalUploadPath: const String.fromEnvironment(
        'EDGE_DEVICE_CERVICAL_UPLOAD_PATH',
        defaultValue: '/upload/cervical',
      ),
      hubPort: const int.fromEnvironment(
        'EDGE_DEVICE_HUB_PORT',
        defaultValue: 80,
      ),
      cervicalPort: const int.fromEnvironment(
        'EDGE_DEVICE_CERVICAL_PORT',
        defaultValue: 8085,
      ),
      ultrasoundPort: const int.fromEnvironment(
        'EDGE_DEVICE_ULTRASOUND_PORT',
        defaultValue: 8086,
      ),
      hubSelectPath: const String.fromEnvironment(
        'EDGE_DEVICE_HUB_SELECT_PATH',
        defaultValue: '/api/select',
      ),
      hubStatusPath: const String.fromEnvironment(
        'EDGE_DEVICE_HUB_STATUS_PATH',
        defaultValue: '/api/status',
      ),
      moduleHealthPath: const String.fromEnvironment(
        'EDGE_DEVICE_MODULE_HEALTH_PATH',
        defaultValue: '/health',
      ),
      predictPath: const String.fromEnvironment(
        'EDGE_DEVICE_PREDICT_PATH',
        defaultValue: '/predict',
      ),
      cervicalModelId: const String.fromEnvironment(
        'EDGE_DEVICE_CERVICAL_MODEL_ID',
        defaultValue: 'cervitriage',
      ),
      ultrasoundModelId: const String.fromEnvironment(
        'EDGE_DEVICE_ULTRASOUND_MODEL_ID',
        defaultValue: 'ultrasound',
      ),
      cervicalHealthReadyField: const String.fromEnvironment(
        'EDGE_DEVICE_CERVICAL_HEALTH_READY_FIELD',
        defaultValue: 'ready',
      ),
      ultrasoundHealthReadyField: const String.fromEnvironment(
        'EDGE_DEVICE_ULTRASOUND_HEALTH_READY_FIELD',
        defaultValue: 'ready',
      ),
      supportedImageMimeTypes: Set<String>.unmodifiable(
        mimeTypes
            .split(',')
            .map((value) => value.trim().toLowerCase())
            .where((value) => value.isNotEmpty),
      ),
      requestTimeout: Duration(
        seconds: edgeRequestTimeoutSeconds >= 0
            ? edgeRequestTimeoutSeconds
            : cervicalHealthTimeoutSeconds,
      ),
      uploadTimeout: uploadTimeout,
      inferenceTimeout: inferenceTimeoutSeconds >= 0
          ? Duration(seconds: inferenceTimeoutSeconds)
          : uploadTimeout,
      modelRequestTimeout: Duration(
        seconds: const int.fromEnvironment(
          'EDGE_DEVICE_MODEL_REQUEST_TIMEOUT_SECONDS',
          defaultValue: 30,
        ),
      ),
      // Process-switch timeout. The hub's own ready_timeout_s is 300.
      modelReadyTimeout: Duration(
        seconds: const int.fromEnvironment(
          'EDGE_DEVICE_MODEL_READY_TIMEOUT_SECONDS',
          defaultValue: 300,
        ),
      ),
      modelPollInterval: Duration(
        milliseconds: const int.fromEnvironment(
          'EDGE_DEVICE_MODEL_POLL_INTERVAL_MILLISECONDS',
          defaultValue: 1000,
        ),
      ),
      moduleHealthGrace: Duration(
        seconds: const int.fromEnvironment(
          'EDGE_DEVICE_MODULE_HEALTH_GRACE_SECONDS',
          defaultValue: 10,
        ),
      ),
    );
  }

  final String baseUrl;

  /// False when no `--dart-define` supplied a device URL and the built-in
  /// legacy default is in effect.
  final bool baseUrlExplicit;
  final bool modelManagementEnabled;
  final bool ultrasoundInferenceEnabled;
  final String apiVersion;
  final String healthPath;
  final String cervicalUploadPath;
  final int hubPort;
  final int cervicalPort;
  final int ultrasoundPort;
  final String hubSelectPath;
  final String hubStatusPath;
  final String moduleHealthPath;
  final String predictPath;
  final String cervicalModelId;
  final String ultrasoundModelId;
  final String cervicalHealthReadyField;
  final String ultrasoundHealthReadyField;
  final Set<String> supportedImageMimeTypes;
  final Duration requestTimeout;
  final Duration uploadTimeout;

  /// Time allowed for one `/predict` request, separate from connectivity
  /// (`requestTimeout`), module selection and model readiness.
  final Duration inferenceTimeout;
  final Duration modelRequestTimeout;
  final Duration modelReadyTimeout;
  final Duration modelPollInterval;

  /// How long a module may report HTTP 200 without an affirmative
  /// model-loaded field before the model is treated as unavailable.
  final Duration moduleHealthGrace;

  String modelId(EdgeAIModel model) => switch (model) {
        EdgeAIModel.cervicalCancer => cervicalModelId,
        EdgeAIModel.ultrasound => ultrasoundModelId,
      };

  int modulePort(EdgeAIModel model) => switch (model) {
        EdgeAIModel.cervicalCancer => cervicalPort,
        EdgeAIModel.ultrasound => ultrasoundPort,
      };

  String healthReadyField(EdgeAIModel model) => switch (model) {
        EdgeAIModel.cervicalCancer => cervicalHealthReadyField,
        EdgeAIModel.ultrasound => ultrasoundHealthReadyField,
      };

  /// A human-readable reason the configuration cannot work with the real
  /// device, or null. Checked before any network request is attempted.
  String? configurationProblem({bool isWeb = false, Uri? pageUri}) {
    if (!modelManagementEnabled) return null;
    final base = Uri.tryParse(baseUrl.trim());
    if (!baseUrlExplicit) {
      return 'No device URL was supplied at build time. --dart-define values '
          'are compile-time: stop the app and re-run it with '
          '--dart-define=EDGE_DEVICE_BASE_URL=http://<device-host> '
          '(a hot restart does not apply them).';
    }
    if (base != null && base.scheme == 'https') {
      return 'The Dawa device hub and modules speak plain HTTP. Use '
          'EDGE_DEVICE_BASE_URL=http://<device-host> (without a port).';
    }
    if (base != null && base.hasPort) {
      return 'EDGE_DEVICE_BASE_URL must not include a port; set '
          'EDGE_DEVICE_HUB_PORT / _CERVICAL_PORT / _ULTRASOUND_PORT instead.';
    }
    if (isWeb && pageUri != null && pageUri.scheme == 'https') {
      return 'This web page is served over HTTPS but the device is HTTP; the '
          'browser blocks it as mixed content. Serve the app over HTTP for '
          'development or use an HTTPS gateway.';
    }
    return null;
  }

  /// Sanitised summary for development logs (no credentials, no query).
  String diagnosticSummary() {
    final base = Uri.tryParse(baseUrl.trim());
    final host = base == null ? 'invalid' : '${base.scheme}://${base.host}';
    return 'base=$host explicit=$baseUrlExplicit '
        'modelManagement=$modelManagementEnabled '
        'ultrasoundInference=$ultrasoundInferenceEnabled '
        'hub=$hubPort cervical=$cervicalPort ultrasound=$ultrasoundPort '
        'connect=${requestTimeout.inSeconds}s select=${modelRequestTimeout.inSeconds}s '
        'ready=${modelReadyTimeout.inSeconds}s inference=${inferenceTimeout.inSeconds}s';
  }

  Uri hubEndpoint(String path) => endpoint(path, port: hubPort);

  Uri moduleEndpoint(EdgeAIModel model, String path) =>
      endpoint(path, port: modulePort(model));

  /// Resolves [path] against the base URL, optionally replacing its port.
  Uri endpoint(String path, {int? port}) {
    final trimmedBase = baseUrl.trim();
    final parsedBase = Uri.tryParse(trimmedBase);
    if (parsedBase == null ||
        !parsedBase.hasAuthority ||
        parsedBase.host.isEmpty ||
        parsedBase.userInfo.isNotEmpty ||
        parsedBase.hasQuery ||
        parsedBase.hasFragment ||
        (parsedBase.scheme != 'https' && parsedBase.scheme != 'http')) {
      throw const FormatException('The edge device base URL is invalid.');
    }

    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final base = port == null
        ? trimmedBase
        : parsedBase.replace(port: port, path: '').toString();
    return Uri.parse(
      '${base.replaceFirst(RegExp(r'/+$'), '')}/$normalizedPath',
    );
  }
}
