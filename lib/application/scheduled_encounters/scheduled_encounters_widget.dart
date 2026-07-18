import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/appbar_nav/appbar_nav_widget.dart';
import '/components/clinician_bottom_nav/clinician_bottom_nav_widget.dart';
import '/components/dawa_design_system.dart';
import '/components/no_data_comp/no_data_comp_widget.dart';
import '/components/shimmer_animation/shimmer_animation_widget.dart';
import '/components/small_side_nav/small_side_nav_widget.dart';
import '/features/appointments/presentation/dawa_mom_appointment_requests.dart';
import '/flutter_flow/flutter_flow_button_tabbar.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:aligned_tooltip/aligned_tooltip.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'scheduled_encounters_model.dart';
export 'scheduled_encounters_model.dart';

class ScheduledEncountersWidget extends StatefulWidget {
  const ScheduledEncountersWidget({super.key});

  static String routeName = 'ScheduledEncounters';
  static String routePath = '/scheduledEncounters';

  @override
  State<ScheduledEncountersWidget> createState() =>
      _ScheduledEncountersWidgetState();
}

class _ScheduledEncountersWidgetState extends State<ScheduledEncountersWidget>
    with TickerProviderStateMixin {
  late ScheduledEncountersModel _model;
  String? _focusedDawaMomAppointmentId;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ScheduledEncountersModel());
    FFAppState().selectedPage = 'Appointments';

    _model.tabBarController = TabController(
      vsync: this,
      length: 3,
      initialIndex: 0,
    )..addListener(() => safeSetState(() {}));

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
        // Customize what your widget looks like when it's loading.
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
        List<DoctorRecord> scheduledEncountersDoctorRecordList = snapshot.data!;
        final scheduledEncountersDoctorRecord =
            scheduledEncountersDoctorRecordList.isNotEmpty
                ? scheduledEncountersDoctorRecordList.first
                : null;

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
                        currentPage: 'Appointments',
                      ),
                body: SafeArea(
                  top: true,
                  child: Row(
                    children: [
                      if (showDesktopSidebar) _buildDesktopSidebar(),
                      Expanded(child: _buildScheduledContent(context)),
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
      actions: [
        DawaMomNotificationButton(
          onOpenAppointment: _openDawaMomAppointment,
        ),
        const SizedBox(width: 4),
      ],
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
      key: const ValueKey('appointments-desktop-sidebar'),
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

  Widget _buildScheduledContent(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isSmallScreen = constraints.maxWidth < 768;
        final double horizontalPadding = isSmallScreen ? 16.0 : 24.0;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 24.0,
          ),
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
                        Text('Appointments', style: DawaTextStyles.pageTitle),
                        SizedBox(height: 6.0),
                        Text(
                          dateTimeFormat('EEEE, d MMMM y', getCurrentTimestamp),
                          style: DawaTextStyles.secondary,
                        ),
                      ],
                    ),
                  ),
                  if (!isSmallScreen) ...[
                    DawaMomNotificationButton(
                      onOpenAppointment: _openDawaMomAppointment,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (!isSmallScreen)
                    ElevatedButton.icon(
                      onPressed: () => _showScheduleAppointmentDialog(context),
                      icon: Icon(Icons.add_rounded, size: 18.0),
                      label: Text('Schedule Appointment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DawaTokens.brandPrimary,
                        foregroundColor: DawaTokens.textInverse,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(DawaTokens.radiusMd),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 18.0),
              Container(
                width: isSmallScreen ? double.infinity : 560.0,
                padding: EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: DawaTokens.surfaceTertiary,
                  borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
                ),
                child: FlutterFlowButtonTabBar(
                  useToggleButtonStyle: true,
                  labelStyle: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.0,
                  ),
                  unselectedLabelStyle: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.0,
                  ),
                  labelColor: DawaTokens.textInverse,
                  unselectedLabelColor: DawaTokens.textSecondary,
                  backgroundColor: DawaTokens.brandPrimary,
                  unselectedBackgroundColor: DawaTokens.surfaceTertiary,
                  unselectedBorderColor: Colors.transparent,
                  borderWidth: 0.0,
                  borderRadius: DawaTokens.radiusMd,
                  elevation: 0.0,
                  buttonMargin: EdgeInsets.zero,
                  padding: EdgeInsets.zero,
                  tabs: [
                    Tab(
                      text: isSmallScreen ? 'Dawa Mom' : 'Dawa Mom requests',
                    ),
                    Tab(text: isSmallScreen ? 'Other' : 'Other pending'),
                    Tab(text: 'Past'),
                  ],
                  controller: _model.tabBarController,
                  onTap: (i) async {
                    [() async {}, () async {}, () async {}][i]();
                  },
                ),
              ),
              if (isSmallScreen) ...[
                SizedBox(height: 12.0),
                SizedBox(
                  width: double.infinity,
                  height: 42.0,
                  child: OutlinedButton.icon(
                    onPressed: () => _showScheduleAppointmentDialog(context),
                    icon: Icon(Icons.add_rounded, size: 18.0),
                    label: Text('Schedule Appointment'),
                  ),
                ),
              ],
              SizedBox(height: 20),
              Expanded(
                child: TabBarView(
                  controller: _model.tabBarController,
                  children: [
                    DawaMomAppointmentRequests(
                      focusedAppointmentId: _focusedDawaMomAppointmentId,
                    ),
                    _buildPendingEncounters(context, true),
                    _buildPastEncounters(context, true),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openDawaMomAppointment(String appointmentId) {
    if (!mounted) return;
    setState(() => _focusedDawaMomAppointmentId = appointmentId);
    _model.tabBarController?.animateTo(0);
  }

  Future<void> _showScheduleAppointmentDialog(BuildContext context) async {
    final patients = await queryMotherRecordOnce(
      queryBuilder: (motherRecord) => motherRecord.orderBy('mother_id'),
    );
    if (!context.mounted) return;

    if (patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Add a patient before scheduling an appointment.'),
          backgroundColor: DawaTokens.statusWarning,
        ),
      );
      return;
    }

    MotherRecord selectedPatient = patients.first;
    DateTime selectedDate = getCurrentTimestamp.add(const Duration(days: 1));
    TimeOfDay selectedTime = TimeOfDay.now();
    var saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final scheduledAt = DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
              selectedTime.hour,
              selectedTime.minute,
            );

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
              ),
              title: Text(
                'Schedule Appointment',
                style: DawaTextStyles.cardTitle.copyWith(fontSize: 18),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Patient', style: DawaTextStyles.label),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<MotherRecord>(
                      value: selectedPatient,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: DawaTokens.surfaceSecondary,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(DawaTokens.radiusMd),
                          borderSide:
                              const BorderSide(color: DawaTokens.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(DawaTokens.radiusMd),
                          borderSide:
                              const BorderSide(color: DawaTokens.border),
                        ),
                      ),
                      items: [
                        for (final patient in patients)
                          DropdownMenuItem(
                            value: patient,
                            child: Text(
                              patient.name.isEmpty
                                  ? patient.reference.id
                                  : patient.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setDialogState(() => selectedPatient = value);
                            },
                    ),
                    const SizedBox(height: 16),
                    Text('Date and time', style: DawaTextStyles.label),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: saving
                              ? null
                              : () async {
                                  final picked = await showDatePicker(
                                    context: dialogContext,
                                    initialDate: selectedDate,
                                    firstDate: DateTime(
                                        getCurrentTimestamp.year,
                                        getCurrentTimestamp.month,
                                        getCurrentTimestamp.day),
                                    lastDate: getCurrentTimestamp
                                        .add(const Duration(days: 365)),
                                  );
                                  if (picked != null) {
                                    setDialogState(() => selectedDate = picked);
                                  }
                                },
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: Text(dateTimeFormat('d MMM y', selectedDate)),
                        ),
                        OutlinedButton.icon(
                          onPressed: saving
                              ? null
                              : () async {
                                  final picked = await showTimePicker(
                                    context: dialogContext,
                                    initialTime: selectedTime,
                                  );
                                  if (picked != null) {
                                    setDialogState(() => selectedTime = picked);
                                  }
                                },
                          icon: const Icon(Icons.schedule_rounded),
                          label: Text(selectedTime.format(dialogContext)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: DawaTokens.brandPrimaryPale,
                        borderRadius:
                            BorderRadius.circular(DawaTokens.radiusMd),
                      ),
                      child: Text(
                        'This will create a pending appointment for ${dateTimeFormat('EEEE, d MMMM y', scheduledAt)} at ${selectedTime.format(dialogContext)}.',
                        style: DawaTextStyles.secondary.copyWith(
                          color: DawaTokens.brandPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          setDialogState(() => saving = true);
                          await _createScheduledAppointment(
                            patient: selectedPatient,
                            scheduledAt: scheduledAt,
                          );
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Appointment scheduled for ${selectedPatient.name}.',
                              ),
                              backgroundColor: DawaTokens.statusSuccess,
                            ),
                          );
                        },
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(saving ? 'Scheduling...' : 'Schedule'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DawaTokens.brandPrimary,
                    foregroundColor: DawaTokens.textInverse,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createScheduledAppointment({
    required MotherRecord patient,
    required DateTime scheduledAt,
  }) {
    return EncounterRecord.collection.doc().set(
          createEncounterRecordData(
            date: scheduledAt,
            nextVisit: scheduledAt,
            motherId: patient.reference,
            doctorId: FFAppState().doctor,
            status: 'scheduled',
            isInstant: false,
            time: dateTimeFormat('Hm', scheduledAt),
          ),
        );
  }

  Widget _buildPendingEncounters(BuildContext context, bool isSmallScreen) {
    return StreamBuilder<List<EncounterRecord>>(
      stream: queryEncounterRecord(
        queryBuilder: (encounterRecord) => encounterRecord
            .where(
              'doctor_id',
              isEqualTo: FFAppState().doctor,
            )
            .where(
              'status',
              isEqualTo: 'scheduled',
            ),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: ShimmerAnimationWidget(),
          );
        }
        List<EncounterRecord> encounterList = snapshot.data!;

        if (encounterList.isEmpty) {
          return Center(
            child: NoDataCompWidget(
              message: 'No pending appointments',
              subtitle:
                  'Scheduled patient reviews will appear here when they are assigned.',
              actionLabel: 'Schedule Appointment',
              onAction: () => _showScheduleAppointmentDialog(context),
            ),
          );
        }

        if (isSmallScreen) {
          // Mobile: Card layout
          return ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            scrollDirection: Axis.vertical,
            itemCount: encounterList.length,
            itemBuilder: (context, index) {
              final encounter = encounterList[index];
              return _buildMobileEncounterCard(context, encounter, true);
            },
          );
        } else {
          // Desktop/Tablet: Table layout
          return ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: FlutterFlowTheme.of(context).alternate,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 10.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'My encounters',
                            style: FlutterFlowTheme.of(context)
                                .titleMedium
                                .override(
                                  font: GoogleFonts.dmSans(),
                                  fontWeight: FontWeight.w600,
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  letterSpacing: 0.0,
                                ),
                          ),
                        ],
                      ),
                    ),
                    // Table Header
                    Container(
                      height: 50.0,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primaryBackground,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Patient Name',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.dmSans(),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Week',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.dmSans(),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Age',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.dmSans(),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Date Scheduled',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.dmSans(),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Time',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.dmSans(),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Status',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.dmSans(),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                        ].divide(SizedBox(width: 16.0)),
                      ),
                    ),
                    // Table Rows
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        scrollDirection: Axis.vertical,
                        itemCount: encounterList.length,
                        itemBuilder: (context, index) {
                          final encounter = encounterList[index];
                          return _buildDesktopEncounterRow(
                              context, encounter, true);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildPastEncounters(BuildContext context, bool isSmallScreen) {
    return StreamBuilder<List<EncounterRecord>>(
      stream: queryEncounterRecord(
        queryBuilder: (encounterRecord) => encounterRecord
            .where(
              'doctor_id',
              isEqualTo: FFAppState().doctor,
            )
            .where(
              'status',
              isNotEqualTo: 'scheduled',
            ),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: ShimmerAnimationWidget(),
          );
        }
        List<EncounterRecord> encounterList = snapshot.data!;

        if (encounterList.isEmpty) {
          return Center(
            child: NoDataCompWidget(
              message: 'No past appointments',
              subtitle:
                  'Completed and canceled appointments will appear here for review.',
            ),
          );
        }

        if (isSmallScreen) {
          // Mobile: Card layout
          return ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            scrollDirection: Axis.vertical,
            itemCount: encounterList.length,
            itemBuilder: (context, index) {
              final encounter = encounterList[index];
              return _buildMobileEncounterCard(context, encounter, false);
            },
          );
        } else {
          // Desktop/Tablet: Table layout
          return ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: FlutterFlowTheme.of(context).alternate,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 10.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Past Encounters',
                            style: FlutterFlowTheme.of(context)
                                .titleMedium
                                .override(
                                  font: GoogleFonts.dmSans(),
                                  fontWeight: FontWeight.w600,
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  letterSpacing: 0.0,
                                ),
                          ),
                        ],
                      ),
                    ),
                    // Table Header
                    Container(
                      height: 50.0,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primaryBackground,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Patient Name',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.dmSans(),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Date Scheduled',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.dmSans(),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Next Visit',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.dmSans(),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Comment',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.dmSans(),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Status',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.dmSans(),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                        ].divide(SizedBox(width: 16.0)),
                      ),
                    ),
                    // Table Rows
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        scrollDirection: Axis.vertical,
                        itemCount: encounterList.length,
                        itemBuilder: (context, index) {
                          final encounter = encounterList[index];
                          return _buildDesktopEncounterRow(
                              context, encounter, false);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildMobileEncounterCard(
    BuildContext context,
    EncounterRecord encounter,
    bool isPending,
  ) {
    return StreamBuilder<MotherRecord>(
      stream: MotherRecord.getDocument(encounter.motherId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ShimmerAnimationWidget();
        }

        final mother = snapshot.data!;
        final statusColor = _getStatusColor(encounter.status);

        return Padding(
          padding: EdgeInsetsDirectional.only(bottom: 12.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(12.0),
            onTap: () async {
              await _handleEncounterTap(context, encounter, mother, isPending);
            },
            child: Container(
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: FlutterFlowTheme.of(context).alternate,
                ),
                boxShadow: _cardShadow(),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 5.0,
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadiusDirectional.only(
                          topStart: Radius.circular(12.0),
                          bottomStart: Radius.circular(12.0),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    mother.name,
                                    style: FlutterFlowTheme.of(context)
                                        .headlineMedium
                                        .override(
                                          font: GoogleFonts.dmSans(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 8.0),
                                _statusBadge(context, encounter.status),
                              ],
                            ),
                            SizedBox(height: 12.0),
                            Wrap(
                              spacing: 12.0,
                              runSpacing: 10.0,
                              children: [
                                _buildMobileDetailItem(
                                  'Date',
                                  dateTimeFormat(
                                    isPending ? "MMM d" : "yMMMd",
                                    encounter.date!,
                                  ),
                                ),
                                _buildMobileDetailItem(
                                  'Time',
                                  isPending ? encounter.time : '-',
                                ),
                                _buildMobileDetailItem(
                                  'Type',
                                  encounter.isInstant
                                      ? 'Instant ANC'
                                      : 'ANC Review',
                                ),
                                if (isPending)
                                  StreamBuilder<List<FirstEncounterRecord>>(
                                    stream: queryFirstEncounterRecord(
                                      queryBuilder: (firstEncounterRecord) =>
                                          firstEncounterRecord.where(
                                        'mother_Id',
                                        isEqualTo: mother.reference,
                                      ),
                                      singleRecord: true,
                                    ),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return _buildMobileDetailItem(
                                            'Week', '-');
                                      }
                                      final firstEncounterList = snapshot.data!;
                                      final firstEncounter =
                                          firstEncounterList.isNotEmpty
                                              ? firstEncounterList.first
                                              : null;

                                      return _buildMobileDetailItem(
                                        'Week',
                                        mother.firstEncounterId != null
                                            ? functions
                                                .calculateGestationalAgeInWeeks(
                                                  firstEncounter!.lnmp!,
                                                )
                                                .toString()
                                            : 'N/A',
                                      );
                                    },
                                  )
                                else
                                  _buildMobileDetailItem(
                                    'Next Visit',
                                    encounter.nextVisit != null
                                        ? dateTimeFormat(
                                            "MMM d",
                                            encounter.nextVisit!,
                                          )
                                        : '-',
                                  ),
                              ],
                            ),
                            SizedBox(height: 12.0),
                            Row(
                              children: [
                                _buildMobileDetailItem(
                                  'Age',
                                  mother.dateOfBirth != null
                                      ? functions
                                          .calculateAge(mother.dateOfBirth!)
                                          .toString()
                                      : 'N/A',
                                ),
                                if (!isPending && encounter.comment.isNotEmpty)
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsetsDirectional.only(
                                          start: 12.0),
                                      child: Text(
                                        encounter.comment,
                                        style: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .override(
                                              font: GoogleFonts.dmSans(),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              letterSpacing: 0.0,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (isPending) ...[
                              SizedBox(height: 12.0),
                              Text(
                                'Tap to review appointment',
                                style: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .override(
                                      font: GoogleFonts.dmSans(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: FlutterFlowTheme.of(context).bodySmall.override(
                font: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w500,
                ),
                color: FlutterFlowTheme.of(context).secondaryText,
                letterSpacing: 0.0,
                fontWeight: FontWeight.w500,
              ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                font: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                ),
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.0,
              ),
        ),
      ],
    );
  }

  Widget _statusBadge(BuildContext context, String status) {
    return DawaStatusBadge(status: status);
  }

  Widget _buildDesktopEncounterRow(
    BuildContext context,
    EncounterRecord encounter,
    bool isPending,
  ) {
    return StreamBuilder<MotherRecord>(
      stream: MotherRecord.getDocument(encounter.motherId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ShimmerAnimationWidget();
        }

        final mother = snapshot.data!;

        return Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              height: 50.0,
              decoration: BoxDecoration(),
              child: InkWell(
                splashColor: Colors.transparent,
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () async {
                  await _handleEncounterTap(
                      context, encounter, mother, isPending);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        mother.name,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.dmSans(),
                              letterSpacing: 0.0,
                            ),
                      ),
                    ),
                    if (isPending) ...[
                      Expanded(
                        flex: 1,
                        child: StreamBuilder<List<FirstEncounterRecord>>(
                          stream: queryFirstEncounterRecord(
                            queryBuilder: (firstEncounterRecord) =>
                                firstEncounterRecord.where(
                              'mother_Id',
                              isEqualTo: mother.reference,
                            ),
                            singleRecord: true,
                          ),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Container(
                                width: 20.0,
                                height: 30.0,
                                child: ShimmerAnimationWidget(),
                              );
                            }
                            List<FirstEncounterRecord> firstEncounterList =
                                snapshot.data!;
                            final firstEncounter = firstEncounterList.isNotEmpty
                                ? firstEncounterList.first
                                : null;

                            return AlignedTooltip(
                              content: Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Text(
                                  'If this is showing N/A then the mother has no past medical history on record',
                                  style: FlutterFlowTheme.of(context)
                                      .bodyLarge
                                      .override(
                                        font: GoogleFonts.dmSans(),
                                        letterSpacing: 0.0,
                                      ),
                                ),
                              ),
                              offset: 4.0,
                              preferredDirection: AxisDirection.down,
                              borderRadius: BorderRadius.circular(8.0),
                              backgroundColor: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                              elevation: 4.0,
                              tailBaseWidth: 24.0,
                              tailLength: 12.0,
                              waitDuration: Duration(milliseconds: 100),
                              showDuration: Duration(milliseconds: 1500),
                              triggerMode: TooltipTriggerMode.tap,
                              child: Text(
                                mother.firstEncounterId != null
                                    ? functions
                                        .calculateGestationalAgeInWeeks(
                                            firstEncounter!.lnmp!)
                                        .toString()
                                    : 'N/A',
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.dmSans(),
                                      letterSpacing: 0.0,
                                    ),
                              ),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: AutoSizeText(
                          functions
                              .calculateAge(mother.dateOfBirth!)
                              .toString(),
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.dmSans(),
                                    letterSpacing: 0.0,
                                  ),
                        ),
                      ),
                    ],
                    Expanded(
                      flex: isPending ? 2 : 1,
                      child: Text(
                        dateTimeFormat(
                          isPending ? "MMMMEEEEd" : "yMMMd",
                          encounter.date!,
                        ),
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.dmSans(),
                              letterSpacing: 0.0,
                            ),
                      ),
                    ),
                    if (isPending) ...[
                      Expanded(
                        flex: 1,
                        child: Text(
                          encounter.time,
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.dmSans(),
                                    letterSpacing: 0.0,
                                  ),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        flex: 1,
                        child: Text(
                          encounter.nextVisit != null
                              ? dateTimeFormat(
                                  "MMMMEEEEd",
                                  encounter.nextVisit!,
                                )
                              : 'No Visit Available',
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.dmSans(),
                                    letterSpacing: 0.0,
                                  ),
                        ),
                      ),
                      Expanded(
                        child: AutoSizeText(
                          encounter.comment.isNotEmpty
                              ? encounter.comment
                              : 'No comment available',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.dmSans(),
                                    letterSpacing: 0.0,
                                  ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: _getStatusColor(encounter.status),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  encounter.status,
                                  textAlign: TextAlign.center,
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.dmSans(),
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ].divide(SizedBox(width: 16.0)),
                ),
              ),
            ),
            Divider(
              thickness: 1.0,
              color: FlutterFlowTheme.of(context).primaryBackground,
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleEncounterTap(
    BuildContext context,
    EncounterRecord encounter,
    MotherRecord mother,
    bool isPending,
  ) async {
    if (isPending) {
      _model.momSelected = await MotherRecord.getDocumentOnce(mother.reference);
      if (_model.momSelected?.firstEncounterId != null) {
        context.pushNamed(
          EditEncounterWidget.routeName,
          queryParameters: {
            'momDetails': serializeParam(
              mother.reference,
              ParamType.DocumentReference,
            ),
            'encounterDetails': serializeParam(
              encounter.reference,
              ParamType.DocumentReference,
            ),
          }.withoutNulls,
        );
      } else {
        context.pushNamed(
          MomDetailsWidget.routeName,
          queryParameters: {
            'momDetails': serializeParam(
              mother.reference,
              ParamType.DocumentReference,
            ),
            'firstEncounter': serializeParam(
              mother.firstEncounterId,
              ParamType.DocumentReference,
            ),
          }.withoutNulls,
        );
      }
    } else {
      if (encounter.status == 'scheduled') {
        context.pushNamed(
          EditEncounterWidget.routeName,
          queryParameters: {
            'momDetails': serializeParam(
              mother.reference,
              ParamType.DocumentReference,
            ),
            'encounterDetails': serializeParam(
              encounter.reference,
              ParamType.DocumentReference,
            ),
          }.withoutNulls,
          extra: <String, dynamic>{
            kTransitionInfoKey: TransitionInfo(
              hasTransition: true,
              transitionType: PageTransitionType.fade,
              duration: Duration(milliseconds: 0),
            ),
          },
        );
      } else if (encounter.status != 'scheduled' &&
          encounter.performedBy != null) {
        context.goNamed(
          EncounterDetsWidget.routeName,
          queryParameters: {
            'momDets': serializeParam(
              mother.reference,
              ParamType.DocumentReference,
            ),
            'encounterDetails': serializeParam(
              encounter.reference,
              ParamType.DocumentReference,
            ),
          }.withoutNulls,
          extra: <String, dynamic>{
            kTransitionInfoKey: TransitionInfo(
              hasTransition: true,
              transitionType: PageTransitionType.fade,
              duration: Duration(milliseconds: 0),
            ),
          },
        );
      } else {
        await showDialog(
          context: context,
          builder: (alertDialogContext) {
            return AlertDialog(
              title: Text('Appointment canceled'),
              content: Text(
                  'It appears that this appointment was canceled before data could be entered'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(alertDialogContext),
                  child: Text('Ok'),
                ),
              ],
            );
          },
        );
      }
    }

    safeSetState(() {});
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return FlutterFlowTheme.of(context).success;
      case 'canceled':
        return FlutterFlowTheme.of(context).error;
      case 'scheduled':
        return FlutterFlowTheme.of(context).warning;
      default:
        return FlutterFlowTheme.of(context).warning;
    }
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
