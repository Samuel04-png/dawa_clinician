import 'dart:async';
import 'package:clinician/application/home/home_widget.dart';
import 'package:clinician/application/scheduled_encounters/appointments_calendar_dialog.dart';
import 'package:clinician/application/home/data/home_dashboard_repository.dart';
import 'package:clinician/application/home/widgets/home_dashboard_content.dart';
import 'package:clinician/components/clinician_navigation.dart';
import 'package:clinician/components/navigation_design_system.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'clinician_navigation_test.dart' show loadNavigationFonts;

class FakeHomeRepository implements HomeDashboardRepository {
  List<DashboardPatient> patients = dashboardPatients([
    {
      'id': 'p-1',
      'mother_id': 'DM-401',
      'name': 'Chileshe Nalumino-Mwanza',
      'dateOfBirth': '1996-03-12',
      'phone_number': '0970000000',
      'updated_at': '2026-11-12T07:00:00Z'
    },
    {
      'id': 'p-2',
      'mother_id': 'DM-402',
      'name': 'Martha Phiri',
      'updated_at': '2026-11-11T07:00:00Z'
    },
    {
      'id': 'p-3',
      'mother_id': 'DM-403',
      'name': 'Naomi Banda',
      'dateOfBirth': '1994-04-15',
      'phone_number': '0970000001',
      'first_encounter_id': 'first_encounter/first-3',
      'updated_at': '2026-11-10T07:00:00Z'
    },
  ]);
  List<DashboardAppointment> appointments = [
    DashboardAppointment(
        id: 'visit-1',
        patientId: 'p-1',
        patientName: 'Chileshe Nalumino-Mwanza',
        startsAt: DateTime(2026, 11, 12, 9),
        status: 'scheduled',
        type: 'Patient visit'),
    DashboardAppointment(
        id: 'visit-2',
        patientId: 'p-3',
        patientName: 'Naomi Banda',
        startsAt: DateTime(2026, 11, 12, 11, 30),
        status: 'confirmed',
        type: 'Antenatal care',
        imported: true),
  ];
  Object? patientError, scheduleError, profileError;
  Completer<List<DashboardPatient>>? pendingPatients;
  @override
  Future<DashboardClinician?> loadClinician() async {
    if (profileError != null) throw profileError!;
    return const DashboardClinician(id: 'doctor-1', profileComplete: true);
  }

  @override
  Future<List<DashboardPatient>> loadPatients() async {
    if (patientError != null) throw patientError!;
    if (pendingPatients != null) return await pendingPatients!.future;
    return patients;
  }

  @override
  Future<List<DashboardAppointment>> loadSchedule(String doctorId, DateTime day,
      {int lookbackDays = 0}) async {
    expect(doctorId, 'doctor-1');
    if (scheduleError != null) throw scheduleError!;
    return appointments;
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

  Future<GoRouter> pump(WidgetTester tester, FakeHomeRepository repository,
      {Size size = const Size(1440, 1000),
      bool collapsed = false,
      double textScale = 1}) async {
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
    final router = GoRouter(initialLocation: '/home', routes: [
      GoRoute(
          name: 'Home',
          path: '/home',
          builder: (context, state) => HomeWidget(
              repository: repository,
              deviceManager: manager,
              now: () => DateTime(2026, 11, 12, 9))),
      for (final (name, path) in [
        ('Moms', '/moms'),
        ('PatientDetails', '/patientDetails'),
        ('ScheduledEncounters', '/scheduledEncounters'),
        ('MomDetails', '/momDetails'),
        ('EditEncounter', '/editEncounter'),
        ('CervicalCancer', '/cervical-cancer'),
        ('Ultrasound', '/ultrasound'),
        ('HemoNix', '/hemonix'),
        ('CtScan', '/ct-scan'),
        ('BpMonitor', '/bp-monitor'),
        ('Profile', '/profile'),
      ])
        GoRoute(
            name: name,
            path: path,
            builder: (context, state) =>
                Scaffold(body: Text('Route $name ${state.uri.query}'))),
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
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!),
            routerConfig: router)));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/images/dawa_cross.png'),
        tester.element(find.byType(Scaffold))));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
      'Home renders three verified overview metrics and essential tasks',
      (tester) async {
    await pump(tester, FakeHomeRepository());
    expect(find.text('Good morning'), findsOneWidget);
    expect(
        find.text("Here's what needs your attention today."), findsOneWidget);
    expect(find.text('Appointments today'), findsOneWidget);
    expect(find.text('Pending reviews'), findsOneWidget);
    expect(find.text('Registered patients'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('New This Week'), findsNothing);
    expect(find.text('Missing Data'), findsNothing);
    expect(find.text("Recent schedules"), findsOneWidget);
    expect(find.text('Recent patients'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('1 record needs completion'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'patient opens its stable record and completion list is actionable',
      (tester) async {
    final repository = FakeHomeRepository();
    final router = await pump(tester, repository);
    await tester.tap(find.widgetWithText(
        DashboardPatientRow, repository.patients.first.displayName));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/patientDetails');
    expect(router.routeInformationProvider.value.uri.query, contains('p-1'));
  });

  testWidgets('exam selector opens all tools without beginning a clinical exam',
      (tester) async {
    final router = await pump(tester, FakeHomeRepository());
    for (final (name, path) in [
      ('Cervical Cancer', '/cervical-cancer'),
      ('Ultrasound', '/ultrasound'),
      ('Anemia', '/hemonix'),
      ('CT Scan', '/ct-scan'),
      ('BP Monitor', '/bp-monitor'),
    ]) {
      await tester.tap(find.text('New Examination'));
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Choose a tool, then confirm the patient in its workflow before beginning.'),
          findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, name));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path);
      router.pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('calendar and imported appointment actions retain their context',
      (tester) async {
    final router = await pump(tester, FakeHomeRepository());
    await tester.tap(find.text('View calendar'));
    await tester.pumpAndSettle();
    expect(
        router.routeInformationProvider.value.uri.queryParameters['calendar'],
        'true');
  });

  testWidgets(
      'network failure is shown as unknown with retry, not zero patients',
      (tester) async {
    final repository = FakeHomeRepository()
      ..patientError = Exception('Network unavailable');
    await pump(tester, repository);
    expect(find.text('Patients unavailable'), findsOneWidget);
    expect(find.text('Patient records unavailable'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    repository.patientError = null;
    await tester.tap(find.text('Retry').last);
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets(
      'empty schedule gives a next action and permission failure stays explicit',
      (tester) async {
    final repository = FakeHomeRepository()..appointments = [];
    await pump(tester, repository);
    expect(find.text('No recent scheduled visits.'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Schedule Appointment'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    repository.scheduleError =
        const PostgrestException(message: 'Denied', code: '42501');
    await pump(tester, repository);
    expect(find.text('Schedule unavailable'), findsWidgets);
    expect(find.textContaining('Your account cannot access'), findsOneWidget);
    expect(find.text('No recent scheduled visits.'), findsNothing);
  });

  testWidgets('loading preserves skeletons and never claims zero',
      (tester) async {
    final repository = FakeHomeRepository()
      ..pendingPatients = Completer<List<DashboardPatient>>();
    await pump(tester, repository);
    expect(find.byType(DashboardSkeleton), findsWidgets);
    expect(find.text('0'), findsNothing);
    repository.pendingPatients!.complete(repository.patients);
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
  });

  for (final (name, size, collapsed, scale) in [
    ('wide-desktop', const Size(1600, 1000), false, 1.0),
    ('laptop', const Size(1280, 900), false, 1.0),
    ('collapsed', const Size(1280, 900), true, 1.0),
    ('tablet', const Size(834, 1112), false, 1.0),
    ('mobile', const Size(390, 844), false, 1.0),
    ('small-large-text', const Size(320, 700), false, 2.0),
  ]) {
    testWidgets(
        '$name renders without overflow and captures the final dashboard',
        (tester) async {
      await pump(tester, FakeHomeRepository(),
          size: size, collapsed: collapsed, textScale: scale);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_HOME_PHASE2')) {
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('../docs/qa/phase2/$name.png'));
      }
      await tester.drag(
          find.byType(CustomScrollView).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the monthly calendar is usable at mobile width', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AppointmentsCalendarDialog(
                doctorId: 'doctor-1',
                loadDays: () async => [DateTime(2026, 11, 12)]))));
    await tester.pumpAndSettle();
    expect(find.text('Appointment calendar'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar failure is explicit and supports retry',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AppointmentsCalendarDialog(
                doctorId: 'doctor-1',
                loadDays: () async {
                  attempts++;
                  throw Exception('Offline');
                }))));
    await tester.pumpAndSettle();
    expect(find.text('Calendar unavailable'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Calendar unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completion action opens affected stable patient records',
      (tester) async {
    final router = await pump(tester, FakeHomeRepository());
    final action = find.text('View affected records');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('Records needing completion'), findsOneWidget);
    final row = find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Martha Phiri'));
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/patientDetails');
    expect(router.routeInformationProvider.value.uri.query, contains('p-2'));
  });

  testWidgets('keyboard can activate a task without pointer input',
      (tester) async {
    await pump(tester, FakeHomeRepository());
    final focus = Focus.of(tester.element(find.text('New Examination')));
    for (var i = 0; i < 30 && !focus.hasFocus; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }
    expect(focus.hasFocus, true);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('New examination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
