import 'package:clinician/components/appbar_nav/appbar_nav_widget.dart';
import 'package:clinician/application/home/home_dashboard_header.dart';
import 'package:clinician/components/clinician_navigation.dart';
import 'package:clinician/components/navigation_design_system.dart';
import 'package:clinician/components/small_side_nav/small_side_nav_widget.dart';
import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'clinician_navigation_test.dart' show loadNavigationFonts;

void main() {
  setUpAll(loadNavigationFonts);
  setUp(() => clinicianSidebarCollapsed.value = false);

  Future<void> pumpHome(WidgetTester tester, Size size,
      {bool collapsed = false, double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    clinicianSidebarCollapsed.value = collapsed;
    final manager = EdgeDeviceManager(
      client: EdgeDeviceClient(
        config: const EdgeDeviceConfig(
            baseUrl: 'http://dawa.local', modelManagementEnabled: true),
        httpClient:
            MockClient((_) async => throw http.ClientException('Offline')),
      ),
    );
    addTearDown(manager.dispose);
    final desktop = size.width >= NavigationTokens.desktopBreakpoint;
    final scaffoldKey = GlobalKey<ScaffoldState>();
    final router = GoRouter(initialLocation: '/home', routes: [
      GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
                key: scaffoldKey,
                backgroundColor: NavigationTokens.canvas,
                drawer: desktop
                    ? null
                    : const Drawer(
                        width: NavigationTokens.expandedWidth,
                        child: SmallSideNavWidget()),
                body: SafeArea(
                    child: Row(children: [
                  if (desktop) const SmallSideNavWidget(),
                  Expanded(
                      child: LayoutBuilder(builder: (context, constraints) {
                    final padding = constraints.maxWidth < 700 ? 16.0 : 24.0;
                    return Column(children: [
                      Row(children: [
                        if (!desktop)
                          IconButton(
                              tooltip: 'Open navigation',
                              onPressed: () =>
                                  scaffoldKey.currentState!.openDrawer(),
                              icon: const Icon(Icons.menu)),
                        Expanded(
                            child: AppbarNavWidget(
                                showTitle: false, deviceManager: manager)),
                      ]),
                      Padding(
                          padding:
                              EdgeInsets.fromLTRB(padding, 16, padding, 22),
                          child: Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 1120),
                                  child: HomeDashboardHeader(
                                    greeting: 'Good Morning',
                                    date: 'Thursday, 12 November 2026',
                                    deviceManager: manager,
                                    onOpenNavigation: () =>
                                        scaffoldKey.currentState!.openDrawer(),
                                  )))),
                      Expanded(
                          child: ListView(
                              padding:
                                  EdgeInsets.symmetric(horizontal: padding),
                              children: [
                            for (var index = 0; index < 12; index++)
                              Align(
                                  alignment: Alignment.topCenter,
                                  child: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 1120),
                                      child: Container(
                                          key: ValueKey('content-$index'),
                                          height: 140,
                                          margin:
                                              const EdgeInsets.only(bottom: 24),
                                          color: Colors.white,
                                          alignment: Alignment.center,
                                          child: Text(
                                              'Content fixture ${index + 1}'))))
                          ])),
                    ]);
                  })),
                ])),
              )),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'NavigationQA'),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!),
      routerConfig: router,
    ));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/images/dawa_cross.png'),
        tester.element(find.byType(Scaffold))));
    await tester.pumpAndSettle();
  }

  for (final collapsed in [false, true]) {
    testWidgets(
        'Home greeting leads the ${collapsed ? 'collapsed' : 'expanded'} layout',
        (tester) async {
      await pumpHome(tester, const Size(1280, 900), collapsed: collapsed);
      expect(find.byType(AppBar), findsNothing);
      expect(tester.getTopLeft(find.text('Good Morning')).dy, 80);
      expect(
          tester.getTopLeft(find.byKey(const ValueKey('clinician-sidebar'))).dy,
          0);
      final header = tester.getRect(find.byType(HomeDashboardHeader));
      final content = tester.getRect(find.byKey(const ValueKey('content-0')));
      expect(header.left, content.left);
      expect(tester.getTopLeft(find.text('Good Morning')).dx, content.left);
      expect(content.top - header.bottom, 22);
      expect(
          tester
              .getRect(find.byKey(const ValueKey('edge-device-control')))
              .overlaps(tester.getRect(find.text('Good Morning'))),
          false);
      if (collapsed) {
        await tester.tap(find.byTooltip('Expand navigation'));
        await tester.pumpAndSettle();
        expect(clinicianSidebarCollapsed.value, false);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Home device details remain accessible while content scrolls',
      (tester) async {
    await pumpHome(tester, const Size(1280, 900));
    final initial =
        tester.getTopLeft(find.byKey(const ValueKey('edge-device-control')));
    await tester.drag(find.text('Content fixture 2'), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('edge-device-control'))),
        initial);
    await tester.tap(find.byKey(const ValueKey('edge-device-control')));
    await tester.pumpAndSettle();
    expect(find.text('Connection status'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Retry Connection'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (name, size, scale) in [
    ('mobile', const Size(390, 844), 1.0),
    ('tablet', const Size(834, 1112), 1.0),
    ('large-text', const Size(320, 640), 2.0),
  ]) {
    testWidgets('Home $name layout keeps greeting, date and drawer usable',
        (tester) async {
      await pumpHome(tester, size, textScale: scale);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Good Morning'), findsOneWidget);
      expect(find.text('Thursday, 12 November 2026'), findsOneWidget);
      expect(
          tester.getRect(find.byType(HomeDashboardHeader)).bottom,
          lessThan(
              tester.getRect(find.byKey(const ValueKey('content-0'))).top));
      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close navigation'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('capture Home refinement layouts', (tester) async {
    if (!const bool.fromEnvironment('CAPTURE_HOME_QA')) return;
    for (final (name, size, collapsed) in [
      ('expanded', const Size(1280, 900), false),
      ('collapsed', const Size(1280, 900), true),
      ('mobile', const Size(390, 844), false),
    ]) {
      await pumpHome(tester, size, collapsed: collapsed);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('/tmp/dawa-home-refinement/$name.png'));
      await tester.pumpWidget(const SizedBox());
    }
  });
}
