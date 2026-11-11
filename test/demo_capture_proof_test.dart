import 'package:clinician/application/cacx/cacx_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:54321',
      anonKey: 'local-anon-key-for-demo-capture',
    );
  });

  testWidgets('captures clinician patient registry desktop training fixture',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: CaCxApp(demonstrationMode: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('View Patient Records'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Patient Registry'), findsAtLeastNWidgets(1));
    expect(find.text('Alice Mumba'), findsOneWidget);
    expect(find.text('Chipo Banda'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CaCxApp),
      matchesGoldenFile(
        '../demo_assets/raw/dawa_clinician/patients/patient_registry_training_fixture.png',
      ),
    );
  });
}
