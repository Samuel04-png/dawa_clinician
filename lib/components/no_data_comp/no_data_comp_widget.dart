import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/dawa_design_system.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'no_data_comp_model.dart';
export 'no_data_comp_model.dart';

class NoDataCompWidget extends StatefulWidget {
  const NoDataCompWidget({
    super.key,
    String? message,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  }) : this.message = message ?? 'No record found';

  final String message;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<NoDataCompWidget> createState() => _NoDataCompWidgetState();
}

class _NoDataCompWidgetState extends State<NoDataCompWidget> {
  late NoDataCompModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NoDataCompModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional(0.0, 0.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.asset(
              'assets/images/no_data.png',
              width: 140.0,
              height: 140.0,
              fit: BoxFit.cover,
            ),
          ),
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                  color: DawaTokens.textPrimary,
                  fontSize: 18.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
            SizedBox(height: 8.0),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                widget.subtitle!,
                textAlign: TextAlign.center,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.dmSans(),
                      color: FlutterFlowTheme.of(context).secondaryText,
                      letterSpacing: 0.0,
                    ),
              ),
            ),
          ],
          if (widget.actionLabel != null && widget.onAction != null) ...[
            SizedBox(height: 24.0),
            SizedBox(
              height: 42.0,
              child: OutlinedButton(
                onPressed: widget.onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: DawaTokens.brandPrimary,
                  side: const BorderSide(
                    color: DawaTokens.brandPrimary,
                    width: 1.5,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
                  ),
                ),
                child: Text(
                  widget.actionLabel!,
                  style: FlutterFlowTheme.of(context).titleSmall.override(
                        font: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                        ),
                        color: DawaTokens.brandPrimary,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
