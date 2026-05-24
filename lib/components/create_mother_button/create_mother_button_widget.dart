import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'create_mother_button_model.dart';
export 'create_mother_button_model.dart';

class CreateMotherButtonWidget extends StatefulWidget {
  const CreateMotherButtonWidget({super.key});

  @override
  State<CreateMotherButtonWidget> createState() =>
      _CreateMotherButtonWidgetState();
}

class _CreateMotherButtonWidgetState extends State<CreateMotherButtonWidget> {
  late CreateMotherButtonModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CreateMotherButtonModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FFButtonWidget(
      onPressed: () async {
        context.goNamed(
          CreateMomWidget.routeName,
          extra: <String, dynamic>{
            kTransitionInfoKey: TransitionInfo(
              hasTransition: true,
              transitionType: PageTransitionType.fade,
              duration: Duration(milliseconds: 0),
            ),
          },
        );
      },
      text: 'Create Mother',
      icon: Icon(
        Icons.add_rounded,
        size: 22.0,
      ),
      options: FFButtonOptions(
        width: double.infinity,
        height: 52.0,
        padding: EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
        iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 8.0, 0.0),
        color: FlutterFlowTheme.of(context).primary,
        textStyle: FlutterFlowTheme.of(context).titleSmall.override(
              font: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
              ),
              color: FlutterFlowTheme.of(context).secondaryBackground,
              letterSpacing: 0.0,
              fontWeight: FontWeight.w600,
            ),
        elevation: 0.0,
        borderSide: BorderSide(
          color: Colors.transparent,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(100.0),
      ),
    );
  }
}
