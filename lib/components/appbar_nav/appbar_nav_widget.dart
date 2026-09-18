import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'appbar_nav_model.dart';
export 'appbar_nav_model.dart';

class AppbarNavWidget extends StatefulWidget {
  const AppbarNavWidget({super.key});

  @override
  State<AppbarNavWidget> createState() => _AppbarNavWidgetState();
}

class _AppbarNavWidgetState extends State<AppbarNavWidget> {
  late AppbarNavModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AppbarNavModel());

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360.0;
        final selectedPage = _selectedPageForRoute(context);

        return Container(
          width: double.infinity,
          height: 56.0,
          padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 12.0, 0.0),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            border: Border(
              bottom: BorderSide(
                color: FlutterFlowTheme.of(context).alternate,
                width: 1.0,
              ),
            ),
          ),
          child: Row(
            children: [
              _BrandMark(
                isCompact: isCompact,
                pageTitle: selectedPage,
              ),
              Spacer(),
              _IconAction(
                label: 'Logout',
                icon: Icons.logout,
                color: FlutterFlowTheme.of(context).error,
                onTap: () async {
                  GoRouter.of(context).prepareAuthEvent();
                  await authManager.signOut();
                  GoRouter.of(context).clearRedirectLocation();

                  if (!context.mounted) {
                    return;
                  }

                  context.goNamedAuth(
                    LoginWidget.routeName,
                    context.mounted,
                    extra: <String, dynamic>{
                      kTransitionInfoKey: TransitionInfo(
                        hasTransition: true,
                        transitionType: PageTransitionType.fade,
                        duration: Duration(milliseconds: 0),
                      ),
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

String _selectedPageForRoute(BuildContext context) {
  final path = GoRouterState.of(context).uri.path.toLowerCase();
  final selected = FFAppState().selectedPage;

  if (path.contains('scheduledencounters')) return 'Appointments';
  if (path.contains('moms') ||
      path.contains('momdetails') ||
      path.contains('createmom') ||
      path.contains('encounter')) {
    return 'Patients';
  }
  if (path.contains('profile') || path.contains('editprofile')) {
    return 'Settings';
  }
  if (path.contains('care-tools')) return 'Care Tools';
  if (path.contains('home')) return 'Home';
  if (selected == 'Mothers') return 'Patients';
  return selected.isEmpty ? 'Home' : selected;
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({
    required this.isCompact,
    required this.pageTitle,
  });

  final bool isCompact;
  final String pageTitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.asset(
            'assets/images/trasnsparent assets/Logos-06-removebg-preview.png',
            width: 40.0,
            height: 40.0,
            fit: BoxFit.contain,
          ),
        ),
        if (!isCompact) ...[
          SizedBox(width: 10.0),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dawa Clinician',
                style: FlutterFlowTheme.of(context).titleSmall.override(
                      font: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                      ),
                      color: FlutterFlowTheme.of(context).primary,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                pageTitle,
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      font: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w500,
                      ),
                      color: FlutterFlowTheme.of(context).secondaryText,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      waitDuration: Duration(milliseconds: 500),
      child: InkWell(
        borderRadius: BorderRadius.circular(100.0),
        onTap: onTap,
        child: Container(
          width: 48.0,
          height: 48.0,
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(100.0),
          ),
          child: Icon(
            icon,
            color: color,
            size: 22.0,
          ),
        ),
      ),
    );
  }
}
