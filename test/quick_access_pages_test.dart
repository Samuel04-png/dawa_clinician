import 'package:clinician/application/cacx/cacx_widget.dart';
import 'package:clinician/backend/supabase/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initSupabase();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Cervical Cancer renders full desktop dashboard with sidebar',
      (tester) async {
    await _pumpQuickAccess(
      tester,
      const CaCxApp(),
      size: const Size(1200, 900),
    );

    expect(find.text('Cervical Cancer Dashboard'), findsOneWidget);
    expect(find.textContaining('Welcome, Clinician'), findsOneWidget);
    expect(find.text('Dawa CaCx'), findsOneWidget);
    expect(find.text('Add Screening Record'), findsOneWidget);
    expect(find.text('View Patient Records'), findsOneWidget);
    expect(find.text('View Screening Results'), findsOneWidget);
    expect(find.text('Find Patient'), findsOneWidget);
    expect(find.textContaining('Coming soon'), findsNothing);
  });

  testWidgets('Cervical Cancer renders mobile dashboard with navbar',
      (tester) async {
    await _pumpQuickAccess(
      tester,
      const CaCxApp(),
      size: const Size(390, 820),
    );

    expect(find.text('Cervical Cancer Dashboard'), findsOneWidget);
    expect(find.text('Dawa CaCx'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Patients'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.textContaining('Coming soon'), findsNothing);
  });

  for (final serviceCase in _serviceCases) {
    testWidgets('${serviceCase.title} renders a usable dashboard',
        (tester) async {
      await _pumpQuickAccess(
        tester,
        QuickAccessServiceApp(service: serviceCase.service),
        size: const Size(1180, 860),
      );

      expect(find.text('${serviceCase.title} Dashboard'), findsOneWidget);
      expect(find.textContaining('Welcome, Clinician'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('quick-access-sidebar')), findsOneWidget);
      for (final action in serviceCase.actions) {
        expect(find.text(action), findsAtLeastNWidgets(1));
      }
      expect(find.textContaining('Coming soon'), findsNothing);
    });

    testWidgets('${serviceCase.title} renders a mobile dashboard',
        (tester) async {
      await _pumpQuickAccess(
        tester,
        QuickAccessServiceApp(service: serviceCase.service),
        size: const Size(390, 820),
      );

      expect(find.text('${serviceCase.title} Dashboard'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Records'), findsOneWidget);
      expect(find.text('Results'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.textContaining('Coming soon'), findsNothing);
    });

    testWidgets('${serviceCase.title} renders results page', (tester) async {
      await _pumpQuickAccess(
        tester,
        QuickAccessServiceApp(service: serviceCase.service),
        size: const Size(1180, 860),
      );

      await tester.tap(find.text(serviceCase.resultsLabel).first);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(serviceCase.resultsLabel), findsWidgets);
      expect(find.text('All results'), findsWidgets);
      expect(find.text('Completed'), findsWidgets);
      expect(find.text('Needs review'), findsWidgets);
      expect(
        find.byKey(ValueKey('quick-access-results-search-${serviceCase.key}')),
        findsOneWidget,
      );
      expect(find.textContaining('Coming soon'), findsNothing);
    });
  }

  testWidgets('Quick Access results search matches patient and AI text',
      (tester) async {
    await _pumpQuickAccess(
      tester,
      const QuickAccessServiceApp(service: QuickAccessServiceType.hemonix),
      size: const Size(1180, 860),
    );

    await tester.tap(find.text('Hb Results').first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.byKey(const ValueKey('quick-access-results-search-hemonix')),
      'Grace',
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Grace Mwape'), findsOneWidget);
    expect(find.text('Beatrice Zulu'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('quick-access-results-search-hemonix')),
      'confidence 90',
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Grace Mwape'), findsOneWidget);
  });

  testWidgets('Quick Access needs review filter narrows results',
      (tester) async {
    await _pumpQuickAccess(
      tester,
      const QuickAccessServiceApp(service: QuickAccessServiceType.ultrasound),
      size: const Size(1180, 860),
    );

    await tester.tap(find.text('Scan Reports').first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(
      find.byKey(
        const ValueKey('quick-access-filter-ultrasound-needsReview'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sarah Mbewe'), findsOneWidget);
    expect(find.text('Lillian Chama'), findsNothing);
    expect(find.text('Nancy Kaira'), findsNothing);
  });

  testWidgets('Quick Access open patient navigates to the records tab',
      (tester) async {
    await _pumpQuickAccess(
      tester,
      const QuickAccessServiceApp(service: QuickAccessServiceType.hemonix),
      size: const Size(1180, 860),
    );

    final openPatient = find.text('Open patient').first;
    await tester.ensureVisible(openPatient);
    await tester.pumpAndSettle();
    await tester.tap(openPatient);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Ready to add hb record for '),
      findsOneWidget,
    );
    expect(find.text('Patient-linked hb record entries are ready for review.'),
        findsNothing);
  });

  testWidgets('Cervical Cancer results search and filter are usable',
      (tester) async {
    await _pumpQuickAccess(
      tester,
      const CaCxApp(),
      size: const Size(1200, 900),
    );

    await tester.tap(find.text('View Screening Results'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Screening Results'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('cacx-results-search-field')),
      'Chipo',
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Chipo Banda'), findsOneWidget);
    expect(find.text('Beatrice Zulu'), findsNothing);

    await tester.tap(find.text('Needs review').first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Chipo Banda'), findsOneWidget);
  });
}

Future<void> _pumpQuickAccess(
  WidgetTester tester,
  Widget child, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump(const Duration(milliseconds: 100));
}

class _ServiceCase {
  const _ServiceCase({
    required this.service,
    required this.key,
    required this.title,
    required this.resultsLabel,
    required this.actions,
  });

  final QuickAccessServiceType service;
  final String key;
  final String title;
  final String resultsLabel;
  final List<String> actions;
}

const _serviceCases = [
  _ServiceCase(
    service: QuickAccessServiceType.ultrasound,
    key: 'ultrasound',
    title: 'Ultrasound',
    resultsLabel: 'Scan Reports',
    actions: [
      'Add Scan Record',
      'AI-Guided Scan',
      'View Patient Records',
      'View Scan History',
    ],
  ),
  _ServiceCase(
    service: QuickAccessServiceType.hemonix,
    key: 'hemonix',
    title: 'HemoNix',
    resultsLabel: 'Hb Results',
    actions: [
      'Add Hb Record',
      'View Patient Records',
      'View Hb Results',
      'Search Results',
    ],
  ),
  _ServiceCase(
    service: QuickAccessServiceType.ctScan,
    key: 'ct-scan',
    title: 'CT Scan',
    resultsLabel: 'CT Results',
    actions: [
      'Add CT Record',
      'View Patient Records',
      'View CT Results',
      'Search Results',
    ],
  ),
  _ServiceCase(
    service: QuickAccessServiceType.cervicalCancer,
    key: 'cervical-cancer',
    title: 'Cervical Cancer',
    resultsLabel: 'Screening Results',
    actions: [
      'Add Screening Record',
      'View Patient Records',
      'View Screening Results',
      'Search Results',
    ],
  ),
];
