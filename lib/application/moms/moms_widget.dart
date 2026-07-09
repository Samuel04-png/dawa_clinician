import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/application/create_mom/create_patient_modal_widget.dart';
import '/components/appbar_nav/appbar_nav_widget.dart';
import '/components/clinician_bottom_nav/clinician_bottom_nav_widget.dart';
import '/components/dawa_design_system.dart';
import '/components/no_data_comp/no_data_comp_widget.dart';
import '/components/shimmer_animation/shimmer_animation_widget.dart';
import '/components/small_side_nav/small_side_nav_widget.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'moms_model.dart';
export 'moms_model.dart';

class MomsWidget extends StatefulWidget {
  const MomsWidget({super.key});

  static String routeName = 'Moms';
  static String routePath = '/moms';

  @override
  State<MomsWidget> createState() => _MomsWidgetState();
}

class _MomsWidgetState extends State<MomsWidget> {
  late MomsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MomsModel());
    FFAppState().selectedPage = 'Patients';

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthUserStreamWidget(
      builder: (context) => StreamBuilder<List<DoctorRecord>>(
        stream: _model.mothers(
          uniqueQueryKey: currentUserDisplayName,
          requestFn: () => queryDoctorRecord(
            queryBuilder: (doctorRecord) => doctorRecord.where(
              'user_Id',
              isEqualTo: currentUserReference,
            ),
            singleRecord: true,
          ),
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
                  backgroundColor:
                      FlutterFlowTheme.of(context).primaryBackground,
                  drawer: showDesktopSidebar ? null : _buildMobileDrawer(),
                  appBar: showDesktopSidebar ? null : _buildMobileAppBar(),
                  bottomNavigationBar: showDesktopSidebar
                      ? null
                      : ClinicianBottomNavWidget(
                          currentPage: 'Patients',
                        ),
                  floatingActionButton: _buildCreateMotherFab(context),
                  floatingActionButtonLocation:
                      FloatingActionButtonLocation.endFloat,
                  body: SafeArea(
                    top: true,
                    child: Row(
                      children: [
                        if (showDesktopSidebar) _buildDesktopSidebar(),
                        Expanded(child: _buildPatientsContent(context)),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
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
      key: const ValueKey('patients-desktop-sidebar'),
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

  Widget _buildPatientsContent(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 600.0 ? 16.0 : 24.0;

        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: EdgeInsetsDirectional.fromSTEB(
            horizontalPadding,
            constraints.maxWidth < 600.0 ? 18.0 : 24.0,
            horizontalPadding,
            0.0,
          ),
          child: Align(
            alignment: AlignmentDirectional.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 1040.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Patients',
                              style: DawaTextStyles.pageTitle,
                            ),
                            SizedBox(height: 4.0),
                            Text(
                              'Find patients, review missing data, and open clinical records.',
                              style: DawaTextStyles.secondary,
                            ),
                          ],
                        ),
                      ),
                      if (constraints.maxWidth >= 760.0)
                        SizedBox(
                          height: 40.0,
                          child: ElevatedButton.icon(
                            onPressed: () => _showCreatePatientModal(context),
                            icon: Icon(Icons.person_add_alt_1_rounded,
                                size: 18.0),
                            label: Text('New Patient'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DawaTokens.brandPrimary,
                              foregroundColor: DawaTokens.textInverse,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 16.0),
                  _buildPatientSummaryStrip(context),
                  SizedBox(height: 16.0),
                  _buildSearchBar(context),
                  SizedBox(height: 12.0),
                  _buildFilterChips(context),
                  SizedBox(height: 16.0),
                  Expanded(
                    child:
                        PagedListView<DocumentSnapshot<Object?>?, MotherRecord>(
                      pagingController: _model.setListViewController(
                        _activePatientsQuery(MotherRecord.collection)
                            .orderBy('mother_id'),
                      ),
                      padding: EdgeInsetsDirectional.fromSTEB(
                        0.0,
                        0.0,
                        0.0,
                        96.0,
                      ),
                      builderDelegate: PagedChildBuilderDelegate<MotherRecord>(
                        firstPageProgressIndicatorBuilder: (_) =>
                            ShimmerAnimationWidget(),
                        newPageProgressIndicatorBuilder: (_) =>
                            ShimmerAnimationWidget(),
                        noItemsFoundIndicatorBuilder: (_) => Center(
                          child: NoDataCompWidget(
                            message: 'No mother data found',
                          ),
                        ),
                        itemBuilder: (context, _, listViewIndex) {
                          final listViewMotherRecord = _model
                              .listViewPagingController!
                              .itemList![listViewIndex];

                          if (!_matchesVisibleFilters(listViewMotherRecord)) {
                            return SizedBox.shrink();
                          }

                          return StreamBuilder<List<FirstEncounterRecord>>(
                            stream: queryFirstEncounterRecord(
                              queryBuilder: (firstEncounterRecord) =>
                                  firstEncounterRecord.where(
                                'mother_Id',
                                isEqualTo: listViewMotherRecord.reference,
                              ),
                              singleRecord: true,
                            ),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return ShimmerAnimationWidget();
                              }
                              final firstEncounterRecordList = snapshot.data!;
                              final firstEncounterRecord =
                                  firstEncounterRecordList.isNotEmpty
                                      ? firstEncounterRecordList.first
                                      : null;

                              return _buildPatientCard(
                                context,
                                listViewMotherRecord,
                                firstEncounterRecord,
                              );
                            },
                          );
                        },
                      ),
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

  Widget _buildPatientSummaryStrip(BuildContext context) {
    return StreamBuilder<List<MotherRecord>>(
      stream: queryMotherRecord(queryBuilder: _activePatientsQuery),
      builder: (context, snapshot) {
        final patients = _visiblePatients(
          snapshot.data ?? _model.listViewPagingController?.itemList ?? [],
        );
        final missing = patients
            .where((patient) => patient.firstEncounterId == null)
            .length;
        final active = patients.length - missing;
        final withPhone = patients
            .where((patient) => patient.phoneNumber.trim().isNotEmpty)
            .length;

        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 700.0;
            final cards = [
              _PatientMetric(
                label: 'Total patients',
                value: patients.length.toString(),
                icon: Icons.people_alt_rounded,
                color: DawaTokens.brandPrimary,
              ),
              _PatientMetric(
                label: 'Active records',
                value: active.toString(),
                icon: Icons.verified_user_outlined,
                color: DawaTokens.statusSuccess,
              ),
              _PatientMetric(
                label: 'Missing data',
                value: missing.toString(),
                icon: Icons.warning_amber_rounded,
                color: DawaTokens.statusDanger,
              ),
              _PatientMetric(
                label: 'Contactable',
                value: withPhone.toString(),
                icon: Icons.phone_outlined,
                color: DawaTokens.brandPrimaryLight,
              ),
            ];

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cards
                  .map(
                    (metric) => SizedBox(
                      width: compact
                          ? (constraints.maxWidth - 12) / 2
                          : (constraints.maxWidth - 36) / 4,
                      child: _patientMetricCard(context, metric),
                    ),
                  )
                  .toList(),
            );
          },
        );
      },
    );
  }

  Widget _patientMetricCard(BuildContext context, _PatientMetric metric) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
        border: Border.all(color: _borderColor(context)),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? []
            : DawaTokens.shadowSm,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: metric.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(metric.icon, color: metric.color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.value,
                  style: DawaTextStyles.statNumber.copyWith(fontSize: 21),
                ),
                const SizedBox(height: 3),
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DawaTextStyles.secondary.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateMotherFab(BuildContext context) {
    Future<void> goToCreateMother() async {
      await _showCreatePatientModal(context);
    }

    final isCompact = MediaQuery.sizeOf(context).width < 420.0;

    if (isCompact) {
      return FloatingActionButton(
        onPressed: goToCreateMother,
        backgroundColor: DawaTokens.brandPrimary,
        foregroundColor: DawaTokens.textInverse,
        elevation: 10.0,
        shape: const CircleBorder(),
        tooltip: 'New Patient',
        child: Icon(Icons.add_rounded),
      );
    }

    return SizedBox(
      width: 180.0,
      height: 52.0,
      child: FloatingActionButton.extended(
        onPressed: goToCreateMother,
        backgroundColor: DawaTokens.brandPrimary,
        foregroundColor: DawaTokens.textInverse,
        elevation: 10.0,
        hoverElevation: 12.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        icon: Icon(Icons.add_rounded),
        label: Text(
          'New Patient',
          style: GoogleFonts.dmSans(
            color: DawaTokens.textInverse,
            fontSize: 14.0,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _showCreatePatientModal(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (modalContext) => const CreatePatientModalWidget(),
    );

    if (created == true) {
      _model.listViewPagingController?.refresh();
    }
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      height: 52.0,
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: _borderColor(context),
        ),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? []
            : DawaTokens.shadowSm,
      ),
      child: TextFormField(
        controller: _searchController,
        onChanged: (value) {
          safeSetState(() {
            _searchText = value.trim().toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: 'Search patients',
          hintStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                font: GoogleFonts.dmSans(),
                color: FlutterFlowTheme.of(context).secondaryText,
                letterSpacing: 0.0,
              ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: FlutterFlowTheme.of(context).secondaryText,
          ),
          suffixIcon: _searchText.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    safeSetState(() {
                      _searchText = '';
                    });
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsetsDirectional.fromSTEB(
            0.0,
            16.0,
            16.0,
            16.0,
          ),
        ),
        style: FlutterFlowTheme.of(context).bodyMedium.override(
              font: GoogleFonts.dmSans(),
              color: FlutterFlowTheme.of(context).primaryText,
              letterSpacing: 0.0,
            ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return StreamBuilder<List<MotherRecord>>(
      stream: queryMotherRecord(queryBuilder: _activePatientsQuery),
      builder: (context, snapshot) {
        final loadedPatients = _visiblePatients(
          snapshot.data ?? _model.listViewPagingController?.itemList ?? [],
        );
        final missingData = loadedPatients
            .where((mother) => mother.firstEncounterId == null)
            .length;
        final newImported = loadedPatients.where(_isNewImported).length;
        final counts = <String, int>{
          'All': loadedPatients.length,
          'Missing Data': missingData,
          'Active': loadedPatients.length - missingData,
          'New': newImported,
        };
        final filters = ['All', 'Missing Data', 'Active', 'New'];

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters
                .map(
                  (filter) => Padding(
                    padding: EdgeInsetsDirectional.only(end: 8.0),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(filter),
                          SizedBox(width: 6.0),
                          Container(
                            padding: EdgeInsetsDirectional.fromSTEB(
                              6.0,
                              2.0,
                              6.0,
                              2.0,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedFilter == filter
                                  ? Colors.white.withOpacity(0.18)
                                  : DawaTokens.surfaceTertiary,
                              borderRadius: BorderRadius.circular(99.0),
                            ),
                            child: Text(
                              (counts[filter] ?? 0).toString(),
                              style: GoogleFonts.dmSans(
                                color: _selectedFilter == filter
                                    ? DawaTokens.textInverse
                                    : DawaTokens.textSecondary,
                                fontSize: 11.0,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      selected: _selectedFilter == filter,
                      onSelected: (_) {
                        safeSetState(() {
                          _selectedFilter = filter;
                        });
                      },
                      selectedColor: DawaTokens.brandPrimary,
                      backgroundColor: DawaTokens.surface,
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: _selectedFilter == filter
                              ? DawaTokens.brandPrimary
                              : DawaTokens.border,
                          width: 1.5,
                        ),
                      ),
                      labelStyle: GoogleFonts.dmSans(
                        color: _selectedFilter == filter
                            ? DawaTokens.textInverse
                            : DawaTokens.textSecondary,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildPatientCard(
    BuildContext context,
    MotherRecord mother,
    FirstEncounterRecord? firstEncounter,
  ) {
    final age = mother.dateOfBirth != null
        ? functions.calculateAge(mother.dateOfBirth!).toString()
        : 'N/A';
    final weeks =
        mother.firstEncounterId != null && firstEncounter?.lnmp != null
            ? functions
                .calculateGestationalAgeInWeeks(firstEncounter!.lnmp!)
                .toString()
            : 'N/A';

    final missingData = mother.firstEncounterId == null;

    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: 10.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640.0;
          final meta = 'Age $age  |  Weeks $weeks';
          final phone = mother.phoneNumber.isNotEmpty
              ? mother.phoneNumber
              : 'No phone recorded';
          final address = mother.address.isNotEmpty
              ? mother.address
              : 'No address recorded';

          return Material(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
            child: InkWell(
              borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
              onTap: () => _navigateToDetails(mother, firstEncounter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: double.infinity,
                padding: EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 14.0, 16.0),
                decoration: BoxDecoration(
                  color: _surfaceColor(context),
                  borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
                  border: Border.all(color: _borderColor(context)),
                  boxShadow: Theme.of(context).brightness == Brightness.dark
                      ? []
                      : DawaTokens.shadowSm,
                ),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              DawaAvatarCircle(
                                name: mother.name,
                                moduleColor: _avatarColorForName(mother.name),
                                size: 42.0,
                              ),
                              SizedBox(width: 12.0),
                              Expanded(child: _patientIdentity(mother, meta)),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: DawaTokens.textMuted,
                              ),
                            ],
                          ),
                          SizedBox(height: 12.0),
                          _patientLocation(context, address),
                          SizedBox(height: 10.0),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _patientInfoPill(
                                  context, Icons.phone_outlined, phone),
                              _patientInfoPill(
                                  context,
                                  Icons.badge_outlined,
                                  mother.motherId.isNotEmpty
                                      ? mother.motherId
                                      : 'No patient ID'),
                              if (mother.isImportedFromDawaMom)
                                _patientInfoPill(
                                  context,
                                  Icons.sync_alt_rounded,
                                  'Registered through Dawa Mom',
                                ),
                              _buildStatusBadge(mother),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          DawaAvatarCircle(
                            name: mother.name,
                            moduleColor: _avatarColorForName(mother.name),
                            size: 42.0,
                          ),
                          SizedBox(width: 14.0),
                          Expanded(
                            flex: 3,
                            child: _patientIdentity(mother, meta),
                          ),
                          SizedBox(width: 14.0),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _patientLocation(context, address),
                                SizedBox(height: 6.0),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _patientInfoPill(
                                        context, Icons.phone_outlined, phone),
                                    _patientInfoPill(
                                      context,
                                      Icons.work_outline,
                                      mother.occupation.isNotEmpty
                                          ? mother.occupation
                                          : 'No occupation',
                                    ),
                                    if (mother.isImportedFromDawaMom)
                                      _patientInfoPill(
                                        context,
                                        Icons.sync_alt_rounded,
                                        'Registered through Dawa Mom',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 14.0),
                          SizedBox(
                              width: 170.0, child: _buildStatusBadge(mother)),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: DawaTokens.textMuted,
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _patientIdentity(MotherRecord mother, String meta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          mother.name.isNotEmpty ? mother.name : 'Unnamed patient',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DawaTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 5.0),
        Text(
          meta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DawaTextStyles.secondary.copyWith(fontSize: 12.0),
        ),
      ],
    );
  }

  Widget _patientLocation(BuildContext context, String address) {
    return Row(
      children: [
        Icon(
          Icons.location_on_outlined,
          color: DawaTokens.textMuted,
          size: 15.0,
        ),
        SizedBox(width: 4.0),
        Expanded(
          child: Text(
            address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DawaTextStyles.secondary.copyWith(
              color: _secondaryTextColor(context),
              fontSize: 12.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _patientInfoPill(BuildContext context, IconData icon, String value) {
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(8.0, 5.0, 10.0, 5.0),
      decoration: BoxDecoration(
        color: _mutedSurfaceColor(context),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.0, color: DawaTokens.textMuted),
          SizedBox(width: 5.0),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DawaTextStyles.secondary.copyWith(
              color: _secondaryTextColor(context),
              fontSize: 11.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(BuildContext context, String label, String value) {
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(10.0, 6.0, 10.0, 6.0),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(100.0),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
        ),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: FlutterFlowTheme.of(context).labelSmall.override(
                    font: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w500,
                    ),
                    color: FlutterFlowTheme.of(context).secondaryText,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            TextSpan(
              text: value,
              style: FlutterFlowTheme.of(context).labelSmall.override(
                    font: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                    ),
                    color: FlutterFlowTheme.of(context).primaryText,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconTextRow(
    BuildContext context,
    IconData icon,
    String value,
    Color textColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: FlutterFlowTheme.of(context).secondaryText,
          size: 18.0,
        ),
        SizedBox(width: 8.0),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  font: GoogleFonts.dmSans(),
                  color: textColor,
                  letterSpacing: 0.0,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(MotherRecord mother) {
    if (_isNewImported(mother)) {
      return DawaStatusBadge(status: 'new');
    }

    final missingData = mother.firstEncounterId == null;
    return DawaStatusBadge(
      status: missingData ? 'missing_data' : 'had_first_encounter',
    );
  }

  Color _avatarColorForName(String name) {
    const colors = [
      DawaTokens.brandPrimary,
      DawaTokens.brandPrimaryLight,
      DawaTokens.brandAccent,
    ];
    if (name.isEmpty) return colors.first;
    return colors[name.codeUnitAt(0) % colors.length];
  }

  Color _surfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF181D26)
        : DawaTokens.surface;
  }

  Color _mutedSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF232B38)
        : DawaTokens.surfaceTertiary;
  }

  Color _borderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF303746)
        : DawaTokens.border;
  }

  Color _secondaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB6C2D3)
        : DawaTokens.textSecondary;
  }

  bool _matchesVisibleFilters(MotherRecord mother) {
    if (mother.sourceDeletedAt != null) {
      return false;
    }

    final text = _searchText;
    final matchesSearch = text.isEmpty ||
        mother.name.toLowerCase().contains(text) ||
        mother.phoneNumber.toLowerCase().contains(text) ||
        mother.address.toLowerCase().contains(text) ||
        mother.sourceMotherId.toLowerCase().contains(text);

    if (!matchesSearch) {
      return false;
    }

    switch (_selectedFilter) {
      case 'Missing Data':
        return mother.firstEncounterId == null;
      case 'New':
        return _isNewImported(mother);
      case 'Active':
        return mother.firstEncounterId != null;
      case 'All':
      default:
        return true;
    }
  }

  Query _activePatientsQuery(Query motherRecord) =>
      motherRecord.where('source_deleted_at', isNull: true);

  List<MotherRecord> _visiblePatients(List<MotherRecord> patients) =>
      patients.where((patient) => patient.sourceDeletedAt == null).toList();

  bool _isNewImported(MotherRecord mother) =>
      mother.isImportedFromDawaMom && mother.firstEncounterId == null;

  void _navigateToDetails(
    MotherRecord mother,
    FirstEncounterRecord? firstEncounter,
  ) async {
    context.pushNamed(
      PatientDetailsWidget.routeName,
      queryParameters: {
        'momDetails': serializeParam(
          mother.reference,
          ParamType.DocumentReference,
        ),
        'firstEncounter': serializeParam(
          firstEncounter?.reference,
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

    FFAppState().makingFIrstEncounter = false;
    safeSetState(() {});
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

class _PatientMetric {
  const _PatientMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}
