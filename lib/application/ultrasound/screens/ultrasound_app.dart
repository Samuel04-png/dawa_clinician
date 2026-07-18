import 'dart:convert';

import 'package:flutter/material.dart';

import '/reset_password/reset_password_widget.dart';
import '/components/dawa_design_system.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '../mock/ultrasound_mock_data.dart';
import '../models/ultrasound_models.dart';
import '../services/ultrasound_ai_service.dart';
import '../services/ultrasound_image_picker_service.dart';

// ─── MAIN WIDGET ─────────────────────────────────────────────────────────────

enum _UltrasoundWorkflowChoice { normal, aiGuided }

class UltrasoundApp extends StatefulWidget {
  const UltrasoundApp({
    super.key,
    this.initialPatient,
    this.initialMode = UltrasoundLaunchMode.dashboard,
    this.onExit,
  });

  static String routeName = 'Ultrasound';
  static String routePath = '/ultrasound';

  final PregnantPatient? initialPatient;
  final UltrasoundLaunchMode initialMode;
  final VoidCallback? onExit;

  @override
  State<UltrasoundApp> createState() => _UltrasoundAppState();
}

class _UltrasoundAppState extends State<UltrasoundApp> {
  UltrasoundAppState _appState = UltrasoundAppState.splash;
  UltrasoundDashboardTab _activeTab = UltrasoundDashboardTab.home;

  List<PregnantPatient> _patients = [];
  List<UltrasoundScanRecord> _scanHistory = [];

  PregnantPatient? _selectedPatient;
  String? _capturedImage;
  UltrasoundAnalysisResult? _analysisResult;
  ScanType _activeScanType = ScanType.manual;

  bool _isAnalyzing = false;

  // AI Sweep state
  int _currentSweepStep = 0;
  List<SweepStep> _sweepSteps = [];
  bool _sweepComplete = false;
  bool _initialLaunchHandled = false;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _gaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sweepSteps = SweepGuidanceProtocol.getObstetricSweepSteps();
    _selectedPatient = widget.initialPatient;
    _loadData();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _appState = UltrasoundAppState.dashboard);
        _handleInitialLaunch();
      }
    });
  }

  void _loadData() {
    setState(() {
      final initialPatient = widget.initialPatient;
      final mockPatients = UltrasoundMockData.getPatients();
      _patients = initialPatient != null &&
              !mockPatients.any((patient) => patient.id == initialPatient.id)
          ? [initialPatient, ...mockPatients]
          : mockPatients;
      _scanHistory = UltrasoundMockData.getScanHistory();
    });
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
    // In production this connects to the probe's SDK/stream.
    // For now we fall back to the camera (same physical feed on a tablet).
    _activeScanType = _appState == UltrasoundAppState.aiGuidedScan
        ? ScanType.aiGuided
        : ScanType.manual;
    final image = await UltrasoundImagePickerService.captureImage();
    if (image != null && mounted) {
      setState(() => _capturedImage = image);
      await _runAnalysis();
    }
  }

  Future<void> _pickFromGallery() async {
    _activeScanType = _appState == UltrasoundAppState.aiGuidedScan
        ? ScanType.aiGuided
        : ScanType.manual;
    final image = await UltrasoundImagePickerService.pickImage();
    if (image != null && mounted) {
      setState(() => _capturedImage = image);
      await _runAnalysis();
    }
  }

  Future<void> _runAnalysis() async {
    if (_capturedImage == null) return;
    setState(() => _isAnalyzing = true);

    final result = await UltrasoundAIService.analyzeUltrasoundImage(
      _capturedImage!,
      _selectedPatient?.gestationalAgeWeeks,
    );

    setState(() {
      _analysisResult = result;
      _isAnalyzing = false;
      _appState = UltrasoundAppState.results;
    });
  }

  void _saveResult() {
    if (_analysisResult == null || _selectedPatient == null) return;

    final record = UltrasoundScanRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: _selectedPatient!.id,
      patientName: _selectedPatient!.name,
      date: DateTime.now(),
      scanType: _activeScanType,
      result: _analysisResult!.overallLevel == FindingLevel.normal
          ? 'Normal'
          : 'Abnormal',
      notes: _analysisResult!.overallAssessment,
      aiAnalysis: _analysisResult!.recommendation,
      gestationalAgeWeeks: _analysisResult!.estimatedGestationalAge,
      measurements: _analysisResult!.measurements,
    );

    setState(() {
      _scanHistory = [record, ..._scanHistory];
      _appState = UltrasoundAppState.dashboard;
      _activeTab = UltrasoundDashboardTab.patients;
      _analysisResult = null;
      _capturedImage = null;
      _selectedPatient = null;
      _activeScanType = ScanType.manual;
      _currentSweepStep = 0;
      _sweepComplete = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scan record saved successfully!')),
    );
  }

  void _startManualScan() {
    setState(() {
      _activeScanType = ScanType.manual;
      _appState = UltrasoundAppState.manualScan;
    });
  }

  void _startAIGuidedScan() {
    setState(() {
      _activeScanType = ScanType.aiGuided;
      _currentSweepStep = 0;
      _sweepComplete = false;
      _appState = UltrasoundAppState.aiGuidedScan;
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
                            'Step-by-step sweep guidance with AI-supported analysis.',
                        color: DawaTokens.statusSuccess,
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
    final isMobile = MediaQuery.of(context).size.width <= 768;

    return Scaffold(
      backgroundColor: DawaTokens.surfaceSecondary,
      body: Row(
        children: [
          if (!isMobile) ...[_buildSidebar(), const VerticalDivider(width: 1)],
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
      bottomNavigationBar: isMobile ? _buildMobileBottomNav() : null,
    );
  }

  // ─── SIDEBAR ──────────────────────────────────────────────────────────────

  Widget _buildSidebar() {
    return Container(
      width: 280,
      color: DawaTokens.surface,
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
                    child: Image.asset('assets/images/dawa_cross.png',
                        fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dawa Ultrasound',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black87),
                      ),
                      Text(
                        'Obstetrics Module',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey, letterSpacing: 1),
                      ),
                    ],
                  ),
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
                _buildNavItem(
                    Icons.dashboard, 'Dashboard', UltrasoundDashboardTab.home),
                _buildNavItem(Icons.people, 'Patient Registry',
                    UltrasoundDashboardTab.patients),
                _buildNavItem(Icons.history, 'Scan History',
                    UltrasoundDashboardTab.history),
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

  Widget _buildNavItem(
      IconData icon, String label, UltrasoundDashboardTab tab) {
    final isActive = _activeTab == tab;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isActive ? DawaTokens.brandPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: Icon(
            icon,
            color: isActive ? DawaTokens.textInverse : DawaTokens.textMuted,
          ),
          title: Text(label,
              style: TextStyle(
                color: isActive
                    ? DawaTokens.textInverse
                    : DawaTokens.textSecondary,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              )),
          onTap: () => setState(() => _activeTab = tab),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ─── MOBILE HEADER ────────────────────────────────────────────────────────

  Widget _buildMobileHeader() {
    final compact = MediaQuery.of(context).size.width < 430;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: DawaTokens.surface,
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
              'Dawa Ultrasound',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // ─── MOBILE BOTTOM NAV ────────────────────────────────────────────────────

  Widget _buildMobileBottomNav() {
    return Container(
      color: DawaTokens.surface,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMobileNavItem(
              Icons.dashboard, 'Dashboard', UltrasoundDashboardTab.home),
          _buildMobileNavItem(
              Icons.people, 'Patients', UltrasoundDashboardTab.patients),
          _buildMobileNavItem(
              Icons.history, 'History', UltrasoundDashboardTab.history),
        ],
      ),
    );
  }

  Widget _buildMobileNavItem(
      IconData icon, String label, UltrasoundDashboardTab tab) {
    final isActive = _activeTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tab),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: isActive ? DawaTokens.brandPrimary : Colors.grey,
              size: 24),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: isActive ? DawaTokens.brandPrimary : Colors.grey,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  // ─── TAB ROUTER ───────────────────────────────────────────────────────────

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

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ultrasound Dashboard',
            style: DawaTextStyles.pageTitle.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage obstetric ultrasound scans, patient records, AI-guided analysis, and scan history.',
            style: DawaTextStyles.secondary.copyWith(
              color: DawaTokens.textMuted,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),

          // ── Action Cards ────────────────────────────────────────────────
          _buildDashboardQuickActions(),

          const SizedBox(height: 24),

          // ── Stats ────────────────────────────────────────────────────────
          _buildStatsGrid(),

          const SizedBox(height: 32),

          // ── Quick Tip ────────────────────────────────────────────────────
          _buildProbeTipCard(),

          const SizedBox(height: 24),

          // ── Recent Scans ──────────────────────────────────────────────────
          _buildRecentScansSection(),
        ],
      ),
    );
  }

  Widget _buildDashboardQuickActions() {
    final actions = [
      (
        title: 'Add Scan Record',
        subtitle: 'Choose normal or AI-guided ultrasound workflow.',
        icon: Icons.add_circle_outline,
        color: DawaTokens.brandPrimary,
        chips: <(IconData, String)>[
          (Icons.sensors, 'Normal'),
          (Icons.auto_awesome, 'AI Guided'),
        ],
        onTap: _showAddScanWorkflowSheet,
      ),
      (
        title: 'AI-Guided Scan',
        subtitle: 'Use AI-guided sweep protocol and scan analysis.',
        icon: Icons.auto_fix_high_outlined,
        color: DawaTokens.brandPrimary,
        chips: <(IconData, String)>[(Icons.auto_awesome, 'AI Analysis')],
        onTap: _startAIGuidedScan,
      ),
      (
        title: 'View Patient Records',
        subtitle: 'Open the obstetric registry and select a patient.',
        icon: Icons.people_outline,
        color: DawaTokens.brandPrimary,
        chips: <(IconData, String)>[],
        onTap: () =>
            setState(() => _activeTab = UltrasoundDashboardTab.patients),
      ),
      (
        title: 'View Scan History',
        subtitle: 'Review completed scans, reports, and AI findings.',
        icon: Icons.history,
        color: DawaTokens.brandPrimary,
        chips: <(IconData, String)>[],
        onTap: () =>
            setState(() => _activeTab = UltrasoundDashboardTab.history),
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
                  chips: action.chips,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatsGrid() {
    final needsFollowUp =
        _patients.where((p) => p.scanStatus == ScanStatus.abnormal).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        final width = (constraints.maxWidth - (16 * (columns - 1))) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: width,
              child: _buildStatCard(
                'Registered Patients',
                '${_patients.length}',
                Icons.people,
                DawaTokens.brandPrimary,
                '+${_patients.length} active',
              ),
            ),
            SizedBox(
              width: width,
              child: _buildStatCard(
                'Scans Today',
                '5',
                Icons.monitor_heart,
                DawaTokens.statusSuccess,
                'Normal activity',
              ),
            ),
            SizedBox(
              width: width,
              child: _buildStatCard(
                'Needs Follow-Up',
                '$needsFollowUp',
                Icons.warning_amber,
                DawaTokens.statusWarning,
                needsFollowUp == 1 ? '1 urgent' : '$needsFollowUp urgent',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProbeTipCard() {
    return DawaCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: DawaTokens.brandPrimary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.tips_and_updates,
              color: DawaTokens.brandPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Probe Tip',
                  style: DawaTextStyles.cardTitle.copyWith(
                    color: DawaTokens.brandPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Apply adequate gel before scanning. Start with minimal pressure and increase only when needed to improve image quality.',
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

  Widget _buildRecentScansSection() {
    return DawaCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text('Recent Scans', style: DawaTextStyles.cardTitle),
                ),
                TextButton(
                  onPressed: () => setState(
                    () => _activeTab = UltrasoundDashboardTab.history,
                  ),
                  child: const Text('View all'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: DawaTokens.border),
          if (_scanHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No recent scans yet',
                style: DawaTextStyles.secondary,
              ),
            )
          else
            Column(
              children: _scanHistory.take(3).map(_buildRecentScanTile).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentScanTile(UltrasoundScanRecord record) {
    final isNormal = record.result == 'Normal';
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DawaTokens.border)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isNormal
                ? DawaTokens.statusSuccessBg
                : DawaTokens.statusDangerBg,
            shape: BoxShape.circle,
          ),
          child: Icon(
            record.scanType == ScanType.aiGuided
                ? Icons.auto_fix_high
                : Icons.sensors,
            color:
                isNormal ? DawaTokens.statusSuccess : DawaTokens.statusDanger,
            size: 20,
          ),
        ),
        title: Text(record.patientName, style: DawaTextStyles.cardTitle),
        subtitle: Text(
            '${record.scanTypeString} • ${record.date.day}/${record.date.month}/${record.date.year}'
            '${record.gestationalAgeWeeks != null ? ' • ${record.gestationalAgeWeeks}wks' : ''}'),
        trailing: DawaStatusBadge(
          status: isNormal ? 'normal' : 'needs_review',
          label: record.result,
        ),
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    List<(IconData, String)> chips = const [],
  }) {
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
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final chip in chips)
                            _sourceBadge(chip.$1, chip.$2),
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
                  decoration: const BoxDecoration(
                    color: DawaTokens.surfaceTertiary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
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
      String title, String value, IconData icon, Color color, String sub) {
    final isUrgent = sub.toLowerCase().contains('urgent');
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
              sub,
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

  // ─── MANUAL SCAN SCREEN ───────────────────────────────────────────────────

  // ignore: unused_element
  Widget _buildManualScanScreen() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              setState(() => _appState = UltrasoundAppState.dashboard),
        ),
        title: const Text('Manual Ultrasound'),
        backgroundColor: DawaTokens.brandPrimary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── Probe video feed area ────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: _capturedImage != null
                  ? Image.memory(
                      base64Decode(_capturedImage!.split(',').last),
                      fit: BoxFit.contain,
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sensors, color: Colors.white24, size: 80),
                        const SizedBox(height: 16),
                        const Text('Probe feed will appear here',
                            style: TextStyle(color: Colors.white38)),
                        const SizedBox(height: 8),
                        const Text(
                          'Connect your ultrasound probe via USB / Bluetooth',
                          style: TextStyle(color: Colors.white24, fontSize: 12),
                        ),
                      ],
                    ),
            ),
          ),

          // ── Patient selector ─────────────────────────────────────────────
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.pregnant_woman,
                    color: DawaTokens.brandPrimary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<PregnantPatient>(
                      value: _selectedPatient,
                      hint: const Text('Select patient',
                          style: TextStyle(fontSize: 14)),
                      isExpanded: true,
                      items: _patients
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(
                                    '${p.name} — ${p.gravida ?? ''} ${p.gestationalAgeWeeks != null ? '${p.gestationalAgeWeeks}wks' : ''}',
                                    style: const TextStyle(fontSize: 14)),
                              ))
                          .toList(),
                      onChanged: (p) => setState(() => _selectedPatient = p),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Controls ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Load Image'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side:
                              const BorderSide(color: DawaTokens.brandPrimary),
                          foregroundColor: DawaTokens.brandPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _captureFromProbe,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Capture Frame'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DawaTokens.brandPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isAnalyzing) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('AI is analysing the frame…',
                      style: TextStyle(color: Colors.grey)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── AI GUIDED SWEEP SCREEN ───────────────────────────────────────────────

  // ignore: unused_element
  Widget _buildAIGuidedScanScreen() {
    final step = _sweepSteps[_currentSweepStep];
    final progress = (_currentSweepStep + 1) / _sweepSteps.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _appState = UltrasoundAppState.dashboard;
            _currentSweepStep = 0;
            _sweepComplete = false;
          }),
        ),
        title: const Text('AI-Guided Sweep'),
        backgroundColor: DawaTokens.statusSuccess,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── Progress bar ─────────────────────────────────────────────────
          Container(
            color: DawaTokens.statusSuccess.withOpacity(0.1),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Step ${_currentSweepStep + 1} of ${_sweepSteps.length}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: DawaTokens.statusSuccess),
                    ),
                    Text(
                      '${(progress * 100).toInt()}% complete',
                      style: const TextStyle(
                          color: DawaTokens.statusSuccess, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                    color: DawaTokens.statusSuccess,
                  ),
                ),
              ],
            ),
          ),

          // ── Live feed ────────────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.black,
                  child: _capturedImage != null
                      ? Image.memory(
                          base64Decode(_capturedImage!.split(',').last),
                          fit: BoxFit.contain,
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(step.icon, color: Colors.white24, size: 64),
                              const SizedBox(height: 12),
                              Text(step.bodyPosition,
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 13)),
                            ],
                          ),
                        ),
                ),
                // Overlay: probe angle badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.rotate_right,
                            color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(step.probeAngle,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Step instruction card ─────────────────────────────────────────
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step title
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: DawaTokens.statusSuccess,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(step.icon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(step.title,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Instruction
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(step.instruction,
                        style: const TextStyle(fontSize: 15, height: 1.6)),
                  ),
                  const SizedBox(height: 12),

                  // Landmark
                  _buildStepInfoRow(
                    Icons.visibility,
                    'Look for',
                    step.landmark,
                    DawaTokens.statusInfo,
                  ),
                  const SizedBox(height: 8),

                  // Warning
                  if (step.warningSign != null)
                    _buildStepInfoRow(
                      Icons.warning_amber,
                      'Flag if seen',
                      step.warningSign!,
                      DawaTokens.statusWarning,
                    ),

                  const SizedBox(height: 20),

                  // Capture + Next row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _captureFromProbe,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Capture Frame'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(
                                color: DawaTokens.statusSuccess),
                            foregroundColor: DawaTokens.statusSuccess,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_currentSweepStep < _sweepSteps.length - 1) {
                              setState(() => _currentSweepStep++);
                            } else {
                              setState(() => _sweepComplete = true);
                              _showSweepCompleteDialog();
                            }
                          },
                          icon: Icon(
                            _currentSweepStep < _sweepSteps.length - 1
                                ? Icons.navigate_next
                                : Icons.check_circle,
                          ),
                          label: Text(
                            _currentSweepStep < _sweepSteps.length - 1
                                ? 'Next Step'
                                : 'Complete',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DawaTokens.statusSuccess,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Step dots
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _sweepSteps.length,
                      (i) => Container(
                        width: i == _currentSweepStep ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i <= _currentSweepStep
                              ? DawaTokens.statusSuccess
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
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
    final step = _sweepSteps[_currentSweepStep];
    final progress = (_currentSweepStep + 1) / _sweepSteps.length;

    return Scaffold(
      backgroundColor: DawaTokens.surfaceSecondary,
      appBar: _buildScanAppBar(
        title: 'AI-Guided Ultrasound Scan',
        accent: DawaTokens.statusSuccess,
        onBack: () {
          setState(() {
            _appState = UltrasoundAppState.dashboard;
            _currentSweepStep = 0;
            _sweepComplete = false;
          });
        },
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;

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
                        title: 'AI-guided sweep protocol',
                        subtitle:
                            'Follow each sweep step, capture a representative frame, and send it for AI-supported analysis.',
                        accent: DawaTokens.statusSuccess,
                        badges: const ['Guided sweep', 'AI analysis'],
                      ),
                      const SizedBox(height: 16),
                      _buildAiProgressCard(progress),
                      const SizedBox(height: 16),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: _buildProbePreviewCard(
                                title: 'Live sweep preview',
                                subtitle: 'Current frame and probe position',
                                accent: DawaTokens.statusSuccess,
                                emptyIcon: step.icon,
                                emptyTitle: step.bodyPosition,
                                emptySubtitle:
                                    'Position the probe, confirm the landmark, then capture a frame.',
                                overlay: _buildProbeAngleBadge(step),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  _buildAiInstructionCard(step),
                                  const SizedBox(height: 16),
                                  _buildAiScanActionsCard(),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildProbePreviewCard(
                          title: 'Live sweep preview',
                          subtitle: 'Current frame and probe position',
                          accent: DawaTokens.statusSuccess,
                          emptyIcon: step.icon,
                          emptyTitle: step.bodyPosition,
                          emptySubtitle:
                              'Position the probe, confirm the landmark, then capture a frame.',
                          overlay: _buildProbeAngleBadge(step),
                        ),
                        const SizedBox(height: 16),
                        _buildAiInstructionCard(step),
                        const SizedBox(height: 16),
                        _buildAiScanActionsCard(),
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
    setState(() => _appState = UltrasoundAppState.dashboard);
  }

  Widget _buildScanHeaderCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required List<String> badges,
  }) {
    return DawaCard(
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 28),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DawaTextStyles.pageTitle.copyWith(
                    fontSize: 24,
                    color: DawaTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: DawaTextStyles.secondary.copyWith(
                    color: DawaTokens.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          for (final badge in badges)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accent.withOpacity(0.18)),
              ),
              child: Text(
                badge,
                style: DawaTextStyles.secondary.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
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
                        ? Image.memory(
                            base64Decode(_capturedImage!.split(',').last),
                            fit: BoxFit.contain,
                          )
                        : _buildEmptyProbePreview(
                            icon: emptyIcon,
                            title: emptyTitle,
                            subtitle: emptySubtitle,
                          ),
                  ),
                  Positioned(
                    left: 16,
                    top: 16,
                    child: _buildPreviewBadge(
                      icon: Icons.circle,
                      label: _capturedImage == null ? 'Ready' : 'Frame loaded',
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

  Widget _buildProbeAngleBadge(SweepStep step) {
    return Positioned(
      right: 16,
      top: 16,
      child: _buildPreviewBadge(
        icon: Icons.rotate_right,
        label: step.probeAngle,
        accent: DawaTokens.statusSuccess,
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
                          : '${selected.id} - ${selected.gestationalAgeWeeks ?? '--'} weeks',
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
              hintText: 'Select patient',
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
            onChanged: (patient) => setState(() => _selectedPatient = patient),
          ),
        ],
      ),
    );
  }

  String _patientDropdownLabel(PregnantPatient patient) {
    final parts = <String>[patient.name];
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
            'Use a saved ultrasound frame or capture directly from the connected camera/probe.',
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
                onPressed: _pickFromGallery,
              );
              final capture = _buildScanActionButton(
                label: 'Capture Frame',
                icon: Icons.camera_alt_outlined,
                accent: DawaTokens.brandPrimary,
                onPressed: _captureFromProbe,
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

  Widget _buildAiProgressCard(double progress) {
    return DawaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Step ${_currentSweepStep + 1} of ${_sweepSteps.length}',
                  style: DawaTextStyles.cardTitle.copyWith(
                    color: DawaTokens.statusSuccess,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).toInt()}% complete',
                style: DawaTextStyles.secondary.copyWith(
                  color: DawaTokens.statusSuccess,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: DawaTokens.statusSuccess.withOpacity(0.12),
              color: DawaTokens.statusSuccess,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _sweepSteps.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: index == _currentSweepStep ? 28 : 9,
                height: 9,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: index <= _currentSweepStep
                      ? DawaTokens.statusSuccess
                      : DawaTokens.borderStrong,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiInstructionCard(SweepStep step) {
    return DawaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: DawaTokens.statusSuccess.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(step.icon, color: DawaTokens.statusSuccess),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step.title,
                  style: DawaTextStyles.pageTitle.copyWith(fontSize: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DawaTokens.surfaceSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DawaTokens.border),
            ),
            child: Text(
              step.instruction,
              style: DawaTextStyles.body.copyWith(
                color: DawaTokens.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildStepInfoRow(
            Icons.visibility_outlined,
            'Look for',
            step.landmark,
            DawaTokens.statusInfo,
          ),
          if (step.warningSign != null) ...[
            const SizedBox(height: 8),
            _buildStepInfoRow(
              Icons.warning_amber_outlined,
              'Flag if seen',
              step.warningSign!,
              DawaTokens.statusWarning,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiScanActionsCard() {
    final isLastStep = _currentSweepStep >= _sweepSteps.length - 1;

    return DawaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Guided scan actions', style: DawaTextStyles.cardTitle),
          const SizedBox(height: 6),
          Text(
            'Capture a representative frame for analysis, or move through the sweep protocol step by step.',
            style: DawaTextStyles.secondary.copyWith(
              color: DawaTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 420;
              final capture = _buildScanActionButton(
                label: 'Capture Frame',
                icon: Icons.camera_alt_outlined,
                accent: DawaTokens.statusSuccess,
                outlined: true,
                onPressed: _captureFromProbe,
              );
              final next = _buildScanActionButton(
                label: isLastStep ? 'Complete Sweep' : 'Next Step',
                icon: isLastStep
                    ? Icons.check_circle_outline
                    : Icons.navigate_next,
                accent: DawaTokens.statusSuccess,
                onPressed: _advanceSweepStep,
              );

              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    capture,
                    const SizedBox(height: 12),
                    next,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: capture),
                  const SizedBox(width: 12),
                  Expanded(child: next),
                ],
              );
            },
          ),
          if (_isAnalyzing) _buildAnalysisProgress(DawaTokens.statusSuccess),
        ],
      ),
    );
  }

  Widget _buildScanActionButton({
    required String label,
    required IconData icon,
    required Color accent,
    required VoidCallback onPressed,
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
                    Text('Obstetric patients and their scan records.',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddPatientSheet(),
                icon: const Icon(Icons.add),
                label: const Text('Add Patient'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: DawaTokens.brandPrimary,
                    foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[50],
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by name, ID or phone…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _patients.length,
            itemBuilder: (ctx, i) {
              final p = _patients[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: p.statusColor.withOpacity(0.15),
                    child: Text(p.name[0],
                        style: TextStyle(
                            color: p.statusColor, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(p.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${p.id} • ${p.age}yrs • ${p.gravida ?? ''} • ${p.gestationalAgeWeeks != null ? '${p.gestationalAgeWeeks}wks' : 'Unknown GA'}'
                    '\n${p.pregnancyStatusString}',
                  ),
                  isThreeLine: true,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Chip(
                        backgroundColor: p.statusColor.withOpacity(0.12),
                        label: Text(p.scanStatusString,
                            style: TextStyle(
                                color: p.statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  onTap: () {
                    setState(() => _selectedPatient = p);
                    _startAIGuidedScan();
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddPatientSheet() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        final isCompact = size.width < 700.0;

        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: isCompact ? 12.0 : 24.0,
            vertical: isCompact ? 12.0 : 24.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isCompact ? 20.0 : 28.0),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isCompact ? size.width - 24.0 : 560.0,
              maxHeight: size.height * 0.88,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'New Patient',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Age',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _gaController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'GA (weeks)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_nameController.text.isEmpty) return;
                        final ga = int.tryParse(_gaController.text);
                        final newP = PregnantPatient(
                          id: 'OB-${2000 + _patients.length}',
                          name: _nameController.text,
                          age: int.tryParse(_ageController.text) ?? 0,
                          contact: _phoneController.text,
                          gestationalAgeWeeks: ga,
                          pregnancyStatus: ga == null
                              ? PregnancyStatus.unknown
                              : ga < 14
                                  ? PregnancyStatus.firstTrimester
                                  : ga < 28
                                      ? PregnancyStatus.secondTrimester
                                      : PregnancyStatus.thirdTrimester,
                          scanStatus: ScanStatus.unscanned,
                          riskLevel: RiskLevel.low,
                        );
                        setState(() {
                          _patients = [newP, ..._patients];
                          _nameController.clear();
                          _ageController.clear();
                          _gaController.clear();
                          _phoneController.clear();
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DawaTokens.brandPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Register Patient'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── HISTORY TAB ──────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          color: Colors.white,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scan History',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('All past ultrasound scans and AI analysis records.',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _scanHistory.length,
            itemBuilder: (ctx, i) {
              final r = _scanHistory[i];
              final isNormal = r.result == 'Normal';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isNormal
                        ? DawaTokens.statusSuccessBg
                        : DawaTokens.statusDangerBg,
                    child: Icon(
                      r.scanType == ScanType.aiGuided
                          ? Icons.auto_fix_high
                          : Icons.sensors,
                      color: isNormal
                          ? DawaTokens.statusSuccess
                          : DawaTokens.statusDanger,
                    ),
                  ),
                  title: Text(r.patientName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${r.date.day}/${r.date.month}/${r.date.year} • ${r.scanTypeString}'
                          '${r.gestationalAgeWeeks != null ? ' • ${r.gestationalAgeWeeks}wks' : ''}'),
                      if (r.aiAnalysis != null)
                        Text(r.aiAnalysis!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  isThreeLine: r.aiAnalysis != null,
                  trailing: Chip(
                    backgroundColor: isNormal
                        ? DawaTokens.statusSuccessBg
                        : DawaTokens.statusDangerBg,
                    label: Text(r.result,
                        style: TextStyle(
                            color: isNormal
                                ? DawaTokens.statusSuccessText
                                : DawaTokens.statusDangerText,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                  ),
                ),
              );
            },
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
          onPressed: () => setState(() {
            _appState = UltrasoundAppState.dashboard;
            _analysisResult = null;
          }),
        ),
        title: const Text('Scan Results'),
        backgroundColor: DawaTokens.brandPrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveResult),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      result.overallLevel == FindingLevel.normal
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
                        Text(result.levelString,
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

            // ── Measurements ───────────────────────────────────────────────
            if (result.measurements != null) ...[
              const Text('Biometric Measurements',
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
                      'Estimated Gestational Age: '
                      '${result.estimatedGestationalAge} weeks',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: DawaTokens.brandPrimary),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

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

            const SizedBox(height: 20),

            // ── Save button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveResult,
                icon: const Icon(Icons.save),
                label: const Text('Save Scan Record'),
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
                      'AI-assisted tool only. Always confirm findings with clinical judgment and refer appropriately.',
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
                        color: f.color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
                Text(f.finding,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                if (f.note != null)
                  Text(f.note!,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
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
