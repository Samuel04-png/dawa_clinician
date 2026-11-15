import 'dart:async';
import 'dart:convert';
import 'package:clinician/application/create_mom/create_patient_modal_widget.dart';
import 'package:clinician/application/home/home_widget.dart';
import 'package:clinician/application/home/data/home_dashboard_repository.dart';
import 'package:clinician/application/home/widgets/home_dashboard_content.dart';
import 'package:clinician/application/moms/moms_widget.dart';
import 'package:clinician/application/moms/patient_registry_filters.dart';
import 'package:clinician/components/clinician_navigation.dart';
import 'package:clinician/components/navigation_design_system.dart';
import 'package:clinician/components/navigation_brand_header.dart';
import 'package:clinician/components/small_side_nav/small_side_nav_widget.dart';
import 'package:clinician/components/edge_device_indicator.dart';
import 'package:clinician/flutter_flow/flutter_flow_util.dart';
import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'clinician_navigation_test.dart' show loadNavigationFonts;
import 'home_dashboard_phase2_test.dart' show FakeHomeRepository;

List<DashboardPatient> registryFixtures() => dashboardPatients([
      {
        'id': 'p-1',
        'mother_id': 'DM-401',
        'name': 'Chileshe Nalumino-Mwanza',
        'dateOfBirth': '1996-03-12',
        'phone_number': '+260 97 000 0001',
        'nrc': '123456/78/1',
        'village': 'Kabwata',
        'clinic_name': 'Lusaka clinic',
        'occupation': 'Teacher',
        'first_encounter_id': 'first_encounter/first-1',
        'created_at': '2026-11-10T07:00:00Z',
        'updated_at': '2026-11-12T07:00:00Z'
      },
      {
        'id': 'p-2',
        'mother_id': 'DM-402',
        'name': 'Martha Phiri',
        'source_project': 'dawa_mom',
        'created_at': '2026-11-11T07:00:00Z',
        'updated_at': '2026-11-11T07:00:00Z'
      },
      {
        'id': 'p-3',
        'mother_id': 'DM-403',
        'name': 'Naomi Banda',
        'dateOfBirth': '1994-04-15',
        'phone_number': '0970000003',
        'created_at': '2026-10-01T07:00:00Z',
        'updated_at': '2026-11-10T07:00:00Z'
      },
      {
        'id': 'p-4',
        'mother_id': 'DM-404',
        'name': 'Naomi Banda',
        'dateOfBirth': '1989-10-10',
        'phone_number': '0970000004',
        'first_encounter_id': 'first_encounter/first-4',
        'updated_at': '2026-11-09T07:00:00Z'
      },
      {
        'id': 'p-5',
        'mother_id': 'DM-405',
        'name': '',
        'updated_at': '2026-11-08T07:00:00Z'
      },
    ]);

class RegistryTestRepository extends FakeHomeRepository {
  int loads = 0;
  @override
  Future<List<DashboardPatient>> loadPatients() {
    loads++;
    return super.loadPatients();
  }
}

void main() {
  setUpAll(() async {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    SharedPreferences.setMockInitialValues({});
    await FFAppState().initializePersistedState();
    await loadNavigationFonts();
  });
  setUp(() {
    clinicianSidebarCollapsed.value = false;
    clinicianScreeningsExpanded.value = true;
  });

  Future<GoRouter> pump(WidgetTester tester, HomeDashboardRepository repo,
      {Size size = const Size(1440, 1000),
      bool collapsed = false,
      double scale = 1,
      String path = '/moms'}) async {
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
            httpClient: MockClient((_) async => http.Response(
                '{"active":null,"state":"stopped","ready":false}', 200))));
    addTearDown(manager.dispose);
    final router = GoRouter(initialLocation: path, routes: [
      GoRoute(
          name: 'Home',
          path: '/home',
          builder: (context, state) => HomeWidget(
              repository: repo,
              deviceManager: manager,
              now: () => DateTime(2026, 11, 12, 9))),
      GoRoute(
          name: 'Moms',
          path: '/moms',
          builder: (context, state) => MomsWidget(
              repository: repo,
              deviceManager: manager,
              now: () => DateTime(2026, 11, 12, 9))),
      GoRoute(
          name: 'PatientDetails',
          path: '/patientDetails',
          builder: (context, state) =>
              Scaffold(body: Text('Patient destination ${state.uri.query}'))),
      for (final (name, route) in [
        ('ScheduledEncounters', '/scheduledEncounters'),
        ('Profile', '/profile'),
        ('CervicalCancer', '/cervical-cancer'),
        ('Ultrasound', '/ultrasound'),
        ('HemoNix', '/hemonix'),
        ('CtScan', '/ct-scan'),
        ('BpMonitor', '/bp-monitor'),
        ('CareTools', '/care-tools')
      ])
        GoRoute(
            name: name,
            path: route,
            builder: (_, state) => Scaffold(body: Text(state.uri.path))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: FFAppState(),
        child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                fontFamily: 'NavigationQA',
                colorSchemeSeed: NavigationTokens.brand),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            routerConfig: router)));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/images/dawa_cross.png'),
        tester.element(find.byType(Scaffold))));
    await tester.pumpAndSettle();
    return router;
  }

  RegistryTestRepository fixtures() =>
      RegistryTestRepository()..patients = registryFixtures();

  test(
      'search covers existing identifiers and normalizes phone formatting safely',
      () {
    final p = registryFixtures().first;
    for (final value in [
      'chileshe',
      'DM-401',
      'p-1',
      '260970000001',
      '123456/78/1',
      'kabwata',
      'lusaka',
      'teacher'
    ]) {
      expect(registryMatchesSearch(p, value), true, reason: value);
    }
    expect(registryMatchesSearch(p, 'unrelated NRC 0001'), false);
    expect(registryMatchesSearch(p, '   '), true);
  });

  test(
      'filters distinguish required registration, first encounters and actual registration dates',
      () {
    final records = registryFixtures();
    final now = DateTime(2026, 11, 12, 9);
    List<String> ids(PatientRegistryFilter f) => records
        .where((p) => registryMatchesFilter(p, f, now))
        .map((p) => p.id)
        .toList();
    expect(ids(PatientRegistryFilter.needsCompletion), ['p-2', 'p-5']);
    expect(ids(PatientRegistryFilter.firstEncounter), ['p-1', 'p-4']);
    expect(ids(PatientRegistryFilter.newImported), ['p-2']);
    expect(ids(PatientRegistryFilter.recentlyAdded), ['p-1', 'p-2']);
    expect(registryPatientAge(records.first, now), 30);
    expect(registryPatientAge(records.last, now), isNull);
    final future = DashboardPatient.fromRow({
      'id': 'future',
      'created_at': '2026-11-13T00:00:00Z',
      'dateOfBirth': '2027-01-01'
    });
    expect(
        registryMatchesFilter(future, PatientRegistryFilter.recentlyAdded, now),
        false);
    expect(registryPatientAge(future, now), isNull);
  });

  testWidgets(
      'Home and Patients share geometry, logo, controls and persisted navigation state',
      (tester) async {
    final router = await pump(tester, fixtures(), path: '/home');
    final sidebar = tester.getRect(find.byType(SmallSideNavWidget));
    final brand = tester.getRect(find.byType(NavigationBrandHeader));
    clinicianScreeningsExpanded.value = false;
    router.goNamed('Moms');
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(SmallSideNavWidget)), sidebar);
    expect(tester.getRect(find.byType(NavigationBrandHeader)), brand);
    expect(clinicianScreeningsExpanded.value, false);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(EdgeDeviceIndicator), findsOneWidget);
    expect(
        tester
            .widgetList<NavigationItem>(find.byType(NavigationItem))
            .singleWhere((w) => w.label == 'Patients')
            .selected,
        true);
    clinicianSidebarCollapsed.value = true;
    await tester.pumpAndSettle();
    final collapsed = tester.getRect(find.byType(SmallSideNavWidget));
    router.goNamed('Home');
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(SmallSideNavWidget)), collapsed);
    expect(collapsed.width, NavigationTokens.collapsedWidth);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'search and filters combine across complete dataset and retain state on detail return',
      (tester) async {
    final router = await pump(tester, fixtures());
    await tester.enterText(find.byType(TextField), 'martha');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Needs completion'));
    await tester.pumpAndSettle();
    expect(find.text('Martha Phiri'), findsOneWidget);
    expect(find.text('Chileshe Nalumino-Mwanza'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('p-2')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.query, contains('p-2'));
    router.pop();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'martha');
    expect(
        tester
            .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, 'Needs completion'))
            .selected,
        true);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Name not recorded'), findsOneWidget);
    expect(find.text('Naomi Banda'), findsNothing);
  });

  testWidgets(
      'stable record and first encounter references survive duplicate patient names',
      (tester) async {
    final router = await pump(tester, fixtures());
    await tester.tap(find.byKey(const ValueKey('p-4')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.query, contains('p-4'));
    expect(
        router.routeInformationProvider.value.uri.query, contains('first-4'));
  });

  testWidgets(
      'missing values are specific and phone NRC and location stay out of rows',
      (tester) async {
    await pump(tester, fixtures());
    expect(find.text('Name not recorded'), findsOneWidget);
    expect(
        find.text('Missing name, date of birth, phone number'), findsOneWidget);
    expect(find.text('Missing date of birth, phone number'), findsOneWidget);
    expect(find.textContaining('Weeks'), findsNothing);
    expect(find.text('+260 97 000 0001'), findsNothing);
    expect(find.text('123456/78/1'), findsNothing);
    expect(find.text('Kabwata'), findsNothing);
    expect(find.text('Naomi Banda'), findsNWidgets(2));
    expect(find.text('New Patient'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('failed permission request stays unknown and retry recovers',
      (tester) async {
    final repo = fixtures()
      ..patientError = const PostgrestException(
          message: 'sensitive internal detail', code: '42501');
    await pump(tester, repo);
    expect(find.text('Patient registry unavailable'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(find.textContaining('sensitive internal detail'), findsNothing);
    repo.patientError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Martha Phiri'), findsOneWidget);
  });

  testWidgets('loading, empty registry and no search results remain distinct',
      (tester) async {
    final completer = Completer<List<DashboardPatient>>();
    final repo = fixtures()..pendingPatients = completer;
    await pump(tester, repo);
    expect(find.byType(DashboardSkeleton), findsOneWidget);
    expect(find.text('0'), findsNothing);
    completer.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('No patients registered yet'), findsOneWidget);
    expect(find.text('New Patient'), findsOneWidget);
  });

  testWidgets(
      'no results offers reset and search does not issue remote requests',
      (tester) async {
    final repo = fixtures();
    await pump(tester, repo);
    await tester.enterText(find.byType(TextField), 'unknown');
    await tester.pumpAndSettle();
    expect(find.text('No matching patients'), findsOneWidget);
    expect(repo.loads, 1);
    await tester.tap(find.text('Clear search and filters'));
    await tester.pumpAndSettle();
    expect(find.text('Martha Phiri'), findsOneWidget);
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        true);
  });

  testWidgets(
      'keyboard activates a patient and semantics identifies the record',
      (tester) async {
    final router = await pump(tester, fixtures());
    final semantics = tester.ensureSemantics();
    final focus =
        Focus.of(tester.element(find.text('Chileshe Nalumino-Mwanza')));
    for (var i = 0; i < 40 && !focus.hasFocus; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }
    expect(focus.hasFocus, true);
    expect(find.bySemanticsLabel(RegExp('Open patient record')), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.query, contains('p-1'));
    semantics.dispose();
  });

  testWidgets(
      'mobile drawer opens with the same navigation and preserves one primary action',
      (tester) async {
    await pump(tester, fixtures(), size: const Size(390, 844));
    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    expect(
        tester
            .widgetList<NavigationItem>(find.byType(NavigationItem))
            .singleWhere((w) => w.label == 'Patients')
            .selected,
        true);
    expect(find.text('New Patient'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (name, size, collapsed, scale) in [
    ('desktop', const Size(1600, 1000), false, 1.0),
    ('laptop', const Size(1280, 900), false, 1.0),
    ('collapsed', const Size(1280, 900), true, 1.0),
    ('tablet', const Size(834, 1112), false, 1.0),
    ('mobile', const Size(390, 844), false, 1.0),
    ('small-large-text', const Size(320, 700), false, 2.0),
  ]) {
    testWidgets('$name stays usable without horizontal overflow',
        (tester) async {
      await pump(tester, fixtures(),
          size: size, collapsed: collapsed, scale: scale);
      expect(find.text('New Patient'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_PATIENTS_PHASE3'))
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('../docs/qa/phase3/$name.png'));
      await tester.drag(
          find.byType(CustomScrollView).first, const Offset(0, -850));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final row in tester
          .widgetList<RegistryPatientRow>(find.byType(RegistryPatientRow))) {
        final bounds = tester.getRect(find.byKey(ValueKey(row.patient.id)));
        expect(bounds.right <= size.width, true);
      }
    });
  }

  testWidgets(
      'metric definitions are exact and registration result refreshes the list',
      (tester) async {
    final repo = fixtures();
    await pump(tester, repo);
    final metrics = tester
        .widgetList<DashboardMetric>(find.byType(DashboardMetric))
        .toList();
    expect(metrics.map((m) => (m.label, m.value)), [
      ('Total patients', '5'),
      ('Needs completion', '2'),
      ('With first encounter', '2')
    ]);
    await tester.tap(find.text('New Patient'));
    await tester.pump();
    repo.patients = [
      ...repo.patients,
      const DashboardPatient(id: 'created', name: 'Newly registered patient')
    ];
    Navigator.of(tester.element(find.byType(CreatePatientModalWidget)))
        .pop(const CreatePatientModalResult.created());
    await tester.pumpAndSettle();
    expect(repo.loads, 2);
    await tester.enterText(find.byType(TextField), 'Newly registered');
    await tester.pumpAndSettle();
    expect(find.text('Newly registered patient'), findsOneWidget);
  });

  testWidgets(
      'an account switch clears loaded records and search before the new response arrives',
      (tester) async {
    final nextResponse = Completer<http.Response>();
    // Supabase owns an isolate. Keep its lifecycle in the real async zone.
    final database = (await tester.runAsync(() async => SupabaseClient(
            'http://localhost', 'public-test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((request) async {
          if (request.headers['Authorization'] == 'Bearer account-b') {
            final response = await nextResponse.future;
            return http.Response(response.body, response.statusCode,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          return http.Response('[{"id":"a","name":"Account A record"}]', 200,
              request: request, headers: {'content-type': 'application/json'});
        }))))!;
    addTearDown(() => tester.runAsync(database.dispose));
    Future<void> signIn(String id, String token) => database.auth
        .setInitialSession(jsonEncode({
          'access_token': token,
          'refresh_token': 'refresh',
          'token_type': 'bearer',
          'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
          'expires_in': 3600,
          'user': {
            'id': id,
            'aud': 'authenticated',
            'created_at': '2026-11-01T00:00:00Z'
          },
        }))
        .then((_) {});
    await tester.runAsync(
        () => signIn('00000000-0000-4000-a000-000000000001', 'account-a'));
    await pump(tester, SupabaseHomeDashboardRepository(client: database));
    expect(find.text('Account A record'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Account A');
    await tester.pumpAndSettle();
    await tester.runAsync(
        () => signIn('00000000-0000-4000-a000-000000000002', 'account-b'));
    await tester.pumpAndSettle();
    expect(find.text('Account A record'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    expect(find.byType(DashboardSkeleton), findsOneWidget);
    nextResponse
        .complete(http.Response('[{"id":"b","name":"Account B record"}]', 200));
    await tester.pumpAndSettle();
    expect(find.text('Account B record'), findsOneWidget);
    expect(find.text('Account A record'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('New Patient opens the existing registration workflow',
      (tester) async {
    await pump(tester, fixtures());
    await tester.tap(find.text('New Patient'));
    await tester.pump();
    expect(find.byType(CreatePatientModalWidget), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('New Patient'), findsOneWidget);
  });
}
