enum EdgeDeviceFailure {
  disabled,
  invalidConfiguration,
  timeout,
  connection,
  http,
  unauthorized,
  unsupported,
  busy,
  conflict,
  invalidResponse,
  modelInitialization,
}

class EdgeDeviceException implements Exception {
  const EdgeDeviceException({
    required this.failure,
    required this.message,
    this.statusCode,
  });

  final EdgeDeviceFailure failure;
  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'EdgeDeviceException(${failure.name}${statusCode == null ? '' : ', HTTP $statusCode'}): $message';
}
