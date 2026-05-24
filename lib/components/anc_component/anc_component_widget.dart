import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:aligned_tooltip/aligned_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'anc_component_model.dart';
export 'anc_component_model.dart';

class AncComponentWidget extends StatefulWidget {
  const AncComponentWidget({super.key});

  @override
  State<AncComponentWidget> createState() => _AncComponentWidgetState();
}

class _AncComponentWidgetState extends State<AncComponentWidget> {
  late AncComponentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AncComponentModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AlignedTooltip(
          content: Padding(
            padding: EdgeInsets.all(4.0),
            child: Text(
              '\'Last Normal Menstrual Period\' and is used to estimate the start date of the pregnancy and the expected due date. Enter the date of the first day of the last menstrual cycle.',
              style: FlutterFlowTheme.of(context).bodyLarge.override(
                    font: GoogleFonts.dmSans(
                      fontWeight:
                          FlutterFlowTheme.of(context).bodyLarge.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyLarge.fontStyle,
                    ),
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).bodyLarge.fontWeight,
                    fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
                  ),
            ),
          ),
          offset: 4.0,
          preferredDirection: AxisDirection.right,
          borderRadius: BorderRadius.circular(8.0),
          backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
          elevation: 4.0,
          tailBaseWidth: 24.0,
          tailLength: 12.0,
          waitDuration: Duration(milliseconds: 100),
          showDuration: Duration(milliseconds: 1500),
          triggerMode: TooltipTriggerMode.tap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ANC Date',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w500,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).secondaryText,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w500,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
              ),
              Icon(
                Icons.info_rounded,
                color: FlutterFlowTheme.of(context).secondaryText,
                size: 24.0,
              ),
            ].divide(SizedBox(width: 10.0)),
          ),
        ),
        Container(
          width: 300.0,
          decoration: BoxDecoration(),
          child: FFButtonWidget(
            onPressed: () async {
              final _datePickedDate = await showDatePicker(
                context: context,
                initialDate: getCurrentTimestamp,
                firstDate: DateTime(1900),
                lastDate: getCurrentTimestamp,
              );

              if (_datePickedDate != null) {
                safeSetState(() {
                  _model.datePicked = DateTime(
                    _datePickedDate.year,
                    _datePickedDate.month,
                    _datePickedDate.day,
                  );
                });
              } else if (_model.datePicked != null) {
                safeSetState(() {
                  _model.datePicked = getCurrentTimestamp;
                });
              }
            },
            text: () {
              if (_model.datePicked != null) {
                return dateTimeFormat("yMMMd", _model.datePicked);
              } else if (_model.datePicked == null) {
                return 'Choose Date';
              } else {
                return 'Choose Date';
              }
            }(),
            options: FFButtonOptions(
              height: 50.0,
              padding: EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
              iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
              color: FlutterFlowTheme.of(context).primaryBackground,
              textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                    font: GoogleFonts.dmSans(
                      fontWeight:
                          FlutterFlowTheme.of(context).titleSmall.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleSmall.fontStyle,
                    ),
                    color: FlutterFlowTheme.of(context).secondaryText,
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).titleSmall.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).titleSmall.fontStyle,
                  ),
              borderSide: BorderSide(
                color: Colors.transparent,
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ],
    );
  }
}
