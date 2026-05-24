import '/auth/firebase_auth/auth_util.dart';
import '/components/dawa_design_system.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'cacx_model.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

// ─── HUGGING FACE / GRADIO SERVICE ────────────────────────────────────────────
class HuggingFaceService {
  static const String _spaceBaseUrl = 'https://kmunzwa-medsiglip-demo.hf.space';

  // Maps whatever the Gradio Space returns → display-friendly canonical label.
  // The Space outputs: Normal, CIN1, CIN2, CIN3, Cancer  (confirmed from /info page)
  static const Map<String, String> _labelMap = {
    'normal': 'Negative',
    'cin1': 'CIN1',
    'cin2': 'CIN2',
    'cin3': 'CIN3',
    'cancer': 'Positive',
    // Fallbacks in case the Space uses different casing
    'negative': 'Negative',
    'positive': 'Positive',
    'label_0': 'Negative',
    'label_1': 'CIN1',
    'label_2': 'CIN2',
    'label_3': 'CIN3',
    'label_4': 'Positive',
  };

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

      final uploadStreamedResponse = await uploadRequest.send();
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
      final predictResponse = await http.post(
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
      );

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
      final resultResponse = await http.get(resultUri);

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
      String mappedLabel;
      double confidence;

      if (resultData is Map<String, dynamic>) {
        final String rawLabel = (resultData['label'] as String).trim();
        mappedLabel = _labelMap[rawLabel.toLowerCase()] ?? rawLabel;

        final List<dynamic>? confidences =
            resultData['confidences'] as List<dynamic>?;
        if (confidences != null && confidences.isNotEmpty) {
          final topConf = confidences.firstWhere(
            (c) =>
                (c['label'] as String).toLowerCase() == rawLabel.toLowerCase(),
            orElse: () => confidences.first,
          );
          confidence = (topConf['confidence'] as num) * 100;
        } else {
          confidence = 0.0;
        }
      } else if (resultData is List<dynamic>) {
        final top = resultData.reduce(
          (a, b) => (a['score'] as num) >= (b['score'] as num) ? a : b,
        );
        final rawLabel = (top['label'] as String).toLowerCase().trim();
        mappedLabel = _labelMap[rawLabel] ?? rawLabel;
        confidence = (top['score'] as num) * 100;
      } else {
        throw Exception('Unexpected Gradio response shape: $resultData');
      }

      debugPrint('Gradio → label: $mappedLabel  confidence: $confidence%');
      return _processResult(base64Image, mappedLabel, confidence);
    } catch (e) {
      debugPrint('Gradio Error: $e');
      return AnalysisResult(
        imageUrl: base64Image,
        label: 'Analysis Failed',
        confidence: 0,
        suspicionLevel: SuspicionLevel.low,
        recommendation:
            'Could not connect to AI model. Please check your connection and try again.',
        error: e.toString(),
      );
    }
  }

  static AnalysisResult _processResult(
      String imageUrl, String label, double confidence) {
    SuspicionLevel suspicion;
    String displayLabel;
    String recommendation;

    switch (label) {
      case 'Negative':
        suspicion = SuspicionLevel.low;
        displayLabel = 'Normal / Negative VIA';
        recommendation =
            'No acetowhite lesion or other abnormality seen. Routine follow-up: repeat VIA in 3 years per national MoH guidelines. Provide patient education on cervical cancer warning signs (e.g., post-coital bleeding, intermenstrual bleeding, foul discharge). Document findings in patient record. No referral needed.';
        break;
      case 'CIN1':
        suspicion = SuspicionLevel.medium;
        displayLabel = 'Low Grade Lesion (CIN1)';
        recommendation =
            'Well-defined, faint/thin acetowhite lesions. Management: Repeat VIA in 12 months. Counsel patient on likely regression, but emphasize importance of returning for repeat screening. Advise smoking cessation if applicable, and discuss HPV transmission. Schedule recall appointment before discharge. No immediate colposcopy unless patient is HIV-positive, immunocompromised, or persistent at 12-24 months.';
        break;
      case 'CIN2':
        suspicion = SuspicionLevel.high;
        displayLabel = 'High Grade Lesion (CIN2)';
        recommendation =
            "Distinct, dense, opaque acetowhite lesions with irregular borders. Action: Refer for colposcopy and directed biopsy within 4 weeks. If colposcopy confirms CIN2+ and patient has completed childbearing or lesion is fully visible, proceed with LEEP/cryotherapy same day. Document lesion size, location, and extension onto fornices. Offer HPV testing if available. Exclude pregnancy before treatment.";
        break;
      case 'CIN3':
        suspicion = SuspicionLevel.high;
        displayLabel = 'High Grade Lesion (CIN3)';
        recommendation =
            "Dense, acetowhite epithelium with sharp borders. May involve crypts. Action: Urgent colposcopy referral within 2 weeks. Biopsy mandatory. 'See and Treat' acceptable if colposcopy suspicious for invasion. Do not delay for results if lesion is large or concerning. Check HIV status — treat earlier if positive. Discuss risk of progression if untreated. Prepare for possible LEEP or cone biopsy.";
        break;
      case 'Positive':
        suspicion = SuspicionLevel.high;
        displayLabel = 'Positive - Cancer Suspected';
        recommendation =
            "Abnormal vessel patterns, irregular surface, ulceration, or friable mass. Likely invasive cancer. Action: URGENT referral — complete oncological referral form immediately. Do not perform LEEP/cryotherapy. Perform guided punch biopsy only if haemorrhage can be controlled. Send biopsy with 'suspicious for invasive cancer' noted. Contact gynaecology oncology team by phone within 24 hours. Advise patient not to wait. Document exam under anaesthesia status and any renal function if contrast imaging planned.";
        break;
      default:
        suspicion = SuspicionLevel.low;
        displayLabel = 'Inconclusive - $label';
        recommendation =
            'Image quality insufficient or interpretation unclear. Likely causes: excess mucus, poor illumination, incomplete acetic acid application, or blurred image. Action: Repeat VIA with clearer visualization. Clean cervix with saline-soaked swab, reapply 5% acetic acid, wait 60 seconds, and reassess. If repeatedly inconclusive, refer for colposcopy. Document reason for inconclusive result in chart.';
    }

    return AnalysisResult(
      imageUrl: imageUrl,
      label: displayLabel,
      confidence: double.parse(confidence.toStringAsFixed(1)),
      suspicionLevel: suspicion,
      recommendation: recommendation,
    );
  }
}

// ??? IMAGE SOURCE PICKER ??????????????????????????????????????????????????????
/// Shows a bottom sheet that lets the user choose between camera and gallery.
/// Returns a base64-encoded data URL string, or null if cancelled.
Future<String?> showImageSourcePicker(BuildContext context) async {
  return showModalBottomSheet<String?>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Image Source',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'How would you like to provide the cervix image?',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                // ?? Camera ??
                Expanded(
                  child: _ImageSourceButton(
                    icon: Icons.camera_alt,
                    label: 'Take Photo',
                    subtitle: 'Use device camera',
                    color: DawaTokens.brandPrimary,
                    onTap: () async {
                      final image = await ImagePickerService.captureImage();
                      Navigator.pop(ctx, image);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // ?? Gallery ??
                Expanded(
                  child: _ImageSourceButton(
                    icon: Icons.photo_library,
                    label: 'Upload Image',
                    subtitle: 'Choose from gallery',
                    color: DawaTokens.brandPrimary,
                    onTap: () async {
                      final image = await ImagePickerService.pickImage();
                      Navigator.pop(ctx, image);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

class _ImageSourceButton extends StatelessWidget {
  const _ImageSourceButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ??? APP MODES ????????????????????????????????????????????????????????????????
enum ScreeningMode { via, training }

enum QuickAccessServiceType { cervicalCancer, ultrasound, hemonix, ctScan }

enum QuickAccessDashboardTab { overview, records, results, search }

enum QuickAccessResultsFilter { all, completed, needsReview }

// ??? MAIN APP WIDGET ??????????????????????????????????????????????????????????
class CaCxApp extends StatefulWidget {
  const CaCxApp({super.key});

  @override
  _CaCxAppState createState() => _CaCxAppState();
}

class _CaCxAppState extends State<CaCxApp> {
  AppState _appState = AppState.dashboard;
  DashboardTab _activeTab = DashboardTab.home;

  // Current mode determines how the results screen is framed.
  ScreeningMode _screeningMode = ScreeningMode.via;

  String _analyzingStatus = 'Running VIA classification via AI model';

  // Data Lists
  List<Patient> _patients = [];
  List<VIATestRecord> _historyRecords = [];
  List<ScreeningData> _screeningData = [];

  // Selected Data
  String? _selectedImage;
  Patient? _selectedPatient;
  AnalysisResult? _analysisResult;
  String _patientSearchText = '';
  bool _patientNeedsReviewOnly = false;

  // UI States
  bool _isAnalyzing = false;
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
  }

  @override
  void dispose() {
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
    });
  }

  void _handleTabChange(DashboardTab tab) => setState(() => _activeTab = tab);

  void _handleLogout() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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
    showDawaToast(context, 'Opened patient registry for ${record.patientName}');
  }

  void _handleViaFollowUp(VIATestRecord record) {
    final needsReview = _recordNeedsReview(record);
    if (needsReview) {
      showDawaToast(
        context,
        'Follow-up planning started for ${record.patientName}',
      );
    } else {
      showDawaToast(
        context,
        'Marked ${record.patientName} for routine follow-up',
      );
    }
  }

  // ?? Unified image-picker entry point ????????????????????????????????????????
  Future<void> _openImageSourcePicker({required ScreeningMode mode}) async {
    final image = await showImageSourcePicker(context);
    if (image == null) return;

    setState(() {
      _selectedImage = image;
      _screeningMode = mode;
      _isAnalyzing = true;
    });

    await _analyzeImage();
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;

    try {
      final result = await HuggingFaceService.analyzeVIAImage(_selectedImage!);
      setState(() {
        _analysisResult = result;
        _isAnalyzing = false;
        _appState = AppState.results;
      });
    } catch (e) {
      debugPrint('HF Error: $e');
      setState(() => _analyzingStatus = 'AI model is warming up, please wait');
      // Fallback mock result for demo / offline dev
      final mockResult = AnalysisResult(
        imageUrl: _selectedImage!,
        label: 'High Grade Lesion (CIN2+)',
        confidence: 94.2,
        suspicionLevel: SuspicionLevel.high,
        recommendation:
            "Refer for colposcopy and biopsy immediately. Consider 'See and Treat' if eligible.",
      );
      setState(() {
        _analysisResult = mockResult;
        _isAnalyzing = false;
        _appState = AppState.results;
      });
    }
  }

  void _saveAnalysisResult() {
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
    // Show a full-screen loader while the HF endpoint is running
    if (_isAnalyzing) return _buildAnalyzingScreen();

    switch (_appState) {
      case AppState.splash:
        return _buildSplashScreen();
      case AppState.results:
        return _buildResultsScreen();
      default:
        return _buildMainLayout();
    }
  }

  // ??? ANALYZING OVERLAY ????????????????????????????????????????????????????
  Widget _buildAnalyzingScreen() {
    return Scaffold(
      backgroundColor: DawaTokens.brandPrimary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_selectedImage != null)
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: MemoryImage(
                      base64Decode(_selectedImage!.split(',').last),
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 24),
            const Text(
              'Analysing Image',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _screeningMode == ScreeningMode.training
                  ? 'Running training feedback via AI model'
                  : 'Running VIA classification via AI model',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: DawaTokens.brandPrimary,
                  child: Text('B', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Back to Home',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Dawa Clinic',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Back to Home',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: _handleLogout,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to Home',
            onPressed: _handleLogout,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: DawaTokens.brandPrimary,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 40,
            height: 40,
            child: Image.asset('assets/images/dawa_cross.png',
                fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          const Text(
            'Dawa CaCx',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87),
          ),
          const Spacer(),
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
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(
              top: BorderSide(color: color, width: 3),
            ),
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
                        onTap: () => showDawaToast(
                              context,
                              'Password changes are managed from Settings',
                            )),
                    ListTile(
                        leading: const Icon(Icons.notifications),
                        title: const Text('Notification Preferences'),
                        onTap: () => showDawaToast(
                              context,
                              'Notification preferences will be available in Settings',
                            )),
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

  // ??? RESULTS SCREEN ???????????????????????????????????????????????????????
  Widget _buildResultsScreen() {
    if (_analysisResult == null) {
      return const Center(child: Text('No analysis results'));
    }

    final isTraining = _screeningMode == ScreeningMode.training;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _appState = AppState.dashboard;
            _analysisResult = null;
          }),
        ),
        title: Text(isTraining ? 'Training Feedback' : 'Analysis Results'),
        actions: [
          if (!isTraining) ...[
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => showDawaToast(
                context,
                'Analysis summary ready to share',
              ),
            ),
            IconButton(
                icon: const Icon(Icons.save), onPressed: _saveAnalysisResult),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Training mode banner
            if (isTraining)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DawaTokens.statusSuccessBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DawaTokens.statusSuccess),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.school, color: DawaTokens.statusSuccessText),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Training Mode - results are for educational purposes only and will not be saved to patient records.',
                        style: TextStyle(
                          color: DawaTokens.statusSuccessText,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Image preview
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                image: _selectedImage != null
                    ? DecorationImage(
                        image: MemoryImage(
                          base64Decode(_selectedImage!.split(',').last),
                        ),
                        fit: BoxFit.contain,
                      )
                    : null,
              ),
              child: _selectedImage == null
                  ? const Center(
                      child: Icon(Icons.image, color: Colors.white, size: 64))
                  : null,
            ),

            const SizedBox(height: 24),

            // Confidence
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('AI Confidence Score',
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold)),
                        Text('${_analysisResult!.confidence}%',
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: _analysisResult!.confidence / 100,
                      backgroundColor: Colors.grey[200],
                      color: _analysisResult!.confidence > 80
                          ? DawaTokens.statusSuccess
                          : _analysisResult!.confidence > 50
                              ? DawaTokens.statusWarning
                              : DawaTokens.statusDanger,
                      minHeight: 10,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Classification
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _analysisResult!.suspicionColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.analytics,
                          color: _analysisResult!.suspicionColor, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isTraining
                                ? 'Training Classification'
                                : 'Staging Classification',
                            style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _analysisResult!.label,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _analysisResult!.suspicionColor),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Based on visual pattern analysis consistent with ${_analysisResult!.suspicionLevelString} risk markers.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Recommendation
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isTraining
                              ? Icons.tips_and_updates
                              : Icons.description,
                          color: DawaTokens.brandPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isTraining
                              ? 'Learning Guidance'
                              : 'Clinical Recommendation',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _analysisResult!.recommendation,
                      style:
                          const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _infoTile(
                            isTraining ? 'Practice Tip' : 'Next Step',
                            isTraining
                                ? 'Review VIA criteria'
                                : 'Schedule Follow-up',
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
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Disclaimer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DawaTokens.statusInfoBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DawaTokens.statusInfo),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: DawaTokens.statusInfo),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isTraining
                          ? 'Training Note: Compare this AI feedback with your own assessment to build diagnostic confidence.'
                          : 'Midwife Note: This analysis is an assistive tool. Always verify results with your clinical judgment and standard diagnostic procedures.',
                      style: const TextStyle(
                        color: DawaTokens.statusInfo,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Training: try another image button
            if (isTraining) ...[
              const SizedBox(height: 24),
              SizedBox(
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
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
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
      textDirection: TextDirection.ltr,
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

class QuickAccessToolSummary {
  const QuickAccessToolSummary({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.records,
    required this.completed,
    required this.needsReview,
    required this.recentPatient,
    required this.recentResult,
    required this.recentDate,
    required this.recordLabel,
  });

  final QuickAccessServiceType type;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int records;
  final int completed;
  final int needsReview;
  final String recentPatient;
  final String recentResult;
  final DateTime recentDate;
  final String recordLabel;
}

List<QuickAccessToolSummary> getQuickAccessToolSummaries() {
  return [
    QuickAccessServiceType.cervicalCancer,
    QuickAccessServiceType.hemonix,
    QuickAccessServiceType.ctScan,
    QuickAccessServiceType.ultrasound,
  ].map((type) {
    final config = _quickAccessConfig(type);
    final records = _quickAccessRecords(type);
    final recent = records.reduce(
      (a, b) => a.date.isAfter(b.date) ? a : b,
    );
    final needsReview = records.where((record) => record.needsReview).length;

    return QuickAccessToolSummary(
      type: type,
      title: type == QuickAccessServiceType.cervicalCancer
          ? 'CaCx Screening'
          : config.title,
      description: switch (type) {
        QuickAccessServiceType.cervicalCancer =>
          'Cervical cancer VIA screening',
        QuickAccessServiceType.hemonix => 'Haemoglobin & anaemia tracking',
        QuickAccessServiceType.ctScan => 'CT imaging records & results',
        QuickAccessServiceType.ultrasound => 'Scan reports & fetal monitoring',
      },
      icon: config.icon,
      color: config.color,
      records: records.length,
      completed: records.length - needsReview,
      needsReview: needsReview,
      recentPatient: recent.patientName,
      recentResult: recent.result,
      recentDate: recent.date,
      recordLabel: switch (type) {
        QuickAccessServiceType.cervicalCancer => 'Patients',
        QuickAccessServiceType.ultrasound => 'Scans',
        QuickAccessServiceType.hemonix => 'Records',
        QuickAccessServiceType.ctScan => 'Records',
      },
    );
  }).toList();
}

String quickAccessFormatDate(DateTime date) {
  return _quickAccessFormatDate(date);
}

Widget quickAccessServiceWidget(QuickAccessServiceType type) {
  if (type == QuickAccessServiceType.cervicalCancer) {
    return const CaCxApp();
  }
  return QuickAccessServiceApp(service: type);
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

Image base64ToImage(String base64String) {
  return Image.memory(
    base64Decode(base64String.split(',').last),
    fit: BoxFit.cover,
  );
}

class QuickAccessServiceApp extends StatefulWidget {
  const QuickAccessServiceApp({
    super.key,
    required this.service,
  });

  final QuickAccessServiceType service;

  @override
  State<QuickAccessServiceApp> createState() => _QuickAccessServiceAppState();
}

class _QuickAccessServiceAppState extends State<QuickAccessServiceApp> {
  QuickAccessDashboardTab _activeTab = QuickAccessDashboardTab.overview;
  QuickAccessResultsFilter _resultsFilter = QuickAccessResultsFilter.all;
  final TextEditingController _resultsSearchController =
      TextEditingController();

  String? _selectedImage;
  String? _selectedPatient;
  String? _analysisResult;
  bool _isAnalyzing = false;

  @override
  void didUpdateWidget(covariant QuickAccessServiceApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      _resetServiceState();
    }
  }

  @override
  void dispose() {
    _resultsSearchController.dispose();
    super.dispose();
  }

  void _resetServiceState() {
    _activeTab = QuickAccessDashboardTab.overview;
    _selectedImage = null;
    _selectedPatient = null;
    _analysisResult = null;
    _isAnalyzing = false;
    _resultsSearchController.clear();
    _resultsFilter = QuickAccessResultsFilter.all;
  }

  void _openQuickAccessPatient(_QuickAccessRecord record) {
    setState(() {
      _selectedPatient = record.patientName;
      _resultsSearchController.text = record.patientName;
      _activeTab = QuickAccessDashboardTab.records;
    });
    showDawaToast(context, 'Opened records for ${record.patientName}');
  }

  void _handleQuickAccessFollowUp(_QuickAccessRecord record) {
    if (record.needsReview) {
      showDawaToast(
        context,
        'Follow-up planning started for ${record.patientName}',
      );
    } else {
      showDawaToast(
        context,
        'Marked ${record.patientName} for routine follow-up',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _quickAccessConfig(widget.service);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SafeArea(
        child: isMobile
            ? Column(
                children: [
                  _buildQuickAccessMobileHeader(config),
                  Expanded(child: _buildContent(config)),
                  _buildMobileNav(config),
                ],
              )
            : Row(
                children: [
                  _buildSidebar(config),
                  const VerticalDivider(width: 1),
                  Expanded(child: _buildContent(config)),
                ],
              ),
      ),
    );
  }

  Widget _buildQuickAccessMobileHeader(_QuickAccessServiceConfig config) {
    return Container(
      color: DawaTokens.surface,
      padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to Home',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: config.color,
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: config.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
            ),
            child: Icon(config.icon, color: config.color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DawaTextStyles.cardTitle.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Quick Access',
                  style: DawaTextStyles.secondary.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(_QuickAccessServiceConfig config) {
    return Container(
      key: const ValueKey('quick-access-sidebar'),
      width: 240,
      color: DawaTokens.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: config.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
                  ),
                  child: Icon(config.icon, color: config.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const Text(
                        'Quick Access',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to Home'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: config.color,
                  side: BorderSide(color: config.color.withOpacity(0.28)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: DawaTokens.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _buildSideNavItem(
                  Icons.dashboard_outlined,
                  'Dashboard',
                  QuickAccessDashboardTab.overview,
                  config,
                ),
                _buildSideNavItem(
                  Icons.people_outline,
                  'Patient Records',
                  QuickAccessDashboardTab.records,
                  config,
                ),
                _buildSideNavItem(
                  Icons.fact_check_outlined,
                  config.resultsLabel,
                  QuickAccessDashboardTab.results,
                  config,
                ),
                _buildSideNavItem(
                  Icons.search,
                  'Search Results',
                  QuickAccessDashboardTab.search,
                  config,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideNavItem(
    IconData icon,
    String label,
    QuickAccessDashboardTab tab,
    _QuickAccessServiceConfig config,
  ) {
    final selected = _activeTab == tab;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
          onTap: () => setState(() => _activeTab = tab),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: selected ? DawaTokens.brandPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 3,
                  height: 26,
                  decoration: BoxDecoration(
                    color:
                        selected ? DawaTokens.textInverse : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  icon,
                  color:
                      selected ? DawaTokens.textInverse : DawaTokens.textMuted,
                  size: 21,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? DawaTokens.textInverse
                          : DawaTokens.textSecondary,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNav(_QuickAccessServiceConfig config) {
    final items = [
      (Icons.dashboard_outlined, 'Home', QuickAccessDashboardTab.overview),
      (Icons.people_outline, 'Records', QuickAccessDashboardTab.records),
      (Icons.fact_check_outlined, 'Results', QuickAccessDashboardTab.results),
      (Icons.search, 'Search', QuickAccessDashboardTab.search),
    ];

    return Container(
      key: const ValueKey('quick-access-mobile-nav'),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final item in items)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _activeTab = item.$3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.$1,
                      color: _activeTab == item.$3
                          ? DawaTokens.brandPrimary
                          : Colors.grey,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _activeTab == item.$3
                            ? DawaTokens.brandPrimary
                            : Colors.grey,
                        fontSize: 11,
                        fontWeight: _activeTab == item.$3
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(_QuickAccessServiceConfig config) {
    switch (_activeTab) {
      case QuickAccessDashboardTab.overview:
        return _buildOverview(config);
      case QuickAccessDashboardTab.records:
        return _buildRecords(config);
      case QuickAccessDashboardTab.results:
        return _buildResults(config);
      case QuickAccessDashboardTab.search:
        return _buildSearch(config);
    }
  }

  Widget _buildOverview(_QuickAccessServiceConfig config) {
    final records = _quickAccessRecords(config.type);
    final needsReview = records.where((record) => record.needsReview).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${config.title} Dashboard',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome, ${_quickAccessClinicianName()}. ${config.description}',
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 24),
              _buildActionGrid(config),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 640;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildSummaryTile(
                          'Total records',
                          records.length.toString(),
                          Icons.folder_outlined,
                          config.color,
                          narrow),
                      _buildSummaryTile(
                          'Completed',
                          (records.length - needsReview).toString(),
                          Icons.check_circle_outline,
                          DawaTokens.statusSuccess,
                          narrow),
                      _buildSummaryTile(
                          'Needs review',
                          needsReview.toString(),
                          Icons.priority_high,
                          DawaTokens.statusWarning,
                          narrow),
                      _buildSummaryTile(
                          'Follow-ups',
                          needsReview.toString(),
                          Icons.event_available,
                          DawaTokens.brandPrimary,
                          narrow),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recent activity',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(
                        () => _activeTab = QuickAccessDashboardTab.results),
                    child: const Text('View results'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (records.isEmpty)
                _buildNoResultsYet(config)
              else
                Column(
                  children: records
                      .take(3)
                      .map((record) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildResultCard(config, record),
                          ))
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionGrid(_QuickAccessServiceConfig config) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 920
            ? 4
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        final itemWidth =
            (constraints.maxWidth - (12 * (columns - 1))) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildQuickAction(
              config.actions[0],
              config.addDescription,
              Icons.add_circle_outline,
              config.color,
              itemWidth,
              () {
                setState(() {
                  _activeTab = QuickAccessDashboardTab.records;
                  _selectedPatient = 'New ${config.recordName.toLowerCase()}';
                  _selectedImage = null;
                  _analysisResult = null;
                  _isAnalyzing = false;
                });
              },
            ),
            _buildQuickAction(
              config.actions[1],
              'Review patient-linked records and recent activity.',
              Icons.people_outline,
              DawaTokens.brandPrimary,
              itemWidth,
              () =>
                  setState(() => _activeTab = QuickAccessDashboardTab.records),
            ),
            _buildQuickAction(
              config.actions[2],
              'Open searchable and filterable result cards.',
              Icons.fact_check_outlined,
              DawaTokens.brandPrimary,
              itemWidth,
              () =>
                  setState(() => _activeTab = QuickAccessDashboardTab.results),
            ),
            _buildQuickAction(
              config.actions[3],
              'Search matching patients, IDs, record IDs, notes, and AI text.',
              Icons.search,
              DawaTokens.brandPrimary,
              itemWidth,
              () => setState(() => _activeTab = QuickAccessDashboardTab.search),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickAction(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    double width,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 148),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryTile(
    String label,
    String value,
    IconData icon,
    Color color,
    bool narrow,
  ) {
    return DawaStatCard(
      width: narrow ? double.infinity : 190,
      label: label,
      value: value,
      icon: icon,
      color: color,
      accentBorder: true,
    );
  }

  Widget _statusBadgeForRecord(_QuickAccessRecord record) {
    return DawaStatusBadge(
      status: record.needsReview ? 'needs_review' : 'completed',
      label: record.needsReview ? 'Needs review' : 'Completed',
    );
  }

  Widget _confidenceForRecord(_QuickAccessRecord record) {
    return DawaAIConfidenceBar(analysis: record.aiAnalysis);
  }

  Color _actionColor(_QuickAccessServiceConfig config, bool needsReview) {
    if (needsReview) {
      if (config.type == QuickAccessServiceType.hemonix) {
        return DawaTokens.statusDanger;
      }
      return DawaTokens.statusWarning;
    }
    if (config.type == QuickAccessServiceType.hemonix) {
      return DawaTokens.brandPrimary;
    }
    return config.color;
  }

  Widget _resultBadge(
      _QuickAccessServiceConfig config, _QuickAccessRecord record) {
    if (config.type != QuickAccessServiceType.hemonix) {
      final weeks = _weeksFromNotes(record.notes);
      if (weeks == null) return const SizedBox.shrink();
      return DawaStatusBadge(
        status: 'active',
        label: '$weeks weeks',
      );
    }

    final normal = !record.needsReview;
    return DawaStatusBadge(
      status: normal ? 'normal' : 'missing_data',
      label: record.result,
    );
  }

  int? _weeksFromNotes(String notes) {
    final match =
        RegExp(r'(\d+)\s*weeks?', caseSensitive: false).firstMatch(notes);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  Widget _buildRecords(_QuickAccessServiceConfig config) {
    final records = _quickAccessRecords(config.type);
    final hasTransientState =
        _isAnalyzing || _selectedImage != null || _analysisResult != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${config.title} Patient Records',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedPatient == null
                    ? 'Patient-linked ${config.recordName.toLowerCase()} entries are ready for review.'
                    : 'Ready to add ${config.recordName.toLowerCase()} for $_selectedPatient.',
                style: const TextStyle(color: Colors.grey),
              ),
              if (hasTransientState) ...[
                const SizedBox(height: 8),
                const Text(
                  'A previous image, patient, or analysis state is being held for this service.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
              const SizedBox(height: 20),
              if (records.isEmpty)
                _buildNoResultsYet(config)
              else
                Column(
                  children: records
                      .map((record) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildResultCard(config, record),
                          ))
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearch(_QuickAccessServiceConfig config) {
    return _buildResults(config, focusSearch: true);
  }

  Widget _buildResults(
    _QuickAccessServiceConfig config, {
    bool focusSearch = false,
  }) {
    final records = _filteredRecords(config);
    final allRecords = _quickAccessRecords(config.type);
    final completedCount =
        allRecords.where((record) => !record.needsReview).length;
    final reviewCount = allRecords.where((record) => record.needsReview).length;

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                config.resultsLabel,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Overview of ${config.recordName.toLowerCase()} results for ${config.title}.',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 640;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildSummaryTile(
                          'All results',
                          allRecords.length.toString(),
                          Icons.assignment,
                          config.color,
                          narrow),
                      _buildSummaryTile('Completed', completedCount.toString(),
                          Icons.check_circle, DawaTokens.statusSuccess, narrow),
                      _buildSummaryTile(
                          'Needs review',
                          reviewCount.toString(),
                          Icons.priority_high,
                          DawaTokens.statusWarning,
                          narrow),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              TextField(
                key: ValueKey('quick-access-results-search-${config.key}'),
                autofocus: focusSearch,
                controller: _resultsSearchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText:
                      'Search patient, ID, record, result, notes, AI analysis, or confidence',
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
                  fillColor: const Color(0xFFF6F8FB),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildGenericFilterChip(
                    config,
                    'All results',
                    QuickAccessResultsFilter.all,
                  ),
                  _buildGenericFilterChip(
                    config,
                    'Completed',
                    QuickAccessResultsFilter.completed,
                  ),
                  _buildGenericFilterChip(
                    config,
                    'Needs review',
                    QuickAccessResultsFilter.needsReview,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? _buildGenericEmptyState(config, allRecords.isEmpty)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _buildResultCard(config, records[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildGenericFilterChip(
    _QuickAccessServiceConfig config,
    String label,
    QuickAccessResultsFilter filter,
  ) {
    return ChoiceChip(
      key: ValueKey('quick-access-filter-${config.key}-${filter.name}'),
      label: Text(label),
      selected: _resultsFilter == filter,
      selectedColor: config.color.withOpacity(0.12),
      labelStyle: TextStyle(
        color: _resultsFilter == filter ? config.color : Colors.grey,
        fontWeight:
            _resultsFilter == filter ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _resultsFilter = filter),
    );
  }

  List<_QuickAccessRecord> _filteredRecords(_QuickAccessServiceConfig config) {
    final query = _resultsSearchController.text.trim();
    return _quickAccessRecords(config.type).where((record) {
      if (_resultsFilter == QuickAccessResultsFilter.completed &&
          record.needsReview) {
        return false;
      }
      if (_resultsFilter == QuickAccessResultsFilter.needsReview &&
          !record.needsReview) {
        return false;
      }
      return record.matches(query);
    }).toList();
  }

  Widget _buildResultCard(
    _QuickAccessServiceConfig config,
    _QuickAccessRecord record,
  ) {
    return DawaCard(
      urgent: record.needsReview,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DawaAvatarCircle(
                name: record.patientName,
                moduleColor: config.color,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          record.patientName,
                          style: DawaTextStyles.cardTitle,
                        ),
                        _resultBadge(config, record),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Patient ${record.patientId} - Record ${record.recordId}',
                      style: DawaTextStyles.secondary.copyWith(
                        color: DawaTokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _statusBadgeForRecord(record),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _recordField(Icons.calendar_today_outlined, 'Date',
                  _quickAccessFormatDate(record.date)),
              _recordField(Icons.assignment_outlined, 'Result', record.result),
              _recordField(Icons.notes_outlined, 'Notes', record.notes),
            ],
          ),
          const SizedBox(height: 10),
          _confidenceForRecord(record),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openQuickAccessPatient(record),
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('Open patient'),
              ),
              ElevatedButton.icon(
                onPressed: () => _handleQuickAccessFollowUp(record),
                icon: Icon(
                  record.needsReview
                      ? Icons.event_available
                      : Icons.check_circle_outline,
                  size: 18,
                ),
                label: Text(
                  record.needsReview ? 'Plan follow-up' : 'Routine follow-up',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _actionColor(config, record.needsReview),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _recordField(IconData icon, String label, String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: DawaTokens.textMuted),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: DawaTextStyles.secondary.copyWith(
              color: DawaTokens.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DawaTextStyles.secondary,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _legacyQuickAccessResultCard(
    _QuickAccessServiceConfig config,
    _QuickAccessRecord record,
  ) {
    final statusColor = record.needsReview
        ? DawaTokens.statusWarning
        : DawaTokens.statusSuccess;
    final statusLabel = record.needsReview ? 'Needs review' : 'Completed';

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
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
                  backgroundColor: config.color.withOpacity(0.12),
                  child: Icon(config.icon, color: config.color),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.patientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Patient ${record.patientId} - Record ${record.recordId}',
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
            Text('Date: ${_quickAccessFormatDate(record.date)}'),
            const SizedBox(height: 6),
            Text(
              'Result: ${record.result}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text('Notes: ${record.notes}'),
            const SizedBox(height: 6),
            Text(
              'AI analysis: ${record.aiAnalysis}',
              style: TextStyle(color: config.color),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openQuickAccessPatient(record),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Open patient'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _handleQuickAccessFollowUp(record),
                  icon: Icon(record.needsReview
                      ? Icons.event_available
                      : Icons.check_circle_outline),
                  label: Text(record.needsReview
                      ? 'Plan follow-up'
                      : 'Routine follow-up'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: config.color,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsYet(_QuickAccessServiceConfig config) {
    return _buildEmptyPanel(
      icon: Icons.assignment_outlined,
      title: 'No results yet',
      message:
          '${config.recordName} entries will appear here after the first record is added.',
      config: config,
    );
  }

  Widget _buildGenericEmptyState(
    _QuickAccessServiceConfig config,
    bool noRecords,
  ) {
    final hasFilters = _resultsSearchController.text.trim().isNotEmpty ||
        _resultsFilter != QuickAccessResultsFilter.all;
    return Center(
      child: _buildEmptyPanel(
        icon: hasFilters ? Icons.search_off : Icons.assignment_outlined,
        title: noRecords ? 'No results yet' : 'No matching results',
        message: hasFilters
            ? 'Clear filters/search or try a different patient, record ID, result, note, or AI analysis term.'
            : '${config.recordName} results will appear here once records are available.',
        config: config,
        action: hasFilters
            ? TextButton.icon(
                onPressed: () {
                  _resultsSearchController.clear();
                  setState(() => _resultsFilter = QuickAccessResultsFilter.all);
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear filters/search'),
              )
            : null,
      ),
    );
  }

  Widget _buildEmptyPanel({
    required IconData icon,
    required String title,
    required String message,
    required _QuickAccessServiceConfig config,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: config.color),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          if (action != null) ...[
            const SizedBox(height: 14),
            action,
          ],
        ],
      ),
    );
  }
}

class _QuickAccessServiceConfig {
  const _QuickAccessServiceConfig({
    required this.type,
    required this.key,
    required this.title,
    required this.description,
    required this.recordName,
    required this.resultsLabel,
    required this.addDescription,
    required this.actions,
    required this.icon,
    required this.color,
  });

  final QuickAccessServiceType type;
  final String key;
  final String title;
  final String description;
  final String recordName;
  final String resultsLabel;
  final String addDescription;
  final List<String> actions;
  final IconData icon;
  final Color color;
}

class _QuickAccessRecord {
  const _QuickAccessRecord({
    required this.patientName,
    required this.patientId,
    required this.recordId,
    required this.date,
    required this.result,
    required this.notes,
    required this.aiAnalysis,
    required this.needsReview,
  });

  final String patientName;
  final String patientId;
  final String recordId;
  final DateTime date;
  final String result;
  final String notes;
  final String aiAnalysis;
  final bool needsReview;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;

    final haystack = [
      patientName,
      patientId,
      recordId,
      result,
      notes,
      aiAnalysis,
      needsReview ? 'needs review' : 'completed',
    ].join(' ').toLowerCase();

    return haystack.contains(normalized);
  }
}

_QuickAccessServiceConfig _quickAccessConfig(QuickAccessServiceType type) {
  switch (type) {
    case QuickAccessServiceType.cervicalCancer:
      return const _QuickAccessServiceConfig(
        type: QuickAccessServiceType.cervicalCancer,
        key: 'cervical-cancer',
        title: 'Cervical Cancer',
        description:
            'Track VIA screening, AI confidence, suspicious findings, and follow-up planning.',
        recordName: 'Screening Record',
        resultsLabel: 'Screening Results',
        addDescription: 'Create a new VIA screening record.',
        actions: [
          'Add Screening Record',
          'View Patient Records',
          'View Screening Results',
          'Search Results',
        ],
        icon: Icons.favorite_border,
        color: DawaTokens.brandPrimary,
      );
    case QuickAccessServiceType.ultrasound:
      return const _QuickAccessServiceConfig(
        type: QuickAccessServiceType.ultrasound,
        key: 'ultrasound',
        title: 'Ultrasound',
        description:
            'Review obstetric scan records, measurements, reports, and follow-up flags.',
        recordName: 'Scan Record',
        resultsLabel: 'Scan Reports',
        addDescription: 'Create a new ultrasound scan record.',
        actions: [
          'Add Scan Record',
          'View Patient Records',
          'View Scan Reports',
          'Search Results',
        ],
        icon: Icons.sensors_rounded,
        color: DawaTokens.brandPrimary,
      );
    case QuickAccessServiceType.hemonix:
      return const _QuickAccessServiceConfig(
        type: QuickAccessServiceType.hemonix,
        key: 'hemonix',
        title: 'HemoNix',
        description:
            'Monitor haemoglobin results, anaemia risk, and treatment follow-up.',
        recordName: 'Hb Record',
        resultsLabel: 'Hb Results',
        addDescription: 'Create a new haemoglobin record.',
        actions: [
          'Add Hb Record',
          'View Patient Records',
          'View Hb Results',
          'Search Results',
        ],
        icon: Icons.bloodtype_outlined,
        color: DawaTokens.brandPrimary,
      );
    case QuickAccessServiceType.ctScan:
      return const _QuickAccessServiceConfig(
        type: QuickAccessServiceType.ctScan,
        key: 'ct-scan',
        title: 'CT Scan',
        description:
            'Organize CT imaging records, radiology results, and urgent review tasks.',
        recordName: 'CT Record',
        resultsLabel: 'CT Results',
        addDescription: 'Create a new CT scan record.',
        actions: [
          'Add CT Record',
          'View Patient Records',
          'View CT Results',
          'Search Results',
        ],
        icon: Icons.desktop_windows_outlined,
        color: DawaTokens.brandPrimary,
      );
  }
}

List<_QuickAccessRecord> _quickAccessRecords(QuickAccessServiceType type) {
  switch (type) {
    case QuickAccessServiceType.cervicalCancer:
      return [
        _QuickAccessRecord(
          patientName: 'Alice Mumba',
          patientId: 'DM-1000',
          recordId: 'CACX-2401',
          date: DateTime(2026, 5, 18),
          result: 'Negative',
          notes: 'Routine VIA screening completed.',
          aiAnalysis: 'AI confidence 94% - low-risk visual pattern.',
          needsReview: false,
        ),
        _QuickAccessRecord(
          patientName: 'Chipo Banda',
          patientId: 'DM-1002',
          recordId: 'CACX-2402',
          date: DateTime(2026, 5, 17),
          result: 'CIN2 suspected',
          notes: 'Dense acetowhite area; needs colposcopy review.',
          aiAnalysis: 'AI confidence 89% - high-risk markers detected.',
          needsReview: true,
        ),
        _QuickAccessRecord(
          patientName: 'Dorothy Lungu',
          patientId: 'DM-1003',
          recordId: 'CACX-2403',
          date: DateTime(2026, 5, 14),
          result: 'Negative',
          notes: 'Routine follow-up in three years.',
          aiAnalysis: 'AI confidence 92% - no abnormality detected.',
          needsReview: false,
        ),
      ];
    case QuickAccessServiceType.ultrasound:
      return [
        _QuickAccessRecord(
          patientName: 'Lillian Chama',
          patientId: 'DM-1204',
          recordId: 'US-7741',
          date: DateTime(2026, 5, 18),
          result: 'Completed scan',
          notes: 'Single live intrauterine pregnancy, 28 weeks.',
          aiAnalysis: 'Measurements consistent; confidence 91%.',
          needsReview: false,
        ),
        _QuickAccessRecord(
          patientName: 'Sarah Mbewe',
          patientId: 'DM-1218',
          recordId: 'US-7742',
          date: DateTime(2026, 5, 16),
          result: 'Needs review',
          notes: 'Growth measurements below expected range.',
          aiAnalysis: 'AI flagged asymmetric growth; confidence 84%.',
          needsReview: true,
        ),
        _QuickAccessRecord(
          patientName: 'Nancy Kaira',
          patientId: 'DM-1214',
          recordId: 'US-7743',
          date: DateTime(2026, 5, 12),
          result: 'Completed scan',
          notes: 'Placenta anterior, normal fluid estimate.',
          aiAnalysis: 'Routine report generated; confidence 88%.',
          needsReview: false,
        ),
      ];
    case QuickAccessServiceType.hemonix:
      return [
        _QuickAccessRecord(
          patientName: 'Beatrice Zulu',
          patientId: 'DM-1001',
          recordId: 'HB-3110',
          date: DateTime(2026, 5, 18),
          result: 'Hb 12.1 g/dL',
          notes: 'Result within expected range.',
          aiAnalysis: 'Anaemia risk low; confidence 93%.',
          needsReview: false,
        ),
        _QuickAccessRecord(
          patientName: 'Grace Mwape',
          patientId: 'DM-1006',
          recordId: 'HB-3111',
          date: DateTime(2026, 5, 15),
          result: 'Hb 8.7 g/dL',
          notes: 'Moderate anaemia; treatment plan required.',
          aiAnalysis: 'Needs review - anaemia risk high; confidence 90%.',
          needsReview: true,
        ),
        _QuickAccessRecord(
          patientName: 'Mary Soko',
          patientId: 'DM-1012',
          recordId: 'HB-3112',
          date: DateTime(2026, 5, 11),
          result: 'Hb 11.4 g/dL',
          notes: 'Routine antenatal haemoglobin check.',
          aiAnalysis: 'Borderline but stable; confidence 86%.',
          needsReview: false,
        ),
      ];
    case QuickAccessServiceType.ctScan:
      return [
        _QuickAccessRecord(
          patientName: 'Patricia Gondwe',
          patientId: 'DM-1015',
          recordId: 'CT-5401',
          date: DateTime(2026, 5, 18),
          result: 'Report completed',
          notes: 'No acute intracranial finding reported.',
          aiAnalysis: 'Radiology workflow complete; confidence 87%.',
          needsReview: false,
        ),
        _QuickAccessRecord(
          patientName: 'Olive Mwanza',
          patientId: 'DM-1014',
          recordId: 'CT-5402',
          date: DateTime(2026, 5, 13),
          result: 'Needs review',
          notes: 'Contrast follow-up recommended by reporting clinician.',
          aiAnalysis: 'Potential abnormality flagged; confidence 82%.',
          needsReview: true,
        ),
        _QuickAccessRecord(
          patientName: 'Ruth Kangwa',
          patientId: 'DM-1017',
          recordId: 'CT-5403',
          date: DateTime(2026, 5, 10),
          result: 'Report completed',
          notes: 'Routine scan archived.',
          aiAnalysis: 'No urgent flag; confidence 89%.',
          needsReview: false,
        ),
      ];
  }
}

String _quickAccessClinicianName() {
  final displayName = currentUserDisplayName.trim();
  if (displayName.isNotEmpty) return displayName;

  final email = currentUserEmail.trim();
  if (email.isNotEmpty) return email;

  return 'Clinician';
}

String _quickAccessFormatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
