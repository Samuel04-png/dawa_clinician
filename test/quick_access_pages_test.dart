import 'package:clinician/application/cacx/cacx_widget.dart';
import 'package:clinician/application/ct_scan/ct_scan_module.dart';
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

  testWidgets('Cervical Cancer renders full desktop dashboard', (tester) async {
    await _pumpQuickAccess(
      tester,
      const CaCxApp(demonstrationMode: true),
      size: const Size(1200, 900),
    );

    expect(find.text('New Screening'), findsOneWidget);
    expect(find.text('Patient Records'), findsWidgets);
    expect(find.text('Screening History'), findsWidgets);
    expect(find.text('Available patients'), findsOneWidget);
    expect(find.textContaining('Coming soon'), findsNothing);
  });

  testWidgets('Cervical Cancer renders mobile dashboard', (tester) async {
    await _pumpQuickAccess(
      tester,
      const CaCxApp(demonstrationMode: true),
      size: const Size(390, 820),
    );

    expect(find.text('New Screening'), findsOneWidget);
    expect(find.text('Patient Records'), findsWidgets);
    expect(find.text('Screening History'), findsWidgets);
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

      expect(find.text(moduleCase.primaryAction), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
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

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Records'), findsOneWidget);
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

  testWidgets('Cervical Cancer results search and filter are usable',
      (tester) async {
    await _pumpQuickAccess(
      tester,
      const CaCxApp(demonstrationMode: true),
      size: const Size(1200, 900),
    );

    await tester.tap(find.text('Screening History').first);
    await tester.pump(const Duration(milliseconds: 200));
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
    required this.primaryAction,
    required this.actions,
  });

  final Widget widget;
  final String key;
  final String title;
  final String resultsLabel;
  final String primaryAction;
  final List<String> actions;
}

const _moduleCases = [
  _ModuleCase(
    widget: CtScanApp(),
    key: 'ct-scan',
    title: 'CT Scan',
    resultsLabel: 'CT Results',
    primaryAction: 'View sample records',
    actions: [
      'Records',
      'CT Results',
      'Search',
    ],
  ),
];
