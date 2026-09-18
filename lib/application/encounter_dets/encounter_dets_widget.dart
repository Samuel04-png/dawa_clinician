import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'encounter_dets_model.dart';
export 'encounter_dets_model.dart';

class EncounterDetsWidget extends StatefulWidget {
  const EncounterDetsWidget({
    super.key,
    required this.momDets,
    required this.encounterDetails,
  });

  final DocumentReference? momDets;
  final DocumentReference? encounterDetails;

  static String routeName = 'EncounterDets';
  static String routePath = '/encounterDets';

  @override
  State<EncounterDetsWidget> createState() => _EncounterDetsWidgetState();
}

class _EncounterDetsWidgetState extends State<EncounterDetsWidget> {
  late EncounterDetsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EncounterDetsModel());

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

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 380;
    final isMediumScreen = screenWidth >= 380 && screenWidth < 600;
    final isLargeScreen = screenWidth >= 600;

    return StreamBuilder<EncounterRecord>(
      stream: EncounterRecord.getDocument(widget.encounterDetails!),
      builder: (context, snapshot) {
        // Customize what your widget looks like when it's loading.
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
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

        final encounterDetsEncounterRecord = snapshot.data!;

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
            appBar: AppBar(
              backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
              automaticallyImplyLeading: false,
              leading: FlutterFlowIconButton(
                borderColor: Colors.transparent,
                borderRadius: 30.0,
                borderWidth: 1.0,
                buttonSize: isSmallScreen ? 50.0 : 60.0,
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: FlutterFlowTheme.of(context).primaryText,
                  size: isSmallScreen ? 24.0 : 30.0,
                ),
                onPressed: () async {
                  context.safePop();
                },
              ),
              title: StreamBuilder<List<MotherRecord>>(
                stream: queryMotherRecord(
                  queryBuilder: (motherRecord) => motherRecord.where(
                    'mother_id',
                    isEqualTo: widget.momDets?.id,
                  ),
                  singleRecord: true,
                ),
                builder: (context, snapshot) {
                  // Customize what your widget looks like when it's loading.
                  if (!snapshot.hasData) {
                    return Center(
                      child: SizedBox(
                        width: 40.0,
                        height: 40.0,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            FlutterFlowTheme.of(context).primary,
                          ),
                        ),
                      ),
                    );
                  }
                  List<MotherRecord> containerMotherRecordList = snapshot.data!;
                  // Return an empty Container when the item does not exist.
                  if (snapshot.data!.isEmpty) {
                    return Container();
                  }
                  final containerMotherRecord =
                      containerMotherRecordList.isNotEmpty
                          ? containerMotherRecordList.first
                          : null;

                  return Container(
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: RichText(
                            textScaler: MediaQuery.of(context).textScaler,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: containerMotherRecord!.name,
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.dmSans(
                                          fontWeight: FontWeight.w500,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        fontSize: isSmallScreen
                                            ? 16.0
                                            : (isMediumScreen ? 18.0 : 22.0),
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.w500,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                ),
                                TextSpan(
                                  text: ' - ',
                                  style: TextStyle(),
                                ),
                                TextSpan(
                                  text: dateTimeFormat("d/M/y",
                                      encounterDetsEncounterRecord.date!),
                                  style: TextStyle(),
                                )
                              ],
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.dmSans(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    fontSize: isSmallScreen
                                        ? 16.0
                                        : (isMediumScreen ? 18.0 : 22.0),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                            ),
                          ),
                        ),
                        if (encounterDetsEncounterRecord.isInstant)
                          Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: isSmallScreen ? 120.0 : 150.0,
                              ),
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context).accent2,
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Padding(
                                padding:
                                    EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                                child: Text(
                                  'Created by Clinician',
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.dmSans(
                                          fontWeight: FontWeight.w600,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                        letterSpacing: 0.0,
                                        fontSize: isSmallScreen ? 10.0 : 12.0,
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              actions: [],
              centerTitle: false,
              elevation: 0.0,
            ),
            body: SafeArea(
              top: true,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    if (encounterDetsEncounterRecord.performedBy !=
                        FFAppState().doctor)
                      Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 20.0),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).warning,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(isSmallScreen ? 8.0 : 12.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.warning_rounded,
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  size: isSmallScreen ? 20.0 : 24.0,
                                ),
                                Expanded(
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Text(
                                      'Note that this encounter was scheduled to be done by you but performed by someone else',
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.dmSans(
                                              fontWeight: FontWeight.w600,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            letterSpacing: 0.0,
                                            fontSize:
                                                isSmallScreen ? 12.0 : 14.0,
                                            fontWeight: FontWeight.w600,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                      textAlign: TextAlign.center,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Align(
                      alignment: AlignmentDirectional(1.0, 0.0),
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            isSmallScreen ? 8.0 : 12.0,
                            0.0,
                            isSmallScreen ? 8.0 : 16.0,
                            isSmallScreen ? 12.0 : 16.0),
                        child: Text(
                          'Updated on: ${dateTimeFormat("d/M/y", encounterDetsEncounterRecord.datePerformed)} ${dateTimeFormat("jms", encounterDetsEncounterRecord.datePerformed)}',
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                font: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                                fontSize: isSmallScreen ? 12.0 : 14.0,
                                fontWeight: FontWeight.w600,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          isSmallScreen ? 8.0 : 16.0,
                          0.0,
                          isSmallScreen ? 8.0 : 16.0,
                          0.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Urinalysis',
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.dmSans(
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      fontSize: isSmallScreen ? 16.0 : 20.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                              ),
                              SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                              Wrap(
                                spacing: isSmallScreen ? 12.0 : 20.0,
                                runSpacing: isSmallScreen ? 8.0 : 10.0,
                                alignment: WrapAlignment.start,
                                crossAxisAlignment: WrapCrossAlignment.start,
                                direction: Axis.horizontal,
                                runAlignment: WrapAlignment.start,
                                verticalDirection: VerticalDirection.down,
                                clipBehavior: Clip.none,
                                children: [
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Leucocytes esterase',
                                    value: encounterDetsEncounterRecord
                                        .leucocytesEsterase,
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Nitrates',
                                    value:
                                        encounterDetsEncounterRecord.nitrates,
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Urorlogobilin',
                                    value: encounterDetsEncounterRecord
                                        .urologobulin,
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Protein',
                                    value: encounterDetsEncounterRecord.protein,
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Bilirubin',
                                    value:
                                        encounterDetsEncounterRecord.bilirubin,
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'pH',
                                    value: encounterDetsEncounterRecord.ph,
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Blood',
                                    value: encounterDetsEncounterRecord.blood,
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'specific gravity',
                                    value: encounterDetsEncounterRecord
                                        .specificGravity,
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Color',
                                    value: encounterDetsEncounterRecord.color,
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Ketones',
                                    value: encounterDetsEncounterRecord.ketones,
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Glucose',
                                    value: encounterDetsEncounterRecord.glucose,
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Clarity',
                                    value: encounterDetsEncounterRecord.clarity,
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Odor',
                                    value: encounterDetsEncounterRecord.odor,
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Casts',
                                    value: encounterDetsEncounterRecord.casts,
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ],
                              ),
                              SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                              Divider(
                                thickness: 1.0,
                                color: FlutterFlowTheme.of(context).alternate,
                              ),
                              SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                              Text(
                                'O/E',
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.dmSans(
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      fontSize: isSmallScreen ? 16.0 : 20.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                              ),
                              SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                              Wrap(
                                spacing: isSmallScreen ? 12.0 : 20.0,
                                runSpacing: isSmallScreen ? 8.0 : 10.0,
                                alignment: WrapAlignment.start,
                                crossAxisAlignment: WrapCrossAlignment.start,
                                direction: Axis.horizontal,
                                runAlignment: WrapAlignment.start,
                                verticalDirection: VerticalDirection.down,
                                clipBehavior: Clip.none,
                                children: [
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Foetal heart beat quality',
                                    value: encounterDetsEncounterRecord
                                        .heartBeatQuality,
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Wombo position',
                                    value: valueOrDefault<String>(
                                      encounterDetsEncounterRecord.wombPosition,
                                      'pulse',
                                    ),
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Estimated baby size',
                                    value: encounterDetsEncounterRecord
                                        .estimatedBabySize
                                        .toString(),
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Foetal hemocheck',
                                    value: encounterDetsEncounterRecord
                                        .hemocheck
                                        .toString(),
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Foetal heart beat',
                                    value: encounterDetsEncounterRecord
                                        .heartBeat
                                        .toString(),
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ],
                              ),
                              SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                              Divider(
                                thickness: 1.0,
                                color: FlutterFlowTheme.of(context).alternate,
                              ),
                              SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, isSmallScreen ? 8.0 : 10.0, 0.0, 0.0),
                                child: Text(
                                  'Summary',
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.dmSans(
                                          fontWeight: FontWeight.w600,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        fontSize: isSmallScreen ? 16.0 : 20.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                              Wrap(
                                spacing: isSmallScreen ? 12.0 : 20.0,
                                runSpacing: isSmallScreen ? 8.0 : 10.0,
                                alignment: WrapAlignment.start,
                                crossAxisAlignment: WrapCrossAlignment.start,
                                direction: Axis.horizontal,
                                runAlignment: WrapAlignment.start,
                                verticalDirection: VerticalDirection.down,
                                clipBehavior: Clip.none,
                                children: [
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Blood pressure',
                                    value: encounterDetsEncounterRecord.bp,
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'pulse',
                                    value: valueOrDefault<String>(
                                      encounterDetsEncounterRecord.pulse
                                          .toString(),
                                      'pulse',
                                    ),
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Referred for anemia',
                                    value: encounterDetsEncounterRecord
                                        .referForAnemia,
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Hemocheck',
                                    value: encounterDetsEncounterRecord
                                        .hemocheck
                                        .toString(),
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Next visit',
                                    value: dateTimeFormat(
                                        "d/M/y",
                                        encounterDetsEncounterRecord
                                            .nextVisit!),
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildDetailItem(
                                    context: context,
                                    title: 'Comment',
                                    value: encounterDetsEncounterRecord.comment,
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                    isComment: true,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 12.0 : 20.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: isSmallScreen
                            ? MainAxisAlignment.spaceEvenly
                            : MainAxisAlignment.start,
                        children: [
                          Expanded(
                            child: FFButtonWidget(
                              onPressed: () async {
                                context.pushNamed(
                                  EditEncounterWidget.routeName,
                                  queryParameters: {
                                    'momDetails': serializeParam(
                                      widget.momDets,
                                      ParamType.DocumentReference,
                                    ),
                                    'encounterDetails': serializeParam(
                                      widget.encounterDetails,
                                      ParamType.DocumentReference,
                                    ),
                                  }.withoutNulls,
                                );
                              },
                              text: 'Edit',
                              options: FFButtonOptions(
                                height: isSmallScreen ? 45.0 : 50.0,
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    isSmallScreen ? 12.0 : 24.0,
                                    0.0,
                                    isSmallScreen ? 12.0 : 24.0,
                                    0.0),
                                iconPadding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 0.0, 0.0, 0.0),
                                color: FlutterFlowTheme.of(context).primary,
                                textStyle: FlutterFlowTheme.of(context)
                                    .titleSmall
                                    .override(
                                      font: GoogleFonts.dmSans(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                      fontSize: isSmallScreen ? 14.0 : 16.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontStyle,
                                    ),
                                elevation: 0.0,
                                borderSide: BorderSide(
                                  color: Colors.transparent,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 12.0 : 20.0),
                          Expanded(
                            child: FFButtonWidget(
                              onPressed: () async {
                                var confirmDialogResponse = await showDialog<
                                        bool>(
                                      context: context,
                                      builder: (alertDialogContext) {
                                        return AlertDialog(
                                          title: Text('Delete this encounter?'),
                                          content: Text(
                                              'This action cannot be undone.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                  alertDialogContext, false),
                                              child: Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                  alertDialogContext, true),
                                              child: Text(
                                                'Delete',
                                                style: TextStyle(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .error,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ) ??
                                    false;
                                if (confirmDialogResponse) {
                                  await widget.encounterDetails!.delete();
                                  _model.firstEncounterID =
                                      await queryFirstEncounterRecordOnce(
                                    queryBuilder: (firstEncounterRecord) =>
                                        firstEncounterRecord.where(
                                      'mother_Id',
                                      isEqualTo: widget.momDets,
                                    ),
                                    singleRecord: true,
                                  ).then((s) => s.firstOrNull);

                                  context.goNamed(
                                    MomDetailsWidget.routeName,
                                    queryParameters: {
                                      'momDetails': serializeParam(
                                        widget.momDets,
                                        ParamType.DocumentReference,
                                      ),
                                      'firstEncounter': serializeParam(
                                        _model.firstEncounterID?.reference,
                                        ParamType.DocumentReference,
                                      ),
                                    }.withoutNulls,
                                  );
                                }

                                safeSetState(() {});
                              },
                              text: 'Delete',
                              options: FFButtonOptions(
                                height: isSmallScreen ? 45.0 : 50.0,
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    isSmallScreen ? 12.0 : 24.0,
                                    0.0,
                                    isSmallScreen ? 12.0 : 24.0,
                                    0.0),
                                iconPadding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 0.0, 0.0, 0.0),
                                color: FlutterFlowTheme.of(context).error,
                                textStyle: FlutterFlowTheme.of(context)
                                    .titleSmall
                                    .override(
                                      font: GoogleFonts.dmSans(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                      fontSize: isSmallScreen ? 14.0 : 16.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontStyle,
                                    ),
                                elevation: 0.0,
                                borderSide: BorderSide(
                                  color: Colors.transparent,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildDetailItem({
    required BuildContext context,
    required String title,
    required String value,
    required bool isSmallScreen,
    required bool isMediumScreen,
    bool isComment = false,
  }) {
    final itemWidth = isComment
        ? double.infinity
        : (isSmallScreen ? 120.0 : (isMediumScreen ? 140.0 : 160.0));

    return Container(
      width: itemWidth,
      padding: EdgeInsets.all(isSmallScreen ? 4.0 : 6.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w500,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
                  color: FlutterFlowTheme.of(context).secondaryText,
                  fontSize:
                      isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 18.0),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w500,
                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          SizedBox(height: isSmallScreen ? 2.0 : 5.0),
          Text(
            value,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w500,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
                  color: FlutterFlowTheme.of(context).primaryText,
                  fontSize:
                      isSmallScreen ? 13.0 : (isMediumScreen ? 14.0 : 16.0),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w500,
                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
            overflow: TextOverflow.ellipsis,
            maxLines: isComment ? 3 : 2,
          ),
        ],
      ),
    );
  }
}
