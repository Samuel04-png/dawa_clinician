import 'package:clinician/application/cacx/cacx_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_manager.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'clinician_navigation_test.dart' show loadNavigationFonts;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final channel in [
      'com.llfbandit.app_links/events',
      'com.llfbandit.app_links/messages'
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
    SharedPreferences.setMockInitialValues({});
    await loadNavigationFonts();
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final weight in [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800
    ]) {
      GoogleFonts.dmSans(fontWeight: weight);
    }
    await GoogleFonts.pendingFonts();
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

    final manager = EdgeDeviceManager(
        client: EdgeDeviceClient(
            config: const EdgeDeviceConfig(baseUrl: 'http://dawa.local'),
            httpClient: MockClient((_) async => http.Response(
                '{"active":"cervitriage","state":"ready","ready":true}',
                200))));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      manager.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            fontFamily: 'NavigationQA',
            colorScheme: const ColorScheme.light(
                primary: Color(0xFF223F91),
                secondary: Color(0xFF5B73B7),
                surface: Colors.white)),
        home: CaCxApp(demonstrationMode: true, deviceManager: manager),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Patient Records').first);
    await tester.pumpAndSettle();

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
