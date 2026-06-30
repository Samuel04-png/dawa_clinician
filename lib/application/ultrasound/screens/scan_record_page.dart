import 'dart:io';

import 'package:flutter/material.dart';

import '../services/echowave_service.dart';

/// Page shown when a sonographer is adding a new scan record for a patient.
///
/// Flow
/// ----
/// 1. User taps "Start Scan" → EchoWave A launches.
// 2. Sonographer scans and saves images/video inside EchoWave A.
/// 3. User returns to Dawa → [AppLifecycleListener] triggers [_onReturnFromScan].
/// 4. Captured files are displayed for review.
/// 5. User taps "Save Record" → files are attached to the patient scan record.
class ScanRecordPage extends StatefulWidget {
  final String patientId;
  final String patientName;

  const ScanRecordPage({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<ScanRecordPage> createState() => _ScanRecordPageState();
}

class _ScanRecordPageState extends State<ScanRecordPage>
    with WidgetsBindingObserver {
  final EchoWaveService _echoWave = EchoWaveService();

  _ScanState _state = _ScanState.idle;
  EchoWaveSessionResult? _sessionResult;
  String? _errorMessage;
  bool _hasLaunchedEchoWave = false;

  // ------------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _echoWave.cancelSession();
    super.dispose();
  }

  /// Called when the user returns to Dawa from EchoWave A.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasLaunchedEchoWave) {
      _hasLaunchedEchoWave = false;
      _onReturnFromScan();
    }
  }

  // ------------------------------------------------------------------
  // Scan flow
  // ------------------------------------------------------------------

  Future<void> _startScan() async {
    setState(() {
      _state = _ScanState.launching;
      _errorMessage = null;
    });

    final launch = await _echoWave.launchEchoWaveA();

    switch (launch.status) {
      case EchoWaveLaunchStatus.launched:
        _hasLaunchedEchoWave = true;
        setState(() => _state = _ScanState.scanning);
        return;

      case EchoWaveLaunchStatus.probeNotConnected:
        // EchoWave A opened but probe isn't plugged in yet — warn and wait.
        _hasLaunchedEchoWave = true;
        setState(() => _state = _ScanState.scanning);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'EchoWave A opened. Please connect the MicrUs Pro probe.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;

      case EchoWaveLaunchStatus.notInstalled:
        setState(() {
          _state = _ScanState.idle;
          _errorMessage = 'EchoWave A is not installed on this device. '
              'Please install the APK and try again.';
        });
        return;

      case EchoWaveLaunchStatus.error:
        setState(() {
          _state = _ScanState.idle;
          _errorMessage = launch.errorMessage ?? 'Failed to launch EchoWave A.';
        });
        return;
    }
  }

  Future<void> _onReturnFromScan() async {
    setState(() => _state = _ScanState.importing);

    final result = await _echoWave.endSession();

    setState(() {
      _sessionResult = result;
      _state = result.hasMedia ? _ScanState.review : _ScanState.noFiles;
    });
  }

  Future<void> _saveRecord() async {
    if (_sessionResult == null || !_sessionResult!.hasMedia) return;

    setState(() => _state = _ScanState.saving);

    try {
      // TODO: replace with your actual DawaMom record save call, e.g.:
      // await ScanRecordRepository.save(
      //   patientId: widget.patientId,
      //   imagePaths: _sessionResult!.imagePaths,
      //   videoPaths: _sessionResult!.videoPaths,
      // );

      // Simulated save delay — remove once wired to real repository.
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Scan record saved — ${_sessionResult!.totalFiles} file(s) attached.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // pop with success = true
      }
    } catch (e) {
      setState(() {
        _state = _ScanState.review;
        _errorMessage = 'Failed to save record: $e';
      });
    }
  }

  void _retakeScan() {
    setState(() {
      _state = _ScanState.idle;
      _sessionResult = null;
      _errorMessage = null;
    });
    _echoWave.cancelSession();
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Scan Record',
              style: TextStyle(
                color: Color(0xFF1A1A2E),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              widget.patientName,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_state) {
      _ScanState.idle => _buildIdleState(),
      _ScanState.launching => _buildLoadingState('Opening EchoWave A…'),
      _ScanState.scanning => _buildScanningState(),
      _ScanState.importing => _buildLoadingState('Importing scan files…'),
      _ScanState.review => _buildReviewState(),
      _ScanState.noFiles => _buildNoFilesState(),
      _ScanState.saving => _buildLoadingState('Saving to patient record…'),
    };
  }

  // --- Idle ----------------------------------------------------------

  Widget _buildIdleState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        _ProbeStatusCard(),
        const SizedBox(height: 32),
        if (_errorMessage != null) ...[
          _ErrorBanner(message: _errorMessage!),
          const SizedBox(height: 24),
        ],
        _PrimaryButton(
          label: 'Start Ultrasound Scan',
          icon: Icons.radar,
          onPressed: _startScan,
        ),
        const SizedBox(height: 16),
        const _InstructionText(
          text: 'This will open EchoWave A. Scan, save your images and video, '
              'then return to Dawa to attach them to this patient record.',
        ),
      ],
    );
  }

  // --- Scanning (EchoWave A is in foreground) ------------------------

  Widget _buildScanningState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.sensors, size: 64, color: Color(0xFF4A90D9)),
        const SizedBox(height: 24),
        const Text(
          'EchoWave A is open',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Perform your scan and save images/video inside EchoWave A.\n\n'
          'When you\'re done, press the back button or switch back to Dawa.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.6),
        ),
        const SizedBox(height: 40),
        OutlinedButton.icon(
          onPressed: _onReturnFromScan,
          icon: const Icon(Icons.download_done_rounded),
          label: const Text('I\'m back — import files'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  // --- Review --------------------------------------------------------

  Widget _buildReviewState() {
    final result = _sessionResult!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          label: 'Images (${result.imagePaths.length})',
          icon: Icons.image_outlined,
        ),
        const SizedBox(height: 12),
        if (result.imagePaths.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: result.imagePaths.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _ThumbnailCard(path: result.imagePaths[i]),
            ),
          )
        else
          const _EmptyMedia(label: 'No images captured'),
        const SizedBox(height: 24),
        _SectionHeader(
          label: 'Videos (${result.videoPaths.length})',
          icon: Icons.videocam_outlined,
        ),
        const SizedBox(height: 12),
        if (result.videoPaths.isNotEmpty)
          ...result.videoPaths.map((p) => _VideoFileRow(path: p))
        else
          const _EmptyMedia(label: 'No videos captured'),
        const Spacer(),
        if (_errorMessage != null) ...[
          _ErrorBanner(message: _errorMessage!),
          const SizedBox(height: 16),
        ],
        _PrimaryButton(
          label: 'Save to Patient Record',
          icon: Icons.save_alt_rounded,
          onPressed: _saveRecord,
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _retakeScan,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Re-scan'),
        ),
      ],
    );
  }

  // --- No files returned ---------------------------------------------

  Widget _buildNoFilesState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.folder_off_outlined,
            size: 56, color: Color(0xFFCBD5E1)),
        const SizedBox(height: 20),
        const Text(
          'No scan files found',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Make sure you saved images or video inside EchoWave A before returning.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
        ),
        const SizedBox(height: 32),
        _PrimaryButton(
          label: 'Open EchoWave A Again',
          icon: Icons.radar,
          onPressed: _startScan,
        ),
      ],
    );
  }

  // --- Loading -------------------------------------------------------

  Widget _buildLoadingState(String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: Color(0xFF4A90D9)),
        const SizedBox(height: 24),
        Text(
          label,
          style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}

// ====================================================================
// State enum
// ====================================================================

enum _ScanState {
  idle,
  launching,
  scanning,
  importing,
  review,
  noFiles,
  saving
}

// ====================================================================
// Sub-widgets
// ====================================================================

class _ProbeStatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        children: [
          Icon(Icons.usb, color: Color(0xFF4A90D9), size: 28),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MicrUs Pro USB Probe',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1A1A2E)),
                ),
                SizedBox(height: 2),
                Text(
                  'Connect probe via USB-C OTG before scanning',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4A90D9),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InstructionText extends StatelessWidget {
  final String text;
  const _InstructionText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style:
          const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.6),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF4A90D9)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E)),
        ),
      ],
    );
  }
}

class _ThumbnailCard extends StatelessWidget {
  final String path;
  const _ThumbnailCard({required this.path});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(
        File(path),
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 120,
          height: 120,
          color: const Color(0xFFE2E8F0),
          child:
              const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8)),
        ),
      ),
    );
  }
}

class _VideoFileRow extends StatelessWidget {
  final String path;
  const _VideoFileRow({required this.path});

  @override
  Widget build(BuildContext context) {
    final fileName = path.split('/').last;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.video_file_outlined,
              color: Color(0xFF4A90D9), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.check_circle_outline,
              color: Color(0xFF22C55E), size: 18),
        ],
      ),
    );
  }
}

class _EmptyMedia extends StatelessWidget {
  final String label;
  const _EmptyMedia({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      ),
    );
  }
}
