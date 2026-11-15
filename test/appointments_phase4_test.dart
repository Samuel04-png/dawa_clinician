import 'dart:async';
import 'package:intl/intl.dart';
import 'package:clinician/application/home/data/home_dashboard_repository.dart';
import 'package:clinician/application/home/home_widget.dart';
import 'package:clinician/application/home/widgets/home_dashboard_content.dart';
import 'package:clinician/application/moms/moms_widget.dart';
import 'package:clinician/application/scheduled_encounters/scheduled_encounters_widget.dart';
import 'package:clinician/components/clinician_navigation.dart';
import 'package:clinician/components/edge_device_indicator.dart';
import 'package:clinician/components/navigation_design_system.dart';
import 'package:clinician/components/small_side_nav/small_side_nav_widget.dart';
import 'package:clinician/features/appointments/data/appointment_workspace_repository.dart';
import 'package:clinician/features/appointments/domain/appointment_entry.dart';
import 'package:clinician/features/appointments/domain/clinician_appointment.dart';
import 'package:clinician/features/appointments/presentation/appointment_workspace_content.dart';
import 'package:clinician/flutter_flow/flutter_flow_calendar.dart';
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
import 'clinician_navigation_test.dart' show loadNavigationFonts;
import 'home_dashboard_phase2_test.dart' show FakeHomeRepository;

List<AppointmentEntry> appointmentFixtures() {
  AppointmentEntry visit(String id, String name, DateTime start, String state,
          {bool legacy = false,
          String source = 'dawa_mom',
          bool encounter = false}) =>
      AppointmentEntry(
          id: id,
          legacy: legacy,
          source: legacy ? 'clinician' : source,
          patientId: 'patient-$id',
          patientName: name,
          patientIdentifier: 'TEST-$id',
          status: state,
          startsAt: start,
          endTime: legacy
              ? ''
              : DateFormat('HH:mm')
                  .format(start.add(const Duration(minutes: 30))),
          type: 'Antenatal visit',
          version: '2026-11-01T07:00:00Z',
          encounterId: encounter ? 'encounter-$id' : null,
          encounterStatus: encounter ? state : null,
          performedBy: encounter ? 'doctor-1' : null,
          firstEncounterId: encounter ? 'first-$id' : null,
          integrationStatus: 'synced');
  return [
    visit('today', 'Chileshe Nalumino-Mwanza', DateTime(2026, 11, 12, 9),
        'confirmed',
        encounter: true),
    visit('legacy', 'Naomi Banda', DateTime(2026, 11, 12, 11), 'scheduled',
        legacy: true, encounter: true),
    visit('old-request', 'Martha Phiri', DateTime(2026, 10, 15, 15, 30),
        'pending'),
    visit('new-request', '', DateTime(2026, 11, 13, 9), 'pending'),
    visit('future', 'Alice Mwale', DateTime(2026, 11, 13, 9), 'confirmed'),
    visit('complete', 'Judith Zulu', DateTime(2026, 11, 10, 9), 'completed',
        encounter: true),
    visit('cancel', 'Mary Mbewe', DateTime(2026, 11, 9, 9), 'canceled',
        legacy: true),
    visit('decline', 'Grace Phiri', DateTime(2026, 11, 8, 9), 'declined'),
    visit('clinic-request', 'Jane Banda', DateTime(2026, 11, 12, 15), 'pending',
        source: 'clinician'),
  ];
}

class FakeAppointmentRepository extends AppointmentWorkspaceRepository {
  List<AppointmentEntry> entries = appointmentFixtures();
  Object? loadError, changeError;
  Completer<List<AppointmentEntry>>? pending;
  final changes = <(String, String, DateTime?, String?)>[];
  int loads = 0;
  @override
  Future<DashboardClinician?> loadClinician() async =>
      const DashboardClinician(id: 'doctor-1', profileComplete: true);
  @override
  Future<List<AppointmentEntry>> loadAppointments(String doctorId) async {
    expect(doctorId, 'doctor-1');
    loads++;
    if (loadError != null) throw loadError!;
    if (pending != null) return pending!.future;
    return entries;
  }

  @override
  Future<List<DashboardPatient>> loadSchedulingPatients() async =>
      const [DashboardPatient(id: 'patient-1', name: 'Registration fixture')];
  @override
  Stream<List<ClinicianNotification>> watchNotifications() => Stream.value([]);
  @override
  Future<void> changeAppointment(
      AppointmentEntry entry, String doctorId, String status,
      {DateTime? start, String? endTime}) async {
    changes.add((entry.id, status, start, endTime));
    if (changeError != null) throw changeError!;
    entries = entries
        .map((a) => a.key == entry.key
            ? AppointmentEntry(
                id: a.id,
                legacy: a.legacy,
                source: a.source,
                patientId: a.patientId,
                patientName: a.patientName,
                patientIdentifier: a.patientIdentifier,
                status: status,
                startsAt: start ?? a.startsAt,
                endTime: endTime ?? a.endTime,
                type: a.type,
                version: '2026-11-12T07:00:00Z')
            : a)
        .toList();
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
  Future<GoRouter> pump(WidgetTester tester, FakeAppointmentRepository repo,
      {Size size = const Size(1440, 1000),
      bool collapsed = false,
      double scale = 1,
      String location = '/scheduledEncounters'}) async {
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
    final home = FakeHomeRepository();
    final router = GoRouter(initialLocation: location, routes: [
      GoRoute(
          name: 'ScheduledEncounters',
          path: '/scheduledEncounters',
          builder: (context, state) => ScheduledEncountersWidget(
              repository: repo,
              deviceManager: manager,
              now: () => DateTime.utc(2026, 11, 12, 7),
              initialAppointmentId: state.uri.queryParameters['appointment'],
              openCalendar: state.uri.queryParameters['calendar'] == 'true')),
      GoRoute(
          name: 'Home',
          path: '/home',
          builder: (_, state) => HomeWidget(
              repository: home,
              deviceManager: manager,
              now: () => DateTime(2026, 11, 12, 9))),
      GoRoute(
          name: 'Moms',
          path: '/moms',
          builder: (_, state) =>
              MomsWidget(repository: home, deviceManager: manager)),
      for (final (name, path) in [
        ('PatientDetails', '/patientDetails'),
        ('MomDetails', '/momDetails'),
        ('EditEncounter', '/editEncounter'),
        ('EncounterDets', '/encounterDets'),
        ('Profile', '/profile')
      ])
        GoRoute(
            name: name,
            path: path,
            builder: (_, state) =>
                Scaffold(body: Text('Destination $name ${state.uri.query}'))),
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

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(ChoiceChip, label));
    await tester.pumpAndSettle();
  }

  Finder row(String key) => find.byKey(ValueKey(key));

  testWidgets(
      'all three pages share sidebar geometry and state without an extra AppBar',
      (tester) async {
    final router =
        await pump(tester, FakeAppointmentRepository(), location: '/home');
    final geometry = tester.getRect(find.byType(SmallSideNavWidget));
    clinicianScreeningsExpanded.value = false;
    for (final route in ['Moms', 'ScheduledEncounters']) {
      router.goNamed(route);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(SmallSideNavWidget)), geometry);
      expect(clinicianScreeningsExpanded.value, false);
    }
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(EdgeDeviceIndicator), findsOneWidget);
    expect(find.text('Schedule Appointment'), findsOneWidget);
    expect(
        tester
            .widgetList<NavigationItem>(find.byType(NavigationItem))
            .singleWhere((n) => n.label == 'Appointments')
            .selected,
        true);
    clinicianSidebarCollapsed.value = true;
    await tester.pumpAndSettle();
    final collapsed = tester.getRect(find.byType(SmallSideNavWidget));
    router.goNamed('Home');
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(SmallSideNavWidget)), collapsed);
  });

  testWidgets(
      'Today Upcoming Requests and History retain actual dates and statuses',
      (tester) async {
    await pump(tester, FakeAppointmentRepository());
    expect(find.text('Chileshe Nalumino-Mwanza'), findsOneWidget);
    expect(find.text('Alice Mwale'), findsNothing);
    await tab(tester, 'Upcoming');
    expect(find.text('Alice Mwale'), findsOneWidget);
    expect(find.text('Chileshe Nalumino-Mwanza'), findsNothing);
    await tab(tester, 'Requests');
    expect(find.text('Martha Phiri'), findsOneWidget);
    expect(find.text('Date passed'), findsOneWidget);
    expect(find.text('Name not recorded'), findsOneWidget);
    expect(find.text('Cancel appointment'), findsNothing);
    await tab(tester, 'History');
    expect(find.text('Judith Zulu'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Declined'), findsOneWidget);
    expect(find.text('Martha Phiri'), findsOneWidget);
  });

  testWidgets('source filter and patient search combine and clear correctly',
      (tester) async {
    await pump(tester, FakeAppointmentRepository());
    await tab(tester, 'Requests');
    await tester.tap(find.text('All sources'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dawa Mom').last);
    await tester.pumpAndSettle();
    expect(find.text('Jane Banda'), findsNothing);
    await tester.enterText(find.byType(TextField), 'TEST-old-request');
    await tester.pumpAndSettle();
    expect(find.text('Martha Phiri'), findsOneWidget);
    expect(find.text('Name not recorded'), findsNothing);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Name not recorded'), findsOneWidget);
  });

  testWidgets('Confirm requires a decision and uses the expected booking',
      (tester) async {
    final repo = FakeAppointmentRepository();
    await pump(tester, repo);
    await tab(tester, 'Requests');
    final button = find.descendant(
        of: row('booking/old-request'), matching: find.text('Confirm'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(repo.changes, isEmpty);
    expect(find.textContaining('This request is past-dated.'), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Confirm')));
    await tester.pumpAndSettle();
    expect(repo.changes.single.$1, 'old-request');
    expect(repo.changes.single.$2, 'confirmed');
    expect(find.text('Martha Phiri'), findsNothing);
  });

  testWidgets(
      'pending requests offer Decline and Reschedule while confirmed visits offer Cancel',
      (tester) async {
    final repo = FakeAppointmentRepository();
    await pump(tester, repo);
    await tab(tester, 'Requests');
    final popup = find.descendant(
        of: row('booking/old-request'),
        matching: find.byType(PopupMenuButton<String>));
    await tester.ensureVisible(popup);
    await tester.tap(popup);
    await tester.pumpAndSettle();
    expect(find.text('Decline'), findsOneWidget);
    expect(find.text('Reschedule'), findsOneWidget);
    expect(find.text('Cancel appointment'), findsNothing);
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Decline')));
    await tester.pumpAndSettle();
    expect(repo.changes.single.$2, 'declined');
    await tab(tester, 'Today');
    await tester.tap(find.descendant(
        of: row('booking/today'),
        matching: find.byType(PopupMenuButton<String>)));
    await tester.pumpAndSettle();
    expect(find.text('Cancel appointment'), findsOneWidget);
    expect(find.text('Decline'), findsNothing);
    expect(find.text('Mark complete'), findsNothing);
    await tester.tap(find.text('Cancel appointment'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel appointment?'), findsOneWidget);
    await tester.tap(find.text('Keep current appointment'));
    await tester.pumpAndSettle();
    expect(repo.changes.length, 1);
  });

  testWidgets(
      'Reschedule selects a future clinic time and calls the supported status workflow',
      (tester) async {
    final repo = FakeAppointmentRepository();
    await pump(tester, repo);
    await tab(tester, 'Requests');
    final popup = find.descendant(
        of: row('booking/old-request'),
        matching: find.byType(PopupMenuButton<String>));
    await tester.ensureVisible(popup);
    await tester.tap(popup);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reschedule'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find
        .descendant(
            of: find.byType(DatePickerDialog), matching: find.text('13'))
        .last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Reschedule appointment?'), findsOneWidget);
    expect(repo.changes, isEmpty);
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Reschedule')));
    await tester.pumpAndSettle();
    expect(repo.changes.single.$2, 'rescheduled');
    expect(repo.changes.single.$3, DateTime(2026, 11, 13, 15, 30));
    expect(repo.changes.single.$4, '16:00');
  });

  testWidgets(
      'Cancel confirms intent, reports errors safely and refreshes the booking',
      (tester) async {
    final repo = FakeAppointmentRepository()
      ..changeError = Exception('private backend detail');
    await pump(tester, repo);
    await tester.tap(find.descendant(
        of: row('booking/today'),
        matching: find.byType(PopupMenuButton<String>)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel appointment'));
    await tester.pumpAndSettle();
    expect(repo.changes, isEmpty);
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Cancel')));
    await tester.pumpAndSettle();
    expect(repo.changes.single.$2, 'cancelled');
    expect(repo.loads, 2);
    expect(find.textContaining('The update could not be confirmed.'),
        findsOneWidget);
    expect(find.textContaining('private backend detail'), findsNothing);
  });

  testWidgets(
      'Schedule Appointment opens the existing booking dialog with authorized patients',
      (tester) async {
    await pump(tester, FakeAppointmentRepository());
    await tester.tap(find.text('Schedule Appointment'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Date and time · Africa/Lusaka'), findsOneWidget);
    expect(find.text('Registration fixture'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('booking dialog remains usable on a small screen with large text',
      (tester) async {
    await pump(tester, FakeAppointmentRepository(),
        size: const Size(320, 700), scale: 2);
    await tester.tap(find.text('Schedule Appointment'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'stale and failed writes refresh before presenting the next action',
      (tester) async {
    final repo = FakeAppointmentRepository()
      ..changeError = const AppointmentChangedException();
    await pump(tester, repo);
    await tab(tester, 'Requests');
    final button = find.descendant(
        of: row('booking/old-request'), matching: find.text('Confirm'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Confirm')));
    await tester.pumpAndSettle();
    expect(repo.loads, 2);
    expect(find.textContaining('This appointment changed.'), findsOneWidget);
  });

  testWidgets(
      'Calendar uses the filtered backend dataset and opens the selected day details',
      (tester) async {
    await pump(tester, FakeAppointmentRepository());
    await tab(tester, 'Upcoming');
    await tab(tester, 'Calendar');
    final calendar =
        tester.widget<FlutterFlowCalendar>(find.byType(FlutterFlowCalendar));
    expect(calendar.markedDates, [DateTime(2026, 11, 13, 9)]);
    await tester.tap(find
        .descendant(
            of: find.byType(FlutterFlowCalendar), matching: find.text('13'))
        .last);
    await tester.pumpAndSettle();
    expect(find.text('Alice Mwale'), findsOneWidget);
    await tester.tap(find.text('Open appointment'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets(
      'deep links focus the authorized booking and completed encounter routes stay compatible',
      (tester) async {
    final router = await pump(tester, FakeAppointmentRepository(),
        location: '/scheduledEncounters?appointment=complete');
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('View encounter'), findsOneWidget);
    await tester.tap(find.text('View encounter'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/encounterDets');
    expect(router.routeInformationProvider.value.uri.query,
        contains('encounter-complete'));
  });

  testWidgets('calendar deep link renders the existing monthly calendar',
      (tester) async {
    await pump(tester, FakeAppointmentRepository(),
        location: '/scheduledEncounters?calendar=true');
    expect(find.byType(FlutterFlowCalendar), findsOneWidget);
  });

  testWidgets('loading errors retry and empty views stay distinct',
      (tester) async {
    final repo = FakeAppointmentRepository()
      ..loadError = Exception('sensitive backend detail');
    await pump(tester, repo);
    expect(find.text('Appointments unavailable'), findsOneWidget);
    expect(find.textContaining('sensitive backend detail'), findsNothing);
    repo.loadError = null;
    repo.entries = [];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No appointments today'), findsOneWidget);
    expect(repo.loads, 2);
  });

  testWidgets(
      'keyboard can open a scheduled appointment and notification control remains available',
      (tester) async {
    await pump(tester, FakeAppointmentRepository());
    final focus = Focus.of(tester.element(find.text('Open appointment').first));
    for (var i = 0; i < 50 && !focus.hasFocus; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }
    expect(focus.hasFocus, true);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('No appointment notifications yet.'), findsOneWidget);
  });

  testWidgets(
      'pending data keeps appointment counts unknown until records arrive',
      (tester) async {
    final pending = Completer<List<AppointmentEntry>>();
    final repo = FakeAppointmentRepository()..pending = pending;
    await pump(tester, repo);
    expect(find.byType(DashboardSkeleton), findsOneWidget);
    expect(find.text('0'), findsNothing);
    pending.complete(appointmentFixtures());
    await tester.pumpAndSettle();
    expect(find.text('Chileshe Nalumino-Mwanza'), findsOneWidget);
  });

  testWidgets(
      'restored patient registry visual reference uses the shared workspace',
      (tester) async {
    await pump(tester, FakeAppointmentRepository(),
        location: '/moms', size: const Size(1600, 1000));
    expect(find.text('Showing 3 of 3 patients'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_APPOINTMENTS_PHASE4'))
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('../docs/qa/phase4/patients-restored-fixture.png'));
  });

  for (final (name, size, collapsed, scale) in [
    ('today', const Size(1600, 1000), false, 1.0),
    ('laptop', const Size(1280, 900), false, 1.0),
    ('collapsed', const Size(1280, 900), true, 1.0),
    ('tablet', const Size(834, 1112), false, 1.0),
    ('mobile', const Size(390, 844), false, 1.0),
    ('large-text', const Size(320, 700), false, 2.0),
  ]) {
    testWidgets('$name has no overflow and one scheduling action',
        (tester) async {
      await pump(tester, FakeAppointmentRepository(),
          size: size, collapsed: collapsed, scale: scale);
      expect(tester.takeException(), isNull);
      expect(find.text('Schedule Appointment'), findsOneWidget);
      if (const bool.fromEnvironment('CAPTURE_APPOINTMENTS_PHASE4'))
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('../docs/qa/phase4/appointments-$name.png'));
      await tester.drag(
          find.byType(CustomScrollView).first, const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  for (final tabName in ['Upcoming', 'Requests', 'History']) {
    testWidgets('$tabName visual review', (tester) async {
      await pump(tester, FakeAppointmentRepository(),
          size: const Size(1600, 1000));
      await tab(tester, tabName);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_APPOINTMENTS_PHASE4'))
        await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
                '../docs/qa/phase4/appointments-${tabName.toLowerCase()}.png'));
    });
  }
}
