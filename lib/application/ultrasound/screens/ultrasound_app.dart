import '/services/clinical_offline_store.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '/reset_password/reset_password_widget.dart';
import '/components/clinical_page_intro.dart' show ClinicalPageIntro;
import '/components/clinical_workspace_components.dart';
import '/components/clinical_tab_bar.dart';
import '/components/clinical_image_frame.dart';
import '/components/dawa_design_system.dart';
import '/components/edge_workflow_status.dart';
import '/components/navigation_design_system.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/edge_device/edge_device_exceptions.dart';
import '/services/edge_device/edge_device_manager.dart';
import '/services/edge_device/edge_device_models.dart';
import '../models/ultrasound_models.dart';
import '../services/ultrasound_ai_service.dart';
import '../services/ultrasound_edge_service.dart';
import '../services/ultrasound_image_picker_service.dart';
import '../repositories/ultrasound_repository.dart';

// ─── MAIN WIDGET ─────────────────────────────────────────────────────────────

enum _UltrasoundWorkflowChoice { normal, aiGuided }

class UltrasoundApp extends StatefulWidget {
  const UltrasoundApp({
    super.key,
    this.initialPatient,
    this.initialMode = UltrasoundLaunchMode.dashboard,
    this.onExit,
    this.repository,
    this.edgeDeviceManager,
  });

  static String routeName = 'Ultrasound';
  static String routePath = '/ultrasound';

  final PregnantPatient? initialPatient;
  final UltrasoundLaunchMode initialMode;
  final VoidCallback? onExit;
  final UltrasoundRepository? repository;
  final EdgeDeviceManager? edgeDeviceManager;

  @override
  State<UltrasoundApp> createState() => _UltrasoundAppState();
}

class _UltrasoundAppState extends State<UltrasoundApp> {
  UltrasoundAppState _appState = UltrasoundAppState.splash;
  UltrasoundDashboardTab _activeTab = UltrasoundDashboardTab.home;

  List<PregnantPatient> _patients = [];
  List<UltrasoundScanRecord> _scanHistory = [];
  bool _isLoadingData = true;
  bool _isSavingResult = false;
  String? _dataError;
  String _patientSearch = '';
  Future<void>? _edgePreparation;
  late final UltrasoundRepository _repository;
  late final EdgeDeviceManager _edgeDeviceManager;
  late final UltrasoundEdgeService _edgeService;

  PregnantPatient? _selectedPatient;
  PregnantPatient? _recordPatient;
  String? _capturedImage;
  String? _activeExaminationId;
  String? _savedRecordExaminationId;
  UltrasoundAnalysisResult? _analysisResult;
  ScanType _activeScanType = ScanType.manual;

  bool _isAnalyzing = false;
  Completer<void>? _inferenceCompletion;

  // AI Sweep state
  int _currentSweepStep = 0;
  List<SweepStep> _sweepSteps = [];
  bool _sweepComplete = false;
  bool _initialLaunchHandled = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? const SupabaseUltrasoundRepository();
    _edgeDeviceManager = widget.edgeDeviceManager ?? EdgeDeviceManager.shared;
    _edgeDeviceManager.addListener(_onEdgeStatusChanged);
    _edgeService = UltrasoundEdgeService(deviceManager: _edgeDeviceManager);
    _sweepSteps = SweepGuidanceProtocol.getObstetricSweepSteps();
    _selectedPatient = widget.initialPatient;
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted)
        unawaited(_edgeDeviceManager.prepareWorkflow(EdgeAIModel.ultrasound));
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _appState = UltrasoundAppState.dashboard);
        _handleInitialLaunch();
      }
    });
  }

  void _onEdgeStatusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _edgeDeviceManager.removeListener(_onEdgeStatusChanged);
    _edgeDeviceManager.cancelWorkflowPreparation(EdgeAIModel.ultrasound);
    final id = _activeExaminationId;
    if (id != null) unawaited(_releaseOnExit(id));
    super.dispose();
  }

  Future<void> _releaseOnExit(String id) async {
    try {
      await _inferenceCompletion?.future;
      await _edgePreparation;
      if (_edgeDeviceManager.activeExaminationId == id) {
        await _edgeDeviceManager.completeExamination(id);
      }
    } on EdgeDeviceException {
      // Preserve an uncertain device session for explicit reconciliation.
    }
  }

  bool get _edgeImageActionsEnabled {
    if (_isAnalyzing) return false;
    if (!_edgeDeviceManager.client.config.ultrasoundInferenceEnabled) {
      return false;
    }
    return _edgeDeviceManager.activeExaminationId == _activeExaminationId &&
        _activeExaminationId != null &&
        _edgeDeviceManager.activeModel == EdgeAIModel.ultrasound &&
        {
          EdgeDeviceState.ready,
          EdgeDeviceState.examining,
        }.contains(_edgeDeviceManager.state);
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoadingData = true;
        _dataError = null;
      });
    }
    try {
      final patients = (await _repository.loadPatients()).toList();
      List<UltrasoundScanRecord> history;
      try {
        history = await _repository.loadScanRecords();
      } catch (_) {
        history = [];
      }
      // History availability must not block patient selection or a new scan.
      final latestRecords = <String, UltrasoundScanRecord>{};
      for (final record in history) {
        latestRecords.putIfAbsent(record.patientId, () => record);
      }
      for (var index = 0; index < patients.length; index++) {
        final patient = patients[index];
        final latestRecord = latestRecords[patient.id];
        if (latestRecord == null) continue;
        patients[index] = PregnantPatient(
          id: patient.id,
          name: patient.name,
          age: patient.age,
          contact: patient.contact,
          gestationalAgeWeeks: patient.gestationalAgeWeeks,
          lmp: patient.lmp,
          edd: patient.edd,
          lastScanDate: latestRecord.date,
          scanStatus: ScanStatus.recorded,
          riskLevel: RiskLevel.unknown,
          pregnancyStatus: patient.pregnancyStatus,
          gravida: patient.gravida,
          imageUrl: patient.imageUrl,
        );
      }
      final initialPatient = widget.initialPatient;
      if (!mounted) return;
      setState(() {
        _patients = patients;
        _scanHistory = history;
        if (initialPatient != null) {
          final authorizedPatient = patients.where(
            (patient) => patient.id == initialPatient.id,
          );
          _selectedPatient =
              authorizedPatient.isEmpty ? null : authorizedPatient.first;
        }
        _isLoadingData = false;
      });
    } catch (error) {
      debugPrint('[Ultrasound] Failed to load saved records: $error');
      if (!mounted) return;
      setState(() {
        _dataError = error.toString();
        _isLoadingData = false;
      });
    }
  }

  void _handleLogout() {
    final onExit = widget.onExit;
    if (onExit != null) {
      onExit();
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _showNotificationPreferencesSheet() async {
    var emailAlerts = true;
    var smsAlerts = false;
    var inAppAlerts = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: DawaTokens.shadowLg,
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: DawaTokens.borderStrong,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Notification Preferences',
                        style: DawaTextStyles.cardTitle,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose how you want to receive ultrasound updates.',
                        style: DawaTextStyles.secondary,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: emailAlerts,
                        onChanged: (value) => setSheetState(
                          () => emailAlerts = value,
                        ),
                        title: const Text('Email alerts'),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: smsAlerts,
                        onChanged: (value) => setSheetState(
                          () => smsAlerts = value,
                        ),
                        title: const Text('SMS alerts'),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: inAppAlerts,
                        onChanged: (value) => setSheetState(
                          () => inAppAlerts = value,
                        ),
                        title: const Text('In-app alerts'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Save preferences'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleInitialLaunch() {
    if (_initialLaunchHandled || !mounted) return;
    _initialLaunchHandled = true;

    switch (widget.initialMode) {
      case UltrasoundLaunchMode.dashboard:
        return;
      case UltrasoundLaunchMode.chooseScanWorkflow:
        _showAddScanWorkflowSheet();
        return;
      case UltrasoundLaunchMode.manualScan:
        _startManualScan();
        return;
      case UltrasoundLaunchMode.aiGuidedScan:
        _startAIGuidedScan();
        return;
      case UltrasoundLaunchMode.uploadImage:
        _pickFromGallery();
        return;
      case UltrasoundLaunchMode.captureImage:
        _captureFromProbe();
        return;
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }

  // ── Image capture ────────────────────────────────────────────────────────

  Future<void> _captureFromProbe() async {
    if (_isAnalyzing) return;
    // In production this connects to the probe's SDK/stream.
    // For now we fall back to the camera (same physical feed on a tablet).
    _activeScanType = _appState == UltrasoundAppState.aiGuidedScan
        ? ScanType.aiGuided
        : ScanType.manual;
    final image = await UltrasoundImagePickerService.captureImage();
    if (image != null && mounted) {
      setState(() => _capturedImage = image);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isAnalyzing) return;
    _activeScanType = _appState == UltrasoundAppState.aiGuidedScan
        ? ScanType.aiGuided
        : ScanType.manual;
    final image = await UltrasoundImagePickerService.pickImage();
    if (image != null && mounted) {
      setState(() => _capturedImage = image);
    }
  }

  void _removePreparedImage() {
    if (_isAnalyzing) return;
    setState(() => _capturedImage = null);
  }

  Future<void> _runAnalysis() async {
    if (_capturedImage == null) return;
    if (!_edgeImageActionsEnabled) {
      _showToast(
          'Image prepared. AI analysis will be available when Ultrasound AI is ready.');
      return;
    }
    final examinationId = _activeExaminationId;
    if (examinationId == null) {
      _showToast('Begin an examination before requesting an analysis.');
      return;
    }
    setState(() => _isAnalyzing = true);
    final completion = Completer<void>();
    _inferenceCompletion = completion;

    UltrasoundAnalysisResult result;
    try {
      result = await _edgeService.analyzeImage(
        image: _capturedImage!,
        gestationalAgeWeeks: _selectedPatient?.gestationalAgeWeeks,
        examinationId: examinationId,
      );
    } on EdgeDeviceException catch (error) {
      result = UltrasoundAIService.unavailableResult(
        _capturedImage!,
        error.message,
      );
    } finally {
      completion.complete();
      _inferenceCompletion = null;
    }

    if (!mounted) return;
    setState(() {
      _analysisResult = result;
      _isAnalyzing = false;
      _appState = UltrasoundAppState.results;
    });
  }

  Future<void> _saveResult() async {
    if (_analysisResult == null ||
        _analysisResult!.error != null ||
        _selectedPatient == null ||
        _isSavingResult) {
      return;
    }

    final examinationId = _activeExaminationId;
    if (examinationId == null) return;
    setState(() => _isSavingResult = true);
    try {
      if (_savedRecordExaminationId != examinationId) {
        final record = await _repository.saveScanRecord(
          patient: _selectedPatient!,
          analysis: _analysisResult!,
          scanType: _activeScanType,
        );
        _scanHistory = [record, ..._scanHistory];
        _savedRecordExaminationId = examinationId;
      }
      final completionError = await _completeActiveEdgeExamination();
      if (completionError != null) {
        if (!mounted) return;
        setState(() => _isSavingResult = false);
        _showToast(
          'Scan record saved. Device session status still requires reconciliation.',
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _isSavingResult = false;
        _appState = UltrasoundAppState.dashboard;
        _activeTab = UltrasoundDashboardTab.patients;
        _analysisResult = null;
        _capturedImage = null;
        _activeExaminationId = null;
        _savedRecordExaminationId = null;
        _selectedPatient = null;
        _activeScanType = ScanType.manual;
        _currentSweepStep = 0;
        _sweepComplete = false;
      });
      _showToast(ClinicalOfflineStore.offline
          ? 'Scan saved on this device. It will sync when online.'
          : 'Scan record saved.');
      await _loadData();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSavingResult = false);
      _showToast('Could not save the scan record: $error');
    }
  }

  void _startManualScan() {
    if (!_requireSelectedPatient()) return;
    final examinationId = const Uuid().v4();
    setState(() {
      _activeScanType = ScanType.manual;
      _savedRecordExaminationId = null;
      _activeExaminationId = examinationId;
      _appState = UltrasoundAppState.manualScan;
    });
    _edgePreparation = _prepareUltrasoundModel(examinationId);
  }

  void _startAIGuidedScan() {
    if (!_requireSelectedPatient()) return;
    final examinationId = const Uuid().v4();
    setState(() {
      _activeScanType = ScanType.aiGuided;
      _savedRecordExaminationId = null;
      _activeExaminationId = examinationId;
      _currentSweepStep = 0;
      _sweepComplete = false;
      _appState = UltrasoundAppState.aiGuidedScan;
    });
    _edgePreparation = _prepareUltrasoundModel(examinationId);
  }

  bool _requireSelectedPatient() {
    final selectedId = _selectedPatient?.id;
    final authorizedPatient = _patients.where(
      (patient) => patient.id == selectedId,
    );
    if (authorizedPatient.isNotEmpty) {
      _selectedPatient = authorizedPatient.first;
      return true;
    }
    _selectedPatient = null;
    setState(() => _activeTab = UltrasoundDashboardTab.patients);
    _showToast('Select an existing patient before beginning a scan.');
    return false;
  }

  Future<void> _retryUltrasoundPreparation() async {
    final id = _activeExaminationId;
    if (id == null) {
      await _edgeDeviceManager.prepareWorkflow(EdgeAIModel.ultrasound);
    } else {
      _edgePreparation = _prepareUltrasoundModel(id);
      await _edgePreparation;
    }
  }

  Future<void> _prepareUltrasoundModel(String examinationId) async {
    if (!_edgeDeviceManager.modelManagementEnabled) return;
    try {
      await _edgeDeviceManager.prepareWorkflow(EdgeAIModel.ultrasound);
      if (!mounted) return;
      if (_edgeDeviceManager.observedReadyModel != EdgeAIModel.ultrasound) {
        return; // Keep preparation available; retry is an explicit action.
      }
      await _edgeService.prepareExamination(examinationId: examinationId);
    } on EdgeDeviceException catch (error) {
      if (mounted) _showToast('Edge model unavailable: ${error.message}');
    }
  }

  Future<String?> _completeActiveEdgeExamination() async {
    final examinationId = _activeExaminationId;
    if (examinationId == null ||
        _edgeDeviceManager.activeExaminationId != examinationId ||
        _edgeDeviceManager.activeModel != EdgeAIModel.ultrasound) {
      return null;
    }
    try {
      final preparation = _edgePreparation;
      if (preparation != null) await preparation;
      if (!{
        EdgeDeviceState.ready,
        EdgeDeviceState.examining,
      }.contains(_edgeDeviceManager.state)) {
        return 'The device examination is not in a state that can be completed.';
      }
      await _edgeDeviceManager.completeExamination(examinationId);
      _edgePreparation = null;
      return null;
    } on EdgeDeviceException catch (error) {
      return error.message;
    }
  }

  Future<void> _reconcileEdgeExamination() async {
    if (_edgeDeviceManager.activeModel != EdgeAIModel.ultrasound ||
        _edgeDeviceManager.activeExaminationId != _activeExaminationId) {
      _showToast(
          'The active device session is not this Ultrasound examination.');
      return;
    }
    try {
      final status = await _edgeDeviceManager.reconcileActiveExamination();
      if (status.state == EdgeDeviceModelState.ready) {
        final examinationId = _edgeDeviceManager.activeExaminationId;
        if (examinationId != null &&
            _savedRecordExaminationId == examinationId) {
          await _edgeDeviceManager.completeExamination(examinationId);
          _activeExaminationId = null;
          _finishSavedExamination();
        }
      } else if (status.state == EdgeDeviceModelState.completed) {
        _activeExaminationId = null;
        if (_savedRecordExaminationId != null) {
          _finishSavedExamination();
        }
      }
      if (mounted) setState(() {});
    } on EdgeDeviceException catch (error) {
      if (mounted) _showToast('Device status is unresolved: ${error.message}');
    }
  }

  void _finishSavedExamination() {
    if (!mounted) return;
    setState(() {
      _appState = UltrasoundAppState.dashboard;
      _activeTab = UltrasoundDashboardTab.history;
      _analysisResult = null;
      _capturedImage = null;
      _activeExaminationId = null;
      _savedRecordExaminationId = null;
      _selectedPatient = null;
      _activeScanType = ScanType.manual;
      _currentSweepStep = 0;
      _sweepComplete = false;
      _edgePreparation = null;
    });
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  Future<void> _showAddScanWorkflowSheet() async {
    final choice = await showModalBottomSheet<_UltrasoundWorkflowChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: BoxDecoration(
                color: DawaTokens.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: DawaTokens.shadowLg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: DawaTokens.borderStrong,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: DawaTokens.brandPrimaryPale,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add_circle_outline,
                          color: DawaTokens.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Scan Record',
                              style: DawaTextStyles.pageTitle.copyWith(
                                fontSize: 20,
                                color: DawaTokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Choose how this ultrasound scan should start.',
                              style: DawaTextStyles.secondary.copyWith(
                                color: DawaTokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 560;
                      final normalTile = _buildWorkflowChoiceTile(
                        icon: Icons.sensors_rounded,
                        title: 'Normal Scan',
                        subtitle:
                            'Manual workspace with gallery upload and camera/probe capture.',
                        color: DawaTokens.brandPrimary,
                        onTap: () => Navigator.of(ctx)
                            .pop(_UltrasoundWorkflowChoice.normal),
                      );
                      final aiTile = _buildWorkflowChoiceTile(
                        icon: Icons.auto_fix_high_outlined,
                        title: 'AI-Guided Scan',
                        subtitle:
                            'Upload an ultrasound image for AI-assisted segmentation and measurement.',
                        color: DawaTokens.brandPrimary,
                        onTap: () => Navigator.of(ctx)
                            .pop(_UltrasoundWorkflowChoice.aiGuided),
                      );

                      if (!isWide) {
                        return Column(
                          children: [
                            normalTile,
                            const SizedBox(height: 12),
                            aiTile,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: normalTile),
                          const SizedBox(width: 12),
                          Expanded(child: aiTile),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!mounted || choice == null) return;

    switch (choice) {
      case _UltrasoundWorkflowChoice.normal:
        _startManualScan();
        return;
      case _UltrasoundWorkflowChoice.aiGuided:
        _startAIGuidedScan();
        return;
    }
  }

  Widget _buildWorkflowChoiceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.24)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: DawaTextStyles.cardTitle.copyWith(
                        color: DawaTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: DawaTextStyles.secondary.copyWith(
                        color: DawaTokens.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.arrow_forward, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_appState) {
      case UltrasoundAppState.splash:
        return _buildSplash();
      case UltrasoundAppState.manualScan:
        return _buildManualScanWorkspace();
      case UltrasoundAppState.aiGuidedScan:
        return _buildAIGuidedScanWorkspace();
      case UltrasoundAppState.results:
        return _buildResultsScreen();
      default:
        return _buildMainLayout();
    }
  }

  // ─── SPLASH ───────────────────────────────────────────────────────────────

  Widget _buildSplash() {
    return Scaffold(
      backgroundColor: DawaTokens.brandPrimary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(seconds: 2),
              tween: Tween(begin: 0, end: 1),
              builder: (context, value, child) =>
                  Transform.scale(scale: 0.8 + value * 0.2, child: child),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Image.asset(
                    'assets/images/dawa_cross.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Dawa Ultrasound',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'AI-Guided Obstetric Scanning',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 16,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 64),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }

  // ─── MAIN LAYOUT ──────────────────────────────────────────────────────────

  Widget _buildMainLayout() {
    return Scaffold(
      backgroundColor: NavigationTokens.canvas,
      body: Column(
        children: [
          if (_dataError != null || _isLoadingData) _buildRepositoryNotice(),
          _buildEdgeDeviceStatus(allowReconcile: true),
          ClinicalTabBar(
            tabs: const [
              ClinicalTab('Overview'),
              ClinicalTab('Patient Records'),
              ClinicalTab('Scan History')
            ],
            activeIndex: _activeTab == UltrasoundDashboardTab.home
                ? 0
                : _activeTab == UltrasoundDashboardTab.patients
                    ? 1
                    : 2,
            enabled: !_isAnalyzing,
            onSelected: (i) => setState(() => _activeTab = [
                  UltrasoundDashboardTab.home,
                  UltrasoundDashboardTab.patients,
                  UltrasoundDashboardTab.history
                ][i]),
          ),
          Expanded(child: _buildCurrentTab()),
        ],
      ),
    );
  }

  Widget _buildRepositoryNotice() {
    if (_isLoadingData) {
      return const LinearProgressIndicator(minHeight: 2);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: DawaTokens.surfaceSecondary,
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: DawaTokens.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Patient and scan records could not be loaded. Check your connection and retry.',
              style: const TextStyle(color: DawaTokens.textSecondary),
            ),
          ),
          TextButton(
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEdgeDeviceStatus({bool allowReconcile = false}) =>
      AnimatedBuilder(
          animation: _edgeDeviceManager,
          builder: (context, _) {
            final manager = _edgeDeviceManager;
            final unresolved = allowReconcile &&
                !_isAnalyzing &&
                manager.activeExaminationId != null &&
                manager.activeExaminationId == _activeExaminationId &&
                manager.activeModel == EdgeAIModel.ultrasound &&
                {
                  EdgeDeviceState.error,
                  EdgeDeviceState.busy,
                  EdgeDeviceState.unsupported
                }.contains(manager.state);
            final relevant = _capturedImage != null ||
                _isAnalyzing ||
                _activeExaminationId != null;
            final hasBlockingNotice = relevant &&
                {
                  EdgeDeviceState.disconnected,
                  EdgeDeviceState.error,
                  EdgeDeviceState.busy,
                  EdgeDeviceState.unsupported,
                }.contains(manager.state);
            final showAnalysisAction = _capturedImage != null;
            if (_appState == UltrasoundAppState.dashboard &&
                !hasBlockingNotice &&
                !showAnalysisAction &&
                !unresolved) {
              return const SizedBox.shrink();
            }
            return Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EdgeWorkflowStatus(
                          manager: manager,
                          model: EdgeAIModel.ultrasound,
                          examinationId: _activeExaminationId,
                          isRelevant:
                              _appState != UltrasoundAppState.dashboard ||
                                  _capturedImage != null ||
                                  _isAnalyzing ||
                                  _activeExaminationId != null,
                          onRetry: _retryUltrasoundPreparation),
                      if (!manager.client.config.ultrasoundInferenceEnabled)
                        const Text(
                            'Local Ultrasound AI analysis is disabled for this installation. Patient and image preparation remain available.'),
                      if (_capturedImage != null)
                        TextButton.icon(
                            onPressed:
                                _edgeImageActionsEnabled ? _runAnalysis : null,
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Analyze Ultrasound Image')),
                      if (_capturedImage != null && !_edgeImageActionsEnabled)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_analysisBlockerMessage(),
                              style: DawaTextStyles.secondary),
                        ),
                      if (unresolved)
                        TextButton.icon(
                            onPressed: _reconcileEdgeExamination,
                            icon: const Icon(Icons.sync),
                            label: const Text('Recheck device session')),
                    ]));
          });

  String _analysisBlockerMessage() {
    if (_isAnalyzing) return 'Ultrasound AI analysis is in progress.';
    if (!_edgeDeviceManager.client.config.ultrasoundInferenceEnabled) {
      return 'Local Ultrasound AI is unavailable for this installation.';
    }
    return switch (_edgeDeviceManager.state) {
      EdgeDeviceState.loadingModel => 'Ultrasound AI is still initializing.',
      EdgeDeviceState.disconnected =>
        'Local AI analysis is unavailable. Reconnect the device to continue.',
      EdgeDeviceState.error =>
        'Local AI analysis is unavailable. Retry the device connection to continue.',
      EdgeDeviceState.busy =>
        'Another examination is using the device. Wait before starting analysis.',
      _ => 'Prepare the ultrasound examination before starting analysis.',
    };
  }

  // ─── SIDEBAR ──────────────────────────────────────────────────────────────

  Widget _buildCurrentTab() {
    switch (_activeTab) {
      case UltrasoundDashboardTab.home:
        return _buildHomeTab();
      case UltrasoundDashboardTab.patients:
        return _buildPatientsTab();
      case UltrasoundDashboardTab.history:
        return _buildHistoryTab();
      case UltrasoundDashboardTab.profile:
        return _buildProfileTab();
    }
  }

  // ─── HOME TAB ─────────────────────────────────────────────────────────────

  Widget _buildHomeTab() => LayoutBuilder(builder: (context, size) {
        final padding = size.maxWidth < 600 ? 16.0 : 24.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(padding, 12, padding, 32),
          child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                    maxWidth: DawaTokens.workspaceMaxWidth),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClinicalPageIntro(
                        subtitle:
                            'Perform and review obstetric ultrasound examinations.',
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        action: _buildPrimaryScanAction(),
                      ),
                      const SizedBox(height: 16),
                      _buildStatsGrid(),
                      const SizedBox(height: 20),
                      _buildRecentScansSection(),
                      const SizedBox(height: 20),
                      _buildProbeTipCard(),
                    ]),
              )),
        );
      });

  Widget _buildPrimaryScanAction() {
    return FilledButton.icon(
      onPressed: _showAddScanWorkflowSheet,
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('New Ultrasound Scan'),
      style: FilledButton.styleFrom(
        backgroundColor: NavigationTokens.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildSecondaryActionCard({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NavigationTokens.border),
            boxShadow: DawaTokens.shadowSm,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: NavigationTokens.brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_outward,
                  color: NavigationTokens.brand,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: DawaTextStyles.cardTitle.copyWith(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DawaTextStyles.secondary.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final scansToday = _scanHistory
        .where((r) => _sameCalendarDay(r.date, DateTime.now()))
        .length;
    final review = _scanHistory.where((record) {
      final level = _findingLevelForRecord(record);
      return level == FindingLevel.monitor || level == FindingLevel.urgent;
    }).length;
    final unavailable = _isLoadingData || _dataError != null;
    final metrics = [
      (
        'Available Patients',
        unavailable ? '—' : '${_patients.length}',
        'Loaded patient records'
      ),
      (
        'Scans Today',
        unavailable ? '—' : '$scansToday',
        'Of ${_scanHistory.length} saved scans'
      ),
      (
        'AI Flags to Review',
        unavailable ? '—' : '$review',
        'Of ${_scanHistory.length} saved scans'
      ),
    ];
    return DawaCard(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(builder: (context, size) {
          final stack = size.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(14) > 21;
          final compact = size.maxWidth < 600;
          final children = [
            for (final metric in metrics)
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(metric.$2,
                    style: DawaTextStyles.statNumber.copyWith(fontSize: 24)),
                const SizedBox(height: 6),
                Text(metric.$1,
                    style: DawaTextStyles.body.copyWith(
                        fontSize: compact ? 12 : 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(unavailable ? 'Awaiting records' : metric.$3,
                    style: DawaTextStyles.secondary.copyWith(
                        fontSize: compact ? 11 : 12,
                        color: DawaTokens.textSecondary)),
              ])
          ];
          if (stack) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < children.length; index++) ...[
                    if (index > 0)
                      const Divider(height: 24, color: DawaTokens.border),
                    children[index],
                  ],
                ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const SizedBox(width: 16),
              Expanded(child: children[index]),
            ],
          ]);
        }));
  }

  Widget _buildProbeTipCard() {
    return DawaCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          color: Colors.transparent,
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: const Icon(Icons.tips_and_updates_outlined,
                color: DawaTokens.brandPrimary, size: 20),
            title: Text('Probe guidance', style: DawaTextStyles.cardTitle),
            subtitle: Text('Optional preparation help',
                style: DawaTextStyles.secondary.copyWith(fontSize: 12)),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Apply adequate gel before scanning. Start with minimal pressure and increase only when needed to improve image quality.',
                  style: DawaTextStyles.secondary
                      .copyWith(color: DawaTokens.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<UltrasoundScanRecord> get _orderedSavedScans =>
      [..._scanHistory]..sort((a, b) => b.date.compareTo(a.date));

  Widget _buildRecentScansSection() {
    final records = _orderedSavedScans.take(5).toList();
    return DawaCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Recent Scans', style: DawaTextStyles.cardTitle),
                  TextButton(
                      onPressed: () => setState(
                          () => _activeTab = UltrasoundDashboardTab.history),
                      child: const Text('View all')),
                ]),
            Text('Saved examinations · Newest first',
                style: DawaTextStyles.secondary.copyWith(fontSize: 12)),
            const SizedBox(height: 12),
            if (_isLoadingData)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()))
            else if (_dataError != null)
              ClinicalEmptyState(
                  surface: false,
                  icon: Icons.cloud_off_outlined,
                  title: 'Scan records unavailable',
                  message:
                      'Check your connection and try loading the saved examinations again.',
                  actionLabel: 'Retry records',
                  onAction: _loadData)
            else if (records.isEmpty)
              ClinicalEmptyState(
                  surface: false,
                  icon: Icons.image_search_outlined,
                  title: 'No recent scans yet',
                  message:
                      'Start an ultrasound examination to save the first scan.',
                  actionLabel: 'New scan',
                  onAction: _showAddScanWorkflowSheet)
            else
              for (var index = 0; index < records.length; index++) ...[
                if (index > 0)
                  const Divider(height: 1, color: DawaTokens.border),
                _buildRecentScanTile(records[index]),
              ],
          ],
        ));
  }

  String _savedScanDate(DateTime date) =>
      dateTimeFormat('d MMM y, h:mm a', date);

  String _shortScanReference(UltrasoundScanRecord record) {
    final id = record.examinationId ?? record.id;
    return id.length > 16
        ? '${id.substring(0, 8)}…${id.substring(id.length - 4)}'
        : id;
  }

  Widget _savedScanBadge(UltrasoundScanRecord record) {
    if (record.segmentation != null) {
      return const ClinicalStatusChip(
          label: 'Measurement', tone: ClinicalStatusTone.info);
    }
    final level = _findingLevelForRecord(record);
    if (level == null) return const ClinicalStatusChip(label: 'Recorded');
    return DawaStatusBadge(
        status: level == FindingLevel.urgent
            ? 'danger'
            : level == FindingLevel.normal
                ? 'normal'
                : 'needs_review',
        label: _levelLabel(level));
  }

  Widget _buildRecentScanTile(UltrasoundScanRecord record,
      {bool showPatient = true}) {
    return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSavedScanDetails(record),
          borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            child: LayoutBuilder(builder: (context, size) {
              final compact = size.maxWidth < 660 ||
                  MediaQuery.textScalerOf(context).scale(14) > 21;
              final identity =
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                DawaAvatarCircle(name: record.patientName, size: 36),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          showPatient
                              ? record.patientName
                              : record.scanTypeString,
                          style:
                              DawaTextStyles.cardTitle.copyWith(fontSize: 15)),
                      const SizedBox(height: 5),
                      Text(
                          '${_savedScanDate(record.date)} · ${record.scanTypeString}',
                          style: DawaTextStyles.secondary.copyWith(
                              fontSize: 12, color: DawaTokens.textSecondary)),
                      const SizedBox(height: 5),
                      Text(
                          record.result.trim().isEmpty
                              ? 'No result summary saved'
                              : record.result,
                          style: DawaTextStyles.body.copyWith(fontSize: 13)),
                      const SizedBox(height: 5),
                      Text(
                          '${_analysisProviderLabel(record.analysisProvider)} · Ref ${_shortScanReference(record)}',
                          style: DawaTextStyles.secondary.copyWith(
                              fontSize: 12, color: DawaTokens.textSecondary)),
                    ])),
              ]);
              final actions = Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _savedScanBadge(record),
                    TextButton.icon(
                        onPressed: () => _showSavedScanDetails(record),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('View Scan')),
                  ]);
              if (compact)
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      identity,
                      const SizedBox(height: 10),
                      actions,
                    ]);
              return Row(children: [
                Expanded(child: identity),
                const SizedBox(width: 16),
                actions
              ]);
            }),
          ),
        ));
  }

  // ─── MANUAL SCAN SCREEN ───────────────────────────────────────────────────

  // ─── AI GUIDED SWEEP SCREEN ───────────────────────────────────────────────

  Widget _buildManualScanWorkspace() {
    return Scaffold(
      backgroundColor: DawaTokens.surfaceSecondary,
      appBar: _buildScanAppBar(
        title: 'Normal Ultrasound Scan',
        accent: DawaTokens.brandPrimary,
        onBack: _returnToDashboard,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 920;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildScanHeaderCard(
                        icon: Icons.sensors_rounded,
                        title: 'Normal ultrasound scan',
                        subtitle:
                            'Upload a saved ultrasound image or capture a frame from the camera/probe.',
                        accent: DawaTokens.brandPrimary,
                        badges: const ['Manual workflow', 'Image analysis'],
                      ),
                      const SizedBox(height: 16),
                      _buildEdgeDeviceStatus(),
                      const SizedBox(height: 16),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: _buildProbePreviewCard(
                                title: 'Scan preview',
                                subtitle: 'Camera, probe, or uploaded image',
                                accent: DawaTokens.brandPrimary,
                                emptyIcon: Icons.sensors_rounded,
                                emptyTitle: 'No image selected',
                                emptySubtitle:
                                    'Upload from gallery or capture a frame to begin analysis.',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  _buildPatientSelectorCard(
                                    accent: DawaTokens.brandPrimary,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildManualScanActionsCard(),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildPatientSelectorCard(
                          accent: DawaTokens.brandPrimary,
                        ),
                        const SizedBox(height: 16),
                        _buildProbePreviewCard(
                          title: 'Scan preview',
                          subtitle: 'Camera, probe, or uploaded image',
                          accent: DawaTokens.brandPrimary,
                          emptyIcon: Icons.sensors_rounded,
                          emptyTitle: 'No image selected',
                          emptySubtitle:
                              'Upload from gallery or capture a frame to begin analysis.',
                        ),
                        const SizedBox(height: 16),
                        _buildManualScanActionsCard(),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAIGuidedScanWorkspace() {
    return Scaffold(
      backgroundColor: DawaTokens.surfaceSecondary,
      appBar: _buildScanAppBar(
        title: 'New Ultrasound Scan',
        accent: DawaTokens.brandPrimary,
        onBack: _returnToDashboard,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 920;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildScanHeaderCard(
                        icon: Icons.auto_fix_high_outlined,
                        title: 'AI-assisted ultrasound analysis',
                        subtitle:
                            'Upload an ultrasound image for AI-assisted segmentation and measurement.',
                        accent: DawaTokens.brandPrimary,
                        badges: const ['Image upload', 'AI-assisted'],
                      ),
                      const SizedBox(height: 16),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: _buildProbePreviewCard(
                                title: 'Ultrasound image',
                                subtitle: 'Original image prepared for review',
                                accent: DawaTokens.brandPrimary,
                                emptyIcon: Icons.image_search_outlined,
                                emptyTitle: 'No image selected',
                                emptySubtitle:
                                    'Choose a saved ultrasound image to prepare it for AI analysis.',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  _buildPatientSelectorCard(
                                    accent: DawaTokens.brandPrimary,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildAiImageActionsCard(),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildPatientSelectorCard(
                          accent: DawaTokens.brandPrimary,
                        ),
                        const SizedBox(height: 16),
                        _buildProbePreviewCard(
                          title: 'Ultrasound image',
                          subtitle: 'Original image prepared for review',
                          accent: DawaTokens.brandPrimary,
                          emptyIcon: Icons.image_search_outlined,
                          emptyTitle: 'No image selected',
                          emptySubtitle:
                              'Choose a saved ultrasound image to prepare it for AI analysis.',
                        ),
                        const SizedBox(height: 16),
                        _buildAiImageActionsCard(),
                      ],
                      const SizedBox(height: 16),
                      _buildEdgeDeviceStatus(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAiImageActionsCard() {
    final hasImage = _capturedImage != null;
    return DawaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Image and analysis', style: DawaTextStyles.cardTitle),
          const SizedBox(height: 6),
          Text(
            hasImage
                ? 'Review the selected image, then explicitly request AI analysis.'
                : 'Choose an existing ultrasound image. Selecting it does not start analysis.',
            style: DawaTextStyles.secondary
                .copyWith(color: DawaTokens.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _isAnalyzing ? null : _pickFromGallery,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(hasImage ? 'Replace image' : 'Choose image'),
              ),
              if (hasImage)
                TextButton.icon(
                  onPressed: _isAnalyzing ? null : _removePreparedImage,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove image'),
                ),
            ],
          ),
          if (_isAnalyzing) _buildAnalysisProgress(DawaTokens.brandPrimary),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildScanAppBar({
    required String title,
    required Color accent,
    required VoidCallback onBack,
  }) {
    return AppBar(
      backgroundColor: DawaTokens.surface,
      foregroundColor: DawaTokens.textPrimary,
      elevation: 0,
      leading: IconButton(
        tooltip: 'Back',
        icon: Icon(Icons.arrow_back, color: accent),
        onPressed: onBack,
      ),
      title: Text(
        title,
        style: DawaTextStyles.cardTitle.copyWith(
          color: DawaTokens.textPrimary,
          fontSize: 18,
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: DawaTokens.border),
      ),
    );
  }

  void _returnToDashboard() {
    _leaveExamination();
  }

  Future<void> _leaveExamination() async {
    final error = await _completeActiveEdgeExamination();
    if (!mounted) return;
    setState(() {
      _appState = UltrasoundAppState.dashboard;
      _currentSweepStep = 0;
      _sweepComplete = false;
    });
    if (error != null) {
      _showToast(
        'The edge session was not confirmed complete. Reconcile it before another edge examination.',
      );
    }
  }

  Widget _buildScanHeaderCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required List<String> badges,
  }) {
    return Text(subtitle,
        style:
            DawaTextStyles.secondary.copyWith(color: DawaTokens.textSecondary));
  }

  Widget _buildProbePreviewCard({
    required String title,
    required String subtitle,
    required Color accent,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
    Widget? overlay,
  }) {
    return DawaCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.monitor_heart_outlined,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: DawaTextStyles.cardTitle),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: DawaTextStyles.secondary.copyWith(
                          color: DawaTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 10,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(DawaTokens.radiusLg),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: const Color(0xFF050816),
                    child: _capturedImage != null
                        ? ClinicalImageFrame(
                            bytes:
                                base64Decode(_capturedImage!.split(',').last),
                            badge: _buildPreviewBadge(
                                icon: Icons.check_circle_outline,
                                label: 'Frame loaded',
                                accent: DawaTokens.statusSuccessText),
                          )
                        : _buildEmptyProbePreview(
                            icon: emptyIcon,
                            title: emptyTitle,
                            subtitle: emptySubtitle,
                          ),
                  ),
                  if (_capturedImage == null)
                    Positioned(
                      left: 16,
                      top: 16,
                      child: _buildPreviewBadge(
                        icon: Icons.circle,
                        label:
                            _capturedImage == null ? 'Ready' : 'Frame loaded',
                        accent: _capturedImage == null
                            ? DawaTokens.textMuted
                            : DawaTokens.statusSuccess,
                      ),
                    ),
                  if (overlay != null) overlay,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyProbePreview({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white24, size: 72),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: DawaTextStyles.cardTitle.copyWith(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: DawaTextStyles.secondary.copyWith(
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewBadge({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.48),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 10),
          const SizedBox(width: 6),
          Text(
            label,
            style: DawaTextStyles.secondary.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientSelectorCard({required Color accent}) {
    final selected = _selectedPatient;

    return DawaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.pregnant_woman, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Patient context', style: DawaTextStyles.cardTitle),
                    const SizedBox(height: 2),
                    Text(
                      selected == null
                          ? 'Select a patient before saving a scan record.'
                          : '${selected.name} · ${selected.gestationalAgeWeeks == null ? 'Gestational age not recorded' : '${selected.gestationalAgeWeeks} weeks'}',
                      style: DawaTextStyles.secondary.copyWith(
                        color: DawaTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<PregnantPatient>(
            value: _selectedPatient,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: DawaTokens.surfaceSecondary,
              hintText: _patients.isEmpty
                  ? 'No patient records available'
                  : 'Select patient',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: DawaTokens.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: DawaTokens.border),
              ),
            ),
            items: _patients
                .map(
                  (patient) => DropdownMenuItem(
                    value: patient,
                    child: Text(
                      _patientDropdownLabel(patient),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _patients.isEmpty
                ? null
                : (patient) => setState(() => _selectedPatient = patient),
          ),
        ],
      ),
    );
  }

  String _patientDropdownLabel(PregnantPatient patient) {
    final parts = <String>[
      patient.name,
      patient.age == null ? 'Age not recorded' : '${patient.age} years',
      'Ref ${patient.id.length > 8 ? patient.id.substring(0, 8) : patient.id}'
    ];
    if ((patient.gravida ?? '').isNotEmpty) parts.add(patient.gravida!);
    if (patient.gestationalAgeWeeks != null) {
      parts.add('${patient.gestationalAgeWeeks} wks');
    }
    return parts.join(' - ');
  }

  Widget _buildManualScanActionsCard() {
    return DawaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Image source', style: DawaTextStyles.cardTitle),
          const SizedBox(height: 6),
          Text(
            'Choose a saved ultrasound image or capture a still image with this device camera.',
            style: DawaTextStyles.secondary.copyWith(
              color: DawaTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 420;
              final upload = _buildScanActionButton(
                label: 'Upload Image',
                icon: Icons.photo_library_outlined,
                accent: DawaTokens.brandPrimary,
                outlined: true,
                onPressed: !_isAnalyzing ? _pickFromGallery : null,
              );
              final capture = _buildScanActionButton(
                label: 'Capture Frame',
                icon: Icons.camera_alt_outlined,
                accent: DawaTokens.brandPrimary,
                onPressed: !_isAnalyzing ? _captureFromProbe : null,
              );

              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    upload,
                    const SizedBox(height: 12),
                    capture,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: upload),
                  const SizedBox(width: 12),
                  Expanded(child: capture),
                ],
              );
            },
          ),
          if (_isAnalyzing) _buildAnalysisProgress(DawaTokens.brandPrimary),
        ],
      ),
    );
  }

  Widget _buildScanActionButton({
    required String label,
    required IconData icon,
    required Color accent,
    required VoidCallback? onPressed,
    bool outlined = false,
  }) {
    final style = outlined
        ? OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: BorderSide(color: accent),
            minimumSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          );

    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: style,
      );
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: style,
    );
  }

  Widget _buildAnalysisProgress(Color accent) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              color: accent,
              backgroundColor: accent.withOpacity(0.14),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'AI is analysing the frame...',
            style: DawaTextStyles.secondary.copyWith(
              color: DawaTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _advanceSweepStep() {
    if (_currentSweepStep < _sweepSteps.length - 1) {
      setState(() => _currentSweepStep++);
      return;
    }

    setState(() => _sweepComplete = true);
    _showSweepCompleteDialog();
  }

  Widget _buildStepInfoRow(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSweepCompleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: DawaTokens.statusSuccess),
            SizedBox(width: 8),
            Text('Sweep Complete!'),
          ],
        ),
        content: const Text(
          'All 6 sweep steps are done. '
          'You can now capture a final summary frame for AI analysis, '
          'or go back to the dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _appState = UltrasoundAppState.dashboard);
            },
            child: const Text('Back to Dashboard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _captureFromProbe();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: DawaTokens.statusSuccess,
                foregroundColor: Colors.white),
            child: const Text('Capture & Analyse'),
          ),
        ],
      ),
    );
  }

  // ─── PATIENTS TAB ─────────────────────────────────────────────────────────

  Widget _buildPatientsTab() {
    final recordPatient = _recordPatient;
    if (recordPatient != null) return _buildPatientRecordProfile(recordPatient);
    final visiblePatients = _patients.where((patient) {
      final query = _patientSearch.trim().toLowerCase();
      return query.isEmpty ||
          patient.name.toLowerCase().contains(query) ||
          patient.id.toLowerCase().contains(query) ||
          patient.contact.toLowerCase().contains(query);
    }).toList(growable: false);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Patient Records', style: DawaTextStyles.pageTitle),
              const SizedBox(height: 4),
              Text(
                  'Find authorized patients and review their saved ultrasound examinations.',
                  style: DawaTextStyles.secondary),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _patientSearch,
                decoration: InputDecoration(
                  hintText: 'Search by patient name, reference or phone',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) => setState(() => _patientSearch = value),
              ),
            ]),
          ),
        ),
        Expanded(
          child: _isLoadingData
              ? const Center(child: CircularProgressIndicator())
              : visiblePatients.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _dataError != null
                              ? 'Patient records are unavailable.'
                              : _patientSearch.isNotEmpty
                                  ? 'No matching patient records.'
                                  : 'No patient records are available.',
                          style: DawaTextStyles.secondary,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: visiblePatients.length,
                      itemBuilder: (ctx, i) {
                        final p = visiblePatients[i];
                        final records = _scanHistory
                            .where((record) => record.patientId == p.id)
                            .toList(growable: false);
                        return DawaCard(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 5),
                          padding: EdgeInsets.zero,
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor:
                                    p.statusColor.withOpacity(0.15),
                                child: Text(p.name[0],
                                    style: TextStyle(
                                        color: p.statusColor,
                                        fontWeight: FontWeight.bold)),
                              ),
                              title: Text(p.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                [
                                  'Ref ${p.id}',
                                  if (p.age != null) '${p.age} years',
                                  if (p.gravida?.isNotEmpty == true) p.gravida!,
                                  if (p.gestationalAgeWeeks != null)
                                    '${p.gestationalAgeWeeks} weeks',
                                ].join(' • '),
                              ),
                              trailing: Text(
                                  '${records.length} ${records.length == 1 ? 'scan' : 'scans'}',
                                  style: DawaTextStyles.secondary
                                      .copyWith(fontWeight: FontWeight.w700)),
                              onTap: () {
                                setState(() => _recordPatient = p);
                              },
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildPatientRecordProfile(PregnantPatient patient) {
    final records = _scanHistory
        .where((record) => record.patientId == patient.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextButton.icon(
                onPressed: () => setState(() => _recordPatient = null),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back to patient records')),
            const SizedBox(height: 8),
            DawaCard(
                child: Wrap(
                    spacing: 16,
                    runSpacing: 14,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                  DawaAvatarCircle(
                      name: patient.name,
                      moduleColor: DawaTokens.brandPrimary,
                      size: 48),
                  ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(patient.name, style: DawaTextStyles.pageTitle),
                            const SizedBox(height: 5),
                            Text(
                                [
                                  'Ref ${patient.id}',
                                  if (patient.age != null)
                                    '${patient.age} years',
                                  if (patient.gravida?.isNotEmpty == true)
                                    patient.gravida!,
                                  if (patient.gestationalAgeWeeks != null)
                                    '${patient.gestationalAgeWeeks} weeks',
                                ].join(' • '),
                                style: DawaTextStyles.secondary),
                            const SizedBox(height: 5),
                            Text(
                                records.isEmpty
                                    ? 'No saved ultrasound examinations'
                                    : '${records.length} saved ultrasound ${records.length == 1 ? 'examination' : 'examinations'}',
                                style: DawaTextStyles.secondary),
                          ])),
                  FilledButton.icon(
                      onPressed: () {
                        setState(() => _selectedPatient = patient);
                        _startAIGuidedScan();
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Ultrasound Scan')),
                ])),
            const SizedBox(height: 20),
            Text('Ultrasound examinations', style: DawaTextStyles.cardTitle),
            const SizedBox(height: 8),
            if (records.isEmpty)
              DawaCard(
                  child: Text(
                      'No ultrasound examinations recorded for this patient.',
                      style: DawaTextStyles.secondary))
            else
              for (final record in records) ...[
                _buildRecordRow(record, showPatient: false),
                const SizedBox(height: 8),
              ],
          ]),
        ),
      ),
    );
  }

  Widget _buildRecordRow(UltrasoundScanRecord record,
          {bool showPatient = true}) =>
      DawaCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildRecentScanTile(record, showPatient: showPatient));

  Future<void> _showSavedScanDetails(UltrasoundScanRecord record) async {
    Widget content() => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Semantics(
                    header: true,
                    child: Text('Saved ultrasound examination',
                        style:
                            DawaTextStyles.pageTitle.copyWith(fontSize: 22)))),
            IconButton(
                tooltip: 'Close scan details',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded)),
          ]),
          const SizedBox(height: 12),
          Text(record.patientName,
              style: DawaTextStyles.cardTitle.copyWith(fontSize: 20)),
          const SizedBox(height: 6),
          Text('${_savedScanDate(record.date)} · ${record.scanTypeString}',
              style: DawaTextStyles.secondary),
          const SizedBox(height: 8),
          Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _savedScanBadge(record),
                Text(_analysisProviderLabel(record.analysisProvider),
                    style: DawaTextStyles.secondary),
                TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(
                          text: record.examinationId ?? record.id));
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Examination reference copied.')));
                    },
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: Text('Ref ${_shortScanReference(record)}')),
              ]),
          const SizedBox(height: 12),
          Text('AI estimate — clinician must review',
              style: DawaTextStyles.secondary
                  .copyWith(fontSize: 12, color: DawaTokens.textSecondary)),
          const Divider(height: 32, color: DawaTokens.border),
          Text('Saved result', style: DawaTextStyles.cardTitle),
          const SizedBox(height: 8),
          Text(
              record.result.trim().isEmpty
                  ? 'No result summary saved.'
                  : record.result,
              style: DawaTextStyles.body),
          if (record.gestationalAgeWeeks != null) ...[
            const SizedBox(height: 8),
            Text(
                'Gestational age at examination · ${record.gestationalAgeWeeks} weeks',
                style: DawaTextStyles.secondary),
          ],
          const SizedBox(height: 20),
          Text('Examination notes', style: DawaTextStyles.cardTitle),
          const SizedBox(height: 8),
          Text(
              record.notes.trim().isEmpty
                  ? 'No examination notes saved.'
                  : record.notes,
              style: DawaTextStyles.body),
          if (record.aiAnalysis?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 20),
            Text('Saved AI analysis', style: DawaTextStyles.cardTitle),
            const SizedBox(height: 8),
            Text(record.aiAnalysis!, style: DawaTextStyles.body),
          ],
          if (record.findings.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Saved findings', style: DawaTextStyles.cardTitle),
            const SizedBox(height: 10),
            ...record.findings.map(_buildFindingTile),
          ],
          if (record.measurements?.isNotEmpty == true) ...[
            const SizedBox(height: 20),
            Text('Saved measurements', style: DawaTextStyles.cardTitle),
            const SizedBox(height: 10),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: record.measurements!.entries
                    .map((entry) =>
                        _buildMeasurementChip(entry.key, '${entry.value}'))
                    .toList()),
          ],
          if (record.segmentation != null) ...[
            const SizedBox(height: 20),
            ..._buildSegmentationSection(record.segmentation!),
          ],
          const SizedBox(height: 20),
          Text('Saved image', style: DawaTextStyles.cardTitle),
          const SizedBox(height: 10),
          _buildSavedScanImage(record.imageUri),
          if (record.modelId != null ||
              record.modelVersion != null ||
              record.deviceId != null) ...[
            const SizedBox(height: 20),
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Analysis details'),
                children: [
                  if (record.modelId != null)
                    _savedMetadata('Model', record.modelId!),
                  if (record.modelVersion != null)
                    _savedMetadata('Model version', record.modelVersion!),
                  if (record.deviceId != null)
                    _savedMetadata('Device', record.deviceId!),
                ]),
          ],
          const SizedBox(height: 16),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'))),
        ]));
    if (MediaQuery.sizeOf(context).width >= 720) {
      await showDialog<void>(
          context: context,
          builder: (dialogContext) => Dialog(
                backgroundColor: DawaTokens.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DawaTokens.radiusLg)),
                child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: 860,
                        maxHeight:
                            MediaQuery.sizeOf(dialogContext).height * .88),
                    child: content()),
              ));
    } else {
      await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: DawaTokens.surface,
          builder: (_) =>
              FractionallySizedBox(heightFactor: .92, child: content()));
    }
  }

  Widget _savedMetadata(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
          alignment: Alignment.centerLeft,
          child: Text('$label · $value', style: DawaTextStyles.secondary)));

  Widget _buildSavedScanImage(String? image) {
    final placeholder = Text(
        image?.isNotEmpty == true
            ? 'Image preview unavailable. The saved result is still available above.'
            : 'No image was saved with this examination.',
        style: DawaTextStyles.secondary);
    if (image == null || image.trim().isEmpty) return placeholder;
    Widget preview;
    try {
      final uri = Uri.parse(image);
      if (uri.scheme == 'data' && uri.data != null) {
        preview = Image.memory(uri.data!.contentAsBytes(),
            fit: BoxFit.contain, errorBuilder: (_, __, ___) => placeholder);
      } else if (uri.scheme == 'http' || uri.scheme == 'https') {
        preview = Image.network(image,
            fit: BoxFit.contain, errorBuilder: (_, __, ___) => placeholder);
      } else {
        return placeholder;
      }
    } on FormatException {
      return placeholder;
    }
    return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320), child: preview);
  }

  // ─── HISTORY TAB ──────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    final records = _orderedSavedScans;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Scan History', style: DawaTextStyles.pageTitle),
                    const SizedBox(height: 4),
                    Text('Review previously saved ultrasound examinations.',
                        style: DawaTextStyles.secondary),
                  ]),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingData
              ? const Center(child: CircularProgressIndicator())
              : _scanHistory.isEmpty
                  ? Center(
                      child: Text(
                        _dataError != null
                            ? 'Scan records are unavailable.'
                            : 'No saved ultrasound records.',
                        style: DawaTextStyles.secondary,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) =>
                          _buildRecordRow(records[index]),
                    ),
        ),
      ],
    );
  }

  // ─── PROFILE TAB ──────────────────────────────────────────────────────────

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('My Profile',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          const Text('Manage your account and preferences.',
              style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 20)
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: DawaTokens.brandPrimary,
                      child: Text('MM',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 20),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Memory Musonda',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Midwife Sonographer • Dawa Clinic',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 14)),
                          SizedBox(height: 8),
                          Chip(
                            label: Text('Verified',
                                style: TextStyle(
                                    color: DawaTokens.brandPrimary,
                                    fontSize: 12)),
                            backgroundColor: DawaTokens.brandPrimaryPale,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Account Settings',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.lock),
                  title: const Text('Change Password'),
                  onTap: () => context.pushNamed(ResetPasswordWidget.routeName),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notification Preferences'),
                  onTap: _showNotificationPreferencesSheet,
                ),
                ListTile(
                  leading:
                      const Icon(Icons.logout, color: DawaTokens.statusDanger),
                  title: const Text('Sign Out',
                      style: TextStyle(color: DawaTokens.statusDanger)),
                  onTap: _handleLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── RESULTS SCREEN ───────────────────────────────────────────────────────

  Widget _buildResultsScreen() {
    final result = _analysisResult;
    if (result == null) {
      return const Center(child: Text('No results available'));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _leaveResults,
        ),
        title: const Text('Ultrasound analysis results'),
        backgroundColor: DawaTokens.brandPrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: result.error == null &&
                    _selectedPatient != null &&
                    !_isSavingResult
                ? _saveResult
                : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedPatient != null) ...[
              DawaCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  const Icon(Icons.person_outline,
                      color: DawaTokens.brandPrimary),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(_selectedPatient!.name,
                            style: DawaTextStyles.cardTitle),
                        Text('Patient reference ${_selectedPatient!.id}',
                            style: DawaTextStyles.secondary),
                      ])),
                ]),
              ),
              const SizedBox(height: 16),
            ],
            // ── Captured image ─────────────────────────────────────────────
            if (_capturedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: Image.memory(
                    base64Decode(_capturedImage!.split(',').last),
                    fit: BoxFit.contain,
                  ),
                ),
              )
            else
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                    child: Icon(Icons.image, color: Colors.white38, size: 48)),
              ),

            const SizedBox(height: 20),

            // ── Overall assessment ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: result.levelColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: result.levelColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                        color: result.levelColor,
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(
                      result.error != null
                          ? Icons.info_outline
                          : result.segmentation != null
                              ? Icons.straighten
                              : result.overallLevel == FindingLevel.normal
                                  ? Icons.check_circle
                                  : result.overallLevel == FindingLevel.monitor
                                      ? Icons.warning_amber
                                      : Icons.error,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            result.error == null
                                ? (result.segmentation != null
                                    ? 'Edge segmentation'
                                    : 'AI ${result.levelString}')
                                : 'Analysis unavailable',
                            style: TextStyle(
                                color: result.levelColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(result.overallAssessment,
                            style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: result.provider == UltrasoundAnalysisProvider.unavailable
                    ? DawaTokens.statusWarningBg
                    : DawaTokens.brandPrimaryPale,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Analysis source: ${_analysisProviderLabel(result.provider)}',
                style: DawaTextStyles.secondary.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('AI estimate — clinician must review'),
            ),
            if (result.modelId != null || result.examinationId != null) ...[
              const SizedBox(height: 8),
              Text(
                [
                  if (result.modelId != null) 'Model ${result.modelId}',
                  if (result.modelVersion != null)
                    'Version ${result.modelVersion}',
                  if (result.deviceId != null) 'Device ${result.deviceId}',
                  if (result.examinationId != null)
                    'Exam ${result.examinationId}',
                ].join(' • '),
                style: DawaTextStyles.secondary.copyWith(fontSize: 11),
              ),
            ],
            if (result.error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DawaTokens.statusWarningBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: DawaTokens.statusWarning),
                ),
                child: Text(
                  'Analysis unavailable. No AI interpretation was produced. '
                  'Review the image manually or retry.',
                  style: TextStyle(color: DawaTokens.statusWarningText),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ── Measurements ───────────────────────────────────────────────
            if (result.measurements != null) ...[
              const Text('AI-returned measurements',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: result.measurements!.entries
                    .map((e) => _buildMeasurementChip(e.key, e.value))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // ── GA estimate ────────────────────────────────────────────────
            if (result.estimatedGestationalAge != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: DawaTokens.brandPrimary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        color: DawaTokens.brandPrimary, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Model-reported gestational age: '
                      '${result.estimatedGestationalAge} weeks',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: DawaTokens.brandPrimary),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            if (result.segmentation != null)
              ..._buildSegmentationSection(result.segmentation!)
            else ...[
              // ── Findings list ──────────────────────────────────────────────
              const Text('Findings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...result.findings.map((f) => _buildFindingTile(f)),

              const SizedBox(height: 16),

              // ── Recommendation ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DawaTokens.statusInfoBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DawaTokens.statusInfo),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.description, color: DawaTokens.statusInfo),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Recommendation',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: DawaTokens.statusInfo)),
                          const SizedBox(height: 6),
                          Text(result.recommendation,
                              style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Save button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: result.error == null &&
                        _selectedPatient != null &&
                        !_isSavingResult
                    ? _saveResult
                    : null,
                icon: const Icon(Icons.save),
                label: Text(
                  _isSavingResult
                      ? 'Saving Scan Record…'
                      : result.error != null
                          ? 'Unavailable analysis cannot be saved'
                          : _selectedPatient == null
                              ? 'Select a patient before saving'
                              : 'Save Scan Record',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DawaTokens.brandPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Disclaimer ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DawaTokens.statusWarningBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: DawaTokens.statusWarning),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: DawaTokens.statusWarning, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result.segmentation != null
                          ? 'Research-stage segmentation using a placeholder prompt and an unvalidated model. It is not a diagnosis, fetal-growth assessment or risk classification. Confirm any measurement with a standard clinical ultrasound measurement.'
                          : 'AI-assisted tool only. Always confirm findings with clinical judgment and refer appropriately.',
                      style: TextStyle(
                          color: DawaTokens.statusWarningText, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _leaveResults() async {
    final error = await _completeActiveEdgeExamination();
    if (!mounted) return;
    setState(() {
      _appState = UltrasoundAppState.dashboard;
      _analysisResult = null;
    });
    if (error != null) {
      _showToast(
        'The edge session was not confirmed complete. Reconcile it before another edge examination.',
      );
    }
  }

  FindingLevel? _findingLevelForRecord(UltrasoundScanRecord record) {
    for (final level in FindingLevel.values) {
      if (level.name == record.result) return level;
    }
    return null;
  }

  Color _levelColor(FindingLevel? level) {
    return switch (level) {
      FindingLevel.normal => DawaTokens.statusSuccess,
      FindingLevel.monitor => DawaTokens.statusWarning,
      FindingLevel.urgent => DawaTokens.statusDanger,
      null => DawaTokens.textMuted,
    };
  }

  String _levelLabel(FindingLevel? level, {bool segmentation = false}) {
    if (segmentation) return 'Measurement';
    return switch (level) {
      FindingLevel.normal => 'No AI flag',
      FindingLevel.monitor => 'Review',
      FindingLevel.urgent => 'Urgent review',
      null => 'Unavailable',
    };
  }

  String _analysisProviderLabel(UltrasoundAnalysisProvider? provider) {
    return switch (provider) {
      UltrasoundAnalysisProvider.cloud => 'Cloud AI',
      UltrasoundAnalysisProvider.edgeDevice => 'Edge device AI',
      UltrasoundAnalysisProvider.unavailable => 'Unavailable',
      null => 'Unknown',
    };
  }

  bool _sameCalendarDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  Widget _buildFindingTile(UltrasoundFinding f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: f.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: f.color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(f.icon, color: f.color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.category,
                    style: TextStyle(
                        color: f.level == FindingLevel.normal
                            ? DawaTokens.statusSuccessText
                            : f.level == FindingLevel.monitor
                                ? DawaTokens.statusWarningText
                                : DawaTokens.statusDangerText,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
                Text(f.finding,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                if (f.note != null)
                  Text(f.note!,
                      style: const TextStyle(
                          color: DawaTokens.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSegmentationSection(UltrasoundSegmentation seg) {
    final overlay = seg.overlay;
    Uint8List? overlayBytes;
    if (overlay != null && overlay.contains(',')) {
      try {
        overlayBytes = base64Decode(overlay.split(',').last);
      } on FormatException {
        overlayBytes = null;
      }
    }
    final ellipse = seg.ellipse;
    return [
      if (overlayBytes != null) ...[
        const Text('Segmentation overlay',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(overlayBytes,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(
                  'Saved segmentation preview unavailable.',
                  style: DawaTextStyles.secondary)),
        ),
        const SizedBox(height: 16),
      ],
      const Text('Abdominal measurement',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      if (!seg.found)
        Text(
          'No abdominal segmentation was found. No measurement is available.',
          style: DawaTextStyles.secondary,
        )
      else ...[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildMeasurementChip('Circumference',
                '${seg.circumferencePx!.toStringAsFixed(1)} px'),
            _buildMeasurementChip(
                'Area', '${seg.areaPx!.toStringAsFixed(0)} px²'),
            if (seg.isCalibrated) ...[
              _buildMeasurementChip('Circumference (calibrated)',
                  '${seg.circumferenceMm!.toStringAsFixed(1)} mm'),
              _buildMeasurementChip('Area (calibrated)',
                  '${seg.areaMm2!.toStringAsFixed(0)} mm²'),
            ],
            if (ellipse != null)
              _buildMeasurementChip('Ellipse axes',
                  '${ellipse.axis1Px.toStringAsFixed(1)} × ${ellipse.axis2Px.toStringAsFixed(1)} px'),
            if (seg.iouScore != null)
              _buildMeasurementChip(
                  'Model IoU score', seg.iouScore!.toStringAsFixed(3)),
          ],
        ),
        if (!seg.isCalibrated) ...[
          const SizedBox(height: 10),
          Text(
            'Pixel spacing is not calibrated. Values are in image pixels and are not physical millimetres.',
            style: DawaTextStyles.secondary,
          ),
        ],
      ],
      if (seg.timingsMs['total'] != null || seg.recordId != null) ...[
        const SizedBox(height: 10),
        Text(
          [
            if (seg.timingsMs['total'] != null)
              'Device time ${seg.timingsMs['total']!.toStringAsFixed(0)} ms',
            if (seg.recordId != null) 'Device record ${seg.recordId}',
          ].join(' • '),
          style: DawaTextStyles.secondary.copyWith(fontSize: 11),
        ),
      ],
      const SizedBox(height: 16),
    ];
  }

  Widget _buildMeasurementChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: DawaTokens.brandPrimary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DawaTokens.brandPrimary.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: DawaTokens.brandPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
