import '/auth/firebase_auth/auth_util.dart';
import '/reset_password/reset_password_widget.dart';
import '/components/image_source_picker_dialog/image_source_picker_dialog_widget.dart';
import '/components/dawa_design_system.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/offline_connectivity_service.dart';
import 'cacx_upload_service.dart';
import 'cacx_model.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

// ─── HUGGING FACE / GRADIO SERVICE ────────────────────────────────────────────
class HuggingFaceService {
  static const String _spaceBaseUrl = 'https://kmunzwa-medsiglip-demo.hf.space';

  static Future<AnalysisResult> analyzeVIAImage(String base64Image) async {
    try {
      final rawBase64 =
          base64Image.contains(',') ? base64Image.split(',').last : base64Image;
      final imageBytes = base64Decode(rawBase64);

      String mimeType = 'image/jpeg';
      String extension = 'jpg';
      if (base64Image.startsWith('data:image/png')) {
        mimeType = 'image/png';
        extension = 'png';
      } else if (base64Image.startsWith('data:image/webp')) {
        mimeType = 'image/webp';
        extension = 'webp';
      }

      // ── Step 1: Upload — note the new /gradio_api/upload path ──────────────
      final uploadUri = Uri.parse('$_spaceBaseUrl/gradio_api/upload');
      final uploadRequest = http.MultipartRequest('POST', uploadUri)
        ..files.add(
          http.MultipartFile.fromBytes(
            'files',
            imageBytes,
            filename: 'image.$extension',
            contentType: MediaType.parse(mimeType),
          ),
        );

      final uploadStreamedResponse =
          await uploadRequest.send().timeout(const Duration(seconds: 20));
      final uploadBody = await uploadStreamedResponse.stream.bytesToString();

      if (uploadStreamedResponse.statusCode != 200) {
        throw Exception(
            'Upload failed ${uploadStreamedResponse.statusCode}: $uploadBody');
      }

      final List<dynamic> uploadedPaths =
          jsonDecode(uploadBody) as List<dynamic>;
      final String serverFilePath = uploadedPaths.first as String;
      debugPrint('Gradio uploaded file path: $serverFilePath');

      // ── Step 2: POST to /gradio_api/call/predict — returns an event_id ─────
      final predictUri = Uri.parse('$_spaceBaseUrl/gradio_api/call/predict');
      final predictResponse = await http
          .post(
            predictUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'data': [
                {
                  'path': serverFilePath,
                  'orig_name': 'image.$extension',
                  'meta': {'_type': 'gradio.FileData'},
                }
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (predictResponse.statusCode != 200) {
        throw Exception(
            'Predict failed ${predictResponse.statusCode}: ${predictResponse.body}');
      }

      final Map<String, dynamic> predictJson =
          jsonDecode(predictResponse.body) as Map<String, dynamic>;
      final String eventId = predictJson['event_id'] as String;
      debugPrint('Gradio event_id: $eventId');

      // ── Step 3: GET the result via SSE ─────────────────────────────────────
      final resultUri =
          Uri.parse('$_spaceBaseUrl/gradio_api/call/predict/$eventId');
      final resultResponse =
          await http.get(resultUri).timeout(const Duration(seconds: 60));

      if (resultResponse.statusCode != 200) {
        throw Exception(
            'Result fetch failed ${resultResponse.statusCode}: ${resultResponse.body}');
      }

      // SSE body looks like:
      //   event: complete
      //   data: [{"label": "CIN1", "confidences": [...]}]
      // ── Step 4: Parse the SSE body ─────────────────────────────────────────────
      final String sseBody = resultResponse.body;
      debugPrint('Gradio SSE response: $sseBody');

// Find the "data:" line that follows "event: complete"
      final lines = sseBody.split('\n');
      String dataLine = '';
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].trim() == 'event: complete' && i + 1 < lines.length) {
          final next = lines[i + 1];
          if (next.startsWith('data:')) {
            dataLine = next;
            break;
          }
        }
      }

      if (dataLine.isEmpty) {
        throw Exception(
            'No complete event data found in SSE response: $sseBody');
      }

      final dynamic resultData =
          (jsonDecode(dataLine.substring(5).trim()) as List<dynamic>).first;

      // ── Step 4: Parse (same logic as before) ───────────────────────────────
      final breakdown = extractPredictionBreakdown(resultData);
      String mappedLabel = breakdown.isNotEmpty
          ? canonicalCacxBaseLabel(breakdown.first.label)
          : '';
      double confidence = breakdown.isNotEmpty ? breakdown.first.confidence : 0;

      if (mappedLabel.isEmpty) {
        if (resultData is Map<String, dynamic>) {
          final String rawLabel =
              (resultData['label'] ?? resultData['prediction'] ?? '')
                  .toString();
          mappedLabel = canonicalCacxBaseLabel(rawLabel);
          confidence = normalizeCacxConfidence(
            resultData['confidence'] ??
                resultData['confidence_percent'] ??
                resultData['probability'] ??
                resultData['score'],
          );
        } else if (resultData is List<dynamic> && resultData.isNotEmpty) {
          final top = resultData.reduce(
            (a, b) {
              final aScore = normalizeCacxConfidence(
                a is Map ? a['score'] ?? a['confidence'] ?? 0 : 0,
              );
              final bScore = normalizeCacxConfidence(
                b is Map ? b['score'] ?? b['confidence'] ?? 0 : 0,
              );
              return aScore >= bScore ? a : b;
            },
          );
          final rawLabel =
              (top is Map ? top['label'] ?? top['class'] ?? '' : '')
                  .toString()
                  .trim();
          mappedLabel = canonicalCacxBaseLabel(rawLabel);
          confidence = normalizeCacxConfidence(
            top is Map ? top['score'] ?? top['confidence'] ?? 0 : 0,
          );
        } else {
          throw Exception('Unexpected Gradio response shape: $resultData');
        }
      }

      debugPrint(
          'Gradio -> label: $mappedLabel confidence: ${confidence.toStringAsFixed(1)}% breakdown=${breakdown.length}');
      return _processResult(
        base64Image,
        mappedLabel,
        confidence,
        predictionBreakdown: breakdown,
      );
    } catch (e) {
      debugPrint('Gradio Error: $e');
      return AnalysisResult(
        imageUrl: base64Image,
        label: 'Analysis Failed',
        confidence: 0,
        suspicionLevel: SuspicionLevel.low,
        recommendation:
            'Could not connect to AI model. Please check your connection and try again.',
        predictionBreakdown: const [],
        error: e.toString(),
      );
    }
  }

  static AnalysisResult _processResult(
    String imageUrl,
    String label,
    double confidence, {
    List<PredictionBreakdownItem> predictionBreakdown = const [],
  }) {
    SuspicionLevel suspicion;
    String displayLabel;
    String recommendation;
    final key = canonicalCacxBaseLabel(label);

    switch (key) {
      case 'negative':
        suspicion = SuspicionLevel.low;
        displayLabel = 'Normal / Negative VIA';
        recommendation =
            'No acetowhite lesion or other abnormality seen. Routine follow-up: repeat VIA in 3 years per national MoH guidelines. Provide patient education on cervical cancer warning signs (e.g., post-coital bleeding, intermenstrual bleeding, foul discharge). Document findings in patient record. No referral needed.';
        break;
      case 'cin1':
        suspicion = SuspicionLevel.medium;
        displayLabel = 'Low Grade Lesion (CIN1)';
        recommendation =
            'Well-defined, faint/thin acetowhite lesions. Management: Repeat VIA in 12 months. Counsel patient on likely regression, but emphasize importance of returning for repeat screening. Advise smoking cessation if applicable, and discuss HPV transmission. Schedule recall appointment before discharge. No immediate colposcopy unless patient is HIV-positive, immunocompromised, or persistent at 12-24 months.';
        break;
      case 'cin2':
        suspicion = SuspicionLevel.high;
        displayLabel = 'High Grade Lesion (CIN2)';
        recommendation =
            "Distinct, dense, opaque acetowhite lesions with irregular borders. Action: Refer for colposcopy and directed biopsy within 4 weeks. If colposcopy confirms CIN2+ and patient has completed childbearing or lesion is fully visible, proceed with LEEP/cryotherapy same day. Document lesion size, location, and extension onto fornices. Offer HPV testing if available. Exclude pregnancy before treatment.";
        break;
      case 'cin3':
        suspicion = SuspicionLevel.high;
        displayLabel = 'High Grade Lesion (CIN3)';
        recommendation =
            "Dense, acetowhite epithelium with sharp borders. May involve crypts. Action: Urgent colposcopy referral within 2 weeks. Biopsy mandatory. 'See and Treat' acceptable if colposcopy suspicious for invasion. Do not delay for results if lesion is large or concerning. Check HIV status — treat earlier if positive. Discuss risk of progression if untreated. Prepare for possible LEEP or cone biopsy.";
        break;
      case 'positive':
        suspicion = SuspicionLevel.high;
        displayLabel = 'Positive - Cancer Suspected';
        recommendation =
            "Abnormal vessel patterns, irregular surface, ulceration, or friable mass. Likely invasive cancer. Action: URGENT referral — complete oncological referral form immediately. Do not perform LEEP/cryotherapy. Perform guided punch biopsy only if haemorrhage can be controlled. Send biopsy with 'suspicious for invasive cancer' noted. Contact gynaecology oncology team by phone within 24 hours. Advise patient not to wait. Document exam under anaesthesia status and any renal function if contrast imaging planned.";
        break;
      default:
        suspicion = SuspicionLevel.low;
        displayLabel = 'Inconclusive - ${canonicalCacxDisplayLabel(label)}';
        recommendation =
            'Image quality insufficient or interpretation unclear. Likely causes: excess mucus, poor illumination, incomplete acetic acid application, or blurred image. Action: Repeat VIA with clearer visualization. Clean cervix with saline-soaked swab, reapply 5% acetic acid, wait 60 seconds, and reassess. If repeatedly inconclusive, refer for colposcopy. Document reason for inconclusive result in chart.';
    }

    return AnalysisResult(
      imageUrl: imageUrl,
      label: displayLabel,
      confidence: double.parse(confidence.toStringAsFixed(1)),
      suspicionLevel: suspicion,
      recommendation: recommendation,
      predictionBreakdown: predictionBreakdown,
    );
  }
}

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
        final image = await ImagePickerService.captureImage();
        if (!ctx.mounted) return;
        Navigator.pop(ctx, image);
      },
      onUploadImage: () async {
        final image = await ImagePickerService.pickImage();
        if (!ctx.mounted) return;
        Navigator.pop(ctx, image);
      },
    ),
  );
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
  });

  final Patient? initialPatient;
  final bool autoStartScreening;
  final bool returnToPreviousOnSave;

  @override
  _CaCxAppState createState() => _CaCxAppState();
}

class _CaCxAppState extends State<CaCxApp> {
  AppState _appState = AppState.dashboard;
  DashboardTab _activeTab = DashboardTab.home;

  // Current mode determines how the results screen is framed.
  ScreeningMode _screeningMode = ScreeningMode.via;

  String _analyzingStatus = 'Ready for cervical device interpretation';
  String? _flowWarningMessage;
  String? _screeningRecordId;
  int? _deviceSecondsRemaining;
  int _deviceRetryCount = 0;
  Timer? _deviceCountdownTimer;
  bool _deviceUploadInProgress = false;
  bool _cloudFallbackRequested = false;
  bool _cloudFallbackInProgress = false;
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
  String _patientSearchText = '';
  bool _patientNeedsReviewOnly = false;
  bool _showAllPredictionClasses = false;

  // UI States
  bool _isAnalyzing = false;
  bool _secondOpinionRequired = false;
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
    _loadMockData();
    if (widget.initialPatient != null) {
      _selectedPatient = widget.initialPatient;
      _patientSearchText = widget.initialPatient!.name;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trySyncPendingCacx();
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
    _deviceCountdownTimer?.cancel();
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _resultsSearchController.dispose();
    super.dispose();
  }

  void _loadMockData() {
    setState(() {
      _patients = MockData.getPatients();
      _historyRecords = MockData.getHistoryRecords();
      _screeningData = MockData.getScreeningData();
      final seededPatient = widget.initialPatient;
      if (seededPatient != null &&
          !_patients.any((patient) => patient.id == seededPatient.id)) {
        _patients = [seededPatient, ..._patients];
      }
    });
  }

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
      _patientSearchText = record.patientName;
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
      _patientSearchText = record.patientName;
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
    final connectivity = await OfflineConnectivityService.refreshStatus();
    if (connectivity.isOffline) {
      return;
    }
    await CacxScreeningResultsRepository.syncPending();
  }

  void _resetScreeningFlow() {
    _flowWarningMessage = null;
    _screeningRecordId = null;
    _primaryDeviceResult = null;
    _secondOpinionResult = null;
    _secondOpinionRequired = false;
    _secondOpinionStatus = 'not_required';
    _analyzingStatus = 'Ready for cervical device interpretation';
    _deviceSecondsRemaining = null;
    _deviceRetryCount = 0;
    _deviceCountdownTimer?.cancel();
    _deviceCountdownTimer = null;
    _deviceUploadInProgress = false;
    _cloudFallbackRequested = false;
    _cloudFallbackInProgress = false;
    _currentScanImagePath = null;
    _currentScanPatientId = null;
    _currentScanUserId = null;
    _showAllPredictionClasses = false;
  }

  // ?? Unified image-picker entry point ????????????????????????????????????????
  Future<void> _openImageSourcePicker({required ScreeningMode mode}) async {
    if (_isAnalyzing || _deviceUploadInProgress || _cloudFallbackInProgress) {
      showDawaToast(
        context,
        'A CaCx scan is already in progress. Please wait for the result.',
      );
      return;
    }

    final image = await showImageSourcePicker(context);
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
      _isAnalyzing = true;
      _appState = AppState.dashboard;
      _resetScreeningFlow();
    });

    await _analyzeImage();
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;

    final image = _selectedImage!;
    final patientId = _selectedPatient?.id;
    final userId = currentUserUid.isEmpty ? null : currentUserUid;
    final imagePath = CacxScreeningResultsRepository.buildImagePath(
      userId: userId,
      patientId: patientId,
    );
    _currentScanImagePath = imagePath;
    _currentScanPatientId = patientId;
    _currentScanUserId = userId;

    final connectivity = await OfflineConnectivityService.refreshStatus();
    if (connectivity.isOffline) {
      await _analyzeImageOfflineOnly(
        image: image,
        patientId: patientId,
        userId: userId,
        imagePath: imagePath,
      );
      return;
    }

    await _trySyncPendingCacx();

    final primary = await _sendImageToDeviceOnce(image, patientId);

    final secondRequired = primary.deviceStatus != 'success';
    final initialSecondStatus = secondRequired ? 'pending' : 'not_required';
    final recordId = await _savePrimaryResultForCurrentScan(
      primary: primary,
      secondOpinionRequired: secondRequired,
      secondOpinionStatus: initialSecondStatus,
    );

    if (!mounted) return;
    setState(() {
      _screeningRecordId = recordId;
      _primaryDeviceResult = primary;
      if (!_cloudFallbackRequested) {
        _secondOpinionRequired = secondRequired;
        _secondOpinionStatus = initialSecondStatus;
      }
    });

    if (_cloudFallbackRequested) {
      _setFlowStatus(
        'Online scan in progress',
        warning:
            'The offline device response was recorded. The online scan result remains active.',
      );
      return;
    }

    _setFlowStatus(
      recordId == null
          ? 'Device status received, but Supabase save failed'
          : 'Device result saved to Supabase',
      warning: recordId == null
          ? 'The screening flow continued, but the screening result row could not be saved.'
          : _flowWarningMessage,
    );

    if (!secondRequired) {
      _setFlowStatus('Device handled case');
      setState(() {
        _deviceSecondsRemaining = null;
        _analysisResult = primary.toAnalysisResult(image);
        _isAnalyzing = false;
        _appState = AppState.results;
      });
      return;
    }

    await _runCloudFallbackForCurrentScan(
      primary: primary,
      statusMessage: primary.deviceStatus == 'timeout'
          ? 'Device did not respond in time. Sending for second opinion.'
          : 'Device failed. Sending for second opinion.',
      warning: 'The online scan is using the same uploaded image.',
    );
  }

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
      const Duration(seconds: CervicalDeviceConfig.timeoutSeconds),
    );
    _deviceUploadInProgress = true;
    _setDeviceCountdown(deadline, 0);

    debugPrint('[Device] Connection attempt');
    _setFlowStatus('Connecting to device...');
    _startDeviceCountdown(deadline);

    try {
      if (!skipHealthCheck) {
        await CervicalDeviceService.checkHealth();
      }

      _setFlowStatus('Sending image to device...');
      debugPrint('[Device] Upload started');

      _setFlowStatus('Waiting for device response...');
      debugPrint('[Device] Waiting for response');
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
      );

      if (result.failed) {
        debugPrint('[Device] Unrecoverable error: ${result.error}');
      } else {
        debugPrint('[Device] Success');
        _setFlowStatus('Device result received');
      }

      return result;
    } on TimeoutException catch (error) {
      final message =
          'Device timeout after ${CervicalDeviceConfig.timeoutSeconds} seconds';
      debugPrint(
          '[Device] Timeout after ${CervicalDeviceConfig.timeoutSeconds} seconds');
      _setFlowStatus(
        allowCloudFallbackMessages
            ? 'Device timed out. Sending for second opinion...'
            : 'Offline mode: Arduino device not connected',
        warning: allowCloudFallbackMessages
            ? 'Device did not respond in time. Sending for second opinion.'
            : 'Offline mode: Arduino device not connected. Please connect the device or go online.',
      );
      return CervicalDeviceInterpretation.failure(
        label: 'Error',
        message: message,
        deviceStatus: 'timeout',
        rawResponse: {
          'status': 'timeout',
          'error': error.toString(),
          'endpoint': CervicalDeviceConfig.imagePostUrl,
          'timeout_seconds': CervicalDeviceConfig.timeoutSeconds,
        },
      );
    } on CervicalDeviceHttpException catch (error) {
      debugPrint('[Device] HTTP failure: $error');
      _setFlowStatus(
        allowCloudFallbackMessages
            ? 'Device failed. Sending for second opinion...'
            : 'Offline mode: Arduino device not connected',
        warning: allowCloudFallbackMessages
            ? (error.body.isEmpty ? error.toString() : error.body)
            : 'Offline mode: Arduino device not connected. Please connect the device or go online.',
      );
      return CervicalDeviceInterpretation.failure(
        label: 'Error',
        message: error.toString(),
        deviceStatus: 'failed',
        rawResponse: {
          'status': 'failed',
          'status_code': error.statusCode,
          'error': error.body,
          'endpoint': CervicalDeviceConfig.imagePostUrl,
        },
      );
    } catch (error) {
      debugPrint('[Device] Network failure: $error');
      _setFlowStatus(
        allowCloudFallbackMessages
            ? 'Device failed. Sending for second opinion...'
            : 'Offline mode: Arduino device not connected',
        warning: allowCloudFallbackMessages
            ? error.toString()
            : 'Offline mode: Arduino device not connected. Please connect the device or go online.',
      );
      return CervicalDeviceInterpretation.failure(
        label: 'Error',
        message: error.toString(),
        deviceStatus: 'failed',
        rawResponse: {
          'status': 'offline',
          'error': error.toString(),
          'endpoint': CervicalDeviceConfig.imagePostUrl,
        },
      );
    } finally {
      _deviceUploadInProgress = false;
      _stopDeviceCountdown();
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
      _deviceRetryCount = retryCount;
    });
  }

  Future<String?> _savePrimaryResultForCurrentScan({
    required CervicalDeviceInterpretation primary,
    required bool secondOpinionRequired,
    required String secondOpinionStatus,
  }) async {
    final existingId = _screeningRecordId;
    if (existingId != null && existingId.isNotEmpty) {
      await CacxScreeningResultsRepository.updatePrimaryResult(
        recordId: existingId,
        primary: primary,
      );
      return existingId;
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

  Future<void> _skipToCloudResultNow() async {
    if (_selectedImage == null || _cloudFallbackInProgress) return;

    _cloudFallbackRequested = true;
    final primary = _primaryDeviceResult ?? _pendingDeviceInterpretation();

    await _savePrimaryResultForCurrentScan(
      primary: primary,
      secondOpinionRequired: true,
      secondOpinionStatus: 'pending',
    );

    if (!mounted) return;
    setState(() {
      _primaryDeviceResult = primary;
      _secondOpinionRequired = true;
      _secondOpinionStatus = 'pending';
    });

    await _runCloudFallbackForCurrentScan(
      primary: primary,
      statusMessage: 'Using online scan result now...',
      warning:
          'The online scan is using the same uploaded image while the offline device request continues.',
    );
  }

  Future<void> _runCloudFallbackForCurrentScan({
    required CervicalDeviceInterpretation primary,
    required String statusMessage,
    String? warning,
  }) async {
    if (_selectedImage == null || _cloudFallbackInProgress) return;

    final connectivity = await OfflineConnectivityService.refreshStatus();
    if (connectivity.isOffline) {
      _setFlowStatus(
        'Offline mode: online scan unavailable',
        warning:
            'Server analysis requires internet. Connect to the internet or use the Arduino device.',
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
      final secondOpinion = await HuggingFaceService.analyzeVIAImage(image);
      final secondOpinionFailed = secondOpinion.error != null ||
          secondOpinion.label.toLowerCase().contains('failed') ||
          secondOpinion.label.toLowerCase().contains('error');
      final finalSecondStatus = secondOpinionFailed ? 'failed' : 'completed';

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
            : null,
      );

      setState(() {
        _deviceSecondsRemaining = null;
        _secondOpinionResult = secondOpinion;
        _secondOpinionStatus = finalSecondStatus;
        _analysisResult = finalResult;
        _isAnalyzing = false;
        _appState = AppState.results;
      });
    } finally {
      _cloudFallbackInProgress = false;
    }
  }

  Future<void> _runManualSecondOpinion() async {
    if (_selectedImage == null) return;

    final connectivity = await OfflineConnectivityService.refreshStatus();
    if (connectivity.isOffline) {
      _setFlowStatus(
        'Offline mode: online scan unavailable',
        warning:
            'Server analysis requires internet. Connect to the internet or use the Arduino device.',
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _secondOpinionRequired = true;
      _secondOpinionStatus = 'pending';
    });
    _setFlowStatus('Sending for second opinion...');

    final secondOpinion = await HuggingFaceService.analyzeVIAImage(
      _selectedImage!,
    );
    final failed = secondOpinion.error != null ||
        secondOpinion.label.toLowerCase().contains('failed') ||
        secondOpinion.label.toLowerCase().contains('error');
    final status = failed ? 'failed' : 'completed';

    await CacxScreeningResultsRepository.updateSecondOpinion(
      recordId: _screeningRecordId,
      result: secondOpinion,
      status: status,
    );

    if (!mounted) return;

    _setFlowStatus(
      failed
          ? 'Second opinion failed - manual review required'
          : 'Second opinion completed',
      warning: failed
          ? 'The server fallback did not complete. Please retry or escalate for clinical review.'
          : null,
    );

    setState(() {
      _secondOpinionResult = secondOpinion;
      _secondOpinionStatus = status;
      _analysisResult = failed ? _analysisResult : secondOpinion;
      _isAnalyzing = false;
      _appState = AppState.results;
    });
  }

  void _saveAnalysisResult() {
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Record Saved Successfully!')),
    );
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

  void _addNewPatient() {
    if (_nameController.text.isEmpty ||
        _ageController.text.isEmpty ||
        _phoneController.text.isEmpty) return;

    final newPatient = Patient(
      id: 'DM-${1000 + _patients.length}',
      name: _nameController.text,
      age: int.parse(_ageController.text),
      contact: _phoneController.text,
      status: PatientStatus.untested,
      riskLevel: RiskLevel.low,
    );

    setState(() {
      _patients = [newPatient, ..._patients];
      _selectedPatient = newPatient;
      _nameController.clear();
      _ageController.clear();
      _phoneController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_appState) {
      case AppState.splash:
        return _buildSplashScreen();
      case AppState.results:
        return _buildResultsScreen();
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
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (!isMobile) ...[
              _buildSidebar(),
              const VerticalDivider(width: 1),
            ],
            Expanded(
              child: Column(
                children: [
                  if (isMobile) ...[
                    _buildMobileHeader(),
                    const Divider(height: 1),
                  ],
                  if (_shouldShowFlowStatus) _buildFlowStatusBanner(),
                  Expanded(child: _buildCurrentTab()),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isMobile ? _buildMobileBottomNav() : null,
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
    final progress = remaining == null
        ? null
        : 1 -
            (remaining / CervicalDeviceConfig.timeoutSeconds)
                .clamp(0.0, 1.0)
                .toDouble();
    final showCloudSkip = _isAnalyzing &&
        _deviceUploadInProgress &&
        !_cloudFallbackRequested &&
        _selectedImage != null;

    return Container(
      width: double.infinity,
      color: DawaTokens.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
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
                      'This may take up to 2 minutes.',
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
                        value: progress,
                        minHeight: 5,
                        color: statusColor,
                        backgroundColor: Colors.white.withOpacity(0.65),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$remaining seconds remaining'
                      '${_deviceRetryCount > 0 ? ' - retry $_deviceRetryCount' : ''}',
                      style: DawaTextStyles.secondary.copyWith(
                        color: warning
                            ? DawaTokens.statusWarningText
                            : DawaTokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (showCloudSkip) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _cloudFallbackInProgress
                            ? null
                            : _skipToCloudResultNow,
                        icon: const Icon(Icons.cloud_outlined, size: 16),
                        label: const Text('Use Online Scan Now'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DawaTokens.brandPrimary,
                          side:
                              const BorderSide(color: DawaTokens.brandPrimary),
                          backgroundColor: DawaTokens.surface,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!showCloudSkip &&
                !_isAnalyzing &&
                _selectedImage != null &&
                _secondOpinionStatus == 'failed')
              TextButton(
                onPressed: _runManualSecondOpinion,
                child: const Text('Retry server'),
              ),
          ],
        ),
      ),
    );
  }

  // ??? SIDEBAR ??????????????????????????????????????????????????????????????
  Widget _buildSidebar() {
    return Container(
      width: 280,
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: DawaTokens.brandPrimary, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      'assets/images/dawa_cross.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dawa CaCx',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87),
                    ),
                    Text(
                      'Dashboard',
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey, letterSpacing: 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: _buildBackToHomeButton(),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildNavItem(Icons.dashboard, 'Dashboard', DashboardTab.home),
                _buildNavItem(
                    Icons.people, 'Patient Registry', DashboardTab.patients),
                _buildNavItem(
                    Icons.history, 'Screening History', DashboardTab.history),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackToHomeButton({
    bool compact = false,
    double? width,
    Color color = DawaTokens.brandPrimary,
  }) {
    final style = OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color.withOpacity(0.28)),
      minimumSize: Size.zero,
      padding: compact
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 12),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
      ),
    );

    final button = compact
        ? OutlinedButton(
            onPressed: _handleLogout,
            style: style,
            child: const Icon(Icons.arrow_back_rounded, size: 18),
          )
        : OutlinedButton.icon(
            onPressed: _handleLogout,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Back to Home'),
            style: style,
          );

    return SizedBox(
      width: width ?? double.infinity,
      height: 38,
      child: Tooltip(
        message: 'Back to Home',
        child: button,
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, DashboardTab tab) {
    final isActive = _activeTab == tab;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive ? DawaTokens.brandPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? DawaTokens.textInverse : DawaTokens.textMuted,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? DawaTokens.textInverse : DawaTokens.textSecondary,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () => _handleTabChange(tab),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ??? MOBILE HEADER ????????????????????????????????????????????????????????
  Widget _buildMobileHeader() {
    final compact = MediaQuery.of(context).size.width < 430;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          _buildBackToHomeButton(
            compact: compact,
            width: compact ? 38 : 136,
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 40,
            height: 40,
            child: Image.asset('assets/images/dawa_cross.png',
                fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Dawa CaCx',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87),
            ),
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            backgroundColor: DawaTokens.brandPrimaryPale,
            child: Text('MM',
                style: TextStyle(
                    color: DawaTokens.brandPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ??? MOBILE BOTTOM NAV ????????????????????????????????????????????????????
  Widget _buildMobileBottomNav() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMobileNavItem(Icons.dashboard, 'Home', DashboardTab.home),
          _buildMobileNavItem(Icons.people, 'Patients', DashboardTab.patients),
          _buildMobileNavItem(Icons.history, 'History', DashboardTab.history),
          _buildMobileNavItem(Icons.person, 'Profile', DashboardTab.profile),
        ],
      ),
    );
  }

  Widget _buildMobileNavItem(IconData icon, String label, DashboardTab tab) {
    final isActive = _activeTab == tab;
    return GestureDetector(
      onTap: () => _handleTabChange(tab),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: isActive ? DawaTokens.brandPrimary : Colors.grey,
              size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isActive ? DawaTokens.brandPrimary : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
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

  // ??? HOME TAB ?????????????????????????????????????????????????????????????
  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cervical Cancer Dashboard',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'Welcome, ${_clinicianName()}. Manage VIA screening, patient records, and AI-supported cervical cancer results.',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 32),
          _buildDashboardActions(),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 840
                  ? 3
                  : constraints.maxWidth >= 560
                      ? 2
                      : 1;
              final cardWidth =
                  (constraints.maxWidth - (16 * (columns - 1))) / columns;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildStatCard(
                        'Registered Patients',
                        '5',
                        Icons.people,
                        DawaTokens.brandPrimary,
                        '+12% this month'),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildStatCard('Follow-Up Required', '3',
                        Icons.warning, DawaTokens.statusWarning, '2 urgent'),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildFreeAnalysisCard(),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          _buildScreeningActivityCard(),
        ],
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
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

  String _clinicianName() {
    final displayName = currentUserDisplayName.trim();
    if (displayName.isNotEmpty) return displayName;

    final email = currentUserEmail.trim();
    if (email.isNotEmpty) return email;

    return 'Clinician';
  }

  Widget _buildDashboardActions() {
    final actions = [
      (
        title: 'Add Screening Record',
        subtitle: 'Capture or upload a VIA image for AI-supported review.',
        icon: Icons.add_circle_outline,
        color: DawaTokens.brandPrimary,
        onTap: () => _openImageSourcePicker(mode: ScreeningMode.via),
      ),
      (
        title: 'View Patient Records',
        subtitle: 'Open the patient registry and select a patient.',
        icon: Icons.people_outline,
        color: DawaTokens.brandPrimary,
        onTap: () => setState(() => _activeTab = DashboardTab.patients),
      ),
      (
        title: 'View Screening Results',
        subtitle: 'Search, filter, and review VIA result history.',
        icon: Icons.fact_check_outlined,
        color: DawaTokens.brandPrimary,
        onTap: () => setState(() => _activeTab = DashboardTab.history),
      ),
      (
        title: 'Find Patient',
        subtitle: 'Search the registry by name, ID, or contact details.',
        icon: Icons.search,
        color: DawaTokens.brandPrimary,
        onTap: () => setState(() => _activeTab = DashboardTab.patients),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        final width = (constraints.maxWidth - (14 * (columns - 1))) / columns;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final action in actions)
              SizedBox(
                width: width,
                child: _buildActionCard(
                  action.title,
                  action.subtitle,
                  action.icon,
                  action.color,
                  action.onTap,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
    return Material(
      color: DawaTokens.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 172),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: DawaTokens.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DawaTokens.border),
            boxShadow: DawaTokens.shadowSm,
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DawaTextStyles.cardTitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: DawaTextStyles.secondary.copyWith(fontSize: 12),
                    ),
                    if (title.contains('Screening') ||
                        title.contains('Training')) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _sourceBadge(Icons.camera_alt, 'Camera'),
                          _sourceBadge(Icons.photo_library, 'Gallery'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: DawaTokens.surfaceTertiary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: DawaTokens.textSecondary,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: DawaTokens.surfaceTertiary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DawaTokens.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: DawaTokens.textSecondary, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: DawaTokens.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color, String trend) {
    final isUrgent = trend.toLowerCase().contains('urgent');
    final badgeBg =
        isUrgent ? DawaTokens.statusDangerBg : DawaTokens.statusSuccessBg;
    final badgeColor =
        isUrgent ? DawaTokens.statusDanger : DawaTokens.statusSuccessText;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DawaTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DawaTokens.border),
        boxShadow: DawaTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: DawaTextStyles.statNumber.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 8),
          Text(title, style: DawaTextStyles.secondary),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              trend,
              style: TextStyle(
                color: badgeColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeAnalysisCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DawaTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DawaTokens.border),
        boxShadow: DawaTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: DawaTokens.statusSuccessBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.verified,
              color: DawaTokens.statusSuccessText,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'FREE',
            style: DawaTextStyles.statNumber.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 8),
          Text('AI Analysis', style: DawaTextStyles.secondary),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: DawaTokens.statusSuccessBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Unlimited Use',
                style: TextStyle(
                    color: DawaTokens.statusSuccessText,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
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

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          color: Colors.white,
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Patient Registry',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Manage and track your patient records.',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    _openImageSourcePicker(mode: ScreeningMode.via),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Add Screening'),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) =>
                      setState(() => _patientSearchText = value),
                  decoration: InputDecoration(
                    hintText: 'Search by name, ID or phone...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              FilterChip(
                selected: _patientNeedsReviewOnly,
                onSelected: (selected) =>
                    setState(() => _patientNeedsReviewOnly = selected),
                avatar: Icon(
                  Icons.priority_high_rounded,
                  size: 16,
                  color: _patientNeedsReviewOnly
                      ? DawaTokens.textInverse
                      : DawaTokens.statusWarning,
                ),
                label: const Text('Needs review'),
                selectedColor: DawaTokens.brandPrimary,
                checkmarkColor: DawaTokens.textInverse,
                labelStyle: TextStyle(
                  color: _patientNeedsReviewOnly
                      ? DawaTokens.textInverse
                      : DawaTokens.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredPatients.isEmpty
              ? _buildNoPatientMatches()
              : ListView.builder(
                  itemCount: filteredPatients.length,
                  itemBuilder: (context, index) {
                    final patient = filteredPatients[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: DawaCard(
                        padding: const EdgeInsets.all(14),
                        urgent: patient.status == PatientStatus.suspicious,
                        onTap: () async {
                          setState(() => _selectedPatient = patient);
                          await _openImageSourcePicker(mode: ScreeningMode.via);
                        },
                        child: Row(
                          children: [
                            DawaAvatarCircle(
                              name: patient.name,
                              moduleColor: DawaTokens.brandPrimary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(patient.name,
                                      style: DawaTextStyles.cardTitle),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${patient.id} | ${patient.age} yrs | ${patient.contact} | Last screened: ${patient.lastTestDate == null ? 'Not yet' : _formatDate(patient.lastTestDate!)}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: DawaTextStyles.secondary,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _patientStatusBadge(patient),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right_rounded,
                                color: DawaTokens.textMuted),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

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
                _patientSearchText = '';
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
        return Column(
          children: [
            Container(
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
            ),
            Expanded(
              child: filteredRecords.isEmpty
                  ? _buildResultsEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: filteredRecords.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _buildHistoryResultCard(filteredRecords[index]),
                    ),
            ),
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

  // ignore: unused_element
  Widget _legacyHistoryResultCard(VIATestRecord record) {
    final needsReview = _recordNeedsReview(record);
    final statusColor =
        needsReview ? DawaTokens.statusWarning : DawaTokens.statusSuccess;
    final statusLabel = needsReview ? 'Needs review' : 'Completed';

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.12),
                  child: Icon(Icons.medical_services, color: statusColor),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.patientName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Patient ${record.patientId} - Record ${record.id}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                Chip(
                  label: Text(statusLabel),
                  backgroundColor: statusColor.withOpacity(0.12),
                  labelStyle: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Date: ${_formatDate(record.date)}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              'Result: ${record.result}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text('Notes: ${record.notes}'),
            if ((record.aiAnalysis ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'AI analysis: ${record.aiAnalysis}',
                style: const TextStyle(color: DawaTokens.brandPrimary),
              ),
            ],
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
                  icon: Icon(needsReview
                      ? Icons.event_available
                      : Icons.check_circle_outline),
                  label: Text(
                      needsReview ? 'Plan follow-up' : 'Routine follow-up'),
                ),
              ],
            ),
          ],
        ),
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
                              : 'Device completed primary diagnosis')
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
              label: const Text('Retry server second opinion'),
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
        ? 'Second Opinion'
        : 'Device AI';

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
              onPressed: _shareAnalysisSummary,
            ),
            IconButton(
                icon: const Icon(Icons.save), onPressed: _saveAnalysisResult),
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
                      isTraining ? 'Training Result' : 'Diagnosis',
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
                _screeningRecordId != null ? 'Saved' : 'Completed',
                DawaTokens.statusSuccessBg,
                DawaTokens.statusSuccessText,
                Icons.check_circle_outline,
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
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildConfidenceCard(String resultSourceLabel) {
    final confidence = _analysisResult!.confidence.clamp(0, 100).toDouble();
    return DawaCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$resultSourceLabel Confidence',
                  style: DawaTextStyles.cardTitle,
                ),
              ),
              Text(
                '${confidence.toStringAsFixed(1)}%',
                style: DawaTextStyles.statNumber.copyWith(
                  color: _confidenceColor(),
                  fontSize: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: confidence / 100,
              backgroundColor: DawaTokens.surfaceTertiary,
              color: _confidenceColor(),
              minHeight: 9,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Confidence is interpreted together with clinical judgement and local screening protocols.',
            style: DawaTextStyles.secondary.copyWith(
              color: DawaTokens.textSecondary,
            ),
          ),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '$resultSourceLabel Confidence',
                  style: DawaTextStyles.cardTitle,
                ),
              ),
              DawaStatusBadge(
                status: 'completed',
                label: '${items.length} classes',
              ),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DawaTextStyles.body.copyWith(
                          color: DawaTokens.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (item.isTopPrediction) ...[
                      const SizedBox(width: 8),
                      _predictionMiniBadge(
                        'Top match',
                        DawaTokens.brandPrimaryPale,
                        DawaTokens.brandPrimary,
                      ),
                    ],
                    if (showRiskBadge) ...[
                      const SizedBox(width: 8),
                      _predictionMiniBadge(
                        _predictionRiskLabel(riskLevel),
                        _predictionBadgeBackground(riskLevel),
                        _predictionBadgeForeground(riskLevel),
                      ),
                    ],
                  ],
                ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          Text(
            label,
            style: DawaTextStyles.secondary.copyWith(fontSize: 12),
          ),
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
