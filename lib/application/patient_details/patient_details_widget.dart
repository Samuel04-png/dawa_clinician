import '/application/cacx/cacx_model.dart';
import '/application/cacx/cacx_widget.dart';
import '/application/mom_details/mom_details_widget.dart';
import '/backend/backend.dart';
import '/backend/supabase/supabase_config.dart';
import '/components/appbar_nav/appbar_nav_widget.dart';
import '/components/dawa_design_system.dart';
import '/components/small_side_nav/small_side_nav_widget.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PatientDetailsWidget extends StatefulWidget {
  const PatientDetailsWidget({
    super.key,
    required this.momDetails,
    this.firstEncounter,
  });

  final DocumentReference? momDetails;
  final DocumentReference? firstEncounter;

  static String routeName = 'PatientDetails';
  static String routePath = '/patientDetails';

  @override
  State<PatientDetailsWidget> createState() => _PatientDetailsWidgetState();
}

class _PatientDetailsWidgetState extends State<PatientDetailsWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  int _historyRefreshKey = 0;

  Future<List<_ScreeningRecord>> _loadScreenings(String patientId) async {
    if (patientId.trim().isEmpty) {
      return const [];
    }

    try {
      final response = await runSupabaseRequest(
        () => supabaseClient
            .from('cacx_screening_results')
            .select()
            .eq('patient_id', patientId)
            .order('created_at', ascending: false),
      );

      return (response as List<dynamic>)
          .whereType<Map>()
          .map(
              (row) => _ScreeningRecord.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (error) {
      debugPrint('[PatientDetails] Failed to load screenings: $error');
      rethrow;
    }
  }

  Future<void> _openAddScreening(MotherRecord patient) async {
    final patientId = _patientIdentifier(patient);
    final screeningPatient = Patient(
      id: patientId,
      name: patient.name.trim().isEmpty ? 'Unnamed patient' : patient.name,
      age: patient.dateOfBirth == null
          ? 0
          : functions.calculateAge(patient.dateOfBirth!),
      contact: patient.phoneNumber,
      lastTestDate: null,
      status: PatientStatus.untested,
      riskLevel: RiskLevel.low,
    );

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CaCxApp(
          initialPatient: screeningPatient,
          autoStartScreening: true,
          returnToPreviousOnSave: true,
        ),
      ),
    );

    if (saved == true && mounted) {
      setState(() {
        _historyRefreshKey++;
      });
    }
  }

  void _openLegacyRecord() {
    context.pushNamed(
      MomDetailsWidget.routeName,
      queryParameters: {
        'momDetails': serializeParam(
          widget.momDetails,
          ParamType.DocumentReference,
        ),
        'firstEncounter': serializeParam(
          widget.firstEncounter,
          ParamType.DocumentReference,
        ),
      }.withoutNulls,
    );
  }

  String _patientIdentifier(MotherRecord patient) {
    final externalId = patient.motherId.trim();
    if (externalId.isNotEmpty) {
      return externalId;
    }
    return patient.reference.id;
  }

  @override
  Widget build(BuildContext context) {
    final showDesktopSidebar = MediaQuery.sizeOf(context).width >= 768.0;

    return StreamBuilder<MotherRecord>(
      stream: MotherRecord.getDocument(widget.momDetails!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoadingScaffold(
            showDesktopSidebar,
            'Loading patient details...',
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          debugPrint(
              '[PatientDetails] Failed to load patient: ${snapshot.error}');
          return _buildErrorScaffold(
            showDesktopSidebar,
            'Could not load patient details. Please try again.',
          );
        }

        final patient = snapshot.data!;
        final patientId = _patientIdentifier(patient);

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
            drawer: showDesktopSidebar ? null : _buildMobileDrawer(),
            appBar: _buildAppBar(showDesktopSidebar),
            body: SafeArea(
              top: true,
              child: Row(
                children: [
                  if (showDesktopSidebar) _buildDesktopSidebar(),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 980.0;
                        final horizontalPadding =
                            constraints.maxWidth < 600.0 ? 16.0 : 24.0;

                        return FutureBuilder<List<_ScreeningRecord>>(
                          key: ValueKey(
                              'screenings-$patientId-$_historyRefreshKey'),
                          future: _loadScreenings(patientId),
                          builder: (context, historySnapshot) {
                            final latest =
                                historySnapshot.data?.isNotEmpty == true
                                    ? historySnapshot.data!.first
                                    : null;

                            return SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                horizontalPadding,
                                18.0,
                                horizontalPadding,
                                32.0,
                              ),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 1180.0,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildPageHeader(patient),
                                      const SizedBox(height: 16.0),
                                      if (isWide)
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              flex: 5,
                                              child: Column(
                                                children: [
                                                  _buildPatientProfileCard(
                                                    patient,
                                                    latest,
                                                  ),
                                                  const SizedBox(height: 16.0),
                                                  _buildQuickActionsCard(
                                                      patient),
                                                  const SizedBox(height: 16.0),
                                                  _buildRiskSummaryCard(latest),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 16.0),
                                            Expanded(
                                              flex: 7,
                                              child: Column(
                                                children: [
                                                  _buildLatestScreeningCard(
                                                      latest),
                                                  const SizedBox(height: 16.0),
                                                  _buildScreeningHistoryCard(
                                                    patient,
                                                    historySnapshot,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        Column(
                                          children: [
                                            _buildPatientProfileCard(
                                              patient,
                                              latest,
                                            ),
                                            const SizedBox(height: 16.0),
                                            _buildQuickActionsCard(patient),
                                            const SizedBox(height: 16.0),
                                            _buildRiskSummaryCard(latest),
                                            const SizedBox(height: 16.0),
                                            _buildLatestScreeningCard(latest),
                                            const SizedBox(height: 16.0),
                                            _buildScreeningHistoryCard(
                                              patient,
                                              historySnapshot,
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

  Scaffold _buildLoadingScaffold(bool showDesktopSidebar, String message) {
    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      drawer: showDesktopSidebar ? null : _buildMobileDrawer(),
      appBar: _buildAppBar(showDesktopSidebar),
      body: SafeArea(
        child: Row(
          children: [
            if (showDesktopSidebar) _buildDesktopSidebar(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 42.0,
                      height: 42.0,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          FlutterFlowTheme.of(context).primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Text(message, style: DawaTextStyles.secondary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Scaffold _buildErrorScaffold(bool showDesktopSidebar, String message) {
    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      drawer: showDesktopSidebar ? null : _buildMobileDrawer(),
      appBar: _buildAppBar(showDesktopSidebar),
      body: SafeArea(
        child: Row(
          children: [
            if (showDesktopSidebar) _buildDesktopSidebar(),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 44.0,
                        color: DawaTokens.statusDanger,
                      ),
                      const SizedBox(height: 12.0),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: DawaTextStyles.secondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar(bool showDesktopSidebar) {
    if (showDesktopSidebar) {
      return null;
    }

    return AppBar(
      backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: Navigator.of(context).canPop()
            ? 'Back to patients'
            : 'Open navigation',
        icon: Icon(
          Navigator.of(context).canPop()
              ? Icons.arrow_back_rounded
              : Icons.menu_rounded,
          color: FlutterFlowTheme.of(context).primary,
        ),
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            scaffoldKey.currentState?.openDrawer();
          }
        },
      ),
      title: AppbarNavWidget(),
      actions: [
        IconButton(
          tooltip: 'Patients',
          icon: Icon(
            Icons.people_alt_rounded,
            color: FlutterFlowTheme.of(context).primary,
          ),
          onPressed: () => context.goNamed(MomsWidget.routeName),
        ),
      ],
      elevation: 0.0,
      titleSpacing: 0.0,
    );
  }

  Widget _buildMobileDrawer() {
    return SizedBox(
      width: 280.0,
      child: Drawer(
        elevation: 16.0,
        child: Container(
          color: FlutterFlowTheme.of(context).primaryBackground,
          child: const SmallSideNavWidget(),
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 240.0,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        border: Border(
          right: BorderSide(
            color: FlutterFlowTheme.of(context).alternate,
            width: 1.0,
          ),
        ),
      ),
      child: const SmallSideNavWidget(),
    );
  }

  Widget _buildPageHeader(MotherRecord patient) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Patient Details', style: DawaTextStyles.pageTitle),
              const SizedBox(height: 4.0),
              Text(
                'Review profile details, start screening, and track historical results for this patient.',
                style: DawaTextStyles.secondary,
              ),
            ],
          ),
        ),
        if (MediaQuery.sizeOf(context).width >= 720.0)
          OutlinedButton.icon(
            onPressed: _openLegacyRecord,
            icon: const Icon(Icons.open_in_new_rounded, size: 18.0),
            label: const Text('Full Maternal Record'),
          ),
      ],
    );
  }

  Widget _buildPatientProfileCard(
    MotherRecord patient,
    _ScreeningRecord? latest,
  ) {
    final age = patient.dateOfBirth == null
        ? 'N/A'
        : functions.calculateAge(patient.dateOfBirth!).toString();
    final lastScreening = latest?.createdAt != null
        ? dateTimeFormat('d MMM y', latest!.createdAt!)
        : 'Not yet screened';

    return DawaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DawaAvatarCircle(
                name: patient.name,
                size: 58.0,
                moduleColor: DawaTokens.brandPrimary,
              ),
              const SizedBox(width: 14.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          patient.name.trim().isEmpty
                              ? 'Unnamed patient'
                              : patient.name,
                          style:
                              DawaTextStyles.pageTitle.copyWith(fontSize: 24.0),
                        ),
                        _buildRiskBadge(latest?.riskLevel ?? 'unknown'),
                      ],
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      'Patient ID ${_patientIdentifier(patient)}',
                      style: DawaTextStyles.secondary.copyWith(
                        color: DawaTokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18.0),
          Wrap(
            spacing: 10.0,
            runSpacing: 10.0,
            children: [
              _profileField('Age', age, Icons.cake_outlined),
              _profileField(
                'Date of birth',
                patient.dateOfBirth == null
                    ? 'Not recorded'
                    : dateTimeFormat('d MMM y', patient.dateOfBirth!),
                Icons.event_outlined,
              ),
              _profileField(
                'Phone',
                patient.phoneNumber.trim().isEmpty
                    ? 'Not recorded'
                    : patient.phoneNumber,
                Icons.phone_outlined,
              ),
              _profileField(
                'Location',
                patient.address.trim().isEmpty
                    ? 'Not recorded'
                    : patient.address,
                Icons.location_on_outlined,
              ),
              _profileField(
                'Occupation',
                patient.occupation.trim().isEmpty
                    ? 'Not recorded'
                    : patient.occupation,
                Icons.work_outline_rounded,
              ),
              _profileField(
                'Last screening',
                lastScreening,
                Icons.history_toggle_off_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(MotherRecord patient) {
    return DawaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: DawaTextStyles.cardTitle),
          const SizedBox(height: 8.0),
          Text(
            'Launch screening with this patient already selected, or open the full maternal record when you need the longer clinical form.',
            style: DawaTextStyles.secondary,
          ),
          const SizedBox(height: 16.0),
          Wrap(
            spacing: 10.0,
            runSpacing: 10.0,
            children: [
              ElevatedButton.icon(
                onPressed: () => _openAddScreening(patient),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18.0),
                label: const Text('Add Screening'),
              ),
              OutlinedButton.icon(
                onPressed: _openLegacyRecord,
                icon: const Icon(Icons.description_outlined, size: 18.0),
                label: const Text('Open Full Record'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskSummaryCard(_ScreeningRecord? latest) {
    final headline =
        latest == null ? 'No screenings yet' : latest.primaryResultOrFallback;
    final recommendation = latest == null
        ? 'Start the first screening for this patient.'
        : latest.recommendationSummary;

    return DawaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Risk Summary', style: DawaTextStyles.cardTitle),
          const SizedBox(height: 12.0),
          Wrap(
            spacing: 10.0,
            runSpacing: 10.0,
            children: [
              _summaryChip(
                'Status',
                latest == null ? 'No screening' : latest.statusLabel,
                Icons.assignment_turned_in_outlined,
              ),
              _summaryChip(
                'Risk level',
                latest == null ? 'Unknown' : latest.riskLabel,
                Icons.health_and_safety_outlined,
              ),
              _summaryChip(
                'Source',
                latest?.sourceLabel ?? 'Not available',
                Icons.hub_outlined,
              ),
            ],
          ),
          const SizedBox(height: 14.0),
          Text(
            headline,
            style: DawaTextStyles.pageTitle.copyWith(fontSize: 20.0),
          ),
          const SizedBox(height: 8.0),
          Text(
            recommendation,
            style: DawaTextStyles.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildLatestScreeningCard(_ScreeningRecord? latest) {
    return DawaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text('Latest Screening', style: DawaTextStyles.cardTitle),
              ),
              if (latest != null)
                Text(
                  latest.completedLabel,
                  style: DawaTextStyles.secondary.copyWith(
                    color: DawaTokens.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14.0),
          if (latest == null)
            Text(
              'No screenings yet. Start the first screening for this patient.',
              style: DawaTextStyles.secondary,
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: DawaTokens.surfaceSecondary,
                borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
                border: Border.all(color: DawaTokens.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      _buildRiskBadge(latest.riskLevel),
                      _smallBadge(
                        latest.sourceLabel,
                        DawaTokens.brandPrimaryPale,
                        DawaTokens.brandPrimary,
                      ),
                      _smallBadge(
                        latest.secondOpinionBadgeLabel,
                        latest.secondOpinionBadgeBackground,
                        latest.secondOpinionBadgeForeground,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    latest.primaryResultOrFallback,
                    style: DawaTextStyles.pageTitle.copyWith(fontSize: 20.0),
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    '${latest.confidenceLabel} confidence',
                    style: DawaTextStyles.secondary,
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    latest.recommendationSummary,
                    style: DawaTextStyles.secondary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScreeningHistoryCard(
    MotherRecord patient,
    AsyncSnapshot<List<_ScreeningRecord>> historySnapshot,
  ) {
    return DawaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Screening History', style: DawaTextStyles.cardTitle),
                    const SizedBox(height: 4.0),
                    Text(
                      'All CaCx screening results linked to this patient, newest first.',
                      style: DawaTextStyles.secondary,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openAddScreening(patient),
                icon: const Icon(Icons.add_rounded, size: 18.0),
                label: const Text('Add Screening'),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          if (historySnapshot.connectionState == ConnectionState.waiting &&
              !historySnapshot.hasData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'Loading screening history...',
                style: DawaTextStyles.secondary,
              ),
            )
          else if (historySnapshot.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'Could not load screening history. Please try again.',
                style: DawaTextStyles.secondary.copyWith(
                  color: DawaTokens.statusDangerText,
                ),
              ),
            )
          else if ((historySnapshot.data ?? const []).isEmpty)
            _buildEmptyHistoryState(patient)
          else
            Column(
              children: (historySnapshot.data ?? const [])
                  .map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _buildHistoryRecordCard(record),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistoryState(MotherRecord patient) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: DawaTokens.surfaceSecondary,
        borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
        border: Border.all(color: DawaTokens.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.assignment_outlined,
            size: 40.0,
            color: DawaTokens.brandPrimary,
          ),
          const SizedBox(height: 12.0),
          Text('No screenings yet', style: DawaTextStyles.cardTitle),
          const SizedBox(height: 6.0),
          Text(
            'Start the first screening for this patient.',
            textAlign: TextAlign.center,
            style: DawaTextStyles.secondary,
          ),
          const SizedBox(height: 14.0),
          ElevatedButton.icon(
            onPressed: () => _openAddScreening(patient),
            icon: const Icon(Icons.add_rounded, size: 18.0),
            label: const Text('Add Screening'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRecordCard(_ScreeningRecord record) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: DawaTokens.surfaceSecondary,
        borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
        border: Border.all(color: DawaTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('CaCx Screening', style: DawaTextStyles.cardTitle),
              _buildRiskBadge(record.riskLevel),
              _smallBadge(
                record.sourceLabel,
                DawaTokens.brandPrimaryPale,
                DawaTokens.brandPrimary,
              ),
              _smallBadge(
                record.statusLabel,
                record.statusBadgeBackground,
                record.statusBadgeForeground,
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          Text(
            '${record.primaryResultOrFallback} · ${record.confidenceLabel} confidence',
            style: DawaTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6.0),
          Text(
            '${record.deviceStatusLabel} · ${record.secondOpinionSummary}',
            style: DawaTextStyles.secondary,
          ),
          const SizedBox(height: 6.0),
          Text(
            'Completed on ${record.completedLabel}',
            style: DawaTextStyles.secondary.copyWith(
              color: DawaTokens.textMuted,
            ),
          ),
          const SizedBox(height: 12.0),
          Text(
            record.recommendationSummary,
            style: DawaTextStyles.secondary,
          ),
          const SizedBox(height: 14.0),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () => _showScreeningDetails(record),
              child: const Text('View Details'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showScreeningDetails(_ScreeningRecord record) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.55,
          maxChildSize: 0.94,
          builder: (context, controller) {
            return Container(
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24.0),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12.0),
                  Container(
                    width: 42.0,
                    height: 4.0,
                    decoration: BoxDecoration(
                      color: DawaTokens.borderStrong,
                      borderRadius: BorderRadius.circular(99.0),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: controller,
                      padding:
                          const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 28.0),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Screening Details',
                                style: DawaTextStyles.pageTitle,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        _detailSection(
                          'Result Summary',
                          [
                            _detailRow('Module', 'CaCx'),
                            _detailRow('Primary result',
                                record.primaryResultOrFallback),
                            _detailRow(
                                'Primary confidence', record.confidenceLabel),
                            _detailRow('Risk level', record.riskLabel),
                            _detailRow('Source', record.sourceLabel),
                            _detailRow('Completed', record.completedLabel),
                            _detailRow('Save status', 'Saved to Supabase'),
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        _detailSection(
                          'Review Status',
                          [
                            _detailRow(
                                'Device status', record.deviceStatusLabel),
                            _detailRow(
                              'Second opinion',
                              record.secondOpinionSummary,
                            ),
                            _detailRow(
                              'Second opinion result',
                              record.secondOpinionResultOrFallback,
                            ),
                            _detailRow(
                              'Second opinion confidence',
                              record.secondOpinionConfidenceLabel,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        _detailSection(
                          'Clinical Recommendation',
                          [
                            Text(
                              record.recommendationSummary,
                              style: DawaTextStyles.secondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        _detailSection(
                          'Image',
                          [
                            _buildImagePreview(record),
                            const SizedBox(height: 10.0),
                            _detailRow(
                              'Image path',
                              record.imagePath?.trim().isNotEmpty == true
                                  ? record.imagePath!
                                  : 'No image path saved',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        _detailSection(
                          'Raw Metadata',
                          [
                            _detailRow(
                                'Primary source label', record.primarySource),
                            _detailRow(
                              'Device endpoint',
                              record.deviceEndpoint?.trim().isNotEmpty == true
                                  ? record.deviceEndpoint!
                                  : 'Not recorded',
                            ),
                            _detailRow(
                              'Device error',
                              record.deviceError?.trim().isNotEmpty == true
                                  ? record.deviceError!
                                  : 'None',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildImagePreview(_ScreeningRecord record) {
    final imageUrl = record.imageUrl;
    final isNetworkImage =
        imageUrl != null && Uri.tryParse(imageUrl)?.hasAbsolutePath == true;

    return Container(
      width: double.infinity,
      height: 220.0,
      decoration: BoxDecoration(
        color: DawaTokens.surfaceSecondary,
        borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
        border: Border.all(color: DawaTokens.border),
      ),
      child: isNetworkImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
              child: Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
              ),
            )
          : _buildImagePlaceholder(),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.image_not_supported_outlined,
          size: 40.0,
          color: DawaTokens.textMuted,
        ),
        const SizedBox(height: 10.0),
        Text(
          'Uploaded image preview unavailable',
          style: DawaTextStyles.secondary,
        ),
      ],
    );
  }

  Widget _detailSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: DawaTokens.surface,
        borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
        border: Border.all(color: DawaTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DawaTextStyles.cardTitle),
          const SizedBox(height: 12.0),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160.0,
            child: Text(
              label,
              style: DawaTextStyles.secondary.copyWith(
                color: DawaTokens.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: DawaTextStyles.secondary),
          ),
        ],
      ),
    );
  }

  Widget _profileField(String label, String value, IconData icon) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150.0, maxWidth: 240.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: DawaTokens.surfaceSecondary,
        borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
        border: Border.all(color: DawaTokens.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16.0, color: DawaTokens.brandPrimary),
          const SizedBox(width: 8.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: DawaTextStyles.label.copyWith(
                    color: DawaTokens.textMuted,
                    fontSize: 10.0,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(value, style: DawaTextStyles.secondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: DawaTokens.surfaceSecondary,
        borderRadius: BorderRadius.circular(99.0),
        border: Border.all(color: DawaTokens.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.0, color: DawaTokens.brandPrimary),
          const SizedBox(width: 6.0),
          Text(
            '$label: $value',
            style: DawaTextStyles.secondary.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskBadge(String riskLevel) {
    final tone = _riskTone(riskLevel);
    return _smallBadge(
      _riskLabel(riskLevel),
      tone.background,
      tone.foreground,
    );
  }

  Widget _smallBadge(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99.0),
        border: Border.all(color: foreground.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          color: foreground,
          fontSize: 11.0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  _Tone _riskTone(String rawRisk) {
    switch (rawRisk.trim().toLowerCase()) {
      case 'normal':
      case 'low':
        return const _Tone(
          background: DawaTokens.statusSuccessBg,
          foreground: DawaTokens.statusSuccessText,
        );
      case 'borderline':
        return const _Tone(
          background: DawaTokens.statusWarningBg,
          foreground: DawaTokens.statusWarningText,
        );
      case 'high':
        return const _Tone(
          background: DawaTokens.statusDangerBg,
          foreground: DawaTokens.statusDangerText,
        );
      case 'unknown':
      default:
        return const _Tone(
          background: DawaTokens.surfaceTertiary,
          foreground: DawaTokens.textSecondary,
        );
    }
  }

  String _riskLabel(String rawRisk) {
    switch (rawRisk.trim().toLowerCase()) {
      case 'normal':
        return 'Normal';
      case 'low':
        return 'Low Risk';
      case 'borderline':
        return 'Borderline';
      case 'high':
        return 'High Risk';
      case 'unknown':
      default:
        return 'Unknown';
    }
  }
}

class _ScreeningRecord {
  const _ScreeningRecord({
    required this.id,
    required this.createdAt,
    required this.primarySource,
    required this.primaryResult,
    required this.primaryConfidence,
    required this.secondOpinionRequired,
    required this.secondOpinionStatus,
    required this.secondOpinionSource,
    required this.secondOpinionResult,
    required this.secondOpinionConfidence,
    required this.riskLevel,
    required this.deviceStatus,
    required this.deviceEndpoint,
    required this.deviceError,
    required this.imageUrl,
    required this.imagePath,
  });

  final String id;
  final DateTime? createdAt;
  final String primarySource;
  final String? primaryResult;
  final double? primaryConfidence;
  final bool secondOpinionRequired;
  final String secondOpinionStatus;
  final String? secondOpinionSource;
  final String? secondOpinionResult;
  final double? secondOpinionConfidence;
  final String riskLevel;
  final String deviceStatus;
  final String? deviceEndpoint;
  final String? deviceError;
  final String? imageUrl;
  final String? imagePath;

  factory _ScreeningRecord.fromMap(Map<String, dynamic> map) {
    return _ScreeningRecord(
      id: map['id']?.toString() ?? '',
      createdAt: _parseDateTime(map['created_at']),
      primarySource: map['primary_source']?.toString() ?? 'arduino_device',
      primaryResult: map['primary_result']?.toString(),
      primaryConfidence: _parseDouble(map['primary_confidence']),
      secondOpinionRequired: map['second_opinion_required'] == true,
      secondOpinionStatus:
          map['second_opinion_status']?.toString() ?? 'not_required',
      secondOpinionSource: map['second_opinion_source']?.toString(),
      secondOpinionResult: map['second_opinion_result']?.toString(),
      secondOpinionConfidence: _parseDouble(map['second_opinion_confidence']),
      riskLevel: map['risk_level']?.toString() ?? 'unknown',
      deviceStatus: map['device_status']?.toString() ?? 'pending',
      deviceEndpoint: map['device_endpoint']?.toString(),
      deviceError: map['device_error']?.toString(),
      imageUrl: map['image_url']?.toString(),
      imagePath: map['image_path']?.toString(),
    );
  }

  String get primaryResultOrFallback =>
      primaryResult?.trim().isNotEmpty == true ? primaryResult! : 'Unknown';

  String get confidenceLabel => primaryConfidence == null
      ? 'Confidence unavailable'
      : '${primaryConfidence!.toStringAsFixed(1)}%';

  String get completedLabel => createdAt == null
      ? 'Unknown date'
      : dateTimeFormat('d MMM y, h:mm a', createdAt!);

  String get statusLabel {
    switch (riskLevel.toLowerCase()) {
      case 'normal':
      case 'low':
        return 'Completed';
      case 'borderline':
      case 'high':
        return 'Needs Review';
      case 'unknown':
      default:
        return 'Completed';
    }
  }

  Color get statusBadgeBackground {
    if (riskLevel == 'high' || riskLevel == 'borderline') {
      return DawaTokens.statusWarningBg;
    }
    return DawaTokens.statusSuccessBg;
  }

  Color get statusBadgeForeground {
    if (riskLevel == 'high' || riskLevel == 'borderline') {
      return DawaTokens.statusWarningText;
    }
    return DawaTokens.statusSuccessText;
  }

  String get riskLabel {
    switch (riskLevel.toLowerCase()) {
      case 'normal':
        return 'Normal';
      case 'low':
        return 'Low Risk';
      case 'borderline':
        return 'Borderline';
      case 'high':
        return 'High Risk';
      default:
        return 'Unknown';
    }
  }

  String get sourceLabel {
    final normalized = (secondOpinionStatus == 'completed'
            ? secondOpinionSource
            : primarySource)
        ?.toLowerCase()
        .trim();

    switch (normalized) {
      case 'gradio_server':
        return 'Cloud AI / Gradio';
      case 'manual':
      case 'clinician_review':
        return 'Manual Review';
      case 'arduino_device':
      default:
        return 'Device AI';
    }
  }

  String get secondOpinionSummary {
    switch (secondOpinionStatus) {
      case 'completed':
        return secondOpinionResult?.trim().isNotEmpty == true
            ? 'Second opinion: ${secondOpinionResult!}'
            : 'Second opinion completed';
      case 'pending':
        return 'Second opinion pending';
      case 'failed':
        return 'Second opinion failed';
      case 'not_required':
      default:
        return 'Second opinion not required';
    }
  }

  String get secondOpinionResultOrFallback =>
      secondOpinionResult?.trim().isNotEmpty == true
          ? secondOpinionResult!
          : 'Not available';

  String get secondOpinionConfidenceLabel => secondOpinionConfidence == null
      ? 'Not available'
      : '${secondOpinionConfidence!.toStringAsFixed(1)}%';

  String get deviceStatusLabel {
    switch (deviceStatus) {
      case 'success':
        return 'Device completed';
      case 'failed':
        return 'Device failed';
      case 'timeout':
        return 'Device timed out';
      case 'pending':
      default:
        return 'Device pending';
    }
  }

  String get secondOpinionBadgeLabel {
    switch (secondOpinionStatus) {
      case 'completed':
        return 'Second opinion completed';
      case 'pending':
        return 'Second opinion pending';
      case 'failed':
        return 'Second opinion failed';
      case 'not_required':
      default:
        return 'Second opinion not required';
    }
  }

  Color get secondOpinionBadgeBackground {
    switch (secondOpinionStatus) {
      case 'completed':
        return DawaTokens.statusSuccessBg;
      case 'pending':
        return DawaTokens.surfaceTertiary;
      case 'failed':
        return DawaTokens.statusDangerBg;
      case 'not_required':
      default:
        return DawaTokens.brandPrimaryPale;
    }
  }

  Color get secondOpinionBadgeForeground {
    switch (secondOpinionStatus) {
      case 'completed':
        return DawaTokens.statusSuccessText;
      case 'pending':
        return DawaTokens.textSecondary;
      case 'failed':
        return DawaTokens.statusDangerText;
      case 'not_required':
      default:
        return DawaTokens.brandPrimary;
    }
  }

  String get recommendationSummary {
    if (secondOpinionStatus == 'completed' &&
        secondOpinionResult?.trim().isNotEmpty == true) {
      return 'Secondary review result: ${secondOpinionResult!}. Continue management according to clinical protocol and local escalation pathways.';
    }

    switch (riskLevel.toLowerCase()) {
      case 'normal':
      case 'low':
        return 'Normal / low-risk screen. Continue routine follow-up according to screening guidelines.';
      case 'borderline':
        return 'Borderline result. Review findings and consider second opinion or repeat screening.';
      case 'high':
        return 'High-risk result. Prioritize clinical review, follow-up planning, and escalation where appropriate.';
      case 'unknown':
      default:
        return 'Result needs clinician interpretation. Review the device and second opinion status before closing the case.';
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}

class _Tone {
  const _Tone({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}
