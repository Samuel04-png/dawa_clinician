import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'navlink_model.dart';
export 'navlink_model.dart';

class NavlinkWidget extends StatefulWidget {
  const NavlinkWidget({
    super.key,
    required this.linkName,
    required this.linkIcon,
  });

  final String? linkName;
  final Widget? linkIcon;

  @override
  State<NavlinkWidget> createState() => _NavlinkWidgetState();
}

class _NavlinkWidgetState extends State<NavlinkWidget> {
  late NavlinkModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NavlinkModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Container(
      width: 230.0,
      height: 55.0,
      decoration: BoxDecoration(
        color: valueOrDefault<Color>(
          FFAppState().selectedPage == widget.linkName
              ? FlutterFlowTheme.of(context).primary
              : FlutterFlowTheme.of(context).secondaryBackground,
          FlutterFlowTheme.of(context).secondaryBackground,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      alignment: AlignmentDirectional(0.0, 0.0),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(10.0, 7.0, 10.0, 7.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            widget.linkIcon!,
            Text(
              widget.linkName!,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                    color: valueOrDefault<Color>(
                      FFAppState().selectedPage == widget.linkName
                          ? FlutterFlowTheme.of(context).secondaryBackground
                          : FlutterFlowTheme.of(context).secondaryText,
                      FlutterFlowTheme.of(context).secondaryText,
                    ),
                    fontSize: 16.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
            ),
          ].divide(SizedBox(width: 16.0)),
        ),
      ),
    );
  }
}
