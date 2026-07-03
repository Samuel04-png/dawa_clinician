import '/auth/firebase_auth/auth_util.dart';
import '/components/dawa_design_system.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'small_side_nav_model.dart';
export 'small_side_nav_model.dart';

class SmallSideNavWidget extends StatefulWidget {
  const SmallSideNavWidget({
    super.key,
    String? iconOne,
    String? iconTwo,
    String? iconThree,
    String? iconFour,
  })  : iconOne = iconOne ?? 'Home',
        iconTwo = iconTwo ?? 'Patients',
        iconThree = iconThree ?? 'Appointments',
        iconFour = iconFour ?? 'Care Tools';

  final String iconOne;
  final String iconTwo;
  final String iconThree;
  final String iconFour;

  @override
  State<SmallSideNavWidget> createState() => _SmallSideNavWidgetState();
}

class _SmallSideNavWidgetState extends State<SmallSideNavWidget> {
  late SmallSideNavModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SmallSideNavModel());
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

    final selectedPage = _normalizedSelectedPage(context);
    final clinicianName = _clinicianName();

    return Container(
      width: 240,
      color: DawaTokens.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/Logos-06.png',
                    width: 42,
                    height: 42,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dawa Clinician',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            color: DawaTokens.brandPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Clinical Portal',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            color: DawaTokens.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: DawaTokens.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
                children: [
                  _SidebarItem(
                    label: widget.iconOne,
                    icon: Icons.home_rounded,
                    active: selectedPage == 'Home',
                    onTap: () => _goTo(context, HomeWidget.routeName, 'Home'),
                  ),
                  _SidebarItem(
                    label: widget.iconTwo,
                    icon: Icons.people_alt_rounded,
                    active: selectedPage == 'Patients',
                    onTap: () =>
                        _goTo(context, MomsWidget.routeName, 'Patients'),
                  ),
                  _SidebarItem(
                    label: widget.iconThree,
                    icon: Icons.calendar_month_rounded,
                    active: selectedPage == 'Appointments',
                    onTap: () => _goTo(
                      context,
                      ScheduledEncountersWidget.routeName,
                      'Appointments',
                    ),
                  ),
                  _SidebarItem(
                    label: widget.iconFour,
                    icon: Icons.medical_services_rounded,
                    active: selectedPage == 'Care Tools',
                    onTap: () =>
                        _goTo(context, CareToolsWidget.routeName, 'Care Tools'),
                  ),
                  _SidebarItem(
                    label: 'HemoNix',
                    icon: Icons.bloodtype_outlined,
                    active: selectedPage == 'HemoNix',
                    onTap: () =>
                        _goTo(context, HemonixApp.routeName, 'HemoNix'),
                  ),
                  _SidebarItem(
                    label: 'CT Scan',
                    icon: Icons.desktop_windows_outlined,
                    active: selectedPage == 'CT Scan',
                    onTap: () => _goTo(context, CtScanApp.routeName, 'CT Scan'),
                  ),
                  _SidebarItem(
                    label: 'Settings',
                    icon: Icons.settings_rounded,
                    active: selectedPage == 'Settings',
                    onTap: () =>
                        _goTo(context, ProfileWidget.routeName, 'Settings'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DawaTokens.surfaceSecondary,
                  borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
                  border: Border.all(color: DawaTokens.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        DawaAvatarCircle(
                          name: clinicianName,
                          moduleColor: DawaTokens.brandPrimary,
                          size: 40,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clinicianName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  color: DawaTokens.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                currentUserEmail.isNotEmpty
                                    ? currentUserEmail
                                    : 'Clinician',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  color: DawaTokens.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('Logout'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DawaTokens.statusDanger,
                          side: const BorderSide(
                            color: DawaTokens.statusDangerBg,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(DawaTokens.radiusMd),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _normalizedSelectedPage(BuildContext context) {
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
    if (path.contains('hemonix')) return 'HemoNix';
    if (path.contains('ct-scan')) return 'CT Scan';
    if (path.contains('care-tools')) return 'Care Tools';
    if (path.contains('home')) return 'Home';
    if (selected == 'Mothers') return 'Patients';
    if (selected.isEmpty) return 'Home';
    return selected;
  }

  String _clinicianName() {
    if (currentUserDisplayName.trim().isNotEmpty) {
      return currentUserDisplayName.trim();
    }
    if (currentUserEmail.trim().isNotEmpty) {
      return currentUserEmail.trim();
    }
    return 'Clinician';
  }

  void _goTo(BuildContext context, String routeName, String pageName) {
    FFAppState().selectedPage = pageName;
    FFAppState().makingFIrstEncounter = false;
    safeSetState(() {});

    context.goNamed(
      routeName,
      extra: <String, dynamic>{
        kTransitionInfoKey: TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.fade,
          duration: Duration.zero,
        ),
      },
    );
  }

  Future<void> _logout() async {
    GoRouter.of(context).prepareAuthEvent();
    await authManager.signOut();
    GoRouter.of(context).clearRedirectLocation();

    if (!mounted) return;

    context.goNamedAuth(
      LoginWidget.routeName,
      mounted,
      extra: <String, dynamic>{
        kTransitionInfoKey: TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.fade,
          duration: Duration.zero,
        ),
      },
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground =
        active ? DawaTokens.textInverse : DawaTokens.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
          onTap: onTap,
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: active ? DawaTokens.brandPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(DawaTokens.radiusMd),
            ),
            child: Row(
              children: [
                const SizedBox(width: 15),
                Icon(icon, color: foreground, size: 21),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: foreground,
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
