import 'dart:async';
import 'package:clinician/components/appbar_nav/appbar_nav_widget.dart';
import 'package:clinician/features/appointments/data/clinician_appointment_repository.dart';
import 'package:clinician/features/appointments/domain/clinician_appointment.dart';
import 'package:clinician/features/appointments/presentation/dawa_mom_appointment_requests.dart';
import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'clinician_navigation_test.dart' show loadNavigationFonts;

class _Notifications extends ClinicianAppointmentRepository {
  final changes = StreamController<List<ClinicianNotification>>.broadcast();
  List<ClinicianNotification> rows = List.generate(
      3,
      (i) => ClinicianNotification(
          id: 'notice-$i',
          appointmentId: 'visit-$i',
          type: 'appointment',
          title: 'Appointment update ${i + 1}',
          body: 'QA patient visit has been updated.',
          isRead: i == 2,
          createdAt: DateTime.now().subtract(Duration(minutes: i + 2))));
  bool fail = false;
  final marked = <String>[];
  Completer<void>? pendingRead;
  @override
  Stream<List<ClinicianNotification>> watchNotifications() async* {
    if (fail) throw StateError('Private notification server trace');
    yield rows;
    yield* changes.stream;
  }

  @override
  Future<void> markNotificationRead(String id) async {
    marked.add(id);
    if (pendingRead != null) await pendingRead!.future;
    rows = rows
        .map((row) => ClinicianNotification(
            id: row.id,
            appointmentId: row.appointmentId,
            type: row.type,
            title: row.title,
            body: row.body,
            isRead: row.id == id || row.isRead,
            createdAt: row.createdAt))
        .toList();
    changes.add(rows);
  }
}

void main() {
  setUpAll(() async {
    await loadNavigationFonts();
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final weight in [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700
    ]) {
      GoogleFonts.dmSans(fontWeight: weight);
    }
    await GoogleFonts.pendingFonts();
  });

  Future<void> pump(WidgetTester tester, _Notifications repository,
      {Size size = const Size(1440, 1000), double scale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final manager = EdgeDeviceManager(
        client: EdgeDeviceClient(
            config: const EdgeDeviceConfig(baseUrl: 'http://dawa.local'),
            httpClient: MockClient((_) async => http.Response(
                '{"active":null,"state":"stopped","ready":false}', 200))));
    final router = GoRouter(initialLocation: '/cervical-cancer', routes: [
      GoRoute(
          path: '/cervical-cancer',
          builder: (_, __) => Scaffold(
                  body: Column(children: [
                AppbarNavWidget(
                    deviceManager: manager,
                    notifications:
                        DawaMomNotificationButton(repository: repository)),
                const Expanded(
                    child: Center(child: Text('Clinical workspace fixture'))),
              ]))),
      GoRoute(
          name: 'ScheduledEncounters',
          path: '/appointments',
          builder: (_, state) => Scaffold(
              body: Text(
                  'Appointment ${state.uri.queryParameters['appointment'] ?? 'list'}'))),
    ]);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await repository.changes.close();
      manager.dispose();
      router.dispose();
    });
    await tester.pumpWidget(MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            fontFamily: 'NavigationQA',
            colorSchemeSeed: const Color(0xFF223F91)),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!)));
    await tester.pumpAndSettle();
  }

  for (final viewport in ['desktop', 'laptop', 'mobile', 'large-text']) {
    testWidgets('global notifications panel is usable at $viewport',
        (tester) async {
      final size = switch (viewport) {
        'laptop' => const Size(1024, 900),
        'mobile' => const Size(390, 844),
        'large-text' => const Size(390, 1000),
        _ => const Size(1440, 1000),
      };
      await pump(tester, _Notifications(),
          size: size, scale: viewport == 'large-text' ? 2 : 1);
      expect(find.text('2'), findsOneWidget);
      final bellFocus = tester.widget<IconButton>(find
          .ancestor(
              of: find.byTooltip('Notifications'),
              matching: find.byType(IconButton))
          .first);
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Appointment update 1'), findsOneWidget);
      expect(find.text('2m ago'), findsOneWidget);
      final panel = tester.getRect(find
          .ancestor(
              of: find.text('Notifications'), matching: find.byType(Material))
          .first);
      expect(panel.right, size.width);
      expect(panel.width, lessThanOrEqualTo(420));
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_RELIABILITY_QA')) {
        await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
                '../docs/qa/reliability/notifications-$viewport.png'));
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Appointment update 1'), findsNothing);
      expect(bellFocus.focusNode!.hasFocus, isTrue);
    });
  }

  testWidgets(
      'notifications open the linked appointment while read persistence is pending',
      (tester) async {
    final repository = _Notifications()..pendingRead = Completer<void>();
    await pump(tester, repository);
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notification-notice-0')));
    await tester.pumpAndSettle();
    expect(find.text('Appointment visit-0'), findsOneWidget);
    expect(repository.marked, ['notice-0']);
    repository.pendingRead!.complete();
    await tester.pumpAndSettle();
    expect(repository.rows.where((row) => !row.isRead).length, 1);
  });

  testWidgets(
      'notifications error offers retry and never exposes raw exceptions',
      (tester) async {
    final repository = _Notifications()..fail = true;
    await pump(tester, repository);
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications unavailable'), findsOneWidget);
    expect(
        find.textContaining('Private notification server trace'), findsNothing);
    repository.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Appointment update 1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });
}
