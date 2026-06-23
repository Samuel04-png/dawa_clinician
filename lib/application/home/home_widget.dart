import 'package:clinician/application/cacx/cacx_widget.dart';
import 'package:clinician/application/ultrasound/ultrasound.dart';
import '/application/patient_details/patient_details_widget.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/application/create_mom/create_patient_modal_widget.dart';
import '/components/appbar_nav/appbar_nav_widget.dart';
import '/components/clinician_bottom_nav/clinician_bottom_nav_widget.dart';
import '/components/dawa_design_system.dart';
import '/components/shimmer_animation/shimmer_animation_widget.dart';
import '/components/small_side_nav/small_side_nav_widget.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/flutter_flow_calendar.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'home_model.dart';
export 'home_model.dart';

class HomeWidget extends StatefulWidget {
  const HomeWidget({
    super.key,
    this.firstEncounter,
  });

  final DocumentReference? firstEncounter;

  static String routeName = 'Home';
  static String routePath = '/home';

  @override
  State<HomeWidget> createState() => _HomeWidgetState();
}

class _HomeWidgetState extends State<HomeWidget> {
  late HomeModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomeModel());
    FFAppState().selectedPage = 'Home';

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.docFound = await queryDoctorRecordOnce(
        queryBuilder: (doctorRecord) => doctorRecord.where(
          'user_Id',
          isEqualTo: currentUserReference,
        ),
        singleRecord: true,
      ).then((s) => s.firstOrNull);
      if ((_model.docFound?.clinicName != null &&
              _model.docFound?.clinicName != '') &&
          (_model.docFound?.startTime != null &&
              _model.docFound?.startTime != '') &&
          (_model.docFound?.endTime != null &&
              _model.docFound?.endTime != '') &&
          (_model.docFound?.name != null && _model.docFound?.name != '') &&
          (_model.docFound?.phoneNumber != null &&
              _model.docFound?.phoneNumber != '')) {
        FFAppState().doctor = _model.docFound?.reference;
        safeSetState(() {});
      } else {
        context.goNamed(CompleteClincianRegWidget.routeName);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return StreamBuilder<List<DoctorRecord>>(
      stream: queryDoctorRecord(
        queryBuilder: (doctorRecord) => doctorRecord.where(
          'user_Id',
          isEqualTo: currentUserReference,
        ),
        singleRecord: true,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
            body: Center(
              child: SizedBox(
                width: 50.0,
                height: 50.0,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    FlutterFlowTheme.of(context).primary,
                  ),
                ),
              ),
            ),
          );
        }
        final homeDoctorRecordList = snapshot.data!;
        final homeDoctorRecord =
            homeDoctorRecordList.isNotEmpty ? homeDoctorRecordList.first : null;

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: LayoutBuilder(
            builder: (context, pageConstraints) {
              final showDesktopSidebar = pageConstraints.maxWidth >= 768.0;

              return Scaffold(
                key: scaffoldKey,
                backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
                drawer: showDesktopSidebar ? null : _buildMobileDrawer(),
                appBar: showDesktopSidebar ? null : _buildMobileAppBar(),
                bottomNavigationBar: showDesktopSidebar
                    ? null
                    : ClinicianBottomNavWidget(
                        currentPage: 'Home',
                      ),
                body: SafeArea(
                  top: true,
                  child: Row(
                    children: [
                      if (showDesktopSidebar) _buildDesktopSidebar(),
                      Expanded(
                        child: _buildHomeContent(
                          context,
                          homeDoctorRecord,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: 'Open navigation',
        icon: Icon(
          Icons.menu_rounded,
          color: FlutterFlowTheme.of(context).primary,
        ),
        onPressed: () => scaffoldKey.currentState?.openDrawer(),
      ),
      title: wrapWithModel(
        model: _model.appbarNavModel,
        updateCallback: () => safeSetState(() {}),
        child: AppbarNavWidget(),
      ),
      actions: [],
      centerTitle: false,
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
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primaryBackground,
          ),
          child: wrapWithModel(
            model: _model.smallSideNavModel,
            updateCallback: () => safeSetState(() {}),
            child: SmallSideNavWidget(),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      key: const ValueKey('home-desktop-sidebar'),
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
      child: wrapWithModel(
        model: _model.smallSideNavModel,
        updateCallback: () => safeSetState(() {}),
        child: SmallSideNavWidget(),
      ),
    );
  }

  Widget _buildHomeContent(
    BuildContext context,
    DoctorRecord? homeDoctorRecord,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 700.0;
        final horizontalPadding = isSmallScreen ? 16.0 : 24.0;

        return SingleChildScrollView(
          padding: EdgeInsetsDirectional.fromSTEB(
            horizontalPadding,
            24.0,
            horizontalPadding,
            isSmallScreen ? 96.0 : 32.0,
          ),
          child: Align(
            alignment: AlignmentDirectional.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 1120.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDashboardHeader(context),
                  SizedBox(height: 22.0),
                  _buildStatsCard(context, homeDoctorRecord),
                  SizedBox(height: 24.0),
                  _buildActionsSection(context),
                  SizedBox(height: 24.0),
                  constraints.maxWidth >= 900.0
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildRecentPatientsSection(context),
                            ),
                            SizedBox(width: 24.0),
                            SizedBox(
                              width: 320.0,
                              child: _buildCalendarCard(
                                context,
                                homeDoctorRecord,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildRecentPatientsSection(context),
                            SizedBox(height: 24.0),
                            _buildCalendarCard(context, homeDoctorRecord),
                          ],
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDashboardHeader(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 560.0;

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateTimeFormat('EEEE, d MMMM y', getCurrentTimestamp),
                style: DawaTextStyles.secondary.copyWith(
                  color: DawaTokens.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                textScaler: MediaQuery.of(context).textScaler,
                text: TextSpan(
                  children: [
                    const TextSpan(text: 'Good '),
                    TextSpan(text: functions.greeting(getCurrentTimestamp)),
                  ],
                  style: DawaTextStyles.pageTitle.copyWith(
                    fontSize: 22,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    textScaler: MediaQuery.of(context).textScaler,
                    text: TextSpan(
                      children: [
                        const TextSpan(text: 'Good '),
                        TextSpan(text: functions.greeting(getCurrentTimestamp)),
                      ],
                      style: DawaTextStyles.pageTitle,
                    ),
                  ),
                  SizedBox(height: 6.0),
                  Text(
                    'Here is your clinical summary for maternal and women\'s health care today.',
                    style: DawaTextStyles.secondary,
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsetsDirectional.fromSTEB(12.0, 8.0, 12.0, 8.0),
              decoration: BoxDecoration(
                color: DawaTokens.brandPrimaryPale,
                borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
                border: Border.all(color: DawaTokens.border),
              ),
              child: Text(
                dateTimeFormat('EEEE, d MMMM y', getCurrentTimestamp),
                style: DawaTextStyles.secondary.copyWith(
                  color: DawaTokens.brandPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsCard(BuildContext context, DoctorRecord? doctorRecord) {
    return StreamBuilder<List<EncounterRecord>>(
      stream: queryEncounterRecord(
        queryBuilder: (encounterRecord) => encounterRecord
            .where(
              'doctor_id',
              isEqualTo: doctorRecord?.reference,
            )
            .where(
              'status',
              isEqualTo: 'scheduled',
            ),
      ),
      builder: (context, appointmentsSnapshot) {
        return FutureBuilder<List<MotherRecord>>(
          future: queryMotherRecordOnce(),
          builder: (context, patientsSnapshot) {
            if (!patientsSnapshot.hasData || !appointmentsSnapshot.hasData) {
              return ShimmerAnimationWidget();
            }

            final patients = patientsSnapshot.data!;
            final appointmentsToday = appointmentsSnapshot.data!
                .where((encounter) => _isSameDay(encounter.date))
                .length;
            final missingData = patients
                .where((mother) => mother.firstEncounterId == null)
                .length;
            final newThisWeek = patients.length < 3 ? patients.length : 3;

            return LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 560.0;
                final isTablet = constraints.maxWidth < 900.0;
                final cardWidth = isMobile
                    ? (constraints.maxWidth - 10.0) / 2
                    : (constraints.maxWidth - (isTablet ? 16.0 : 48.0)) /
                        (isTablet ? 2 : 4);

                final cards = [
                  DawaStatCard(
                    width: cardWidth,
                    icon: Icons.people_alt_rounded,
                    label: 'Patients',
                    value: patients.length.toString(),
                    color: DawaTokens.brandPrimary,
                    onTap: () => _goToPatients(context),
                  ),
                  DawaStatCard(
                    width: cardWidth,
                    icon: Icons.calendar_today_rounded,
                    label: 'Appts Today',
                    value: appointmentsToday.toString(),
                    color: DawaTokens.brandPrimaryLight,
                    onTap: () => _goToAppointments(context),
                  ),
                  DawaStatCard(
                    width: cardWidth,
                    icon: Icons.warning_amber_rounded,
                    label: 'Missing Data',
                    value: missingData.toString(),
                    color: DawaTokens.statusDanger,
                    onTap: () => _goToPatients(context),
                  ),
                  DawaStatCard(
                    width: cardWidth,
                    icon: Icons.fiber_new_rounded,
                    label: 'New This Week',
                    value: newThisWeek.toString(),
                    color: DawaTokens.brandPrimaryLight,
                    onTap: () => _goToPatients(context),
                  ),
                ];

                if (isMobile) {
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: cards,
                  );
                }

                return Wrap(
                  spacing: 16.0,
                  runSpacing: 16.0,
                  children: cards,
                );
              },
            );
          },
        );
      },
    );
  }

  bool _isSameDay(DateTime? value) {
    if (value == null) return false;
    final now = getCurrentTimestamp;
    return value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
  }

  void _goToPatients(BuildContext context) {
    context.goNamed(
      MomsWidget.routeName,
      extra: <String, dynamic>{
        kTransitionInfoKey: TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.fade,
          duration: Duration.zero,
        ),
      },
    );
  }

  void _goToAppointments(BuildContext context) {
    context.goNamed(
      ScheduledEncountersWidget.routeName,
      extra: <String, dynamic>{
        kTransitionInfoKey: TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.fade,
          duration: Duration.zero,
        ),
      },
    );
  }

  Widget _buildCalendarCard(
    BuildContext context,
    DoctorRecord? doctorRecord,
  ) {
    return StreamBuilder<List<EncounterRecord>>(
      stream: queryEncounterRecord(
        queryBuilder: (encounterRecord) => encounterRecord
            .where(
              'doctor_id',
              isEqualTo: doctorRecord?.reference,
            )
            .where(
              'status',
              isEqualTo: 'scheduled',
            ),
      ),
      builder: (context, snapshot) {
        final markedDates = snapshot.data
                ?.where((encounter) => encounter.date != null)
                .map((encounter) => encounter.date!)
                .toList() ??
            [];

        return DawaCard(
          padding: EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Calendar',
                      style: DawaTextStyles.cardTitle,
                    ),
                  ),
                  Icon(
                    Icons.calendar_month_rounded,
                    color: DawaTokens.brandPrimary,
                    size: 20.0,
                  ),
                ],
              ),
              SizedBox(height: 12.0),
              FlutterFlowCalendar(
                color: FlutterFlowTheme.of(context).primary,
                iconColor: FlutterFlowTheme.of(context).primary,
                weekFormat: false,
                weekStartsMonday: false,
                initialDate: getCurrentTimestamp,
                rowHeight: 34.0,
                markedDates: markedDates,
                onChange: (DateTimeRange? newSelectedDate) {
                  safeSetState(
                      () => _model.calendarSelectedDay = newSelectedDate);
                },
                titleStyle:
                    FlutterFlowTheme.of(context).headlineMedium.override(
                          font: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w600,
                          ),
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w600,
                        ),
                dayOfWeekStyle:
                    FlutterFlowTheme.of(context).labelMedium.override(
                          font: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w600,
                          ),
                          color: FlutterFlowTheme.of(context).secondaryText,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w600,
                        ),
                dateStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.dmSans(),
                      color: FlutterFlowTheme.of(context).primaryText,
                      letterSpacing: 0.0,
                    ),
                selectedDateStyle: FlutterFlowTheme.of(context)
                    .titleSmall
                    .override(
                      font: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600,
                      ),
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                    ),
                inactiveDateStyle:
                    FlutterFlowTheme.of(context).bodySmall.override(
                          font: GoogleFonts.dmSans(),
                          color: FlutterFlowTheme.of(context).secondaryText,
                          letterSpacing: 0.0,
                        ),
              ),
              SizedBox(height: 16.0),
              SizedBox(
                width: double.infinity,
                height: 42.0,
                child: ElevatedButton.icon(
                  onPressed: () => _goToAppointments(context),
                  icon: Icon(Icons.add_rounded, size: 18.0),
                  label: Text('Schedule Appointment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DawaTokens.brandPrimary,
                    foregroundColor: DawaTokens.textInverse,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentPatientsSection(BuildContext context) {
    return StreamBuilder<List<MotherRecord>>(
      stream: queryMotherRecord(
        queryBuilder: (motherRecord) => motherRecord.orderBy(
          'mother_id',
          descending: true,
        ),
        limit: 5,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ShimmerAnimationWidget();
        }

        final patients = snapshot.data!;

        return DawaCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(20.0, 16.0, 20.0, 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Recent Patients',
                        style: DawaTextStyles.cardTitle,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _goToPatients(context),
                      child: Text('View all patients'),
                    ),
                  ],
                ),
              ),
              Divider(height: 1.0, color: DawaTokens.border),
              if (patients.isEmpty)
                Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'No recent patients yet',
                    style: DawaTextStyles.secondary,
                  ),
                )
              else
                Column(
                  children: patients
                      .map(
                        (patient) => _recentPatientRow(context, patient),
                      )
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _recentPatientRow(BuildContext context, MotherRecord patient) {
    return StreamBuilder<List<FirstEncounterRecord>>(
      stream: queryFirstEncounterRecord(
        queryBuilder: (firstEncounterRecord) => firstEncounterRecord.where(
          'mother_Id',
          isEqualTo: patient.reference,
        ),
        singleRecord: true,
      ),
      builder: (context, snapshot) {
        final firstEncounter =
            snapshot.data?.isNotEmpty == true ? snapshot.data!.first : null;
        final age = patient.dateOfBirth != null
            ? functions.calculateAge(patient.dateOfBirth!).toString()
            : 'N/A';
        final weeks = firstEncounter?.lnmp != null
            ? functions
                .calculateGestationalAgeInWeeks(firstEncounter!.lnmp!)
                .toString()
            : 'N/A';
        final missingData = patient.firstEncounterId == null;

        return InkWell(
          onTap: () => _openPatient(patient, firstEncounter),
          child: Container(
            padding: EdgeInsetsDirectional.fromSTEB(20.0, 14.0, 20.0, 14.0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: DawaTokens.border),
              ),
            ),
            child: Row(
              children: [
                DawaAvatarCircle(name: patient.name, size: 40.0),
                SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DawaTextStyles.cardTitle,
                      ),
                      SizedBox(height: 3.0),
                      Text(
                        'Age $age | Weeks $weeks | ${patient.phoneNumber.isNotEmpty ? patient.phoneNumber : 'No phone'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DawaTextStyles.secondary,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.0),
                DawaStatusBadge(
                  status: missingData ? 'missing_data' : 'had_first_encounter',
                ),
                SizedBox(width: 8.0),
                Icon(
                  Icons.chevron_right_rounded,
                  color: DawaTokens.textMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openPatient(
      MotherRecord patient, FirstEncounterRecord? firstEncounter) {
    context.pushNamed(
      PatientDetailsWidget.routeName,
      queryParameters: {
        'momDetails': serializeParam(
          patient.reference,
          ParamType.DocumentReference,
        ),
        'firstEncounter': serializeParam(
          firstEncounter?.reference ?? patient.firstEncounterId,
          ParamType.DocumentReference,
        ),
      }.withoutNulls,
      extra: <String, dynamic>{
        kTransitionInfoKey: TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.fade,
          duration: Duration(milliseconds: 160),
        ),
      },
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200.0
            ? 4
            : constraints.maxWidth >= 768.0
                ? 3
                : constraints.maxWidth >= 560.0
                    ? 2
                    : 1;
        final itemWidth =
            (constraints.maxWidth - (12.0 * (columns - 1))) / columns;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: DawaTextStyles.cardTitle.copyWith(fontSize: 16.0),
            ),
            SizedBox(height: 12.0),
            Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              children: [
                _actionCard(
                  width: itemWidth,
                  title: 'New Patient',
                  subtitle: 'Register a health record',
                  icon: Icons.person_add_alt_1_rounded,
                  color: DawaTokens.brandPrimary,
                  onTap: () => _showCreatePatientModal(context),
                ),
                _actionCard(
                  width: itemWidth,
                  title: 'Schedule Appointment',
                  subtitle: 'Create a patient appointment',
                  icon: Icons.event_available_rounded,
                  color: DawaTokens.brandPrimary,
                  onTap: () => _goToAppointments(context),
                ),
                _actionCard(
                  width: itemWidth,
                  title: 'CaCx',
                  subtitle: 'Screening module',
                  icon: Icons.health_and_safety_outlined,
                  color: DawaTokens.brandPrimary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CaCxApp(),
                      ),
                    );
                  },
                ),
                _actionCard(
                  width: itemWidth,
                  title: 'HemoNix',
                  subtitle: 'Haemoglobin tracking',
                  icon: Icons.bloodtype_outlined,
                  color: DawaTokens.brandPrimary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const QuickAccessServiceApp(
                          service: QuickAccessServiceType.hemonix,
                        ),
                      ),
                    );
                  },
                ),
                _actionCard(
                  width: itemWidth,
                  title: 'CT Scan',
                  subtitle: 'Imaging records',
                  icon: Icons.monitor_heart_outlined,
                  color: DawaTokens.brandPrimary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const QuickAccessServiceApp(
                          service: QuickAccessServiceType.ctScan,
                        ),
                      ),
                    );
                  },
                ),
                _actionCard(
                  width: itemWidth,
                  title: 'Ultrasound',
                  subtitle: 'Scan workflows',
                  icon: Icons.sensors_rounded,
                  color: DawaTokens.brandPrimary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UltrasoundApp(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreatePatientModal(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (modalContext) => const CreatePatientModalWidget(),
    );
  }

  Widget _actionCard({
    required double width,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: width,
      child: DawaCard(
        onTap: onTap,
        padding: EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 42.0,
              height: 42.0,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
              ),
              child: Icon(icon, color: color, size: 22.0),
            ),
            SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DawaTextStyles.cardTitle,
                  ),
                  SizedBox(height: 3.0),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DawaTextStyles.secondary.copyWith(fontSize: 12.0),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: DawaTokens.textMuted),
          ],
        ),
      ),
    );
  }

  List<BoxShadow> _cardShadow() {
    return const [
      BoxShadow(
        blurRadius: 8.0,
        color: Color(0x0F000000),
        offset: Offset(0.0, 2.0),
      ),
    ];
  }
}
