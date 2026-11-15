import 'dart:ui' show PointerDeviceKind;
import 'package:clinician/app_state.dart';
import 'package:clinician/components/clinician_navigation.dart';
import 'package:clinician/components/small_side_nav/small_side_nav_widget.dart';
import 'package:clinician/components/appbar_nav/appbar_nav_widget.dart';
import 'package:clinician/components/navigation_brand_header.dart';
import 'package:clinician/components/navigation_design_system.dart';
import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:clinician/flutter_flow/nav/nav.dart'
    show createRouter, AppStateNotifier;

const destinations = {
  'Home': ('Home', '/home'),
  'Patients': ('Moms', '/moms'),
  'Appointments': ('ScheduledEncounters', '/scheduledEncounters'),
  'Cervical Cancer': ('CervicalCancer', '/cervical-cancer'),
  'Ultrasound': ('Ultrasound', '/ultrasound'),
  'Anemia': ('HemoNix', '/hemonix'),
  'CT Scan': ('CtScan', '/ct-scan'),
  'BP Monitor': ('BpMonitor', '/bp-monitor'),
  'Settings': ('Profile', '/profile'),
};

Future<void> loadNavigationFonts() async {
  await (FontLoader('NavigationQA')
        ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf')))
      .load();
  await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
      .load();
  for (final (family, asset) in [
    ('PhosphorRegular', 'Phosphor.ttf'),
    ('PhosphorBold', 'Phosphor-Bold.ttf')
  ]) {
    await (FontLoader('packages/phosphoricons_flutter/$family')
          ..addFont(rootBundle
              .load('packages/phosphoricons_flutter/lib/fonts/$asset')))
        .load();
  }
}

void main() {
  setUpAll(loadNavigationFonts);
  setUp(() {
    clinicianSidebarCollapsed.value = false;
    clinicianScreeningsExpanded.value = true;
  });

  Future<GoRouter> pump(WidgetTester tester,
      {String initial = '/home',
      Size size = const Size(1280, 900),
      double textScale = 1,
      bool reducedMotion = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final manager = EdgeDeviceManager(
        client: EdgeDeviceClient(
            config: const EdgeDeviceConfig(
                baseUrl: 'http://dawa.local', modelManagementEnabled: true),
            httpClient: MockClient((_) async => http.Response(
                '{"active":null,"state":"stopped","ready":false}', 200))));
    addTearDown(manager.dispose);
    final desktop = size.width >= NavigationTokens.desktopBreakpoint;
    final router = GoRouter(initialLocation: initial, routes: [
      for (final entry in destinations.entries)
        GoRoute(
            name: entry.value.$1,
            path: entry.value.$2,
            builder: (context, state) => Scaffold(
                appBar: AppBar(
                    toolbarHeight: NavigationTokens.appBarHeight,
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    titleSpacing: 0,
                    title: AppbarNavWidget(deviceManager: manager)),
                drawer: desktop
                    ? null
                    : const Drawer(
                        width: NavigationTokens.expandedWidth,
                        child: SmallSideNavWidget()),
                body: Row(children: [
                  if (desktop) const SmallSideNavWidget(),
                  Expanded(
                      child: ColoredBox(
                          color: NavigationTokens.canvas,
                          child: Center(
                              child: Text('Destination: ${entry.key}')))),
                ]))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            fontFamily: 'NavigationQA',
            colorSchemeSeed: NavigationTokens.brand),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
                disableAnimations: reducedMotion),
            child: child!),
        routerConfig: router));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/images/dawa_cross.png'),
        tester.element(find.byType(Scaffold).first)));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (const bool.fromEnvironment('CAPTURE_NAV_QA')) {
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('../docs/qa/phase1b/$name.png'));
    }
  }

  test('production router preserves existing names and URLs', () {
    final router = createRouter(AppStateNotifier.instance);
    addTearDown(router.dispose);
    for (final entry in destinations.entries) {
      expect(router.namedLocation(entry.value.$1), entry.value.$2);
    }
    expect(router.namedLocation('CareTools'), '/care-tools');
    expect(router.namedLocation('EditProfile'), '/editProfile');
  });

  testWidgets(
      'official branding appears only in sidebar; page title is contextual',
      (tester) async {
    await pump(tester, initial: '/hemonix');
    expect(find.byType(DawaBrandMark), findsOneWidget);
    expect(find.text('Dawa'), findsOneWidget);
    expect(find.text('Dawa Clinician'), findsNothing);
    expect(find.text('Anemia Screening'), findsOneWidget);
    expect(find.byType(NavigationIcon), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all destinations route and persist selection', (tester) async {
    final router = await pump(tester);
    for (final entry in destinations.entries) {
      await tester.tap(find.text(entry.key).first);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, entry.value.$2);
      expect(find.text('Destination: ${entry.key}'), findsOneWidget);
      expect(
          tester.widgetList<Semantics>(find.byType(Semantics)).where((s) =>
              s.properties.label == entry.key && s.properties.selected == true),
          isNotEmpty);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Screenings remembers disclosure and opens for active child',
      (tester) async {
    final router = await pump(tester);
    await tester.tap(find.text('Screenings'));
    await tester.pumpAndSettle();
    expect(find.text('Anemia'), findsNothing);
    await tester.tap(find.text('Patients'));
    await tester.pumpAndSettle();
    expect(find.text('Anemia'), findsNothing);
    router.goNamed('HemoNix');
    await tester.pumpAndSettle();
    expect(find.text('Anemia'), findsOneWidget);
    expect(
        tester.widgetList<Semantics>(find.byType(Semantics)).where((s) =>
            s.properties.label == 'Screenings' &&
            s.properties.selected == true),
        isEmpty);
    expect(clinicianScreeningsExpanded.value, true);
  });

  testWidgets('deep link recreation and desktop collapse retain URL selection',
      (tester) async {
    await pump(tester, initial: '/hemonix');
    expect(find.text('Destination: Anemia'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await pump(tester, initial: '/ct-scan');
    expect(find.text('Destination: CT Scan'), findsOneWidget);
    await tester.tap(find.byTooltip('Collapse navigation'));
    await tester.pumpAndSettle();
    expect(
        tester.getSize(find.byKey(const ValueKey('clinician-sidebar'))).width,
        64);
    expect(find.byTooltip('Screenings · CT Scan'), findsOneWidget);
    await tester.tap(find.byTooltip('Expand navigation'));
    await tester.pumpAndSettle();
    expect(find.text('CT Scan'), findsNWidgets(2));
  });

  testWidgets('expanded, collapsed tool menu and account actions',
      (tester) async {
    final router = await pump(tester);
    expect(
        tester.getSize(find.byKey(const ValueKey('clinician-sidebar'))).width,
        256);
    await capture(tester, 'desktop-expanded');
    await tester.tap(find.byTooltip('Collapse navigation'));
    await tester.pumpAndSettle();
    await capture(tester, 'desktop-collapsed');
    await tester.tap(find.byTooltip('Screenings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BP Monitor'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/bp-monitor');
    await tester.tap(find.byTooltip('Clinician account'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Account information'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    await tester.tap(find.text('Account information'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tab and Enter activate navigation in reading order',
      (tester) async {
    final router = await pump(tester);
    // Notifications, device status, sidebar collapse, Home, Patients.
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/moms');
  });

  for (final (label, size) in [
    ('tablet', const Size(834, 1112)),
    ('mobile', const Size(390, 844)),
    ('small-mobile', const Size(320, 640)),
  ]) {
    testWidgets('$label drawer opens, closes and routes without overflow',
        (tester) async {
      clinicianSidebarCollapsed.value = true;
      final router = await pump(tester, size: size);
      expect(find.byType(SmallSideNavWidget), findsNothing);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      expect(find.text('Cervical Cancer'), findsOneWidget);
      expect(find.byTooltip('Close navigation'), findsOneWidget);
      await capture(tester, '$label-drawer');
      await tester.tap(find.text('Ultrasound'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/ultrasound');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('200 percent type and reduced motion keep chrome usable',
      (tester) async {
    await pump(tester, textScale: 2, reducedMotion: true);
    await capture(tester, 'desktop-large-type');
    expect(tester.takeException(), isNull);
    final panel = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('clinician-sidebar')));
    expect(panel.duration, Duration.zero);
    await tester.tap(find.byTooltip('Collapse navigation'));
    await tester.pump();
    expect(
        tester.getSize(find.byKey(const ValueKey('clinician-sidebar'))).width,
        64);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'navigation has distinct hover, pressed and keyboard focus states',
      (tester) async {
    final router = await pump(tester);
    final target = find.widgetWithText(NavigationItem, 'Patients');
    final item = tester.widget<NavigationItem>(target);
    expect(tester.getSize(target).height, NavigationTokens.rowHeight);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(target));
    await tester.pumpAndSettle();
    final hoverBox = tester.widget<AnimatedContainer>(find
        .descendant(of: target, matching: find.byType(AnimatedContainer))
        .first);
    expect(
        (hoverBox.decoration! as BoxDecoration).color, NavigationTokens.hover);
    await mouse.removePointer();
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.pumpAndSettle();
    final focusBox = tester.widget<AnimatedContainer>(find
        .descendant(of: target, matching: find.byType(AnimatedContainer))
        .first);
    expect(
        ((focusBox.decoration! as BoxDecoration).border! as Border).top.color,
        NavigationTokens.brand);
    final gesture = await tester.startGesture(tester.getCenter(target),
        kind: PointerDeviceKind.mouse, pointer: 99);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/home');
    final pressed = tester.widget<AnimatedContainer>(find
        .descendant(of: target, matching: find.byType(AnimatedContainer))
        .first);
    expect(
        (pressed.decoration! as BoxDecoration).color, NavigationTokens.pressed);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/moms');
    expect(item.label, 'Patients');
  });

  Future<void> captureInteraction(WidgetTester tester, String name) async {
    if (const bool.fromEnvironment('CAPTURE_SIDEBAR_INTERACTION')) {
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('../docs/qa/sidebar-interaction/$name.png'));
    }
  }

  testWidgets(
      'expanded sidebar hover keeps icon weight and text stable without tooltips',
      (tester) async {
    await pump(tester);
    final target = find.widgetWithText(NavigationItem, 'Patients');
    final before = tester.widget<NavigationIcon>(find
        .descendant(of: target, matching: find.byType(NavigationIcon))
        .first);
    final beforeSize = tester.getSize(target);
    await captureInteraction(tester, 'expanded-default');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    final after = tester.widget<NavigationIcon>(find
        .descendant(of: target, matching: find.byType(NavigationIcon))
        .first);
    expect(after.strong, before.strong);
    expect(after.color, before.color);
    expect(tester.getSize(target), beforeSize);
    expect(find.text('Patients'), findsOneWidget,
        reason: 'The visible label does not need another hover label.');
    await captureInteraction(tester, 'expanded-hover');
    final home = find.widgetWithText(NavigationItem, 'Home');
    await mouse.moveTo(tester.getCenter(home));
    await tester.pumpAndSettle();
    final selectedBox = tester.widget<AnimatedContainer>(find
        .descendant(of: home, matching: find.byType(AnimatedContainer))
        .first);
    expect((selectedBox.decoration as BoxDecoration).color,
        NavigationTokens.selected);
    await captureInteraction(tester, 'selected-hover');
    await mouse.removePointer();
  });

  testWidgets(
      'collapsed tooltips are delayed and dismiss immediately on navigation',
      (tester) async {
    final router = await pump(tester);
    await tester.tap(find.byTooltip('Collapse navigation'));
    await tester.pumpAndSettle();
    final target = find.byTooltip('Patients');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Patients'), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Patients'), findsOneWidget);
    await captureInteraction(tester, 'collapsed-tooltip');
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/moms');
    expect(find.text('Patients'), findsOneWidget,
        reason: 'Only the contextual page heading remains.');
    await mouse.removePointer();
  });

  testWidgets('clicking the current page preserves its active session state',
      (tester) async {
    final router = await pump(tester);
    FFAppState().makingFIrstEncounter = true;
    addTearDown(() => FFAppState().makingFIrstEncounter = false);
    await tester.tap(find.widgetWithText(NavigationItem, 'Home'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(FFAppState().makingFIrstEncounter, isTrue);
    await tester.tap(find.text('Patients'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/moms');
    expect(FFAppState().makingFIrstEncounter, isFalse);
  });

  testWidgets(
      'current-page clicks close the mobile drawer without navigating away',
      (tester) async {
    final router = await pump(tester, size: const Size(390, 844));
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationItem, 'Home'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(find.byType(SmallSideNavWidget), findsNothing);
    expect(find.text('Destination: Home'), findsOneWidget);
  });

  testWidgets('sidebar destination clears an existing registry query',
      (tester) async {
    final router = await pump(tester, initial: '/moms?search=clinic');
    await tester.tap(find.widgetWithText(NavigationItem, 'Patients'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.toString(), '/moms');
  });

  test('color states and navigation text meet WCAG AA', () {
    double contrast(Color a, Color b) {
      final l1 = a.computeLuminance(), l2 = b.computeLuminance();
      return l1 > l2 ? (l1 + .05) / (l2 + .05) : (l2 + .05) / (l1 + .05);
    }

    for (final (foreground, background) in [
      (NavigationTokens.secondary, NavigationTokens.surface),
      (NavigationTokens.selectedText, NavigationTokens.selected),
      (NavigationTokens.itemText, NavigationTokens.hover),
      (NavigationTokens.itemText, NavigationTokens.pressed),
    ]) {
      expect(contrast(foreground, background), greaterThanOrEqualTo(4.5));
    }
    expect(
        NavigationItemColors.resolve(selected: false, hovered: true).background,
        NavigationTokens.hover);
    expect(
        NavigationItemColors.resolve(selected: true, pressed: true).background,
        NavigationTokens.pressed);
    expect(NavigationItemColors.resolve(selected: true).background,
        NavigationTokens.selected);
  });
}
