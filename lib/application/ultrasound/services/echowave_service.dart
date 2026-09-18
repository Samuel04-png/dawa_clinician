import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

/// Result returned after an EchoWave A scan session.
class EchoWaveSessionResult {
  /// Absolute paths to captured image files (.jpg / .png)
  final List<String> imagePaths;

  /// Absolute paths to captured video files (.mp4)
  final List<String> videoPaths;

  const EchoWaveSessionResult({
    required this.imagePaths,
    required this.videoPaths,
  });

  bool get hasMedia => imagePaths.isNotEmpty || videoPaths.isNotEmpty;

  int get totalFiles => imagePaths.length + videoPaths.length;
}

/// Possible outcomes when attempting to launch EchoWave A.
enum EchoWaveLaunchStatus {
  /// EchoWave A launched successfully.
  launched,

  /// EchoWave A APK is not installed on this device.
  notInstalled,

  /// USB OTG / probe not detected (reported by native side).
  probeNotConnected,

  /// An unexpected error occurred.
  error,
}

class EchoWaveLaunchResult {
  final EchoWaveLaunchStatus status;
  final String? errorMessage;

  const EchoWaveLaunchResult({required this.status, this.errorMessage});
}

/// Service that bridges Flutter with the TELEMED EchoWave A Android app.
///
/// Integration strategy
/// --------------------
/// 1. [launchEchoWaveA] — sends an Intent to open EchoWave A via MethodChannel.
/// 2. [waitForScanFiles] — polls the device's Pictures/Movies directories for
///    new files written by EchoWave A while it was in the foreground.
/// 3. [endSession] — stops the file watcher and returns an [EchoWaveSessionResult]
///    with paths ready to attach to a DawaMom scan record.
///
/// EchoWave A saves files to:
///   Images : /sdcard/Pictures/   (*.jpg)
///   Videos : /sdcard/Movies/     (*.mp4)
class EchoWaveService {
  static const MethodChannel _channel =
      MethodChannel('com.dawahealth.dawa_clinic/echowave');

  /// Package name of the TELEMED EchoWave A application.
  static const String _echoWavePackage = 'com.telemed.echowavea';

  // ------------------------------------------------------------------
  // Session state
  // ------------------------------------------------------------------

  DateTime? _sessionStart;
  final List<String> _capturedImages = [];
  final List<String> _capturedVideos = [];
  Timer? _pollTimer;
  StreamController<EchoWaveSessionResult>? _sessionController;

  /// Stream that emits updated [EchoWaveSessionResult] as new files appear.
  Stream<EchoWaveSessionResult>? get sessionStream =>
      _sessionController?.stream;

  // ------------------------------------------------------------------
  // Public API
  // ------------------------------------------------------------------

  /// Launches EchoWave A via an Android Intent.
  ///
  /// Returns [EchoWaveLaunchStatus.notInstalled] if the APK is not present.
  /// On success begins background file watching automatically.
  Future<EchoWaveLaunchResult> launchEchoWaveA() async {
    try {
      final result = await _channel.invokeMethod<String>('launchEchoWaveA', {
        'package': _echoWavePackage,
      });

      switch (result) {
        case 'launched':
          _beginSession();
          return const EchoWaveLaunchResult(
              status: EchoWaveLaunchStatus.launched);

        case 'not_installed':
          return const EchoWaveLaunchResult(
              status: EchoWaveLaunchStatus.notInstalled);

        case 'probe_not_connected':
          return const EchoWaveLaunchResult(
              status: EchoWaveLaunchStatus.probeNotConnected);

        default:
          return EchoWaveLaunchResult(
            status: EchoWaveLaunchStatus.error,
            errorMessage: result ?? 'Unknown error from native bridge',
          );
      }
    } on PlatformException catch (e) {
      return EchoWaveLaunchResult(
        status: EchoWaveLaunchStatus.error,
        errorMessage: e.message,
      );
    }
  }

  /// Call this when the user returns to Dawa (e.g. onResume / AppLifecycle).
  ///
  /// Performs a final sweep of saved files and stops the background watcher.
  Future<EchoWaveSessionResult> endSession() async {
    _pollTimer?.cancel();
    _pollTimer = null;

    // Final sweep to catch any files written in the last polling interval.
    await _sweepForNewFiles();

    final result = EchoWaveSessionResult(
      imagePaths: List.unmodifiable(_capturedImages),
      videoPaths: List.unmodifiable(_capturedVideos),
    );

    _sessionController?.add(result);
    await _sessionController?.close();
    _sessionController = null;

    return result;
  }

  /// Clears session state without returning a result.
  /// Use this if the user cancels the scan flow entirely.
  void cancelSession() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _sessionStart = null;
    _capturedImages.clear();
    _capturedVideos.clear();
    _sessionController?.close();
    _sessionController = null;
  }

  // ------------------------------------------------------------------
  // Internal helpers
  // ------------------------------------------------------------------

  void _beginSession() {
    _sessionStart = DateTime.now();
    _capturedImages.clear();
    _capturedVideos.clear();
    _sessionController = StreamController<EchoWaveSessionResult>.broadcast();

    // Poll every 3 seconds while EchoWave A is in the foreground.
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _sweepForNewFiles();
    });
  }

  Future<void> _sweepForNewFiles() async {
    if (_sessionStart == null) return;

    await _sweepDirectory(
      directoryPath: '/sdcard/Pictures',
      extensions: {'.jpg', '.jpeg', '.png'},
      targetList: _capturedImages,
    );

    await _sweepDirectory(
      directoryPath: '/sdcard/Movies',
      extensions: {'.mp4'},
      targetList: _capturedVideos,
    );

    if (_capturedImages.isNotEmpty || _capturedVideos.isNotEmpty) {
      _sessionController?.add(EchoWaveSessionResult(
        imagePaths: List.unmodifiable(_capturedImages),
        videoPaths: List.unmodifiable(_capturedVideos),
      ));
    }
  }

  Future<void> _sweepDirectory({
    required String directoryPath,
    required Set<String> extensions,
    required List<String> targetList,
  }) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return;

    await for (final entity in dir.list()) {
      if (entity is! File) continue;

      final ext = path.extension(entity.path).toLowerCase();
      if (!extensions.contains(ext)) continue;

      // Only pick up files created after this session started.
      final stat = await entity.stat();
      if (stat.modified.isBefore(_sessionStart!)) continue;

      // Avoid duplicates.
      if (!targetList.contains(entity.path)) {
        targetList.add(entity.path);
      }
    }
  }
}
