import 'package:clinician/application/cacx/cacx_widget.dart';
import 'package:clinician/application/ct_scan/ct_scan_module.dart';
import 'package:clinician/application/hemonix/hemonix_module.dart';
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

  for (final moduleCase in _moduleCases) {
    testWidgets('${moduleCase.title} renders a usable dashboard',
        (tester) async {
      await _pumpQuickAccess(
        tester,
        moduleCase.widget,
        size: const Size(1180, 860),
      );

      expect(find.text('${moduleCase.title} Dashboard'), findsOneWidget);
      expect(find.textContaining('Welcome, Clinician'), findsOneWidget);
      expect(find.byKey(ValueKey('${moduleCase.key}-sidebar')), findsOneWidget);
      for (final action in moduleCase.actions) {
        expect(find.text(action), findsAtLeastNWidgets(1));
      }
      expect(find.textContaining('Coming soon'), findsNothing);
    });

    testWidgets('${moduleCase.title} renders a mobile dashboard',
        (tester) async {
      await _pumpQuickAccess(
        tester,
        moduleCase.widget,
        size: const Size(390, 820),
      );

      expect(find.text('${moduleCase.title} Dashboard'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Records'), findsOneWidget);
      expect(find.text('Results'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.textContaining('Coming soon'), findsNothing);
    });

    testWidgets('${moduleCase.title} renders results page', (tester) async {
      await _pumpQuickAccess(
        tester,
        moduleCase.widget,
        size: const Size(1180, 860),
      );

      await tester.tap(find.text(moduleCase.resultsLabel).first);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(moduleCase.resultsLabel), findsWidgets);
      expect(find.text('All results'), findsWidgets);
      expect(find.text('Completed'), findsWidgets);
      expect(find.text('Needs review'), findsWidgets);
      expect(
        find.byKey(ValueKey('${moduleCase.key}-results-search')),
        findsOneWidget,
      );
      expect(find.textContaining('Coming soon'), findsNothing);
    });
  }

  testWidgets('HemoNix results search matches patient and AI text',
      (tester) async {
    await _pumpQuickAccess(
      tester,
      const HemonixApp(),
      size: const Size(1180, 860),
    );

    await tester.tap(find.text('Hb Results').first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.byKey(const ValueKey('hemonix-results-search')),
      'Grace',
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Grace Mwape'), findsOneWidget);
    expect(find.text('Beatrice Zulu'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('hemonix-results-search')),
      'confidence 90',
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Grace Mwape'), findsOneWidget);
  });

  testWidgets('HemoNix needs review filter narrows results', (tester) async {
    await _pumpQuickAccess(
      tester,
      const HemonixApp(),
      size: const Size(1180, 860),
    );

    await tester.tap(find.text('Hb Results').first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(
      find.byKey(
        const ValueKey('hemonix-filter-needsReview'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Grace Mwape'), findsOneWidget);
    expect(find.text('Beatrice Zulu'), findsNothing);
    expect(find.text('Mary Soko'), findsNothing);
  });

  testWidgets('HemoNix open patient navigates to the records tab',
      (tester) async {
    await _pumpQuickAccess(
      tester,
      const HemonixApp(),
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

class _ModuleCase {
  const _ModuleCase({
    required this.widget,
    required this.key,
    required this.title,
    required this.resultsLabel,
    required this.actions,
  });

  final Widget widget;
  final String key;
  final String title;
  final String resultsLabel;
  final List<String> actions;
}

const _moduleCases = [
  _ModuleCase(
    widget: HemonixApp(),
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
  _ModuleCase(
    widget: CtScanApp(),
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
];
