import 'package:clinician/application/home/home_widget.dart';
import 'package:flutter/material.dart';
import '/components/dawa_design_system.dart';
import 'dart:convert';
import 'ultrasound_model.dart';

// ─── MAIN WIDGET ─────────────────────────────────────────────────────────────

class UltrasoundApp extends StatefulWidget {
  const UltrasoundApp({super.key});

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

  bool _isAnalyzing = false;

  // AI Sweep state
  int _currentSweepStep = 0;
  List<SweepStep> _sweepSteps = [];
  bool _sweepComplete = false;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _gaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sweepSteps = SweepGuidanceProtocol.getObstetricSweepSteps();
    _loadData();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _appState = UltrasoundAppState.dashboard);
      }
    });
  }

  void _loadData() {
    setState(() {
      _patients = UltrasoundMockData.getPatients();
      _scanHistory = UltrasoundMockData.getScanHistory();
    });
  }

  void _handleLogout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeWidget()),
      (route) => false,
    );
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
    final image = await UltrasoundImagePickerService.captureImage();
    if (image != null && mounted) {
      setState(() => _capturedImage = image);
      await _runAnalysis();
    }
  }

  Future<void> _pickFromGallery() async {
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
      scanType: _appState == UltrasoundAppState.aiGuidedScan
          ? ScanType.aiGuided
          : ScanType.manual,
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
      _currentSweepStep = 0;
      _sweepComplete = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scan record saved successfully!')),
    );
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    switch (_appState) {
      case UltrasoundAppState.splash:
        return _buildSplash();
      case UltrasoundAppState.manualScan:
        return _buildManualScanScreen();
      case UltrasoundAppState.aiGuidedScan:
        return _buildAIGuidedScanScreen();
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
                    child: Image.asset('assets/images/dawa_cross.png',
                        fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dawa Ultrasound',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87)),
                    Text('Obstetrics Module',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            letterSpacing: 1)),
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
                _buildNavItem(
                    Icons.dashboard, 'Dashboard', UltrasoundDashboardTab.home),
                _buildNavItem(Icons.pregnant_woman, 'Patients',
                    UltrasoundDashboardTab.patients),
                _buildNavItem(Icons.history, 'Scan History',
                    UltrasoundDashboardTab.history),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!))),
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
                      Text('Back to Portal',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Dawa Clinic',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
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

  Widget _buildNavItem(
      IconData icon, String label, UltrasoundDashboardTab tab) {
    final isActive = _activeTab == tab;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive ? DawaTokens.brandPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading:
            Icon(icon, color: isActive ? DawaTokens.textInverse : Colors.grey),
        title: Text(label,
            style: TextStyle(
              color: isActive ? DawaTokens.textInverse : Colors.grey[700],
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            )),
        onTap: () => setState(() => _activeTab = tab),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── MOBILE HEADER ────────────────────────────────────────────────────────

  Widget _buildMobileHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Image.asset('assets/images/dawa_cross.png',
                fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          const Text('Dawa Ultrasound',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87)),
          const Spacer(),
          CircleAvatar(
            backgroundColor: DawaTokens.brandPrimary.withOpacity(0.15),
            child: const Text('MM',
                style: TextStyle(
                    color: DawaTokens.brandPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ─── MOBILE BOTTOM NAV ────────────────────────────────────────────────────

  Widget _buildMobileBottomNav() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMobileNavItem(
              Icons.dashboard, 'Home', UltrasoundDashboardTab.home),
          _buildMobileNavItem(Icons.pregnant_woman, 'Patients',
              UltrasoundDashboardTab.patients),
          _buildMobileNavItem(
              Icons.history, 'History', UltrasoundDashboardTab.history),
          _buildMobileNavItem(
              Icons.person, 'Profile', UltrasoundDashboardTab.profile),
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
          const Text('Dashboard',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          const Text("Welcome back! Here's today's obstetric overview.",
              style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 32),

          // ── Action Cards ────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  'Manual Ultrasound',
                  'Connect your probe and view live imaging. Annotate and capture frames.',
                  Icons.sensors,
                  DawaTokens.brandPrimary,
                  () =>
                      setState(() => _appState = UltrasoundAppState.manualScan),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionCard(
                  'AI-Guided Sweep',
                  'Let AI guide you through a step-by-step blind sweep of the pregnant abdomen.',
                  Icons.auto_fix_high,
                  DawaTokens.statusSuccess,
                  () {
                    setState(() {
                      _currentSweepStep = 0;
                      _sweepComplete = false;
                      _appState = UltrasoundAppState.aiGuidedScan;
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Stats ────────────────────────────────────────────────────────
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildStatCard('Total Patients', '${_patients.length}',
                  Icons.pregnant_woman, DawaTokens.brandPrimary, 'This month'),
              _buildStatCard('Scans Today', '5', Icons.monitor_heart,
                  DawaTokens.statusSuccess, 'Normal activity'),
              _buildStatCard(
                  'Needs Follow-Up',
                  '${_patients.where((p) => p.scanStatus == ScanStatus.abnormal).length}',
                  Icons.warning_amber,
                  DawaTokens.statusWarning,
                  'Refer urgently'),
            ],
          ),

          const SizedBox(height: 32),

          // ── Quick Tip ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: DawaTokens.brandPrimary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: DawaTokens.brandPrimary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: DawaTokens.brandPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.tips_and_updates,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Probe Tip',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: DawaTokens.brandPrimary)),
                      SizedBox(height: 4),
                      Text(
                        'Apply adequate gel to the abdomen before scanning. '
                        'Start with minimal pressure and increase only when needed to improve image quality.',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Recent Scans ──────────────────────────────────────────────────
          Row(
            children: [
              const Text('Recent Scans',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    setState(() => _activeTab = UltrasoundDashboardTab.history),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._scanHistory.take(3).map((record) => _buildRecentScanTile(record)),
        ],
      ),
    );
  }

  Widget _buildRecentScanTile(UltrasoundScanRecord record) {
    final isNormal = record.result == 'Normal';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isNormal ? DawaTokens.statusSuccessBg : DawaTokens.statusDangerBg,
          child: Icon(
            isNormal ? Icons.check_circle : Icons.warning,
            color:
                isNormal ? DawaTokens.statusSuccess : DawaTokens.statusDanger,
          ),
        ),
        title: Text(record.patientName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            '${record.scanTypeString} • ${record.date.day}/${record.date.month}/${record.date.year}'
            '${record.gestationalAgeWeeks != null ? ' • ${record.gestationalAgeWeeks}wks' : ''}'),
        trailing: Chip(
          backgroundColor:
              isNormal ? DawaTokens.statusSuccessBg : DawaTokens.statusDangerBg,
          label: Text(record.result,
              style: TextStyle(
                  color: isNormal
                      ? DawaTokens.statusSuccessText
                      : DawaTokens.statusDangerText,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 20)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.85), fontSize: 13)),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20)),
                child: Icon(Icons.arrow_forward, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color, String sub) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 20)
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 6),
          Text(title,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Text(sub,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── MANUAL SCAN SCREEN ───────────────────────────────────────────────────

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
                    setState(() {
                      _selectedPatient = p;
                      _currentSweepStep = 0;
                      _sweepComplete = false;
                      _appState = UltrasoundAppState.aiGuidedScan;
                    });
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Patient',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: 'Full Name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Age', border: OutlineInputBorder())),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                      controller: _gaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'GA (weeks)',
                          border: OutlineInputBorder())),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Phone', border: OutlineInputBorder())),
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
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Register Patient'),
              ),
            ),
          ],
        ),
      ),
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
                  onTap: () =>
                      _showToast('Password changes are managed from Settings'),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notification Preferences'),
                  onTap: () => _showToast(
                    'Notification preferences will be available in Settings',
                  ),
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
