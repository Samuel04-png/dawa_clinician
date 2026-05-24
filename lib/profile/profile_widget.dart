import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/clinician_bottom_nav/clinician_bottom_nav_widget.dart';
import '/components/dawa_design_system.dart';
import '/components/small_side_nav/small_side_nav_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'profile_model.dart';
export 'profile_model.dart';

class ProfileWidget extends StatefulWidget {
  const ProfileWidget({super.key});

  static String routeName = 'Profile';
  static String routePath = '/profile';

  @override
  State<ProfileWidget> createState() => _ProfileWidgetState();
}

class _ProfileWidgetState extends State<ProfileWidget> {
  late ProfileModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfileModel());
    FFAppState().selectedPage = 'Settings';

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

    return StreamBuilder<DoctorRecord>(
      stream: DoctorRecord.getDocument(FFAppState().doctor!),
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

        final profileDoctorRecord = snapshot.data!;

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showDesktopSidebar = constraints.maxWidth >= 768.0;

              return Scaffold(
                key: scaffoldKey,
                backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
                bottomNavigationBar: showDesktopSidebar
                    ? null
                    : const ClinicianBottomNavWidget(
                        currentPage: 'Settings',
                      ),
                body: SafeArea(
                  top: true,
                  child: Row(
                    children: [
                      if (showDesktopSidebar) _buildDesktopSidebar(context),
                      Expanded(
                        child: _buildSettingsContent(
                          context,
                          profileDoctorRecord,
                          showDesktopSidebar,
                        ),
                      ),
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

  Widget _buildDesktopSidebar(BuildContext context) {
    return Container(
      key: const ValueKey('settings-desktop-sidebar'),
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
      child: const SmallSideNavWidget(),
    );
  }

  Widget _buildSettingsContent(
    BuildContext context,
    DoctorRecord doctor,
    bool showDesktopSidebar,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.fromSTEB(
        16.0,
        showDesktopSidebar ? 24.0 : 16.0,
        16.0,
        showDesktopSidebar ? 32.0 : 96.0,
      ),
      child: Align(
        alignment: AlignmentDirectional.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 680.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _settingsHeader(context),
              SizedBox(height: 24.0),
              _buildProfileCard(context, doctor),
              SizedBox(height: 24.0),
              _sectionHeader(context, 'Account'),
              SizedBox(height: 8.0),
              _settingsGroup(
                context,
                children: [
                  _settingsRow(
                    context: context,
                    icon: Icons.account_circle_outlined,
                    label: 'Edit Profile',
                    iconKind: _SettingIconKind.profile,
                    onTap: () async {
                      context.pushNamed(
                        EditProfileWidget.routeName,
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
                  _switchRow(context),
                ],
              ),
              SizedBox(height: 20.0),
              _sectionHeader(context, 'General'),
              SizedBox(height: 8.0),
              _settingsGroup(
                context,
                children: [
                  _settingsRow(
                    context: context,
                    icon: Icons.help_outline_rounded,
                    label: 'Support',
                    iconKind: _SettingIconKind.support,
                    onTap: () => _showSupportDialog(context),
                  ),
                  _settingsRow(
                    context: context,
                    icon: Icons.privacy_tip_rounded,
                    label: 'Terms of Service',
                    iconKind: _SettingIconKind.terms,
                    onTap: () => _showTermsDialog(context),
                  ),
                ],
              ),
              SizedBox(height: 20.0),
              _sectionHeader(context, 'Session'),
              SizedBox(height: 8.0),
              _settingsGroup(
                context,
                children: [
                  _logoutRow(context),
                ],
              ),
              Padding(
                padding: EdgeInsetsDirectional.only(top: 24.0, bottom: 8.0),
                child: Center(
                  child: Text(
                    'Dawa Clinician v1.0.0',
                    style: DawaTextStyles.secondary.copyWith(
                      color: DawaTokens.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsHeader(BuildContext context) {
    return Row(
      children: [
        Material(
          color: DawaTokens.surfaceTertiary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _goHome,
            child: SizedBox(
              width: 36.0,
              height: 36.0,
              child: Icon(
                Icons.arrow_back_rounded,
                color: DawaTokens.textPrimary,
                size: 20.0,
              ),
            ),
          ),
        ),
        SizedBox(width: 12.0),
        Text(
          'Settings',
          style: DawaTextStyles.pageTitle,
        ),
      ],
    );
  }

  Widget _settingsGroup(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: DawaTokens.surface,
        borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
        border: Border.all(color: DawaTokens.border),
        boxShadow: DawaTokens.shadowSm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, color: DawaTokens.border),
          ],
        ],
      ),
    );
  }

  void _goHome() {
    context.goNamed(
      HomeWidget.routeName,
      extra: <String, dynamic>{
        kTransitionInfoKey: TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.fade,
          duration: Duration(milliseconds: 0),
        ),
      },
    );
  }

  Future<void> _showSupportDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (alertDialogContext) {
        return AlertDialog(
          title: Text('Contact support'),
          content: Text(
            'If you have a question or are experiencing a problem, please email developer@thestackone.com or call +260779406330 for assistance.',
          ),
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

  Future<void> _showTermsDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (alertDialogContext) {
        return AlertDialog(
          title: const Text('Terms of Service'),
          content: const Text(
            'Dawa Clinician is intended for authorized clinical users. Use patient data only according to your facility policies, consent requirements, and applicable health privacy regulations.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(alertDialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileCard(BuildContext context, DoctorRecord doctor) {
    final initials = _initialsFor(doctor.name);
    final role = doctor.speciality.isNotEmpty ? doctor.speciality : 'Clinician';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DawaTokens.brandPrimary,
            DawaTokens.brandPrimaryLight,
          ],
        ),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: DawaTokens.shadowMd,
      ),
      child: Row(
        children: [
          Container(
            width: 56.0,
            height: 56.0,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 2.0,
              ),
            ),
            alignment: AlignmentDirectional.center,
            child: Text(
              initials,
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 22.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 18.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3.0),
                Text(
                  role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 13.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (doctor.clinicName.isNotEmpty) ...[
                  SizedBox(height: 2.0),
                  Text(
                    doctor.clinicName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: Colors.white.withOpacity(0.68),
                      fontSize: 12.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.dmSans(
        color: DawaTokens.textMuted,
        fontSize: 11.0,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.88,
      ),
    );
  }

  Widget _settingsRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    _SettingIconKind iconKind = _SettingIconKind.profile,
    Color? color,
  }) {
    final rowColor = color ?? DawaTokens.textPrimary;
    final spec = _settingIconSpec(iconKind, color);

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: 62.0),
        padding: EdgeInsetsDirectional.fromSTEB(16.0, 12.0, 14.0, 12.0),
        child: Row(
          children: [
            Container(
              width: 34.0,
              height: 34.0,
              decoration: BoxDecoration(
                color: spec.$1,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Icon(
                icon,
                color: spec.$2,
                size: 18.0,
              ),
            ),
            SizedBox(width: 14.0),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  color: rowColor,
                  fontSize: 15.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: color ?? DawaTokens.textMuted,
              size: 24.0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchRow(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 62.0),
      padding: EdgeInsetsDirectional.fromSTEB(16.0, 12.0, 14.0, 12.0),
      child: Row(
        children: [
          Container(
            width: 34.0,
            height: 34.0,
            decoration: BoxDecoration(
              color: DawaTokens.brandPrimaryPale,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Icon(
              Icons.dark_mode_outlined,
              color: DawaTokens.brandPrimary,
              size: 18.0,
            ),
          ),
          SizedBox(width: 14.0),
          Expanded(
            child: Text(
              'Dark Mode',
              style: GoogleFonts.dmSans(
                color: DawaTokens.textPrimary,
                fontSize: 15.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch.adaptive(
            value: Theme.of(context).brightness == Brightness.dark,
            onChanged: (newValue) async {
              if (newValue) {
                setDarkModeSetting(context, ThemeMode.dark);
              } else {
                setDarkModeSetting(context, ThemeMode.light);
              }
            },
            activeColor: FlutterFlowTheme.of(context).secondaryBackground,
            activeTrackColor: FlutterFlowTheme.of(context).primary,
            inactiveThumbColor:
                FlutterFlowTheme.of(context).secondaryBackground,
            inactiveTrackColor: FlutterFlowTheme.of(context).secondaryText,
          ),
        ],
      ),
    );
  }

  (Color, Color) _settingIconSpec(_SettingIconKind kind, Color? overrideColor) {
    if (overrideColor != null) {
      return (DawaTokens.statusDangerBg, overrideColor);
    }

    return switch (kind) {
      _SettingIconKind.profile => (
          DawaTokens.statusInfoBg,
          DawaTokens.statusInfo
        ),
      _SettingIconKind.support => (
          DawaTokens.statusSuccessBg,
          DawaTokens.statusSuccessText
        ),
      _SettingIconKind.terms => (
          DawaTokens.statusWarningBg,
          DawaTokens.statusWarning
        ),
      _SettingIconKind.logout => (
          DawaTokens.statusDangerBg,
          DawaTokens.statusDanger
        ),
    };
  }

  Widget _logoutRow(BuildContext context) {
    return _settingsRow(
      context: context,
      icon: Icons.logout,
      label: 'Log Out',
      iconKind: _SettingIconKind.logout,
      color: DawaTokens.statusDanger,
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
    );
  }

  String _initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'CL';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
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

enum _SettingIconKind { profile, support, terms, logout }
