import '/auth/firebase_auth/auth_util.dart';
import '/components/clinician_navigation.dart';
import '/components/clinical_features.dart';
import '/components/navigation_design_system.dart';
import '/components/navigation_brand_header.dart';
import '/components/clinician_account_menu.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'small_side_nav_model.dart';
export 'small_side_nav_model.dart';

class SmallSideNavWidget extends StatefulWidget {
  const SmallSideNavWidget(
      {super.key,
      this.iconOne = 'Home',
      this.iconTwo = 'Patients',
      this.iconThree = 'Appointments',
      this.iconFour = 'Care Tools'});
  // Retain generated callers' constructor compatibility.
  final String iconOne, iconTwo, iconThree, iconFour;
  @override
  State<SmallSideNavWidget> createState() => _SmallSideNavWidgetState();
}

class _SmallSideNavWidgetState extends State<SmallSideNavWidget> {
  String? _observedPath;
  static const tools = [
    ('Cervical Cancer', 'CervicalCancer', NavigationSymbol.cervical),
    ('Ultrasound', 'Ultrasound', NavigationSymbol.ultrasound),
    ('Anemia', 'HemoNix', NavigationSymbol.anemia),
    if (ClinicalFeatures.ctScan) ('CT Scan', 'CtScan', NavigationSymbol.ct),
    ('BP Monitor', 'BpMonitor', NavigationSymbol.bloodPressure),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final path = GoRouterState.of(context).uri.path;
    if (path != _observedPath) {
      _observedPath = path;
      if (tools.any((t) => t.$1 == clinicianDestination(path))) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _observedPath == path)
            clinicianScreeningsExpanded.value = true;
        });
      }
    }
  }

  void _goTo(String route, String label) {
    final router = GoRouter.of(context);
    final currentLocation = GoRouterState.of(context).uri.toString();
    Tooltip.dismissAllToolTips();
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isDrawerOpen ?? false) scaffold!.closeDrawer();
    if (currentLocation == router.namedLocation(route)) return;
    // Commit route selection through the existing router before updating the
    // generated application state. Highlighting itself always follows the URL.
    context.goNamed(route);
    FFAppState().selectedPage = label;
    FFAppState().makingFIrstEncounter = false;
  }

  @override
  Widget build(BuildContext context) {
    final active = clinicianDestination(GoRouterState.of(context).uri.path);
    final drawer = (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) ||
        MediaQuery.sizeOf(context).width < NavigationTokens.desktopBreakpoint;
    final activeChild = tools.any((t) => t.$1 == active);
    return ListenableBuilder(
      listenable: Listenable.merge(
          [clinicianSidebarCollapsed, clinicianScreeningsExpanded]),
      builder: (context, _) {
        final collapsed = !drawer && clinicianSidebarCollapsed.value;
        final expanded = clinicianScreeningsExpanded.value;
        Widget item(String label, NavigationSymbol symbol, VoidCallback onTap,
                {bool? selected, bool nested = false}) =>
            NavigationItem(
                label: label,
                symbol: symbol,
                onTap: onTap,
                collapsed: collapsed,
                touch: drawer,
                nested: nested,
                selected: selected ?? active == label);
        final width = collapsed
            ? NavigationTokens.collapsedWidth
            : NavigationTokens.expandedWidth;
        return AnimatedContainer(
          key: const ValueKey('clinician-sidebar'),
          duration: NavigationTokens.duration(context, layout: true),
          curve: Curves.easeInOut,
          width: width,
          decoration: const BoxDecoration(
              color: NavigationTokens.surface,
              border:
                  Border(right: BorderSide(color: NavigationTokens.border))),
          child: ClipRect(
              child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: width,
            maxWidth: width,
            child: SafeArea(
                child: Column(children: [
              NavigationBrandHeader(collapsed: collapsed, drawer: drawer),
              const Divider(height: 1, color: NavigationTokens.border),
              Expanded(
                  child: ListView(
                      primary: false,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      children: [
                    NavigationSectionLabel('Workspace', collapsed: collapsed),
                    item('Home', NavigationSymbol.home,
                        () => _goTo(HomeWidget.routeName, 'Home')),
                    item('Patients', NavigationSymbol.patients,
                        () => _goTo(MomsWidget.routeName, 'Patients')),
                    item(
                        'Appointments',
                        NavigationSymbol.appointments,
                        () => _goTo(ScheduledEncountersWidget.routeName,
                            'Appointments')),
                    const SizedBox(height: NavigationTokens.sectionGap),
                    NavigationSectionLabel('Clinical Tools',
                        collapsed: collapsed),
                    if (collapsed)
                      MenuAnchor(
                        menuChildren: [
                          for (final tool in tools)
                            MenuItemButton(
                                onPressed: () => _goTo(tool.$2, tool.$1),
                                leadingIcon: NavigationIcon(tool.$3,
                                    strong: active == tool.$1,
                                    color: active == tool.$1
                                        ? NavigationTokens.brand
                                        : NavigationTokens.secondary),
                                trailingIcon: active == tool.$1
                                    ? const NavigationIcon(
                                        NavigationSymbol.check,
                                        size: 16)
                                    : null,
                                child: Text(tool.$1)),
                        ],
                        builder: (context, controller, _) => NavigationItem(
                            label: 'Screenings',
                            symbol: NavigationSymbol.screenings,
                            tooltip: activeChild
                                ? 'Screenings · $active'
                                : 'Screenings',
                            collapsed: true,
                            selected: active == 'Screenings',
                            indicateGroup: activeChild,
                            onTap: () => controller.isOpen
                                ? controller.close()
                                : controller.open()),
                      )
                    else ...[
                      NavigationItem(
                          label: 'Screenings',
                          symbol: NavigationSymbol.screenings,
                          selected: active == 'Screenings',
                          expanded: expanded,
                          touch: drawer,
                          onTap: () =>
                              clinicianScreeningsExpanded.value = !expanded,
                          trailing: AnimatedRotation(
                              turns: expanded ? .5 : 0,
                              duration: NavigationTokens.duration(context,
                                  layout: true),
                              child: const NavigationIcon(
                                  NavigationSymbol.chevron,
                                  size: 16))),
                      AnimatedSize(
                          alignment: Alignment.topCenter,
                          duration:
                              NavigationTokens.duration(context, layout: true),
                          child: expanded
                              ? Container(
                                  margin: const EdgeInsets.only(left: 20),
                                  decoration: const BoxDecoration(
                                      border: Border(
                                          left: BorderSide(
                                              color: NavigationTokens.border))),
                                  child: Column(children: [
                                    for (final tool in tools)
                                      item(tool.$1, tool.$3,
                                          () => _goTo(tool.$2, tool.$1),
                                          nested: true),
                                  ]))
                              : const SizedBox.shrink()),
                    ],
                  ])),
              const Divider(
                  height: 1,
                  indent: 12,
                  endIndent: 12,
                  color: NavigationTokens.border),
              Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(children: [
                    item('Settings', NavigationSymbol.settings,
                        () => _goTo(ProfileWidget.routeName, 'Settings')),
                    ClinicianAccountMenu(
                        collapsed: collapsed,
                        touch: drawer,
                        onProfile: () =>
                            _goTo(ProfileWidget.routeName, 'Settings'),
                        onSignOut: _logout),
                  ])),
            ])),
          )),
        );
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
