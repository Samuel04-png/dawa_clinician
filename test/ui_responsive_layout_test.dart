import 'package:clinician/application/cacx/cacx_widget.dart';
import 'package:clinician/application/care_tools/care_tools_widget.dart';
import 'package:clinician/application/ct_scan/ct_scan_module.dart';
import 'package:clinician/application/hemonix/hemonix_module.dart';
import 'package:clinician/application/ultrasound/ultrasound.dart';
import 'package:clinician/app_state.dart';
import 'package:clinician/backend/supabase/supabase_config.dart';
import 'package:clinician/flutter_flow/flutter_flow_theme.dart';
import 'package:clinician/flutter_flow/nav/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await FlutterFlowTheme.initialize();
    await initSupabase();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FFAppState.reset();
  });

  testWidgets('Care Tools lays out at desktop, tablet, and narrow widths',
      (tester) async {
    for (final size in _responsiveSizes) {
      await _pumpCareTools(tester, size);

      expect(find.text('Care Tools'), findsWidgets);
      expect(find.text('Open CaCx Screening'), findsOneWidget);
      expect(find.text('Open HemoNix'), findsOneWidget);
      expect(find.text('Open CT Scan'), findsOneWidget);
      expect(find.text('Open Ultrasound'), findsOneWidget);
    }
  });

  testWidgets('CaCx and quick access modules do not overflow at tablet width',
      (tester) async {
    await _pumpPlain(tester, const CaCxApp(), const Size(820, 900));
    expect(find.text('Cervical Cancer Dashboard'), findsOneWidget);

    await _pumpPlain(
      tester,
      const HemonixApp(),
      const Size(820, 900),
    );
    expect(find.text('HemoNix Dashboard'), findsOneWidget);

    await _pumpPlain(
      tester,
      const CtScanApp(),
      const Size(820, 900),
    );
    expect(find.text('CT Scan Dashboard'), findsOneWidget);

    await _pumpPlain(
      tester,
      const UltrasoundApp(),
      const Size(820, 900),
    );
    expect(find.text('Ultrasound Dashboard'), findsOneWidget);
  });
}

const _responsiveSizes = [
  Size(1200, 900),
  Size(820, 900),
  Size(390, 820),
];

Future<void> _pumpCareTools(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final router = GoRouter(
    initialLocation: CareToolsWidget.routePath,
    routes: [
      GoRoute(
        name: CareToolsWidget.routeName,
        path: CareToolsWidget.routePath,
        builder: (context, state) => const CareToolsWidget(),
      ),
    ],
  );

  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => FFAppState(),
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pumpPlain(WidgetTester tester, Widget child, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump(const Duration(milliseconds: 100));
}
