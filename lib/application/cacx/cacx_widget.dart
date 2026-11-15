import '/services/clinical_offline_store.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/reset_password/reset_password_widget.dart';
import '/components/image_source_picker_dialog/image_source_picker_dialog_widget.dart';
import '/components/dawa_design_system.dart';
import '/components/clinical_screening_layout.dart';
import '/components/clinical_workspace_components.dart';
import '/components/clinical_page_intro.dart';
import '/components/clinical_tab_bar.dart';
import '/components/navigation_design_system.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/offline_connectivity_service.dart';
import '/components/edge_workflow_status.dart';
import '/services/screening_patient_repository.dart';
import '/backend/supabase/supabase_config.dart';
import '/services/edge_device/edge_device_models.dart';
import 'cacx_upload_service.dart';
import 'cacx_device_failure.dart';
import 'cacx_analysis_policy.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import '/services/edge_device/edge_device_manager.dart';
import '/services/edge_device/edge_device_exceptions.dart';
import 'cacx_model.dart';
import 'cacx_scan_drafts.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'cacx_second_opinion_service.dart';
export 'cacx_second_opinion_service.dart';

// ??? IMAGE SOURCE PICKER ??????????????????????????????????????????????????????
/// Shows a bottom sheet that lets the user choose between camera and gallery.
/// Returns a base64-encoded data URL string, or null if cancelled.
Future<String?> showImageSourcePicker(BuildContext context) async {
  return showDialog<String?>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => ImageSourcePickerDialogWidget(
      title: 'Select Image Source',
      subtitle: 'Choose how you want to provide the cervix image.',
      takePhotoLabel: 'Take Photo',
      takePhotoSubtitle: 'Use the device camera',
      uploadLabel: 'Upload Image',
      uploadSubtitle: 'Choose from gallery',
      onTakePhoto: () async {
        await _pickCacxImage(ctx, ImagePickerService.captureImage);
      },
      onUploadImage: () async {
        await _pickCacxImage(ctx, ImagePickerService.pickImage);
      },
    ),
  );
}

Future<void> _pickCacxImage(
  BuildContext context,
  Future<String?> Function() pick,
) async {
  try {
    final image = await pick();
    if (context.mounted) Navigator.pop(context, image);
  } catch (error, stackTrace) {
    debugPrint('[CaCx] Image selection failed: ${error.runtimeType}');
    debugPrintStack(stackTrace: stackTrace);
    if (context.mounted) {
      showDawaToast(context,
          'Could not load the image. Select a JPEG or PNG and try again.');
    }
  }
}

// ??? APP MODES ????????????????????????????????????????????????????????????????
enum ScreeningMode { via, training }

enum QuickAccessResultsFilter { all, completed, needsReview }

// ??? MAIN APP WIDGET ??????????????????????????????????????????????????????????
class CaCxApp extends StatefulWidget {
  const CaCxApp({
    super.key,
    this.initialPatient,
    this.autoStartScreening = false,
    this.returnToPreviousOnSave = false,
    this.deviceManager,
    this.patientRepository,
    this.demonstrationMode = false,
    this.pickImage,
    this.requestSecondOpinion,
    this.checkConnectivity,
    this.allowOnlineFallback = CacxAnalysisConfig.allowOnlineFallback,
  });

  final Future<String?> Function()? pickImage;
  final Future<AnalysisResult> Function(String image)? requestSecondOpinion;
  final Future<OfflineConnectivitySnapshot> Function()? checkConnectivity;
  final EdgeDeviceManager? deviceManager;
  final ScreeningPatientRepository? patientRepository;
  final bool demonstrationMode;
  final bool allowOnlineFallback;
  final Patient? initialPatient;
  final bool autoStartScreening;
  final bool returnToPreviousOnSave;

  @override
  _CaCxAppState createState() => _CaCxAppState();
}

class _CaCxAppState extends State<CaCxApp> {
  final _analysisAttempt = CacxAnalysisAttempt();
  bool? _onlineAvailable;
  bool _savingDraft = false;
  bool _resultQueued = false;
  String? _draftId;
  List<Map<String, dynamic>> _scanDrafts = [];
  late final EdgeDeviceManager _deviceManager;
  bool _loadingPatients = true;
  bool _patientsLoaded = false, _historyLoaded = false;
  String? _patientLoadError;
  AppState _appState = AppState.dashboard;
  DashboardTab _activeTab = DashboardTab.home;

  // Current mode determines how the results screen is framed.
  ScreeningMode _screeningMode = ScreeningMode.via;

  String _analyzingStatus = 'Ready for cervical device interpretation';
  String? _flowWarningMessage;
  String? _screeningRecordId;
  int? _deviceSecondsRemaining;
  Timer? _deviceCountdownTimer;
  bool _deviceUploadInProgress = false;
  bool _cloudFallbackRequested = false;
  CacxDeviceFailure? _lastDeviceFailure;
  bool _cloudFallbackInProgress = false;
  bool _onlineRequestInProgress = false;
  String? _currentScanImagePath;
  String? _currentScanPatientId;
  String? _currentScanUserId;

  // Data Lists
  List<Patient> _patients = [];
  List<VIATestRecord> _historyRecords = [];
  List<ScreeningData> _screeningData = [];

  // Selected Data
  String? _selectedImage;
  Patient? _selectedPatient;
  AnalysisResult? _analysisResult;
  CervicalDeviceInterpretation? _primaryDeviceResult;
  AnalysisResult? _secondOpinionResult;
  final _patientSearchController = TextEditingController();
  String get _patientSearchText => _patientSearchController.text;
  String _screeningPatientQuery = '';
  bool _patientNeedsReviewOnly = false;
  bool _showAllPredictionClasses = false;

  // UI States
  bool _isAnalyzing = false;
  bool _secondOpinionRequired = false;
  bool _secondOpinionPersisted = false;
  bool _savingOpinionResult = false;
  String _secondOpinionStatus = 'not_required';
  String _resultExplanationLanguage = 'English';
  QuickAccessResultsFilter _resultsFilter = QuickAccessResultsFilter.all;

  // Form Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _resultsSearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _deviceManager = widget.deviceManager ?? EdgeDeviceManager.shared;
    _loadScreeningData();
    unawaited(_reloadScanDrafts());
    OfflineConnectivityService.statusNotifier.addListener(_onConnectionChanged);
    if (widget.initialPatient != null) {
      _selectedPatient = widget.initialPatient;
      _patientSearchController.text = widget.initialPatient!.name;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.allowOnlineFallback) {
        unawaited(() async {
          try {
            final connection = await (widget.checkConnectivity?.call() ??
                OfflineConnectivityService.refreshStatus());
            if (mounted)
              setState(() => _onlineAvailable = connection.internetAvailable);
          } catch (_) {
            if (mounted) setState(() => _onlineAvailable = false);
          }
        }());
      }
      _trySyncPendingCacx();
      final manager = _deviceManager;
      if (kDebugMode) {
        debugPrint('[Device] CaCx configuration: '
            '${manager.client.config.diagnosticSummary()}');
      }
      unawaited(manager.prepareWorkflow(EdgeAIModel.cervicalCancer));
    });
    if (widget.autoStartScreening) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _openImageSourcePicker(mode: ScreeningMode.via);
      });
    }
  }

  @override
  void dispose() {
    OfflineConnectivityService.statusNotifier
        .removeListener(_onConnectionChanged);
    _deviceManager.cancelWorkflowPreparation(EdgeAIModel.cervicalCancer);
    _deviceCountdownTimer?.cancel();
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _resultsSearchController.dispose();
    _patientSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadScreeningData() async {
    if (widget.demonstrationMode) {
      setState(() {
        _patients = MockData.getPatients();
        _historyRecords = MockData.getHistoryRecords();
        _screeningData = MockData.getScreeningData();
        _loadingPatients = false;
        _patientsLoaded = true;
        _historyLoaded = true;
      });
      return;
    }
    if (mounted)
      setState(() {
        _loadingPatients = true;
        _patientsLoaded = false;
        _historyLoaded = false;
        _patientLoadError = null;
      });
    try {
      final patients = await (widget.patientRepository ??
              const SupabaseScreeningPatientRepository())
          .loadPatients();
      if (!mounted) return;
      setState(() {
        _patients = patients
            .map((p) => Patient(
                id: p.id,
                name: p.name,
                age: p.age ?? 0,
                contact: p.contact,
                status: PatientStatus.untested,
                riskLevel: RiskLevel.low))
            .toList();
        _loadingPatients = false;
        _patientsLoaded = true;
        final selectedId = _selectedPatient?.id;
        final matches = _patients.where((p) => p.id == selectedId);
        _selectedPatient = matches.isEmpty ? null : matches.first;
      });
      if (widget.patientRepository == null) await _loadSavedScreenings();
    } catch (_) {
      if (mounted)
        setState(() {
          _loadingPatients = false;
          _patientLoadError =
              'Patient records could not be loaded. For offline scans, connect once and open cervical screening to cache your patient list, then keep the local Dawa device connected. Retry when connected.';
        });
    }
  }

  Future<void> _loadSavedScreenings() async {
    final userId = currentUserUid;
    if (userId.isEmpty) return;
    try {
      final savedRows = await ClinicalOfflineStore.read(
          userId,
          'cervical-history',
          () => runSupabaseRequest(() => supabaseClient
              .from(CacxScreeningResultsRepository.table)
              .select()
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .limit(100)),
          emptyOffline: true);
      final pending = await CacxScreeningResultsRepository.pendingRows(userId);
      final rows = [
        ...pending,
        ...savedRows.where((row) => !pending.any((p) => p['id'] == row['id']))
      ];
      final byId = {for (final patient in _patients) patient.id: patient.name};
      final history = <VIATestRecord>[];
      for (final row in rows) {
        final date = DateTime.tryParse(row['created_at']?.toString() ?? '');
        final patientId = row['patient_id'];
        final id = row['id'];
        final onlineCompleted = row['second_opinion_status'] == 'completed' &&
            row['second_opinion_result'] is String;
        final label = onlineCompleted
            ? row['second_opinion_result']
            : row['primary_result'];
        final confidence = onlineCompleted
            ? row['second_opinion_confidence']
            : row['primary_confidence'];
        if (date == null ||
            patientId is! String ||
            id is! String ||
            label is! String ||
            !byId.containsKey(patientId)) continue;
        history.add(VIATestRecord(
            id: id,
            patientId: patientId,
            patientName: byId[patientId]!,
            date: date,
            result: label,
            notes: onlineCompleted
                ? (row['device_status'] == 'success'
                    ? 'Analysed online'
                    : 'Analysed online (device unavailable)')
                : row['device_status'] == 'success'
                    ? 'Analysed on Dawa device'
                    : 'Analysis did not complete',
            aiAnalysis:
                confidence is num ? 'Model confidence: $confidence%' : null));
      }
      if (mounted)
        setState(() {
          _historyRecords = history;
          _historyLoaded = true;
          _screeningData = [];
        });
    } catch (_) {
      // History availability must never block selection of cached patients.
      if (mounted) setState(() => _historyLoaded = false);
    }
  }

  bool get _scanOffline =>
      _onlineAvailable == false ||
      OfflineConnectivityService.statusNotifier.value?.isOffline == true;

  bool get _canTryLocal =>
      _deviceManager.activeExaminationId == null &&
      _deviceManager.state != EdgeDeviceState.busy;

  bool get _localCervicalReady =>
      _deviceManager.state == EdgeDeviceState.ready &&
      _deviceManager.hubConnected != false &&
      _deviceManager.observedReadyModel == EdgeAIModel.cervicalCancer &&
      _deviceManager.activeExaminationId == null;

  void _handleTabChange(DashboardTab tab) => setState(() => _activeTab = tab);

  void _handleLogout() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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
                        'Choose how you want to receive screening and follow-up updates.',
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

  void _openPatientFromRecord(VIATestRecord record) {
    Patient? patient;
    for (final item in _patients) {
      if (item.id == record.patientId) {
        patient = item;
        break;
      }
    }
    setState(() {
      _selectedPatient = patient;
      _patientSearchController.text = record.patientName;
      _activeTab = DashboardTab.patients;
    });
  }

  void _handleViaFollowUp(VIATestRecord record) {
    final needsReview = _recordNeedsReview(record);
    Patient? patient;
    for (final item in _patients) {
      if (item.id == record.patientId) {
        patient = item;
        break;
      }
    }

    setState(() {
      _selectedPatient = patient;
      _patientSearchController.text = record.patientName;
      _patientNeedsReviewOnly = needsReview;
      _activeTab = needsReview ? DashboardTab.patients : DashboardTab.history;
    });
  }

  void _setFlowStatus(String message, {String? warning}) {
    if (!mounted) return;
    setState(() {
      _analyzingStatus = message;
      _flowWarningMessage = warning;
    });
  }

  Future<void> _trySyncPendingCacx() async {
    final connectivity = await (widget.checkConnectivity?.call() ??
        OfflineConnectivityService.refreshStatus());
    if (!connectivity.supabaseReachable) {
      return;
    }
    await CacxScreeningResultsRepository.syncPending();
    await CacxScanDrafts.sync();
    await _reloadScanDrafts();
  }

  void _resetScreeningFlow() {
    _flowWarningMessage = null;
    _screeningRecordId = null;
    _resultQueued = false;
    _primaryDeviceResult = null;
    _secondOpinionResult = null;
    _secondOpinionPersisted = false;
    _secondOpinionRequired = false;
    _secondOpinionStatus = 'not_required';
    _analyzingStatus = 'Ready for cervical device interpretation';
    _deviceSecondsRemaining = null;
    _deviceCountdownTimer?.cancel();
    _deviceCountdownTimer = null;
    _deviceUploadInProgress = false;
    _cloudFallbackRequested = false;
    _lastDeviceFailure = null;
    _cloudFallbackInProgress = false;
    _currentScanImagePath = null;
    _currentScanPatientId = null;
    _currentScanUserId = null;
    _showAllPredictionClasses = false;
  }

  // ?? Unified image-picker entry point ????????????????????????????????????????
  Future<void> _openImageSourcePicker({
    required ScreeningMode mode,
    bool startAnalysisAfterSelection = true,
  }) async {
    if (_isAnalyzing || _deviceUploadInProgress || _cloudFallbackInProgress) {
      showDawaToast(
        context,
        'A CaCx scan is already in progress. Please wait for the result.',
      );
      return;
    }

    if (widget.demonstrationMode) {
      showDawaToast(context,
          'Training data cannot be used for a real screening. Open a patient record in the clinical workflow.');
      return;
    }
    final image =
        await (widget.pickImage?.call() ?? showImageSourcePicker(context));
    if (!mounted) return;
    if (image == null) {
      if (widget.autoStartScreening &&
          widget.returnToPreviousOnSave &&
          mounted &&
          _analysisResult == null) {
        Navigator.of(context).pop(false);
      }
      return;
    }

    setState(() {
      _selectedImage = image;
      _screeningMode = mode;
      _isAnalyzing = startAnalysisAfterSelection;
      _appState =
          startAnalysisAfterSelection ? AppState.dashboard : AppState.viaTest;
      _resetScreeningFlow();
    });

    if (startAnalysisAfterSelection) await _analyzeImage();
  }

  Future<void> _analyzeImage() => _analysisAttempt.run(() async {
        if (_selectedImage == null || widget.demonstrationMode) {
          if (mounted) setState(() => _isAnalyzing = false);
          return;
        }
        final patient = _selectedPatient;
        if (patient == null || !_patients.any((p) => p.id == patient.id)) {
          setState(() => _isAnalyzing = false);
          showDawaToast(
              context, 'Select an existing patient before starting analysis.');
          return;
        }
        if (_deviceManager.activeExaminationId != null ||
            _deviceManager.state == EdgeDeviceState.busy) {
          setState(() => _isAnalyzing = false);
          showDawaToast(context,
              'Finish or reconcile the current device examination before starting another scan.');
          return;
        }
        final image = _selectedImage!;
        _resetScreeningFlow();
        setState(() {
          _analysisResult = null;
          _isAnalyzing = true;
        });
        _currentScanPatientId = patient.id;
        _currentScanUserId = currentUserUid.isEmpty ? null : currentUserUid;
        _currentScanImagePath = CacxScreeningResultsRepository.buildImagePath(
            userId: _currentScanUserId, patientId: patient.id);
        try {
          // Await local preparation before considering any online provider.
          // Never start a competing provider while a local request is outstanding.
          if (!_localCervicalReady &&
              _deviceManager.activeExaminationId == null &&
              _deviceManager.state != EdgeDeviceState.busy) {
            _setFlowStatus('Connecting to the local Dawa device…');
            await _deviceManager.prepareWorkflow(EdgeAIModel.cervicalCancer);
            if (!mounted) return;
          }
          final preparationFailure = _deviceManager.preparationFailure;
          if (!_localCervicalReady && preparationFailure != null) {
            _lastDeviceFailure = classifyCacxDeviceFailure(preparationFailure);
          }
          final primary = _localCervicalReady
              ? await _sendImageToDeviceOnce(image, patient.id)
              : CervicalDeviceInterpretation.failure(
                  label: 'Device unavailable',
                  message: 'Local analysis is unavailable.',
                  rawResponse: const {'status': 'unavailable'},
                  deviceStatus: 'failed');
          if (!mounted) return;
          final fallback = cacxAllowsAutomaticFallback(
              enabled: widget.allowOnlineFallback &&
                  _onlineAvailable != false &&
                  OfflineConnectivityService
                          .statusNotifier.value?.internetAvailable !=
                      false,
              deviceStatus: primary.deviceStatus,
              failure: _lastDeviceFailure?.kind);
          _primaryDeviceResult = primary;
          _secondOpinionRequired = fallback;
          _secondOpinionStatus = fallback ? 'pending' : 'not_required';
          _setFlowStatus(fallback
              ? 'Device unavailable — analysing online'
              : 'Device result received');
          _screeningRecordId = await _savePrimaryResultForCurrentScan(
              primary: primary,
              secondOpinionRequired: fallback,
              secondOpinionStatus: _secondOpinionStatus);
          if (!mounted) return;
          if (primary.deviceStatus == 'success') {
            if (_draftId != null && _currentScanUserId != null) {
              await CacxScanDrafts.markAnalyzed(_currentScanUserId!, _draftId!);
              await _reloadScanDrafts();
              if (!mounted) return;
            }
            setState(() {
              _analysisResult = primary.toAnalysisResult(image);
              _appState = AppState.results;
            });
          } else if (fallback) {
            await _runCloudFallbackForCurrentScan(
                primary: primary,
                statusMessage: 'Device unavailable — analysing online',
                warning:
                    'The selected image is being sent to the online analysis service.');
            if (mounted && _analysisResult == null) {
              setState(() => _appState = AppState.viaTest);
            }
          } else {
            _setFlowStatus(
                primary.deviceStatus == 'rejected'
                    ? 'Image could not be analysed. Retake or replace the image.'
                    : 'Analysis failed — try again',
                warning:
                    'Your patient and image are retained. Review them before retrying.');
            setState(() => _appState = AppState.viaTest);
          }
        } catch (error, stack) {
          debugPrint('[CaCx] Analysis attempt failed: ${error.runtimeType}');
          debugPrintStack(stackTrace: stack);
          if (mounted) {
            _setFlowStatus('Analysis failed — try again',
                warning: 'Your patient and image are retained.');
            setState(() => _appState = AppState.viaTest);
          }
        } finally {
          if (mounted) setState(() => _isAnalyzing = false);
        }
      });

  Future<void> _analyzeImageOfflineOnly({
    required String image,
    required String? patientId,
    required String? userId,
    required String imagePath,
  }) async {
    _setFlowStatus('Offline mode: checking Arduino device...');

    final deviceReachable =
        await OfflineConnectivityService.isDeviceReachable();
    if (!deviceReachable) {
      _showOfflineDeviceUnavailable();
      return;
    }

    final primary = await _sendImageToDeviceOnce(
      image,
      patientId,
      allowCloudFallbackMessages: false,
      skipHealthCheck: true,
    );

    if (primary.deviceStatus != 'success') {
      if (_lastDeviceFailure?.isApplicationError == true) {
        _showApplicationFailure();
        return;
      }
      if (primary.deviceStatus == 'rejected') {
        if (!mounted) return;
        _setFlowStatus(
          'Image rejected — retake the photo',
          warning: primary.error ??
              'The image is not suitable for screening. Please retake the photo.',
        );
        setState(() {
          _primaryDeviceResult = primary;
          _isAnalyzing = false;
          _deviceSecondsRemaining = null;
          _appState = AppState.dashboard;
        });
        return;
      }
      _showOfflineDeviceUnavailable();
      return;
    }

    await CacxScreeningResultsRepository.enqueuePrimaryResult(
      patientId: patientId,
      userId: userId,
      imagePath: imagePath,
      primary: primary,
      secondOpinionRequired: false,
      secondOpinionStatus: 'not_required',
    );

    if (!mounted) return;
    _setFlowStatus(
      'Offline mode: device result saved locally',
      warning: 'Result queued for Supabase sync when internet returns.',
    );
    setState(() {
      _screeningRecordId = null;
      _primaryDeviceResult = primary;
      _secondOpinionRequired = false;
      _secondOpinionStatus = 'not_required';
      _analysisResult = primary.toAnalysisResult(image);
      _isAnalyzing = false;
      _appState = AppState.results;
    });
  }

  void _showOfflineDeviceUnavailable() {
    if (!mounted) return;
    _setFlowStatus(
      'Offline mode: Arduino device not connected',
      warning:
          'Offline mode: Arduino device not connected. Please connect the device or go online.',
    );
    setState(() {
      _deviceSecondsRemaining = null;
      _isAnalyzing = false;
      _secondOpinionStatus = 'failed';
      _appState = AppState.dashboard;
    });
  }

  void _showApplicationFailure() {
    if (!mounted) return;
    _setFlowStatus(
      'Examination failed in the application',
      warning: _lastDeviceFailure!.message,
    );
    setState(() {
      _isAnalyzing = false;
      _deviceSecondsRemaining = null;
      _secondOpinionStatus = 'not_required';
    });
  }

  Future<CervicalDeviceInterpretation> _sendImageToDeviceOnce(
    String image,
    String? patientId, {
    bool allowCloudFallbackMessages = true,
    bool skipHealthCheck = false,
  }) async {
    if (_deviceUploadInProgress) {
      return CervicalDeviceInterpretation.failure(
        label: 'Device Upload In Progress',
        message: 'A device upload is already in progress for this scan.',
        deviceStatus: 'failed',
        rawResponse: {
          'status': 'duplicate_blocked',
          'endpoint': CervicalDeviceConfig.imagePostUrl,
        },
      );
    }

    final deadline = DateTime.now().add(
      Duration(seconds: CervicalDeviceConfig.timeoutSeconds),
    );
    _deviceUploadInProgress = true;
    _setDeviceCountdown(deadline, 0);

    debugPrint('[Device] Connection attempt');
    _setFlowStatus('Connecting to Dawa Device...');
    _startDeviceCountdown(deadline);

    final manager = _deviceManager;
    void syncDeviceStatus() {
      if (!mounted || !_deviceUploadInProgress) return;
      final status = switch (manager.state) {
        EdgeDeviceState.connecting ||
        EdgeDeviceState.connected =>
          'Connecting to Dawa Device...',
        EdgeDeviceState.loadingModel => manager.readinessMessage ??
            'Preparing Cervical AI. Patient and image preparation remain available.',
        EdgeDeviceState.ready => 'Cervical AI ready',
        EdgeDeviceState.examining => 'Sending image for device processing...',
        EdgeDeviceState.busy => 'Device busy',
        _ => null,
      };
      if (status != null) _setFlowStatus(status);
    }

    if (manager.modelManagementEnabled) manager.addListener(syncDeviceStatus);

    var inferenceCompleted = false;
    try {
      if (!skipHealthCheck && !_deviceManager.modelManagementEnabled) {
        await CervicalDeviceService.checkHealth();
      }

      _setFlowStatus('Preparing cervical AI...');
      debugPrint('[Device] Preparing device request');
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw TimeoutException(
          'Device did not respond within ${CervicalDeviceConfig.timeoutSeconds} seconds',
        );
      }

      final result = await CervicalDeviceService.analyzeImage(
        image,
        patientId,
        timeout: remaining,
        deviceManager: manager,
      );

      inferenceCompleted = true;
      if (result.failed) {
        if (result.deviceStatus != 'rejected') {
          _lastDeviceFailure = const CacxDeviceFailure(
              CacxDeviceFailureKind.invalidResponse,
              'The image could not be analysed. Review the image and retry.');
        }
        debugPrint('[Device] Unrecoverable error: ${result.error}');
      } else {
        debugPrint('[Device] Success');
        _setFlowStatus('Device result received');
      }

      return result;
    } catch (error, stackTrace) {
      final failure = classifyCacxDeviceFailure(error, isWeb: kIsWeb);
      final timedOut = failure.kind == CacxDeviceFailureKind.timeout;
      if (failure.isApplicationError) {
        debugPrint('[CaCx] Application exception: ${error.runtimeType}');
        debugPrintStack(stackTrace: stackTrace);
      }
      debugPrint('[Device] Fallback reason: ${failure.kind.name} '
          '(${error.runtimeType})');
      _lastDeviceFailure = failure;
      _setFlowStatus('Device analysis could not complete.',
          warning: 'Your patient and image are retained.');
      return CervicalDeviceInterpretation.failure(
        label: 'Error',
        message: failure.message,
        deviceStatus: timedOut ? 'timeout' : 'failed',
        rawResponse: {
          'status': timedOut ? 'timeout' : 'failed',
          'failure_kind': failure.kind.name,
          'error': failure.message,
          'endpoint': CervicalDeviceConfig.imagePostUrl,
          if (timedOut) 'timeout_seconds': CervicalDeviceConfig.timeoutSeconds,
        },
      );
    } finally {
      if (manager.modelManagementEnabled) {
        manager.removeListener(syncDeviceStatus);
      }
      _deviceUploadInProgress = false;
      _stopDeviceCountdown();
      if (inferenceCompleted) {
        unawaited(
          manager.refreshObservedReadiness(EdgeAIModel.cervicalCancer),
        );
      }
    }
  }

  void _startDeviceCountdown(DateTime deadline) {
    _deviceCountdownTimer?.cancel();
    _deviceCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _setDeviceCountdown(deadline, 0);
    });
  }

  void _stopDeviceCountdown() {
    _deviceCountdownTimer?.cancel();
    _deviceCountdownTimer = null;
  }

  void _setDeviceCountdown(DateTime deadline, int retryCount) {
    if (!mounted) return;
    final remaining = deadline.difference(DateTime.now()).inSeconds;
    setState(() {
      _deviceSecondsRemaining = remaining
          .clamp(
            0,
            CervicalDeviceConfig.timeoutSeconds,
          )
          .toInt();
    });
  }

  Future<String?> _savePrimaryResultForCurrentScan({
    required CervicalDeviceInterpretation primary,
    required bool secondOpinionRequired,
    required String secondOpinionStatus,
  }) async {
    if (_scanOffline) {
      await CacxScreeningResultsRepository.enqueuePrimaryResult(
          patientId: _currentScanPatientId,
          userId: _currentScanUserId,
          imagePath: _currentScanImagePath!,
          primary: primary,
          secondOpinionRequired: false,
          secondOpinionStatus: 'not_required');
      _resultQueued = true;
      if (primary.deviceStatus == 'success') {
        _setFlowStatus('Device analysis complete · saved locally',
            warning: 'Result will sync automatically when you are online.');
      }
      return null;
    }
    final existingId = _screeningRecordId;
    if (existingId != null && existingId.isNotEmpty) {
      final saved = await CacxScreeningResultsRepository.updatePrimaryResult(
        recordId: existingId,
        primary: primary,
      );
      return saved ? existingId : null;
    }

    final recordId = await CacxScreeningResultsRepository.insertPrimaryResult(
      patientId: _currentScanPatientId,
      userId: _currentScanUserId,
      imagePath: _currentScanImagePath ??
          CacxScreeningResultsRepository.buildImagePath(
            userId: _currentScanUserId,
            patientId: _currentScanPatientId,
          ),
      primary: primary,
      secondOpinionRequired: secondOpinionRequired,
      secondOpinionStatus: secondOpinionStatus,
    );
    _resultQueued = recordId == null;
    if (recordId != null && mounted) {
      setState(() => _screeningRecordId = recordId);
    }
    return recordId;
  }

  CervicalDeviceInterpretation _pendingDeviceInterpretation() {
    return CervicalDeviceInterpretation(
      label: 'Awaiting device response',
      confidence: 0,
      rawResponse: {
        'status': 'pending',
        'endpoint': CervicalDeviceConfig.imagePostUrl,
        'fallback': 'online_scan_selected',
      },
      riskLevel: 'unknown',
      deviceStatus: 'pending',
      deviceEndpoint: CervicalDeviceConfig.imagePostUrl,
    );
  }

  Future<void> _runCloudFallbackForCurrentScan({
    required CervicalDeviceInterpretation primary,
    required String statusMessage,
    String? warning,
  }) async {
    if (_selectedImage == null || _cloudFallbackInProgress) return;

    final connectivity = await (widget.checkConnectivity?.call() ??
        OfflineConnectivityService.refreshStatus());
    if (mounted)
      setState(() => _onlineAvailable = connectivity.internetAvailable);
    if (!connectivity.internetAvailable) {
      _setFlowStatus(
        'Offline mode: online scan unavailable',
        warning:
            'Connect to the internet or reconnect the Dawa device, then retry Analyze image.',
      );
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _secondOpinionStatus = 'failed';
      });
      return;
    }

    _cloudFallbackRequested = true;
    _cloudFallbackInProgress = true;
    debugPrint('[Device] Routing to Gradio');
    _setFlowStatus(statusMessage, warning: warning);

    final image = _selectedImage!;
    try {
      final secondOpinion = await (widget.requestSecondOpinion?.call(image) ??
          HuggingFaceService.analyzeVIAImage(image));
      final secondOpinionFailed = secondOpinion.error != null ||
          secondOpinion.label.toLowerCase().contains('failed') ||
          secondOpinion.label.toLowerCase().contains('error');
      final finalSecondStatus = secondOpinionFailed ? 'failed' : 'completed';

      final opinionSaved =
          await CacxScreeningResultsRepository.updateSecondOpinion(
        recordId: _screeningRecordId,
        result: secondOpinion,
        status: finalSecondStatus,
      );

      if (!mounted) return;

      final finalResult = secondOpinionFailed
          ? AnalysisResult(
              imageUrl: image,
              label: primary.toAnalysisResult(image).label,
              confidence: primary.confidence,
              suspicionLevel:
                  CacxRiskMapper.suspicionForRisk(primary.riskLevel),
              recommendation:
                  'Primary device result requires second opinion, but the server second opinion failed. Please retry the server route or escalate for manual clinical review.',
              rawOutput: primary.rawResponse,
              error: secondOpinion.error ?? secondOpinion.label,
            )
          : secondOpinion;

      _setFlowStatus(
        secondOpinionFailed
            ? 'Second opinion failed - manual review required'
            : 'Second opinion completed',
        warning: secondOpinionFailed
            ? 'The server fallback did not complete. Please retry or escalate for clinical review.'
            : opinionSaved
                ? null
                : 'Online analysis completed, but the result could not be saved. Keep this page open.',
      );

      setState(() {
        _secondOpinionPersisted = opinionSaved;
        _deviceSecondsRemaining = null;
        _secondOpinionResult = secondOpinion;
        _secondOpinionStatus = finalSecondStatus;
        _analysisResult =
            secondOpinionFailed && primary.deviceStatus != 'success'
                ? null
                : finalResult;
        _isAnalyzing = false;
        _appState =
            _analysisResult == null ? AppState.dashboard : AppState.results;
      });
    } catch (_) {
      if (!mounted) return;
      _setFlowStatus('Online second opinion unavailable',
          warning:
              'The service did not complete the request. Your image is kept; retry when connected.');
      setState(() {
        _isAnalyzing = false;
        _secondOpinionStatus = 'failed';
        _appState =
            _analysisResult == null ? AppState.dashboard : AppState.results;
      });
    } finally {
      _cloudFallbackInProgress = false;
    }
  }

  Future<void> _runManualSecondOpinion() => _analyzeImage();

  Future<void> _saveAnalysisResult() async {
    if (_savingOpinionResult ||
        _isAnalyzing ||
        _onlineRequestInProgress ||
        _cloudFallbackInProgress) return;
    if (_secondOpinionRequired && !_secondOpinionPersisted) {
      final opinion = _secondOpinionResult;
      if (_screeningRecordId != null && opinion != null) {
        setState(() => _savingOpinionResult = true);
        final saved = await CacxScreeningResultsRepository.updateSecondOpinion(
            recordId: _screeningRecordId,
            result: opinion,
            status: _secondOpinionStatus);
        if (!mounted) return;
        setState(() {
          _secondOpinionPersisted = saved;
          _savingOpinionResult = false;
          if (saved) {
            _flowWarningMessage = null;
            _analyzingStatus = 'Second opinion saved';
          }
        });
      }
      if (!_secondOpinionPersisted) {
        showDawaToast(context,
            'The second opinion has not been saved. Keep this page open and check your connection.');
        return;
      }
    }
    if (widget.returnToPreviousOnSave) {
      Navigator.of(context).pop(true);
      return;
    }

    if (_analysisResult == null || _selectedPatient == null) return;

    final updatedPatients = _patients.map((patient) {
      if (patient.id == _selectedPatient!.id) {
        return Patient(
          id: patient.id,
          name: patient.name,
          age: patient.age,
          contact: patient.contact,
          lastTestDate: DateTime.now(),
          status: _analysisResult!.suspicionLevel == SuspicionLevel.low
              ? PatientStatus.normal
              : PatientStatus.suspicious,
          riskLevel: _analysisResult!.suspicionLevel == SuspicionLevel.high
              ? RiskLevel.high
              : _analysisResult!.suspicionLevel == SuspicionLevel.medium
                  ? RiskLevel.medium
                  : RiskLevel.low,
        );
      }
      return patient;
    }).toList();

    final newRecord = VIATestRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: _selectedPatient!.id,
      patientName: _selectedPatient!.name,
      date: DateTime.now(),
      result: _analysisResult!.suspicionLevel == SuspicionLevel.low
          ? 'Normal'
          : 'Suspicious',
      notes: 'AI Analysis: ${_analysisResult!.label}',
      aiAnalysis: 'Confidence: ${_analysisResult!.confidence}%',
      analysisJson: _analysisResult!.toJson(),
    );

    setState(() {
      _patients = updatedPatients;
      _historyRecords = [newRecord, ..._historyRecords];
      _appState = AppState.dashboard;
      _activeTab = DashboardTab.patients;
      _analysisResult = null;
      _selectedImage = null;
      _selectedPatient = null;
    });

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
          const SnackBar(content: Text('Record Saved Successfully!')));
  }

  Future<void> _shareAnalysisSummary() async {
    if (_analysisResult == null) return;

    final summary = StringBuffer()
      ..writeln('CaCx analysis summary')
      ..writeln('Diagnosis: ${_analysisResult!.label}')
      ..writeln(
          'Confidence: ${_analysisResult!.confidence.toStringAsFixed(1)}%')
      ..writeln('Risk: ${_analysisResult!.suspicionLevelString}')
      ..writeln('Recommendation: ${_analysisResult!.recommendation}');

    await Clipboard.setData(ClipboardData(text: summary.toString().trim()));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Analysis summary copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_appState) {
      case AppState.splash:
        return _buildSplashScreen();
      case AppState.results:
        return _buildResultsScreen();
      case AppState.viaTest:
        return _buildScreeningWorkspace();
      default:
        return _buildMainLayout();
    }
  }

  // ??? SPLASH SCREEN ????????????????????????????????????????????????????????
  Widget _buildSplashScreen() {
    return Scaffold(
      backgroundColor: DawaTokens.brandPrimary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              duration: const Duration(seconds: 2),
              tween: Tween<double>(begin: 0, end: 1),
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
              'Dawa CaCx',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Smart Cervical Screening',
              style: TextStyle(
                color: Colors.white70,
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

  // ??? MAIN LAYOUT ??????????????????????????????????????????????????????????
  Widget _buildMainLayout() {
    return Scaffold(
      backgroundColor: NavigationTokens.canvas,
      body: Column(
        children: [
          if (_loadingPatients) const LinearProgressIndicator(),
          if (widget.demonstrationMode)
            const Text('Training data — real screening is disabled.'),
          if (_patientLoadError != null &&
              (_activeTab != DashboardTab.home || _patientsLoaded))
            Padding(
                padding: const EdgeInsets.all(8),
                child: Row(children: [
                  Expanded(child: Text(_patientLoadError!)),
                  TextButton(
                      onPressed: _loadScreeningData,
                      child: const Text('Retry records')),
                ])),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: _buildCacxEdgeStatus(compact: true)),
          if (_shouldShowFlowStatus) _buildFlowStatusBanner(),
          ClinicalTabBar(
            tabs: const [
              ClinicalTab('Overview'),
              ClinicalTab('Patient Records'),
              ClinicalTab('Screening History')
            ],
            activeIndex: _activeTab == DashboardTab.home
                ? 0
                : _activeTab == DashboardTab.patients
                    ? 1
                    : 2,
            enabled: !_isAnalyzing,
            onSelected: (i) => _handleTabChange([
              DashboardTab.home,
              DashboardTab.patients,
              DashboardTab.history
            ][i]),
          ),
          Expanded(child: _buildCurrentTab()),
        ],
      ),
    );
  }

  bool get _shouldShowFlowStatus =>
      _isAnalyzing ||
      _primaryDeviceResult != null ||
      _flowWarningMessage != null ||
      _analyzingStatus != 'Ready for cervical device interpretation';

  Widget _buildFlowStatusBanner() {
    final warning = _flowWarningMessage != null;
    final statusColor =
        warning ? DawaTokens.statusWarning : DawaTokens.brandPrimary;
    final background =
        warning ? DawaTokens.statusWarningBg : DawaTokens.brandPrimaryPale;
    final statusIcon = warning
        ? Icons.warning_amber_rounded
        : _isAnalyzing
            ? Icons.sync_rounded
            : Icons.check_circle_outline;
    final remaining = _deviceSecondsRemaining;
    return Container(
      width: double.infinity,
      color: DawaTokens.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
              border: Border.all(
                color: warning ? DawaTokens.statusWarning : DawaTokens.border,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isAnalyzing)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: statusColor,
                    ),
                  )
                else
                  Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _analyzingStatus,
                        style: DawaTextStyles.secondary.copyWith(
                          color: warning
                              ? DawaTokens.statusWarningText
                              : DawaTokens.brandPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_flowWarningMessage != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          _flowWarningMessage!,
                          style: DawaTextStyles.secondary.copyWith(
                            color: DawaTokens.statusWarningText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (_isAnalyzing && remaining != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'The device is processing this screening. Readiness and results are confirmed by the device.',
                          style: DawaTextStyles.secondary.copyWith(
                            color: warning
                                ? DawaTokens.statusWarningText
                                : DawaTokens.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            minHeight: 5,
                            color: statusColor,
                            backgroundColor: Colors.white.withOpacity(0.65),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!_isAnalyzing &&
                    _selectedImage != null &&
                    _secondOpinionStatus == 'failed')
                  TextButton(
                    onPressed: _runManualSecondOpinion,
                    child: const Text('Retry analysis'),
                  ),
                if (!_isAnalyzing &&
                    _selectedImage != null &&
                    _lastDeviceFailure?.isApplicationError == true)
                  TextButton(
                    onPressed: () {
                      setState(() => _isAnalyzing = true);
                      _analyzeImage();
                    },
                    child: const Text('Retry device'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacxEdgeStatus({bool compact = false}) => AnimatedBuilder(
      animation: _deviceManager,
      builder: (context, _) {
        final manager = _deviceManager;
        if (compact) {
          final hub = manager.hubConnected == true
              ? 'Hub connected'
              : manager.hubConnected == false
                  ? 'Hub offline'
                  : 'Checking hub';
          final model = _localCervicalReady
              ? 'Cervical model ready'
              : manager.activeExaminationId != null
                  ? 'Device in use'
                  : 'Cervical model not ready';
          return SizedBox(
              width: double.infinity,
              child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(Icons.hub_outlined,
                        size: 16, color: NavigationTokens.secondary),
                    Text('$hub · $model',
                        style: DawaTextStyles.secondary.copyWith(fontSize: 12)),
                    if (widget.allowOnlineFallback) ...[
                      Text(
                          _onlineAvailable == false
                              ? 'Online unavailable'
                              : 'Automatic online fallback',
                          style:
                              DawaTextStyles.secondary.copyWith(fontSize: 12)),
                      const Tooltip(
                          message:
                              'If the device is unavailable, Analyze sends the screening image to the online analysis service. Patient identity is not sent.',
                          child: Icon(Icons.info_outline_rounded,
                              size: 16, color: NavigationTokens.secondary)),
                    ],
                  ]));
        }
        final unresolved = manager.activeModel == EdgeAIModel.cervicalCancer &&
            manager.activeExaminationId != null &&
            !_deviceUploadInProgress &&
            {
              EdgeDeviceState.error,
              EdgeDeviceState.busy,
              EdgeDeviceState.unsupported
            }.contains(manager.state);
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EdgeWorkflowStatus(
                  manager: manager,
                  model: EdgeAIModel.cervicalCancer,
                  examinationId: _deviceUploadInProgress
                      ? manager.activeExaminationId
                      : null,
                  isRelevant: _appState == AppState.viaTest ||
                      _selectedImage != null ||
                      _isAnalyzing ||
                      _deviceUploadInProgress),
              if (_selectedImage != null)
                FilledButton.icon(
                    onPressed: (_localCervicalReady ||
                                _canTryLocal ||
                                widget.allowOnlineFallback &&
                                    _onlineAvailable != false) &&
                            _selectedPatient != null &&
                            _deviceManager.activeExaminationId == null &&
                            _deviceManager.state != EdgeDeviceState.busy &&
                            !_isAnalyzing &&
                            !_analysisAttempt.running &&
                            !widget.demonstrationMode
                        ? () {
                            setState(() => _isAnalyzing = true);
                            unawaited(_analyzeImage());
                          }
                        : null,
                    icon: const Icon(Icons.biotech),
                    label: const Text('Analyze image')),
              if (widget.allowOnlineFallback)
                Text(
                    'Analyze tries the local Dawa device first. If it is unavailable and internet is available, the image is sent for online analysis. Patient identity is not sent.',
                    style: DawaTextStyles.secondary),
              if (!_localCervicalReady)
                Text(
                    widget.allowOnlineFallback && _onlineAvailable != false
                        ? 'The local Dawa device is checked first. Online analysis is used only if it is unavailable.'
                        : 'No internet. Analyze will connect to the local Dawa device; results will sync later.',
                    style: DawaTextStyles.secondary),
              if (_onlineAvailable == false && !_localCervicalReady)
                TextButton(
                    onPressed: () async {
                      final connection =
                          await (widget.checkConnectivity?.call() ??
                              OfflineConnectivityService.refreshStatus());
                      if (mounted)
                        setState(() =>
                            _onlineAvailable = connection.internetAvailable);
                    },
                    child: const Text('Retry connection')),
              if (unresolved)
                TextButton.icon(
                    onPressed: _reconcileCacxEdgeSession,
                    icon: const Icon(Icons.sync),
                    label: const Text('Check interrupted device session')),
            ]);
      });

  Future<void> _reconcileCacxEdgeSession() async {
    final manager = _deviceManager;
    if (manager.activeModel != EdgeAIModel.cervicalCancer) {
      if (mounted) {
        showDawaToast(
          context,
          'The active device session is not a cervical examination.',
        );
      }
      return;
    }
    try {
      final status = await manager.reconcileActiveExamination();
      if (status.state == EdgeDeviceModelState.ready) {
        final examinationId = manager.activeExaminationId;
        if (examinationId != null) {
          await manager.completeExamination(examinationId);
        }
      }
    } on EdgeDeviceException catch (error) {
      if (mounted) {
        showDawaToast(context, 'Device status is unresolved: ${error.message}');
      }
    }
  }

  Widget _buildCurrentTab() {
    switch (_activeTab) {
      case DashboardTab.home:
        return _buildHomeTab();
      case DashboardTab.patients:
        return _buildPatientsTab();
      case DashboardTab.history:
        return _buildHistoryTab();
      case DashboardTab.profile:
        return _buildProfileTab();
    }
  }

  void _beginNewScreening() {
    if (_isAnalyzing || _deviceUploadInProgress || _cloudFallbackInProgress) {
      showDawaToast(context, 'A cervical screening is already in progress.');
      return;
    }
    setState(() {
      _screeningMode = ScreeningMode.via;
      _draftId = null;
      _selectedImage = null;
      _analysisResult = null;
      _resetScreeningFlow();
      _appState = AppState.viaTest;
    });
  }

  Widget _buildScreeningWorkspace() {
    final patient = _selectedPatient;
    final imagePrepared = _selectedImage != null;
    return Scaffold(
      backgroundColor: NavigationTokens.canvas,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: _isAnalyzing
                                ? null
                                : () => setState(
                                    () => _appState = AppState.dashboard),
                            icon:
                                const Icon(Icons.arrow_back_rounded, size: 18),
                            label: const Text('Back to overview'),
                          ),
                          if (patient != null)
                            DawaStatusBadge(
                                status: 'pending',
                                label: 'Screening in progress'),
                        ]),
                    const SizedBox(height: 8),
                    Text(
                      'Confirm the patient, prepare an image, then request AI-assisted analysis.',
                      style: DawaTextStyles.secondary
                          .copyWith(color: DawaTokens.textSecondary),
                    ),
                    const SizedBox(height: 18),
                    if (_scanDrafts.isNotEmpty) _buildSavedScanDrafts(),
                    _buildScreeningSteps(
                        patient: patient, imagePrepared: imagePrepared),
                    const SizedBox(height: 20),
                    ClinicalScreeningLayout(
                      image: _buildWorkflowImageCard(),
                      analysis: Column(children: [
                        _buildWorkflowPatientCard(),
                        const SizedBox(height: 16),
                        _buildWorkflowAnalysisCard(),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    if (_flowWarningMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: DawaTokens.statusWarningBg,
                          borderRadius:
                              BorderRadius.circular(DawaTokens.radiusMd),
                          border: Border.all(
                              color: DawaTokens.statusWarning.withOpacity(.35)),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_analyzingStatus,
                                  style: DawaTextStyles.secondary.copyWith(
                                      color: DawaTokens.statusWarningText,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(
                                  'Analysis needs attention. Retry the device connection above, or replace the image and try again.',
                                  style: DawaTextStyles.secondary),
                            ]),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildScreeningSteps(
      {required Patient? patient, required bool imagePrepared}) {
    final steps = <(String, bool)>[
      ('Patient', patient != null),
      ('Image', imagePrepared),
      ('Analysis', _isAnalyzing || _analysisResult != null),
      ('Review', _analysisResult != null),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < steps.length; index++)
          Semantics(
            label:
                '${steps[index].$1}${steps[index].$2 ? ', complete' : ', pending'}',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: steps[index].$2
                    ? NavigationTokens.selected
                    : DawaTokens.surface,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                    color: steps[index].$2
                        ? NavigationTokens.brand
                        : DawaTokens.border),
              ),
              child: Text('${index + 1}. ${steps[index].$1}',
                  style: DawaTextStyles.secondary.copyWith(
                      color: steps[index].$2
                          ? NavigationTokens.brand
                          : DawaTokens.textSecondary,
                      fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }

  Widget _buildWorkflowPatientCard() {
    final locked =
        (_selectedImage != null && _selectedPatient != null) || _isAnalyzing;
    final query = _screeningPatientQuery.trim().toLowerCase();
    final matching = _patients
        .where((patient) =>
            query.isEmpty ||
            patient.name.toLowerCase().contains(query) ||
            patient.id.toLowerCase().contains(query))
        .take(6)
        .toList();
    final patient = _selectedPatient;
    return DawaCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('1. Select patient', style: DawaTextStyles.cardTitle),
        const SizedBox(height: 6),
        Text(
            'Choose an authorized patient before preparing the examination image.',
            style: DawaTextStyles.secondary),
        const SizedBox(height: 14),
        if (patient != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NavigationTokens.selected,
              borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
              border:
                  Border.all(color: NavigationTokens.brand.withOpacity(.22)),
            ),
            child: Row(children: [
              DawaAvatarCircle(
                  name: patient.name,
                  moduleColor: NavigationTokens.brand,
                  size: 36),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(patient.name, style: DawaTextStyles.cardTitle),
                    Text(
                        '${patient.age > 0 ? '${patient.age} years' : 'Age not recorded'} · Ref ${patient.id.length > 8 ? patient.id.substring(0, 8) : patient.id}',
                        style: DawaTextStyles.secondary),
                  ])),
              TextButton(
                onPressed: locked
                    ? null
                    : () => setState(() => _selectedPatient = null),
                child: const Text('Change'),
              ),
            ]),
          )
        else if (_loadingPatients)
          const LinearProgressIndicator()
        else if (_patientLoadError != null)
          Text(_patientLoadError!,
              style: DawaTextStyles.secondary
                  .copyWith(color: DawaTokens.statusDangerText))
        else ...[
          TextField(
            enabled: !locked,
            decoration: const InputDecoration(
              labelText: 'Search patient name or ID',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) =>
                setState(() => _screeningPatientQuery = value),
          ),
          const SizedBox(height: 8),
          if (matching.isEmpty)
            Text('No authorized patients match this search.',
                style: DawaTextStyles.secondary)
          else
            for (final candidate in matching)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: DawaAvatarCircle(
                    name: candidate.name,
                    moduleColor: NavigationTokens.brand,
                    size: 34),
                title: Text(candidate.name,
                    style: DawaTextStyles.secondary
                        .copyWith(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${candidate.age > 0 ? '${candidate.age} years' : 'Age not recorded'} · Ref ${candidate.id.length > 8 ? candidate.id.substring(0, 8) : candidate.id}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => setState(() => _selectedPatient = candidate),
              ),
        ],
        if (locked) ...[
          const SizedBox(height: 10),
          Text('Patient identity is locked while this image is prepared.',
              style: DawaTextStyles.secondary
                  .copyWith(color: DawaTokens.textSecondary)),
        ],
      ]),
    );
  }

  Widget _buildWorkflowImageCard() {
    final image = _selectedImage;
    return DawaCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('2. Prepare cervical image', style: DawaTextStyles.cardTitle),
        const SizedBox(height: 6),
        Text(
            'Use a clear image. Uploading an image does not submit it for analysis.',
            style: DawaTextStyles.secondary),
        const SizedBox(height: 14),
        if (image != null)
          Container(
            height: 250,
            width: double.infinity,
            decoration: BoxDecoration(
              color: DawaTokens.surfaceSecondary,
              borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
              border: Border.all(color: DawaTokens.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.memory(base64Decode(image.split(',').last),
                  fit: BoxFit.contain),
            ),
          )
        else
          Container(
            height: 170,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DawaTokens.surfaceSecondary,
              borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
              border: Border.all(color: DawaTokens.border),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.add_a_photo_outlined,
                  size: 32, color: DawaTokens.textMuted),
              const SizedBox(height: 8),
              Text('No image selected', style: DawaTextStyles.secondary),
            ]),
          ),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          OutlinedButton.icon(
            onPressed: _isAnalyzing
                ? null
                : () => _pickWorkflowImage(ImagePickerService.captureImage),
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: Text(image == null ? 'Take photo' : 'Retake photo'),
          ),
          OutlinedButton.icon(
            onPressed: _isAnalyzing
                ? null
                : () => _pickWorkflowImage(ImagePickerService.pickImage),
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: Text(image == null ? 'Choose image' : 'Replace image'),
          ),
        ]),
      ]),
    );
  }

  void _onConnectionChanged() {
    final connection = OfflineConnectivityService.statusNotifier.value;
    if (connection == null) return;
    if (mounted)
      setState(() => _onlineAvailable = connection.internetAvailable);
    if (connection.supabaseReachable) {
      unawaited(CacxScanDrafts.sync().then((_) => _reloadScanDrafts()));
    }
  }

  Future<void> _reloadScanDrafts() async {
    final uid = currentUserUid;
    final drafts = await CacxScanDrafts.forUser(uid);
    if (mounted && currentUserUid == uid) setState(() => _scanDrafts = drafts);
  }

  Future<void> _saveScanForLater() async {
    final patient = _selectedPatient;
    final image = _selectedImage;
    if (patient == null || image == null || _savingDraft) return;
    setState(() => _savingDraft = true);
    try {
      _draftId = await CacxScanDrafts.save(
          uid: currentUserUid,
          patientId: patient.id,
          patientName: patient.name,
          image: image,
          id: _draftId);
      await _reloadScanDrafts();
      if (!mounted) return;
      showDawaToast(context,
          'Scan saved on this device. It will upload when online; analysis is still pending.');
      if (OfflineConnectivityService.statusNotifier.value?.supabaseReachable ==
          true) {
        unawaited(CacxScanDrafts.sync().then((_) => _reloadScanDrafts()));
      }
    } catch (_) {
      if (mounted)
        showDawaToast(context,
            'Could not save the scan. Keep this page open and try again.');
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  Widget _buildSavedScanDrafts() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final draft in _scanDrafts)
            ListTile(
              title: Text('Saved scan: ${draft['patient_name']}'),
              subtitle: Text(draft['synced'] == true
                  ? 'Uploaded · awaiting analysis'
                  : 'Saved locally · upload pending'),
              trailing: TextButton(
                  onPressed: _isAnalyzing
                      ? null
                      : () {
                          final matches = _patients
                              .where((p) => p.id == draft['patient_id']);
                          if (matches.isEmpty) {
                            showDawaToast(context,
                                'Load the authorized patient list before resuming this scan.');
                            return;
                          }
                          setState(() {
                            _resetScreeningFlow();
                            _draftId = draft['id'] as String;
                            _selectedPatient = matches.first;
                            _selectedImage = draft['image_data_uri'] as String;
                            _analysisResult = null;
                            _appState = AppState.viaTest;
                          });
                        },
                  child: const Text('Resume')),
            )
        ],
      );

  Widget _buildWorkflowAnalysisCard() {
    final hasPatient = _selectedPatient != null;
    final hasImage = _selectedImage != null;
    final ready = _localCervicalReady;
    final blocker = !hasPatient
        ? 'Select a patient before continuing.'
        : !hasImage
            ? 'Choose or capture an image before continuing.'
            : _isAnalyzing
                ? 'The edge device is processing this image.'
                : ready
                    ? 'Cervical AI is ready for local analysis.'
                    : _cervicalReadinessMessage();
    return DawaCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('3. AI-assisted analysis', style: DawaTextStyles.cardTitle),
        const SizedBox(height: 6),
        Text(
            'The image is sent to the local Dawa device only when analysis begins.',
            style: DawaTextStyles.secondary),
        const SizedBox(height: 12),
        Text(blocker,
            style: DawaTextStyles.secondary.copyWith(
                color: ready
                    ? DawaTokens.statusSuccessText
                    : DawaTokens.textSecondary)),
        const SizedBox(height: 12),
        _buildCacxEdgeStatus(),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: hasPatient &&
                  hasImage &&
                  !_isAnalyzing &&
                  !_savingDraft &&
                  !widget.demonstrationMode
              ? _saveScanForLater
              : null,
          icon: const Icon(Icons.save_outlined),
          label: Text(_savingDraft ? 'Saving scan…' : 'Save scan for later'),
        ),
        Text(
            'Save the patient and image on this device, then upload automatically when online. Analysis remains pending until a device or online service is available.',
            style: DawaTextStyles.secondary),
      ]),
    );
  }

  String _cervicalReadinessMessage() => switch (_deviceManager.state) {
        EdgeDeviceState.loadingModel => 'Cervical AI is still preparing.',
        EdgeDeviceState.disconnected =>
          'Local analysis is unavailable. Reconnect the device to continue.',
        EdgeDeviceState.error =>
          'Local analysis is unavailable. Retry the device connection to continue.',
        EdgeDeviceState.busy =>
          'Another examination is using the device. Wait before starting analysis.',
        _ => 'Preparing the local cervical screening device.',
      };

  Future<void> _pickWorkflowImage(Future<String?> Function() picker) async {
    if (_isAnalyzing || _deviceUploadInProgress || _cloudFallbackInProgress) {
      return;
    }
    try {
      final image = await (widget.pickImage?.call() ?? picker());
      if (!mounted || image == null) return;
      setState(() {
        _selectedImage = image;
        _screeningMode = ScreeningMode.via;
        _resetScreeningFlow();
      });
    } catch (_) {
      if (mounted) {
        showDawaToast(context,
            'Could not load the image. Select a JPEG or PNG and try again.');
      }
    }
  }

  // ??? HOME TAB ?????????????????????????????????????????????????????????????
  Widget _buildHomeTab() {
    return LayoutBuilder(builder: (context, size) {
      final padding = size.maxWidth < 600 ? 16.0 : 24.0;
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(padding, 8, padding, 32),
        child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: DawaTokens.workspaceMaxWidth),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClinicalPageHeader(
                      subtitle: 'Find a patient to start a cervical screening.',
                      action: FilledButton.icon(
                        onPressed: _beginNewScreening,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('New Screening'),
                        style: FilledButton.styleFrom(
                            backgroundColor: NavigationTokens.brand,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 42)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildOverviewMetrics(),
                    const SizedBox(height: 20),
                    LayoutBuilder(builder: (context, content) {
                      final patients = _buildOverviewPatients();
                      final recent = _buildOverviewRecentScreenings();
                      if (content.maxWidth < 900 || largeText) {
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              patients,
                              const SizedBox(height: 20),
                              recent
                            ]);
                      }
                      return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: patients),
                            const SizedBox(width: 20),
                            Expanded(flex: 5, child: recent),
                          ]);
                    }),
                    if (_screeningData.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildScreeningActivityCard(),
                    ],
                  ]),
            )),
      );
    });
  }

  Widget _buildOverviewMetrics() => LayoutBuilder(builder: (context, size) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
        final stack = size.maxWidth < 340 || largeText;
        final compact = size.maxWidth < 600 && !stack;
        final metrics = [
          (
            'Available patients',
            _patientsLoaded ? '${_patients.length}' : '—',
            _patientsLoaded
                ? 'Loaded patient records'
                : 'Awaiting patient records',
            Icons.people_outline,
            DashboardTab.patients
          ),
          (
            'Loaded screenings',
            _historyLoaded ? '${_historyRecords.length}' : '—',
            'Saved results available here',
            Icons.assignment_outlined,
            DashboardTab.history
          ),
          (
            'Needs review',
            _historyLoaded
                ? '${_historyRecords.where(_recordNeedsReview).length}'
                : '—',
            _historyLoaded
                ? 'Of ${_historyRecords.length} loaded screenings'
                : 'Awaiting saved results',
            Icons.fact_check_outlined,
            DashboardTab.history
          ),
        ];
        final cards = <Widget>[
          for (final metric in metrics)
            SizedBox(
              width: stack ? size.maxWidth : (size.maxWidth - 24) / 3,
              child: DawaCard(
                  padding: EdgeInsets.all(compact ? 12 : 16),
                  onTap: () => setState(() {
                        _activeTab = metric.$5;
                        if (metric.$1 == 'Needs review')
                          _resultsFilter = QuickAccessResultsFilter.needsReview;
                      }),
                  child: Row(children: [
                    if (!compact) ...[
                      Icon(metric.$4, size: 20, color: NavigationTokens.brand),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(metric.$2,
                              style: DawaTextStyles.statNumber
                                  .copyWith(fontSize: 24)),
                          const SizedBox(height: 6),
                          Text(metric.$1,
                              style: DawaTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: compact ? 12 : 14)),
                          const SizedBox(height: 4),
                          Text(metric.$3,
                              style: DawaTextStyles.secondary
                                  .copyWith(fontSize: compact ? 11 : 12)),
                        ])),
                  ])),
            ),
        ];
        if (stack) return Wrap(runSpacing: 12, children: cards);
        return IntrinsicHeight(
            child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              if (index > 0) const SizedBox(width: 12),
              cards[index],
            ],
          ],
        ));
      });

  Widget _buildOverviewPatients() {
    final query = _patientSearchController.text.trim().toLowerCase();
    final matches = _patients
        .where((patient) =>
            query.isEmpty ||
            patient.name.toLowerCase().contains(query) ||
            patient.id.toLowerCase().contains(query) ||
            patient.contact.toLowerCase().contains(query))
        .toList();
    return DawaCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_scanDrafts.isNotEmpty) _buildSavedScanDrafts(),
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Patients', style: DawaTextStyles.cardTitle),
            TextButton(
                onPressed: () =>
                    setState(() => _activeTab = DashboardTab.patients),
                child: Text(_patientsLoaded
                    ? 'View all (${_patients.length})'
                    : 'View patient records')),
          ]),
      const SizedBox(height: 8),
      TextField(
        key: const ValueKey('cacx-overview-patient-search'),
        controller: _patientSearchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
            labelText: 'Find a patient',
            hintText: 'Name, reference or phone',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear patient search',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () =>
                        setState(() => _patientSearchController.clear())),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DawaTokens.radiusMd))),
      ),
      const SizedBox(height: 12),
      if (_loadingPatients)
        const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()))
      else if (!_patientsLoaded)
        ClinicalEmptyState(
            surface: false,
            icon: Icons.cloud_off_outlined,
            title: 'Patient records unavailable',
            message: 'Check your connection and sign-in, then try again.',
            actionLabel: 'Retry records',
            onAction: _loadScreeningData)
      else if (_patients.isEmpty)
        ClinicalEmptyState(
            surface: false,
            icon: Icons.person_add_outlined,
            title: 'No patients available',
            message: 'Register a patient in Patients to start screening.',
            actionLabel: 'Open Patients',
            onAction: () => context.goNamed('Moms'))
      else if (matches.isEmpty)
        ClinicalEmptyState(
            surface: false,
            icon: Icons.search_off_rounded,
            title: 'No matching patients',
            message: 'Try another name, reference or phone number.',
            actionLabel: 'Clear search',
            onAction: () => setState(() => _patientSearchController.clear()))
      else ...[
        for (var index = 0; index < matches.take(5).length; index++) ...[
          if (index > 0) const Divider(height: 1, color: DawaTokens.border),
          _buildOverviewPatientRow(matches[index]),
        ],
        if (matches.length > 5) ...[
          const Divider(height: 1, color: DawaTokens.border),
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Showing 5 of ${matches.length} matching patients',
                  style: DawaTextStyles.secondary.copyWith(fontSize: 12))),
        ],
      ],
    ]));
  }

  Widget _buildOverviewPatientRow(Patient patient) {
    final ref = patient.id.length > 18
        ? '${patient.id.substring(0, 8)}…${patient.id.substring(patient.id.length - 4)}'
        : patient.id;
    final identity =
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      DawaAvatarCircle(name: patient.name, size: 34),
      const SizedBox(width: 10),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(patient.name,
            style: DawaTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
            'Ref $ref · ${patient.age > 0 ? '${patient.age} years' : 'Age unavailable'}',
            style: DawaTextStyles.secondary.copyWith(fontSize: 12)),
      ])),
    ]);
    final action = Semantics(
        label: 'Start screening for ${patient.name}',
        button: true,
        child: TextButton.icon(
            onPressed: () {
              setState(() => _selectedPatient = patient);
              _beginNewScreening();
            },
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Screen')));
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: LayoutBuilder(builder: (context, size) {
          if (size.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(14) > 21) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  Align(alignment: Alignment.centerRight, child: action)
                ]);
          }
          return Row(children: [
            Expanded(child: identity),
            const SizedBox(width: 12),
            action
          ]);
        }));
  }

  Widget _buildOverviewRecentScreenings() {
    final records = [..._historyRecords]
      ..sort((a, b) => b.date.compareTo(a.date));
    return DawaCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Recent screenings', style: DawaTextStyles.cardTitle),
            TextButton(
                onPressed: () =>
                    setState(() => _activeTab = DashboardTab.history),
                child: const Text('View history')),
          ]),
      if (!_historyLoaded)
        ClinicalEmptyState(
            surface: false,
            icon: Icons.history_rounded,
            title: _loadingPatients
                ? 'Loading screening history'
                : 'Screening history unavailable',
            message:
                'Saved results will appear here when records are available.',
            actionLabel: 'Refresh records',
            onAction: _loadScreeningData)
      else if (records.isEmpty)
        ClinicalEmptyState(
            surface: false,
            icon: Icons.assignment_outlined,
            title: 'No saved screenings yet',
            message: 'Choose a patient to record the first cervical screening.',
            actionLabel: 'New screening',
            onAction: _beginNewScreening)
      else
        for (var index = 0; index < records.take(3).length; index++) ...[
          if (index > 0) const Divider(height: 1, color: DawaTokens.border),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(records[index].patientName,
                        style: DawaTextStyles.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(_formatDate(records[index].date),
                        style: DawaTextStyles.secondary.copyWith(fontSize: 12)),
                    const SizedBox(height: 8),
                    Text(records[index].result, style: DawaTextStyles.body),
                    const SizedBox(height: 10),
                    Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          DawaStatusBadge(
                              status: _recordNeedsReview(records[index])
                                  ? 'needs_review'
                                  : 'completed'),
                          TextButton(
                              onPressed: () {
                                setState(() {
                                  _activeTab = DashboardTab.history;
                                  _resultsFilter = QuickAccessResultsFilter.all;
                                  _resultsSearchController.text =
                                      records[index].id;
                                });
                              },
                              child: const Text('View result')),
                        ]),
                  ])),
        ],
    ]));
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

  Widget _buildScreeningActivityCard() {
    final totalNormal =
        _screeningData.fold<int>(0, (sum, data) => sum + data.normal);
    final totalLow =
        _screeningData.fold<int>(0, (sum, data) => sum + data.lowGrade);
    final totalHigh =
        _screeningData.fold<int>(0, (sum, data) => sum + data.highGrade);
    final totalScreenings = totalNormal + totalLow + totalHigh;

    return DawaCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Screening Activity',
                    style: DawaTextStyles.cardTitle.copyWith(fontSize: 16),
                  ),
                  Text(
                    'VIA screening outcomes - last 6 months',
                    style: DawaTextStyles.secondary.copyWith(fontSize: 12),
                  ),
                ],
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _activeTab = DashboardTab.history),
                child: const Text('View all results'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _ChartSummaryPill(
                label: 'Normal',
                value: totalNormal,
                color: DawaTokens.statusSuccess,
              ),
              _ChartSummaryPill(
                label: 'Low grade',
                value: totalLow,
                color: DawaTokens.statusWarning,
              ),
              _ChartSummaryPill(
                label: 'High grade',
                value: totalHigh,
                color: DawaTokens.statusDanger,
              ),
              _ChartSummaryPill(
                label: 'Total',
                value: totalScreenings,
                color: DawaTokens.brandPrimary,
                showDot: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (totalScreenings == 0)
            ClinicalEmptyState(
              icon: Icons.assignment_outlined,
              title: 'No screening activity yet',
              message:
                  'Start a cervical screening to record the first result for this period.',
              actionLabel: 'New screening',
              onAction: _beginNewScreening,
              surface: false,
            )
          else
            SizedBox(
              height: 220,
              child: _ScreeningStackedBarChart(
                data: _screeningData,
              ),
            ),
        ],
      ),
    );
  }

  // ??? PATIENTS TAB ?????????????????????????????????????????????????????????
  Widget _buildPatientsTab() {
    final filteredPatients = _patients.where((patient) {
      final normalized = _patientSearchText.trim().toLowerCase();
      final matchesSearch = normalized.isEmpty ||
          patient.name.toLowerCase().contains(normalized) ||
          patient.id.toLowerCase().contains(normalized) ||
          patient.contact.toLowerCase().contains(normalized);
      final matchesReview = !_patientNeedsReviewOnly ||
          patient.status == PatientStatus.suspicious ||
          patient.riskLevel == RiskLevel.high;
      return matchesSearch && matchesReview;
    }).toList();

    return CustomScrollView(
      key: const PageStorageKey('cacx-patients'),
      slivers: [
        SliverToBoxAdapter(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Patient Registry', style: DawaTextStyles.pageTitle),
            const SizedBox(height: 4),
            Text('Manage and track your patient records.',
                style: DawaTextStyles.secondary),
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: _beginNewScreening,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('Add Screening')),
          ]),
        )),
        SliverToBoxAdapter(
            child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
                controller: _patientSearchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                    labelText: 'Search patients',
                    hintText: 'Name, ID or phone',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white)),
            const SizedBox(height: 8),
            FilterChip(
                selected: _patientNeedsReviewOnly,
                onSelected: (selected) =>
                    setState(() => _patientNeedsReviewOnly = selected),
                label: const Text('Needs review'),
                selectedColor: NavigationTokens.selected,
                checkmarkColor: NavigationTokens.brand),
          ]),
        )),
        if (filteredPatients.isEmpty)
          SliverFillRemaining(
              hasScrollBody: false, child: _buildNoPatientMatches())
        else
          SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.builder(
                  itemCount: filteredPatients.length,
                  itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildPatientRow(filteredPatients[index])))),
      ],
    );
  }

  Widget _buildPatientRow(Patient patient) => DawaCard(
        padding: const EdgeInsets.all(14),
        urgent: patient.status == PatientStatus.suspicious,
        onTap: () async {
          setState(() => _selectedPatient = patient);
          _beginNewScreening();
        },
        child: LayoutBuilder(builder: (context, constraints) {
          final inline = constraints.maxWidth >= 680 &&
              MediaQuery.textScalerOf(context).scale(14) <= 21;
          final age =
              patient.age > 0 ? '${patient.age} yrs' : 'Age unavailable';
          final lastScreened = patient.lastTestDate == null
              ? 'Not yet'
              : _formatDate(patient.lastTestDate!);
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            DawaAvatarCircle(
                name: patient.name, moduleColor: DawaTokens.brandPrimary),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(patient.name, style: DawaTextStyles.cardTitle),
                  const SizedBox(height: 4),
                  if (inline)
                    Text(
                        '${patient.id} · $age${patient.contact.isEmpty ? '' : ' · ${patient.contact}'} · Last screened: $lastScreened',
                        style: DawaTextStyles.secondary)
                  else ...[
                    Text('${patient.id} · $age',
                        style: DawaTextStyles.secondary),
                    if (patient.contact.isNotEmpty)
                      Text(patient.contact, style: DawaTextStyles.secondary),
                    Text('Last screened: $lastScreened',
                        style: DawaTextStyles.secondary),
                    const SizedBox(height: 8),
                    _patientStatusBadge(patient),
                  ],
                ])),
            if (inline) ...[
              const SizedBox(width: 12),
              _patientStatusBadge(patient)
            ],
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: DawaTokens.textMuted),
          ]);
        }),
      );

  Widget _buildNoPatientMatches() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 42,
              color: DawaTokens.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'No patients found',
              style: DawaTextStyles.cardTitle.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              'Clear the search or turn off the review filter.',
              textAlign: TextAlign.center,
              style: DawaTextStyles.secondary,
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: () => setState(() {
                _patientSearchController.text = '';
                _patientNeedsReviewOnly = false;
              }),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _patientStatusBadge(Patient patient) {
    final status = switch (patient.status) {
      PatientStatus.normal => 'normal',
      PatientStatus.suspicious => 'suspicious',
      PatientStatus.pending => 'pending',
      PatientStatus.untested => 'pending',
    };
    return DawaStatusBadge(
      status: status,
      label: patient.status == PatientStatus.untested
          ? 'Pending'
          : patient.statusString,
    );
  }

  // ??? HISTORY TAB ??????????????????????????????????????????????????????????
  Widget _buildHistoryTab() {
    final filteredRecords = _filteredHistoryRecords();
    final completedCount =
        _historyRecords.where((record) => !_recordNeedsReview(record)).length;
    final needsReviewCount = _historyRecords.where(_recordNeedsReview).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 640;
        return CustomScrollView(
          key: const PageStorageKey('cacx-history'),
          slivers: [
            SliverToBoxAdapter(
                child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Screening Results',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Search, filter, and review VIA results with AI confidence notes.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildResultMetricCard(
                        'All Results',
                        _historyRecords.length.toString(),
                        Icons.assignment_outlined,
                        DawaTokens.brandPrimary,
                        isNarrow,
                      ),
                      _buildResultMetricCard(
                        'Completed',
                        completedCount.toString(),
                        Icons.check_circle_outline,
                        DawaTokens.statusSuccess,
                        isNarrow,
                      ),
                      _buildResultMetricCard(
                        'Needs Review',
                        needsReviewCount.toString(),
                        Icons.priority_high,
                        DawaTokens.statusWarning,
                        isNarrow,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    key: const ValueKey('cacx-results-search-field'),
                    controller: _resultsSearchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText:
                          'Search patient name, patient ID, record ID, result, notes, or AI confidence',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _resultsSearchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _resultsSearchController.clear();
                                setState(() {});
                              },
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        'All results',
                        QuickAccessResultsFilter.all,
                      ),
                      _buildFilterChip(
                        'Completed',
                        QuickAccessResultsFilter.completed,
                      ),
                      _buildFilterChip(
                        'Needs review',
                        QuickAccessResultsFilter.needsReview,
                      ),
                    ],
                  ),
                ],
              ),
            )),
            if (filteredRecords.isEmpty)
              SliverFillRemaining(
                  hasScrollBody: false, child: _buildResultsEmptyState())
            else
              SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  sliver: SliverList.builder(
                      itemCount: filteredRecords.length,
                      itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildHistoryResultCard(
                              filteredRecords[index])))),
          ],
        );
      },
    );
  }

  List<VIATestRecord> _filteredHistoryRecords() {
    final query = _resultsSearchController.text.trim().toLowerCase();
    return _historyRecords.where((record) {
      if (_resultsFilter == QuickAccessResultsFilter.completed &&
          _recordNeedsReview(record)) {
        return false;
      }
      if (_resultsFilter == QuickAccessResultsFilter.needsReview &&
          !_recordNeedsReview(record)) {
        return false;
      }
      if (query.isEmpty) return true;

      final haystack = [
        record.patientName,
        record.patientId,
        record.id,
        record.result,
        record.notes,
        record.aiAnalysis ?? '',
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  bool _recordNeedsReview(VIATestRecord record) {
    final text = '${record.result} ${record.notes} ${record.aiAnalysis ?? ''}'
        .toLowerCase();
    return text.contains('suspicious') ||
        text.contains('requires') ||
        text.contains('follow-up') ||
        text.contains('review') ||
        text.contains('cin') ||
        text.contains('positive');
  }

  Widget _buildFilterChip(String label, QuickAccessResultsFilter filter) {
    return ChoiceChip(
      label: Text(label),
      selected: _resultsFilter == filter,
      onSelected: (_) => setState(() => _resultsFilter = filter),
      selectedColor: DawaTokens.brandPrimaryPale,
      labelStyle: TextStyle(
        color: _resultsFilter == filter ? DawaTokens.brandPrimary : Colors.grey,
        fontWeight:
            _resultsFilter == filter ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildResultMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isNarrow,
  ) {
    return DawaStatCard(
      width: isNarrow ? double.infinity : 180,
      label: label,
      value: value,
      icon: icon,
      color: color,
      accentBorder: true,
    );
  }

  Widget _buildHistoryResultCard(VIATestRecord record) {
    final needsReview = _recordNeedsReview(record);
    final statusLabel = needsReview ? 'Needs review' : 'Completed';

    return DawaCard(
      urgent: needsReview,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DawaAvatarCircle(
                name: record.patientName,
                moduleColor: DawaTokens.brandPrimary,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.patientName, style: DawaTextStyles.cardTitle),
                  Text(
                    'Patient ${record.patientId} - Record ${record.id}',
                    style: DawaTextStyles.secondary.copyWith(
                      color: DawaTokens.textMuted,
                    ),
                  ),
                ],
              ),
              DawaStatusBadge(
                status: needsReview ? 'needs_review' : 'completed',
                label: statusLabel,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Date: ${_formatDate(record.date)}',
            style: DawaTextStyles.secondary,
          ),
          const SizedBox(height: 8),
          Text(
            'Result: ${record.result}',
            style: DawaTextStyles.secondary.copyWith(
              color: DawaTokens.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text('Notes: ${record.notes}', style: DawaTextStyles.secondary),
          if ((record.aiAnalysis ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            DawaAIConfidenceBar(analysis: record.aiAnalysis!),
          ],
          const SizedBox(height: 10),
          _buildPredictionBreakdownCard(
            resultSourceLabel: 'Saved result',
            isTraining: false,
            breakdown: record.analysisResult?.predictionBreakdown,
            compact: true,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openPatientFromRecord(record),
                icon: const Icon(Icons.person_outline),
                label: const Text('Open patient'),
              ),
              ElevatedButton.icon(
                onPressed: () => _handleViaFollowUp(record),
                icon: Icon(
                  needsReview
                      ? Icons.event_available
                      : Icons.check_circle_outline,
                ),
                label:
                    Text(needsReview ? 'Plan follow-up' : 'Routine follow-up'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: needsReview
                      ? DawaTokens.statusWarning
                      : DawaTokens.brandPrimary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsEmptyState() {
    final hasSearch = _resultsSearchController.text.trim().isNotEmpty ||
        _resultsFilter != QuickAccessResultsFilter.all;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch ? Icons.search_off : Icons.assignment_outlined,
              size: 56,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch ? 'No matching results' : 'No results yet',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Try a different patient name, ID, record ID, result, note, or AI confidence.'
                  : 'Completed screening records will appear here when they are available.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            if (hasSearch) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  _resultsSearchController.clear();
                  setState(() => _resultsFilter = QuickAccessResultsFilter.all);
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear filters/search'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // ??? PROFILE TAB ??????????????????????????????????????????????????????????
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
          const Text('Manage your account settings and preferences.',
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
                                  fontSize: 24, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Certified Midwife - Dawa Clinic',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 16)),
                          SizedBox(height: 8),
                          Chip(
                            label: Text('Verified Account',
                                style:
                                    TextStyle(color: DawaTokens.brandPrimary)),
                            backgroundColor: DawaTokens.brandPrimaryPale,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount:
                      MediaQuery.of(context).size.width > 600 ? 2 : 1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 3,
                  children: [
                    _buildProfileDetail('Full Name', 'Memory Musonda'),
                    _buildProfileDetail('License Number', 'MW-1234-5678'),
                    _buildProfileDetail(
                        'Email Address', 'memory.musonda@dawahealth.zm'),
                    _buildProfileDetail('Phone Number', '+260 97 123 4567'),
                    _buildProfileDetail(
                        'Clinic / Facility', 'Dawa Clinic, Lusaka'),
                    _buildProfileDetail('Role', 'Senior Midwife'),
                  ],
                ),
                const SizedBox(height: 32),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Account Settings',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock),
                      title: const Text('Change Password'),
                      onTap: () =>
                          context.pushNamed(ResetPasswordWidget.routeName),
                    ),
                    ListTile(
                      leading: const Icon(Icons.notifications),
                      title: const Text('Notification Preferences'),
                      onTap: _showNotificationPreferencesSheet,
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.logout,
                        color: DawaTokens.statusDanger,
                      ),
                      title: const Text('Sign Out',
                          style: TextStyle(color: DawaTokens.statusDanger)),
                      onTap: _handleLogout,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetail(String label, String value) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildScreeningFlowSummary() {
    final primary = _primaryDeviceResult!;
    final secondResult = _secondOpinionResult;
    final secondStatusLabel = switch (_secondOpinionStatus) {
      'not_required' => 'Not required',
      'pending' => 'Pending',
      'completed' => 'Completed',
      'failed' => 'Failed',
      _ => 'Unknown',
    };
    final secondStatusColor = switch (_secondOpinionStatus) {
      'not_required' => DawaTokens.statusSuccessText,
      'completed' => DawaTokens.statusSuccessText,
      'pending' => DawaTokens.statusWarningText,
      'failed' => DawaTokens.statusDangerText,
      _ => DawaTokens.textSecondary,
    };

    return DawaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.route_outlined,
                color: DawaTokens.brandPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CaCx Upload Flow',
                  style: DawaTextStyles.cardTitle,
                ),
              ),
              if (_screeningRecordId != null)
                DawaStatusBadge(status: 'completed', label: 'Result saved'),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 640;
              final itemWidth =
                  stacked ? double.infinity : (constraints.maxWidth - 10) / 2;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _flowSummaryItem(
                      icon: Icons.memory_outlined,
                      title: 'Primary device',
                      value:
                          '${primary.label} (${primary.confidence.toStringAsFixed(1)}%)',
                      detail: 'Risk level: ${primary.riskLevel}',
                      color: DawaTokens.brandPrimary,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _flowSummaryItem(
                      icon: Icons.fact_check_outlined,
                      title: 'Second opinion',
                      value: secondStatusLabel,
                      detail: secondResult == null
                          ? (_secondOpinionRequired
                              ? 'Online scan route'
                              : 'Device completed local screening; clinician review required')
                          : '${secondResult.label} (${secondResult.confidence.toStringAsFixed(1)}%)',
                      color: secondStatusColor,
                    ),
                  ),
                ],
              );
            },
          ),
          if (_flowWarningMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _flowWarningMessage!,
              style: DawaTextStyles.secondary.copyWith(
                color: DawaTokens.statusWarningText,
                fontSize: 12,
              ),
            ),
          ],
          if (_secondOpinionStatus == 'failed' && _selectedImage != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isAnalyzing ? null : _runManualSecondOpinion,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry analysis'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _flowSummaryItem({
    required IconData icon,
    required String title,
    required String value,
    required String detail,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: DawaTokens.surfaceSecondary,
        borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
        border: Border.all(color: DawaTokens.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DawaTextStyles.label.copyWith(
                    color: DawaTokens.textMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DawaTextStyles.secondary.copyWith(
                    color: DawaTokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DawaTextStyles.secondary.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ??? RESULTS SCREEN ???????????????????????????????????????????????????????
  Widget _buildResultsScreen() {
    if (_analysisResult == null) {
      return const Center(child: Text('No analysis results'));
    }

    final isTraining = _screeningMode == ScreeningMode.training;
    final resultSourceLabel = !isTraining &&
            _secondOpinionRequired &&
            _secondOpinionStatus == 'completed'
        ? 'Analysed online (device unavailable)'
        : 'Analysed on Dawa device';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.returnToPreviousOnSave) {
              Navigator.of(context).pop(true);
              return;
            }
            setState(() {
              _appState = AppState.dashboard;
              _analysisResult = null;
            });
          },
        ),
        title: Text(isTraining ? 'Training Feedback' : 'Analysis Results'),
        actions: [
          if (!isTraining && !widget.returnToPreviousOnSave) ...[
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share screening summary',
              onPressed: _shareAnalysisSummary,
            ),
            IconButton(
                tooltip: _savingOpinionResult
                    ? 'Saving screening'
                    : 'Save screening',
                icon: const Icon(Icons.save),
                onPressed: _savingOpinionResult ||
                        _isAnalyzing ||
                        _onlineRequestInProgress ||
                        _cloudFallbackInProgress
                    ? null
                    : _saveAnalysisResult),
          ],
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isWide = width >= 900;
          final pagePadding = width < 560
              ? const EdgeInsets.all(16)
              : const EdgeInsets.symmetric(horizontal: 28, vertical: 24);

          return SingleChildScrollView(
            padding: pagePadding,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isTraining) ...[
                      _buildTrainingBanner(),
                      const SizedBox(height: 16),
                    ],
                    if (!isTraining && _primaryDeviceResult != null) ...[
                      _buildScreeningFlowSummary(),
                      const SizedBox(height: 18),
                    ],
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 11,
                            child: Column(
                              children: [
                                _buildResultImageCard(isWide: true),
                                const SizedBox(height: 16),
                                _buildImageMetadataCard(resultSourceLabel),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            flex: 13,
                            child: Column(
                              children: [
                                _buildResultSummaryCard(
                                  resultSourceLabel: resultSourceLabel,
                                  isTraining: isTraining,
                                ),
                                const SizedBox(height: 16),
                                _buildRecommendationCard(
                                    isTraining: isTraining),
                                const SizedBox(height: 16),
                                _buildPredictionBreakdownCard(
                                  resultSourceLabel: resultSourceLabel,
                                  isTraining: isTraining,
                                ),
                                const SizedBox(height: 16),
                                _buildClassificationCard(
                                  resultSourceLabel: resultSourceLabel,
                                  isTraining: isTraining,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildResultImageCard(isWide: false),
                      const SizedBox(height: 16),
                      _buildImageMetadataCard(resultSourceLabel),
                      const SizedBox(height: 16),
                      _buildResultSummaryCard(
                        resultSourceLabel: resultSourceLabel,
                        isTraining: isTraining,
                      ),
                      const SizedBox(height: 16),
                      _buildRecommendationCard(isTraining: isTraining),
                      const SizedBox(height: 16),
                      _buildPredictionBreakdownCard(
                        resultSourceLabel: resultSourceLabel,
                        isTraining: isTraining,
                      ),
                      const SizedBox(height: 16),
                      _buildClassificationCard(
                        resultSourceLabel: resultSourceLabel,
                        isTraining: isTraining,
                      ),
                    ],
                    const SizedBox(height: 18),
                    _buildReturnedModelDetails(),
                    const SizedBox(height: 18),
                    _buildResultDisclaimer(isTraining),
                    if (!isTraining && widget.returnToPreviousOnSave) ...[
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(true),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Back to Patient Details'),
                        ),
                      ),
                    ],
                    if (isTraining) ...[
                      const SizedBox(height: 18),
                      _buildTryAnotherTrainingImageButton(),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTrainingBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DawaTokens.statusSuccessBg,
        borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
        border: Border.all(color: DawaTokens.statusSuccess.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.school, color: DawaTokens.statusSuccessText),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Training Mode - results are for educational purposes only and will not be saved to patient records.',
              style: DawaTextStyles.secondary.copyWith(
                color: DawaTokens.statusSuccessText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnedModelDetails() {
    final primary = _primaryDeviceResult;
    final online = _secondOpinionResult;
    Widget provider(String title, String label, double? confidence,
        Map<String, dynamic>? raw, String status) {
      final fields = <String, String>{
        'Classification': label,
        'Status': status,
        if (confidence != null)
          'Model confidence': '${confidence.toStringAsFixed(1)}%',
        if (raw?['gatekeeper_flagged'] is bool)
          'Image suitability check':
              raw!['gatekeeper_flagged'] == true ? 'Rejected' : 'Passed',
      };
      const names = {
        'record_id': 'Model record reference',
        'model_id': 'Model',
        'model': 'Model',
        'model_version': 'Model version',
        'device_id': 'Device reference',
        'message': 'Model message',
        'image_quality': 'Image quality',
        'findings': 'Returned findings',
        'timings_ms': 'Model timings (ms)'
      };
      for (final entry in names.entries) {
        final value = raw?[entry.key];
        if (value != null && value.toString().trim().isNotEmpty) {
          fields[entry.value] = value is Map || value is List
              ? jsonEncode(value)
              : value.toString();
        }
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: DawaTextStyles.cardTitle),
        const SizedBox(height: 10),
        for (final field in fields.entries)
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(field.key, style: DawaTextStyles.secondary),
                    SelectableText(field.value,
                        style: DawaTextStyles.secondary
                            .copyWith(fontWeight: FontWeight.w600)),
                  ])),
        if (raw == null || !names.keys.any((key) => raw[key] != null))
          Text('No additional model metadata was returned.',
              style: DawaTextStyles.secondary),
      ]);
    }

    return DawaCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Screening details', style: DawaTextStyles.cardTitle),
      const SizedBox(height: 8),
      if (_selectedPatient != null)
        SelectableText(
            'Patient: ${_selectedPatient!.name} · Reference: ${_selectedPatient!.id}',
            style: DawaTextStyles.secondary),
      Text(
          _screeningRecordId != null
              ? 'Database reference: $_screeningRecordId'
              : _resultQueued
                  ? 'Saved on this device; database sync pending.'
                  : 'Database save not confirmed.',
          style: DawaTextStyles.secondary),
      const Divider(height: 28),
      if (primary != null)
        provider(
            'Local Dawa device output',
            primary.label,
            primary.deviceStatus == 'success' ? primary.confidence : null,
            primary.rawResponse,
            primary.deviceStatus),
      if (online != null) ...[
        const Divider(height: 28),
        provider('Online model output', online.label, online.confidence,
            online.rawOutput, _secondOpinionStatus),
      ],
      if (primary == null && online == null)
        provider(
            'Model output',
            _analysisResult!.label,
            _analysisResult!.confidence,
            _analysisResult!.rawOutput,
            'completed'),
      const SizedBox(height: 8),
      Text(
          'Confidence describes the model output for this image. It is not a confirmed diagnosis or a measured probability that the patient has cancer.',
          style: DawaTextStyles.secondary),
    ]));
  }

  Widget _buildResultImageCard({required bool isWide}) {
    final image = _selectedImage;
    return DawaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.image_outlined,
                color: DawaTokens.brandPrimary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text('Uploaded Image', style: DawaTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: isWide ? 390 : 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: DawaTokens.surfaceSecondary,
              borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
              border: Border.all(color: DawaTokens.border),
            ),
            child: image == null
                ? const Center(
                    child: Icon(
                      Icons.image_outlined,
                      color: DawaTokens.textMuted,
                      size: 52,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
                      child: Image.memory(
                        base64Decode(image.split(',').last),
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageMetadataCard(String sourceLabel) {
    return DawaCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: _compactMetric(
              'Source',
              sourceLabel,
              Icons.hub_outlined,
              DawaTokens.brandPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _compactMetric(
              'Mode',
              _screeningMode == ScreeningMode.training
                  ? 'Training'
                  : 'Clinical',
              Icons.assignment_outlined,
              DawaTokens.brandAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSummaryCard({
    required String resultSourceLabel,
    required bool isTraining,
  }) {
    final tone = _riskTone();
    return DawaCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: tone.background,
                  borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
                ),
                child: Icon(
                  _riskIcon(),
                  color: tone.foreground,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTraining ? 'Training Result' : 'AI screening result',
                      style: DawaTextStyles.label.copyWith(
                        color: DawaTokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _analysisResult!.label,
                      style: DawaTextStyles.pageTitle.copyWith(
                        color: DawaTokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pillBadge(
                _analysisResult!.suspicionLevelString,
                tone.background,
                tone.foreground,
                Icons.health_and_safety_outlined,
              ),
              _pillBadge(
                resultSourceLabel,
                DawaTokens.brandPrimaryPale,
                DawaTokens.brandPrimary,
                Icons.memory_outlined,
              ),
              if (!isTraining)
                _pillBadge(
                  'Risk: ${_analysisResult!.suspicionLevelString}',
                  tone.background,
                  tone.foreground,
                  Icons.health_and_safety_outlined,
                ),
              _pillBadge(
                _screeningRecordId != null &&
                        (!_secondOpinionRequired || _secondOpinionPersisted)
                    ? 'Saved'
                    : _resultQueued
                        ? 'Saved locally · sync pending'
                        : 'Not saved',
                _resultQueued
                    ? DawaTokens.statusWarningBg
                    : DawaTokens.statusSuccessBg,
                _resultQueued
                    ? DawaTokens.statusWarningText
                    : DawaTokens.statusSuccessText,
                _resultQueued
                    ? Icons.cloud_upload_outlined
                    : Icons.check_circle_outline,
              ),
              if (!_secondOpinionRequired)
                _pillBadge(
                  'Second opinion not required',
                  DawaTokens.surfaceTertiary,
                  DawaTokens.textSecondary,
                  Icons.fact_check_outlined,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _compactMetric(
            'Confidence',
            '${_analysisResult!.confidence.toStringAsFixed(1)}%',
            Icons.bar_chart_rounded,
            _confidenceColor(),
          ),
          const SizedBox(height: 12),
          Text('AI estimate — clinician must review',
              style: DawaTextStyles.secondary
                  .copyWith(color: DawaTokens.textSecondary)),
          Text(
              _analysisResult!.rawOutput?['timings_ms'] != null
                  ? 'Model timings (ms): ${jsonEncode(_analysisResult!.rawOutput!['timings_ms'])}'
                  : 'Analysis time not supplied by model',
              style: DawaTextStyles.secondary
                  .copyWith(color: DawaTokens.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildPredictionBreakdownCard({
    required String resultSourceLabel,
    required bool isTraining,
    List<PredictionBreakdownItem>? breakdown,
    bool compact = false,
  }) {
    final items = _compactPredictionBreakdownItems(
      breakdown ?? _analysisResult?.predictionBreakdown ?? const [],
    );
    final helperText = isTraining
        ? 'Training breakdown shows how the model distributed confidence across the available classes.'
        : 'Confidence scores should be interpreted together with clinical judgment and local screening protocols.';
    final isWideDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final showAll =
        isWideDesktop || _showAllPredictionClasses || items.length <= 3;
    final visibleItems = showAll ? items : items.take(3).toList();
    final hiddenCount = items.length - visibleItems.length;
    final toggleLabel =
        showAll ? 'Show top 3' : 'Show all ${items.length.clamp(3, 6)}';

    return DawaCard(
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('$resultSourceLabel Confidence',
                  style: DawaTextStyles.cardTitle),
              DawaStatusBadge(
                  status: 'completed',
                  label: items.isEmpty
                      ? 'Top score ${_analysisResult!.confidence.toStringAsFixed(1)}%'
                      : '${items.length} classes'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            helperText,
            style: DawaTextStyles.secondary.copyWith(
              color: DawaTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DawaTokens.surfaceSecondary,
                borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
                border: Border.all(color: DawaTokens.border),
              ),
              child: Text(
                'Detailed class breakdown was not returned by the model.',
                style: DawaTextStyles.secondary.copyWith(
                  color: DawaTokens.textSecondary,
                ),
              ),
            )
          else ...[
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              child: Column(
                children: [
                  for (final item in visibleItems) ...[
                    _buildCompactPredictionBreakdownItem(item),
                    const SizedBox(height: 8),
                  ],
                  if (!showAll && hiddenCount > 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: DawaTokens.surfaceSecondary,
                        borderRadius:
                            BorderRadius.circular(DawaTokens.radiusMd),
                        border: Border.all(color: DawaTokens.border),
                      ),
                      child: Text(
                        '$hiddenCount more classes are hidden until you expand the list.',
                        style: DawaTextStyles.secondary.copyWith(
                          color: DawaTokens.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (items.length > 3 && !isWideDesktop)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAllPredictionClasses = !showAll;
                    });
                  },
                  icon: Icon(
                    showAll
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                  label: Text(toggleLabel),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactPredictionBreakdownItem(PredictionBreakdownItem item) {
    final percent = item.confidence.clamp(0, 100).toDouble();
    final riskLevel = (item.riskLevel ?? 'review').toLowerCase();
    final color = _predictionBreakdownColor(item);
    final showRiskBadge = percent >= 5 && riskLevel != 'low';
    final rowBackground = item.isTopPrediction && riskLevel == 'low'
        ? DawaTokens.statusSuccessBg
        : percent <= 0
            ? DawaTokens.surfaceSecondary
            : color.withOpacity(item.isTopPrediction ? 0.08 : 0.05);
    final borderColor = item.isTopPrediction && riskLevel == 'low'
        ? DawaTokens.statusSuccess.withOpacity(0.35)
        : percent <= 0
            ? DawaTokens.border
            : color.withOpacity(0.18);
    final barColor = percent <= 0 ? DawaTokens.borderStrong : color;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: rowBackground,
        borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.label,
                    style: DawaTextStyles.body.copyWith(
                        color: DawaTokens.textPrimary,
                        fontWeight: FontWeight.w700)),
                if (item.isTopPrediction || showRiskBadge) ...[
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (item.isTopPrediction)
                      _predictionMiniBadge('Top match',
                          DawaTokens.brandPrimaryPale, DawaTokens.brandPrimary),
                    if (showRiskBadge)
                      _predictionMiniBadge(
                          _predictionRiskLabel(riskLevel),
                          _predictionBadgeBackground(riskLevel),
                          _predictionBadgeForeground(riskLevel)),
                  ]),
                ],
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    value: percent / 100,
                    backgroundColor: DawaTokens.surfaceTertiary,
                    color: barColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${percent.toStringAsFixed(1)}%',
            style: DawaTextStyles.cardTitle.copyWith(
              color: percent <= 0 ? DawaTokens.textMuted : color,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }

  List<PredictionBreakdownItem> _compactPredictionBreakdownItems(
    List<PredictionBreakdownItem> rawItems,
  ) {
    final merged = <String, PredictionBreakdownItem>{};

    for (final rawItem in rawItems) {
      final canonicalLabel = canonicalCacxDisplayLabel(rawItem.label);
      final key = canonicalCacxBaseLabel(canonicalLabel);
      final existing = merged[key];
      if (existing == null) {
        merged[key] = PredictionBreakdownItem(
          label: canonicalLabel,
          confidence: rawItem.confidence.clamp(0, 100).toDouble(),
          riskLevel: rawItem.riskLevel,
          isTopPrediction: rawItem.isTopPrediction,
        );
        continue;
      }

      merged[key] = PredictionBreakdownItem(
        label: canonicalLabel,
        confidence: existing.confidence >= rawItem.confidence
            ? existing.confidence
            : rawItem.confidence.clamp(0, 100).toDouble(),
        riskLevel: _preferredRiskLevel(existing.riskLevel, rawItem.riskLevel),
        isTopPrediction: existing.isTopPrediction || rawItem.isTopPrediction,
      );
    }

    final items = merged.values.toList()
      ..sort((a, b) {
        final confidenceCompare = b.confidence.compareTo(a.confidence);
        if (confidenceCompare != 0) return confidenceCompare;
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });

    if (items.isNotEmpty) {
      final topIndex = items.indexWhere((item) => item.isTopPrediction);
      final resolvedTopIndex = topIndex >= 0 ? topIndex : 0;
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        items[i] = PredictionBreakdownItem(
          label: item.label,
          confidence: item.confidence,
          riskLevel: item.riskLevel,
          isTopPrediction: i == resolvedTopIndex,
        );
      }
    }

    return items;
  }

  String? _preferredRiskLevel(String? current, String? next) {
    final currentValue = current?.trim();
    final nextValue = next?.trim();
    if (nextValue == null || nextValue.isEmpty) return currentValue;
    if (currentValue == null || currentValue.isEmpty) return nextValue;
    if (currentValue == nextValue) return currentValue;

    const priority = {'high': 3, 'medium': 2, 'low': 1, 'review': 0};
    final currentPriority = priority[currentValue.toLowerCase()] ?? 0;
    final nextPriority = priority[nextValue.toLowerCase()] ?? 0;
    return nextPriority >= currentPriority ? nextValue : currentValue;
  }

  Widget _predictionMiniBadge(
    String label,
    Color background,
    Color foreground,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withOpacity(0.16)),
      ),
      child: Text(
        label,
        style: DawaTextStyles.label.copyWith(
          color: foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _predictionBreakdownColor(PredictionBreakdownItem item) {
    final risk = (item.riskLevel ?? '').toLowerCase();
    if (item.confidence <= 0) return DawaTokens.textMuted;
    if (risk == 'low') return DawaTokens.statusSuccess;
    if (risk == 'medium') return DawaTokens.statusWarning;
    if (risk == 'high') return DawaTokens.statusDanger;
    return const Color(0xFF64748B);
  }

  String _predictionRiskLabel(String? riskLevel) {
    switch ((riskLevel ?? 'review').toLowerCase()) {
      case 'low':
        return 'Low Risk';
      case 'medium':
        return 'Moderate';
      case 'high':
        return 'High Risk';
      case 'review':
      default:
        return 'Review';
    }
  }

  Color _predictionBadgeBackground(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return DawaTokens.statusSuccessBg;
      case 'medium':
        return DawaTokens.statusWarningBg;
      case 'high':
        return DawaTokens.statusDangerBg;
      default:
        return DawaTokens.surfaceTertiary;
    }
  }

  Color _predictionBadgeForeground(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return DawaTokens.statusSuccessText;
      case 'medium':
        return DawaTokens.statusWarningText;
      case 'high':
        return DawaTokens.statusDangerText;
      default:
        return DawaTokens.textSecondary;
    }
  }

  String _statusForRiskLevel(String riskLabel) {
    switch (riskLabel.toLowerCase()) {
      case 'low':
        return 'completed';
      case 'medium':
        return 'pending';
      case 'high':
        return 'needs_review';
      default:
        return 'info';
    }
  }

  Widget _buildClassificationCard({
    required String resultSourceLabel,
    required bool isTraining,
  }) {
    final tone = _riskTone();
    return DawaCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: tone.background,
              borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
            ),
            child: Icon(Icons.analytics_outlined,
                color: tone.foreground, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isTraining
                            ? 'Training Classification'
                            : '$resultSourceLabel Classification',
                        style: DawaTextStyles.label.copyWith(
                          color: DawaTokens.textMuted,
                        ),
                      ),
                    ),
                    _pillBadge(
                      _analysisResult!.suspicionLevelString,
                      tone.background,
                      tone.foreground,
                      null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _analysisResult!.label,
                  style: DawaTextStyles.cardTitle.copyWith(
                    color: tone.foreground,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Visual pattern analysis is consistent with ${_analysisResult!.suspicionLevelString.toLowerCase()} risk markers.',
                  style: DawaTextStyles.secondary.copyWith(
                    color: DawaTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard({required bool isTraining}) {
    return DawaCard(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sideBySide = constraints.maxWidth >= 760;
          final guidance = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isTraining ? Icons.tips_and_updates : Icons.description,
                    color: DawaTokens.brandPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isTraining
                          ? 'Learning Guidance'
                          : 'Clinical Recommendation',
                      style: DawaTextStyles.cardTitle.copyWith(fontSize: 18),
                    ),
                  ),
                  if (!isTraining) _buildLanguageSelector(),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _localizedResultExplanation(isTraining: isTraining),
                style: DawaTextStyles.body.copyWith(
                  color: DawaTokens.textPrimary,
                  fontSize: 15,
                ),
              ),
              if (!isTraining && _resultExplanationLanguage != 'English') ...[
                const SizedBox(height: 10),
                Text(
                  'Original recommendation: ${_analysisResult!.recommendation}',
                  style: DawaTextStyles.secondary.copyWith(
                    color: DawaTokens.textSecondary,
                  ),
                ),
              ],
            ],
          );
          final actions = sideBySide
              ? Row(
                  children: [
                    Expanded(
                      child: _infoTile(
                        isTraining ? 'Practice Tip' : 'Next Step',
                        isTraining ? 'Review VIA criteria' : _nextStepLabel(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _infoTile(
                        'Protocol',
                        'Zambian MoH / WHO',
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _infoTile(
                      isTraining ? 'Practice Tip' : 'Next Step',
                      isTraining ? 'Review VIA criteria' : _nextStepLabel(),
                    ),
                    const SizedBox(height: 10),
                    _infoTile('Protocol', 'Zambian MoH / WHO'),
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              guidance,
              const SizedBox(height: 18),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildLanguageSelector() {
    const languages = [
      'English',
      'Nyanja',
      'Bemba',
      'Tonga',
      'Shona',
      'Ndebele',
    ];

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: DawaTokens.surfaceSecondary,
        borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
        border: Border.all(color: DawaTokens.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _resultExplanationLanguage,
          iconSize: 18,
          style: DawaTextStyles.secondary.copyWith(
            color: DawaTokens.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          items: languages
              .map(
                (language) => DropdownMenuItem(
                  value: language,
                  child: Text(language),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _resultExplanationLanguage = value);
          },
        ),
      ),
    );
  }

  Widget _buildResultDisclaimer(bool isTraining) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DawaTokens.statusInfoBg,
        borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
        border: Border.all(color: DawaTokens.statusInfo.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: DawaTokens.statusInfo),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isTraining
                  ? 'Training Note: Compare this AI feedback with your own assessment to build diagnostic confidence.'
                  : 'Midwife Note: This analysis is an assistive tool. Always verify results with your clinical judgment and standard diagnostic procedures.',
              style: DawaTextStyles.secondary.copyWith(
                color: DawaTokens.statusInfo,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTryAnotherTrainingImageButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          setState(() {
            _appState = AppState.dashboard;
            _analysisResult = null;
            _selectedImage = null;
          });
          _openImageSourcePicker(mode: ScreeningMode.training);
        },
        icon: const Icon(Icons.refresh),
        label: const Text('Try Another Image'),
        style: ElevatedButton.styleFrom(
          backgroundColor: DawaTokens.brandPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
          ),
        ),
      ),
    );
  }

  Widget _compactMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DawaTokens.surfaceSecondary,
        borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
        border: Border.all(color: DawaTokens.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: DawaTextStyles.label.copyWith(
                    color: DawaTokens.textMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: DawaTextStyles.secondary.copyWith(
                    color: DawaTokens.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillBadge(
    String label,
    Color background,
    Color foreground,
    IconData? icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: foreground.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: DawaTextStyles.secondary.copyWith(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Color _confidenceColor() {
    final confidence = _analysisResult?.confidence ?? 0;
    if (confidence >= 80) return DawaTokens.statusSuccess;
    if (confidence >= 50) return DawaTokens.statusWarning;
    return DawaTokens.statusDanger;
  }

  _ResultTone _riskTone() {
    switch (_analysisResult!.suspicionLevel) {
      case SuspicionLevel.low:
        return const _ResultTone(
          background: DawaTokens.statusSuccessBg,
          foreground: DawaTokens.statusSuccessText,
        );
      case SuspicionLevel.medium:
        return const _ResultTone(
          background: DawaTokens.statusWarningBg,
          foreground: DawaTokens.statusWarningText,
        );
      case SuspicionLevel.high:
        return const _ResultTone(
          background: Color(0xFFFFF7ED),
          foreground: Color(0xFFC2410C),
        );
    }
  }

  IconData _riskIcon() {
    switch (_analysisResult!.suspicionLevel) {
      case SuspicionLevel.low:
        return Icons.check_circle_outline;
      case SuspicionLevel.medium:
        return Icons.manage_search_outlined;
      case SuspicionLevel.high:
        return Icons.priority_high_rounded;
    }
  }

  String _nextStepLabel() {
    switch (_analysisResult!.suspicionLevel) {
      case SuspicionLevel.low:
        return 'Routine follow-up';
      case SuspicionLevel.medium:
        return 'Clinical review';
      case SuspicionLevel.high:
        return 'Referral planning';
    }
  }

  String _localizedResultExplanation({required bool isTraining}) {
    if (isTraining || _resultExplanationLanguage == 'English') {
      return _analysisResult!.recommendation;
    }

    final diagnosis = _analysisResult!.label;
    final risk = _analysisResult!.suspicionLevelString.toLowerCase();
    final confidence = _analysisResult!.confidence.toStringAsFixed(1);

    switch (_resultExplanationLanguage) {
      case 'Nyanja':
        return 'Zotsatira za $diagnosis zikuonetsa chiopsezo cha $risk. Chikhulupiriro cha makina ndi $confidence%. Gwiritsani ntchito izi ngati chithandizo, kenako tsimikizani ndi kuunika kwa chipatala ndi malamulo a MoH/WHO.';
      case 'Bemba':
        return 'Ifyo cafumamo pa $diagnosis filelanga ubusanso bwa $risk. Ukusumina kwa makina kuli $confidence%. Bomfya ici nga ubukafwilisho, elyo ukashinishishe ne kupima kwa chipatala pamo ne milao ya MoH/WHO.';
      case 'Tonga':
        return 'Mabbazu a $diagnosis alanga bubi bwa $risk. Kusinizya kwa muchina kuli $confidence%. Kozya kucibelesya buyo kuti cikugwasye, pele kasinizyeula mukulanga kwa cipatala alimwi njiila ya MoH/WHO.';
      case 'Shona':
        return 'Mhedzisiro ye $diagnosis inoratidza njodzi ye $risk. Kuvimba kwemuchina kuri $confidence%. Shandisa izvi sekubatsira, wozosimbisa nekuongorora kwekiriniki uye mitemo yeMoH/WHO.';
      case 'Ndebele':
        return 'Umphumela we $diagnosis utshengisa ubungozi be $risk. Ukuthembeka komshini kungu $confidence%. Sebenzisa lokhu njengosizo, ubusukuqinisekisa ngokuhlolwa kwekliniki langemithetho yeMoH/WHO.';
      default:
        return _analysisResult!.recommendation;
    }
  }
}

class _ResultTone {
  const _ResultTone({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}

class _ChartSummaryPill extends StatelessWidget {
  const _ChartSummaryPill({
    required this.label,
    required this.value,
    required this.color,
    this.showDot = true,
  });

  final String label;
  final int value;
  final Color color;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: DawaTokens.surfaceTertiary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
              child: Text(
            label,
            style: DawaTextStyles.secondary.copyWith(fontSize: 12),
          )),
          const SizedBox(width: 4),
          Text(
            value.toString(),
            style: DawaTextStyles.secondary.copyWith(
              color: DawaTokens.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreeningStackedBarChart extends StatelessWidget {
  const _ScreeningStackedBarChart({required this.data});

  final List<ScreeningData> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No screening activity yet',
          style: DawaTextStyles.secondary,
        ),
      );
    }

    return CustomPaint(
      painter: _ScreeningStackedBarPainter(data),
      child: const SizedBox.expand(),
    );
  }
}

class _ScreeningStackedBarPainter extends CustomPainter {
  const _ScreeningStackedBarPainter(this.data);

  final List<ScreeningData> data;
  static const double _leftAxis = 34;
  static const double _rightPadding = 8;
  static const double _topPadding = 18;
  static const double _bottomAxis = 30;
  static const int _maxY = 100;

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    final chartWidth = size.width - _leftAxis - _rightPadding;
    final chartHeight = size.height - _topPadding - _bottomAxis;
    final origin = Offset(_leftAxis, _topPadding + chartHeight);

    final gridPaint = Paint()
      ..color = DawaTokens.surfaceTertiary
      ..strokeWidth = 1;
    final axisTextStyle = DawaTextStyles.secondary.copyWith(
      color: DawaTokens.textMuted,
      fontSize: 11,
    );

    for (final tick in [0, 20, 40, 60, 80, 100]) {
      final y = origin.dy - (tick / _maxY) * chartHeight;
      canvas.drawLine(
        Offset(_leftAxis, y),
        Offset(size.width - _rightPadding, y),
        gridPaint,
      );
      if (tick > 0) {
        textPainter.text = TextSpan(text: '$tick', style: axisTextStyle);
        textPainter.layout(minWidth: 0, maxWidth: _leftAxis - 6);
        textPainter.paint(
          canvas,
          Offset(_leftAxis - textPainter.width - 8, y - textPainter.height / 2),
        );
      }
    }

    final slotWidth = chartWidth / data.length;
    final barWidth = (slotWidth * 0.56).clamp(28.0, 54.0).toDouble();
    final monthStyle = DawaTextStyles.secondary.copyWith(
      color: DawaTokens.textMuted,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    );
    final totalStyle = DawaTextStyles.secondary.copyWith(
      color: DawaTokens.textPrimary,
      fontSize: 12,
      fontWeight: FontWeight.w800,
    );

    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final total = item.normal + item.lowGrade + item.highGrade;
      final xCenter = _leftAxis + slotWidth * index + slotWidth / 2;
      final barLeft = xCenter - barWidth / 2;
      final barBottom = origin.dy;
      var cursor = barBottom;

      void drawSegment(int value, Color color,
          {bool top = false, bool bottom = false}) {
        if (value <= 0) return;
        final segmentHeight = (value / _maxY) * chartHeight;
        final rect = Rect.fromLTWH(
          barLeft,
          cursor - segmentHeight,
          barWidth,
          segmentHeight,
        );
        final radius = Radius.circular(top || bottom ? 4 : 0);
        final rrect = RRect.fromRectAndCorners(
          rect,
          topLeft: top ? radius : Radius.zero,
          topRight: top ? radius : Radius.zero,
          bottomLeft: bottom ? radius : Radius.zero,
          bottomRight: bottom ? radius : Radius.zero,
        );
        canvas.drawRRect(rrect, Paint()..color = color);
        cursor -= segmentHeight;
      }

      drawSegment(item.normal, DawaTokens.statusSuccess, bottom: true);
      drawSegment(item.lowGrade, DawaTokens.statusWarning);
      drawSegment(item.highGrade, DawaTokens.statusDanger, top: true);

      textPainter.text = TextSpan(text: '$total', style: totalStyle);
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
            xCenter - textPainter.width / 2, cursor - textPainter.height - 6),
      );

      textPainter.text = TextSpan(text: item.month, style: monthStyle);
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(xCenter - textPainter.width / 2, origin.dy + 10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScreeningStackedBarPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

void showDawaToast(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
      backgroundColor:
          isError ? DawaTokens.statusDanger : DawaTokens.textPrimary,
    ),
  );
}
