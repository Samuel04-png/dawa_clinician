import 'dart:async';

import '/services/edge_device/edge_device_exceptions.dart';
import 'cacx_upload_service.dart';

enum CacxDeviceFailureKind {
  configuration,
  browserTransport,
  network,
  timeout,
  unauthorized,
  busy,
  modelUnavailable,
  invalidResponse,
  deviceError,
  application,
  unknown,
}

class CacxDeviceFailure {
  const CacxDeviceFailure(this.kind, this.message);

  final CacxDeviceFailureKind kind;

  /// Clinician-facing, sanitised explanation (no response bodies).
  final String message;

  /// The device is working but occupied; a retry (not another provider) is the
  /// natural next step.
  bool get isConflict => kind == CacxDeviceFailureKind.busy;

  bool get isApplicationError =>
      kind == CacxDeviceFailureKind.application ||
      kind == CacxDeviceFailureKind.unknown;
}

String cacxOutcomeStatus(CervicalDeviceInterpretation primary,
    {required bool saved}) {
  if (primary.deviceStatus == 'success') {
    return saved
        ? 'Inference completed and result saved to Supabase'
        : 'Inference completed; Supabase save failed';
  }
  if (primary.deviceStatus == 'rejected') {
    return saved
        ? 'Image rejected; attempt saved to Supabase'
        : 'Image rejected; attempt not saved to Supabase';
  }
  return saved
      ? 'Examination failed; attempt saved to Supabase'
      : 'Examination failed; attempt not saved to Supabase';
}

/// Classifies a device failure so the UI can explain it and decide what to
/// offer. A failure is only produced after the edge manager has finished
/// waiting (model start-up is polled inside the manager, never classified).
CacxDeviceFailure classifyCacxDeviceFailure(
  Object error, {
  bool isWeb = false,
}) {
  if (error is TimeoutException) {
    final detail = error.message;
    return CacxDeviceFailure(
      CacxDeviceFailureKind.timeout,
      detail == null || detail.isEmpty || detail.startsWith('Future')
          ? 'The device did not respond within the configured time.'
          : detail,
    );
  }
  if (error is CervicalDeviceHttpException) {
    return switch (error.statusCode) {
      401 || 403 => const CacxDeviceFailure(
          CacxDeviceFailureKind.unauthorized,
          'The device rejected the request as unauthorized.',
        ),
      409 || 423 => CacxDeviceFailure(
          CacxDeviceFailureKind.busy,
          error.body.contains('exam_in_progress') ||
                  error.body.contains('Another examination')
              ? 'Another examination is in progress on the device.'
              : 'The device is busy processing another request.',
        ),
      503 => const CacxDeviceFailure(
          CacxDeviceFailureKind.modelUnavailable,
          'The cervical AI model is not ready on the device.',
        ),
      _ => CacxDeviceFailure(
          CacxDeviceFailureKind.deviceError,
          'The device returned HTTP ${error.statusCode}.',
        ),
    };
  }
  if (error is EdgeDeviceException) {
    switch (error.failure) {
      case EdgeDeviceFailure.invalidConfiguration:
        return CacxDeviceFailure(
          CacxDeviceFailureKind.configuration,
          error.message,
        );
      case EdgeDeviceFailure.timeout:
        return CacxDeviceFailure(
          CacxDeviceFailureKind.timeout,
          error.message.isEmpty
              ? 'The device did not respond within the configured time.'
              : error.message,
        );
      case EdgeDeviceFailure.connection:
        return isWeb
            ? const CacxDeviceFailure(
                CacxDeviceFailureKind.browserTransport,
                'The browser could not complete the request to the device. '
                'The device sends no CORS headers, so a browser app needs the '
                'development proxy (tool/edge_dev_proxy.dart), or the device '
                'is unreachable.',
              )
            : const CacxDeviceFailure(
                CacxDeviceFailureKind.network,
                'Could not contact the Dawa device on the network.',
              );
      case EdgeDeviceFailure.unauthorized:
        return const CacxDeviceFailure(
          CacxDeviceFailureKind.unauthorized,
          'The device rejected the request as unauthorized.',
        );
      case EdgeDeviceFailure.busy:
      case EdgeDeviceFailure.conflict:
        return CacxDeviceFailure(
          CacxDeviceFailureKind.busy,
          error.message.isEmpty ? 'The device is busy.' : error.message,
        );
      case EdgeDeviceFailure.unsupported:
      case EdgeDeviceFailure.modelInitialization:
      case EdgeDeviceFailure.disabled:
        return CacxDeviceFailure(
          CacxDeviceFailureKind.modelUnavailable,
          error.message.isEmpty
              ? 'The cervical AI model is unavailable on the device.'
              : error.message,
        );
      case EdgeDeviceFailure.invalidResponse:
        return const CacxDeviceFailure(
          CacxDeviceFailureKind.invalidResponse,
          'The device returned a response the app could not validate.',
        );
      case EdgeDeviceFailure.http:
        return CacxDeviceFailure(
          CacxDeviceFailureKind.deviceError,
          'The device returned HTTP ${error.statusCode ?? 'error'}.',
        );
    }
  }
  return const CacxDeviceFailure(
    CacxDeviceFailureKind.application,
    'The application could not process this image. The image is retained for retry.',
  );
}
