import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import 'package:aligned_tooltip/aligned_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'parity_input_component_model.dart';
export 'parity_input_component_model.dart';

class ParityInputComponentWidget extends StatefulWidget {
  const ParityInputComponentWidget({super.key});

  @override
  State<ParityInputComponentWidget> createState() =>
      _ParityInputComponentWidgetState();
}

class _ParityInputComponentWidgetState
    extends State<ParityInputComponentWidget> {
  late ParityInputComponentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ParityInputComponentModel());

    _model.birthyearTextController ??= TextEditingController();
    _model.birthyearFocusNode ??= FocusNode();

    _model.birthWeightTextController ??= TextEditingController();
    _model.birthWeightFocusNode ??= FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 20.0,
      runSpacing: 10.0,
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.start,
      direction: Axis.horizontal,
      runAlignment: WrapAlignment.start,
      verticalDirection: VerticalDirection.down,
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AlignedTooltip(
              content: Padding(
                padding: EdgeInsets.all(4.0),
                child: Text(
                  'The year that the baby was born. Only put the year',
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
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyLarge.fontStyle,
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
                    'Year of birth',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w500,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
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
              child: TextFormField(
                controller: _model.birthyearTextController,
                focusNode: _model.birthyearFocusNode,
                autofocus: false,
                textCapitalization: TextCapitalization.none,
                obscureText: false,
                decoration: InputDecoration(
                  labelStyle: FlutterFlowTheme.of(context).labelMedium.override(
                        font: GoogleFonts.dmSans(
                          fontWeight: FlutterFlowTheme.of(context)
                              .labelMedium
                              .fontWeight,
                          fontStyle: FlutterFlowTheme.of(context)
                              .labelMedium
                              .fontStyle,
                        ),
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).labelMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).labelMedium.fontStyle,
                      ),
                  hintText: '2003',
                  hintStyle: FlutterFlowTheme.of(context).labelMedium.override(
                        font: GoogleFonts.dmSans(
                          fontWeight: FlutterFlowTheme.of(context)
                              .labelMedium
                              .fontWeight,
                          fontStyle: FlutterFlowTheme.of(context)
                              .labelMedium
                              .fontStyle,
                        ),
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).labelMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).labelMedium.fontStyle,
                      ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).primaryBackground,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).primary,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).error,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).error,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  filled: true,
                  fillColor: FlutterFlowTheme.of(context).primaryBackground,
                ),
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.dmSans(
                        fontWeight:
                            FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      letterSpacing: 0.0,
                      fontWeight:
                          FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                maxLength: 4,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                keyboardType: TextInputType.number,
                validator: _model.birthyearTextControllerValidator
                    .asValidator(context),
                inputFormatters: [
                  if (!isAndroid && !isiOS)
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return TextEditingValue(
                        selection: newValue.selection,
                        text: newValue.text
                            .toCapitalization(TextCapitalization.none),
                      );
                    }),
                  FilteringTextInputFormatter.allow(RegExp('[0-9]'))
                ],
              ),
            ),
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AlignedTooltip(
              content: Padding(
                padding: EdgeInsets.all(4.0),
                child: Text(
                  'The weight of the baby at the time of birth',
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
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyLarge.fontStyle,
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
                    'Birth Weight',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w500,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
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
              child: TextFormField(
                controller: _model.birthWeightTextController,
                focusNode: _model.birthWeightFocusNode,
                autofocus: false,
                textCapitalization: TextCapitalization.none,
                obscureText: false,
                decoration: InputDecoration(
                  labelStyle: FlutterFlowTheme.of(context).labelMedium.override(
                        font: GoogleFonts.dmSans(
                          fontWeight: FlutterFlowTheme.of(context)
                              .labelMedium
                              .fontWeight,
                          fontStyle: FlutterFlowTheme.of(context)
                              .labelMedium
                              .fontStyle,
                        ),
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).labelMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).labelMedium.fontStyle,
                      ),
                  hintText: 'Birth Weight',
                  hintStyle: FlutterFlowTheme.of(context).labelMedium.override(
                        font: GoogleFonts.dmSans(
                          fontWeight: FlutterFlowTheme.of(context)
                              .labelMedium
                              .fontWeight,
                          fontStyle: FlutterFlowTheme.of(context)
                              .labelMedium
                              .fontStyle,
                        ),
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).labelMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).labelMedium.fontStyle,
                      ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).primaryBackground,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).primary,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).error,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).error,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  filled: true,
                  fillColor: FlutterFlowTheme.of(context).primaryBackground,
                ),
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.dmSans(
                        fontWeight:
                            FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      letterSpacing: 0.0,
                      fontWeight:
                          FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                keyboardType: TextInputType.number,
                validator: _model.birthWeightTextControllerValidator
                    .asValidator(context),
                inputFormatters: [
                  if (!isAndroid && !isiOS)
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return TextEditingValue(
                        selection: newValue.selection,
                        text: newValue.text
                            .toCapitalization(TextCapitalization.none),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AlignedTooltip(
              content: Padding(
                padding: EdgeInsets.all(4.0),
                child: Text(
                  'The method by which the baby is born, typically either vaginal delivery or cesarean section',
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
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyLarge.fontStyle,
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
                    'Mode of delivery',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w500,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
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
              child: FlutterFlowDropDown<String>(
                controller: _model.modeOfDeliValueController ??=
                    FormFieldController<String>(null),
                options: ['Vaginal', 'Cesarean section (C-section)', 'None'],
                onChanged: (val) =>
                    safeSetState(() => _model.modeOfDeliValue = val),
                width: 300.0,
                height: 50.0,
                textStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.dmSans(
                        fontWeight:
                            FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      letterSpacing: 0.0,
                      fontWeight:
                          FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                hintText: 'Please select...',
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: FlutterFlowTheme.of(context).secondaryText,
                  size: 24.0,
                ),
                fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                elevation: 2.0,
                borderColor: FlutterFlowTheme.of(context).alternate,
                borderWidth: 2.0,
                borderRadius: 8.0,
                margin: EdgeInsetsDirectional.fromSTEB(16.0, 4.0, 16.0, 4.0),
                hidesUnderline: true,
                isSearchable: false,
                isMultiSelect: false,
              ),
            ),
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AlignedTooltip(
              content: Padding(
                padding: EdgeInsets.all(4.0),
                child: Text(
                  'The condition or health status of the baby immediately after birth',
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
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyLarge.fontStyle,
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
                    'Birth State',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w500,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
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
              child: FlutterFlowDropDown<String>(
                controller: _model.birthStateValueController ??=
                    FormFieldController<String>(null),
                options: [
                  'Alive and Well',
                  'Alive with Complications',
                  'Stillbirth',
                  'Premature',
                  'Resuscitated'
                ],
                onChanged: (val) =>
                    safeSetState(() => _model.birthStateValue = val),
                width: 300.0,
                height: 50.0,
                textStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.dmSans(
                        fontWeight:
                            FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      letterSpacing: 0.0,
                      fontWeight:
                          FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                hintText: 'Please select...',
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: FlutterFlowTheme.of(context).secondaryText,
                  size: 24.0,
                ),
                fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                elevation: 2.0,
                borderColor: FlutterFlowTheme.of(context).alternate,
                borderWidth: 2.0,
                borderRadius: 8.0,
                margin: EdgeInsetsDirectional.fromSTEB(16.0, 4.0, 16.0, 4.0),
                hidesUnderline: true,
                isSearchable: false,
                isMultiSelect: false,
              ),
            ),
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AlignedTooltip(
              content: Padding(
                padding: EdgeInsets.all(4.0),
                child: Text(
                  'Any unexpected problems or adverse outcomes that arise during pregnancy, labor, delivery, or the postpartum period',
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
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyLarge.fontStyle,
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
                    'Complications',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w500,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
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
              child: FlutterFlowDropDown<String>(
                multiSelectController: _model.complicationsValueController ??=
                    FormListFieldController<String>(null),
                options: [
                  'None',
                  'Placenta Previa',
                  'Placental Abruption',
                  'Postpartum Hemorrhage',
                  'Uterine Rapture',
                  'Meconium Aspiration',
                  'Prolonged Labour',
                  'Cephalopelvic Disproportion'
                ],
                width: 300.0,
                height: 50.0,
                textStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.dmSans(
                        fontWeight:
                            FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      letterSpacing: 0.0,
                      fontWeight:
                          FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                hintText: 'Please select...',
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: FlutterFlowTheme.of(context).secondaryText,
                  size: 24.0,
                ),
                fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                elevation: 2.0,
                borderColor: FlutterFlowTheme.of(context).alternate,
                borderWidth: 2.0,
                borderRadius: 8.0,
                margin: EdgeInsetsDirectional.fromSTEB(16.0, 4.0, 16.0, 4.0),
                hidesUnderline: true,
                isSearchable: false,
                isMultiSelect: true,
                onMultiSelectChanged: (val) =>
                    safeSetState(() => _model.complicationsValue = val),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
