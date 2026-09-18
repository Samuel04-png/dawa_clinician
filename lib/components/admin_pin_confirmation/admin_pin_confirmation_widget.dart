import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_pin_confirmation_model.dart';
export 'admin_pin_confirmation_model.dart';

class AdminPinConfirmationWidget extends StatefulWidget {
  const AdminPinConfirmationWidget({super.key});

  @override
  State<AdminPinConfirmationWidget> createState() =>
      _AdminPinConfirmationWidgetState();
}

class _AdminPinConfirmationWidgetState
    extends State<AdminPinConfirmationWidget> {
  late AdminPinConfirmationModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AdminPinConfirmationModel());

    _model.pinCodeFocusNode ??= FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 500.0,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: FlutterFlowTheme.of(context).primaryBackground,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(30.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outlined,
              color: FlutterFlowTheme.of(context).primary,
              size: 60.0,
            ),
            Text(
              'Confirm your identity',
              style: FlutterFlowTheme.of(context).headlineMedium.override(
                    font: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                    ),
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
            ),
            Text(
              'Enter the administrator pin to continue with clinician registration',
              textAlign: TextAlign.center,
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
            PinCodeTextField(
              autoDisposeControllers: false,
              appContext: context,
              length: 6,
              textStyle: FlutterFlowTheme.of(context).bodyLarge.override(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              enableActiveFill: false,
              autoFocus: true,
              focusNode: _model.pinCodeFocusNode,
              enablePinAutofill: false,
              errorTextSpace: 16.0,
              showCursor: true,
              cursorColor: FlutterFlowTheme.of(context).primary,
              obscureText: true,
              obscuringCharacter: '●',
              hintCharacter: '●',
              keyboardType: TextInputType.number,
              pinTheme: PinTheme(
                fieldHeight: 44.0,
                fieldWidth: 44.0,
                borderWidth: 1.0,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12.0),
                  bottomRight: Radius.circular(12.0),
                  topLeft: Radius.circular(12.0),
                  topRight: Radius.circular(12.0),
                ),
                shape: PinCodeFieldShape.box,
                activeColor: FlutterFlowTheme.of(context).primaryText,
                inactiveColor: FlutterFlowTheme.of(context).primaryBackground,
                selectedColor: FlutterFlowTheme.of(context).primary,
              ),
              controller: _model.pinCodeController,
              onChanged: (_) {},
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: _model.pinCodeControllerValidator.asValidator(context),
            ),
            Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
              child: FFButtonWidget(
                onPressed: () async {
                  final pin = _model.pinCodeController?.text.trim() ?? '';
                  if (pin != '123456') {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Invalid administrator pin.'),
                      ),
                    );
                    return;
                  }

                  FFAppState().adminPin = pin;
                  _model.updatePage(() {});

                  Navigator.of(context).pop();
                },
                text: 'Submit',
                    options: FFButtonOptions(
                      height: 40.0,
                      padding:
                          EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
                      iconPadding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                      color: FlutterFlowTheme.of(context).primary,
                      textStyle:
                          FlutterFlowTheme.of(context).titleSmall.override(
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
          ].divide(SizedBox(height: 10.0)),
        ),
      ),
    );
  }
}
