import 'package:clinician/app_state.dart';
import 'package:clinician/backend/supabase/supabase_config.dart';
import 'package:clinician/application/bp_monitor/bp_monitor_widget.dart';
import 'package:clinician/application/cacx/cacx_widget.dart';
import 'package:clinician/application/ct_scan/ct_scan_module.dart';
import 'package:clinician/application/hemonix/models/anemia_result.dart';
import 'package:clinician/application/hemonix/repository/anemia_repository.dart';
import 'package:clinician/application/hemonix/screens/hemonix_app.dart';
import 'package:clinician/application/ultrasound/models/ultrasound_models.dart';
import 'package:clinician/application/ultrasound/repositories/ultrasound_repository.dart';
import 'package:clinician/application/ultrasound/screens/ultrasound_app.dart';
import 'package:clinician/components/clinical_navigation_shell.dart';
import 'package:clinician/components/clinical_tab_bar.dart';
import 'package:clinician/components/navigation_design_system.dart';
import 'package:clinician/components/clinician_navigation.dart';
import 'package:clinician/components/small_side_nav/small_side_nav_widget.dart';
import 'package:clinician/services/screening_patient_repository.dart';
import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'clinician_navigation_test.dart' show loadNavigationFonts;

class _UltrasoundRepository implements UltrasoundRepository {
  @override
  Future<List<PregnantPatient>> loadPatients() async => [];
  @override
  Future<List<UltrasoundScanRecord>> loadScanRecords() async => [];
  @override
  Future<UltrasoundScanRecord> saveScanRecord(
          {required PregnantPatient patient,
          required UltrasoundAnalysisResult analysis,
          required ScanType scanType}) =>
      throw StateError('Visual review does not save clinical records.');
}

class _CervicalPatients implements ScreeningPatientRepository {
  bool fail = false;
  List<ScreeningPatient> patients = [];
  @override
  Future<List<ScreeningPatient>> loadPatients() async {
    if (fail) throw StateError('Private database error');
    return patients;
  }
}

class _SavedUltrasoundRepository extends _UltrasoundRepository {
  bool fail = false;
  int reads = 0, saves = 0;
  final image =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
  @override
  Future<List<PregnantPatient>> loadPatients() async => [
        PregnantPatient(
            id: 'qa-patient',
            name: 'QA Amina Banda',
            age: 28,
            contact: '',
            scanStatus: ScanStatus.recorded,
            riskLevel: RiskLevel.unknown,
            pregnancyStatus: PregnancyStatus.unknown),
        PregnantPatient(
            id: 'qa-other',
            name: 'QA Chipo Banda',
            age: 31,
            contact: '',
            scanStatus: ScanStatus.recorded,
            riskLevel: RiskLevel.unknown,
            pregnancyStatus: PregnancyStatus.unknown),
      ];
  @override
  Future<List<UltrasoundScanRecord>> loadScanRecords() async {
    reads++;
    if (fail) throw StateError('Private ultrasound database trace');
    return [
      UltrasoundScanRecord(
          id: 'qa-older-scan',
          patientId: 'qa-other',
          patientName: 'QA Chipo Banda',
          date: DateTime(2026, 11, 10, 8, 30),
          scanType: ScanType.manual,
          result: 'Previous saved assessment',
          notes: '',
          imageUri: 'data:image/png;base64,invalid~'),
      UltrasoundScanRecord(
          id: 'qa-latest-scan',
          patientId: 'qa-patient',
          patientName: 'QA Amina Banda',
          date: DateTime(2026, 11, 13, 9, 45),
          scanType: ScanType.aiGuided,
          result: 'Abdominal circumference measurement',
          notes: 'QA saved examination notes.',
          aiAnalysis: 'QA saved analysis description.',
          imageUri: image,
          examinationId: 'qa-examination-123456789',
          modelId: 'qa-ultrasound-model',
          modelVersion: 'qa-version',
          analysisProvider: UltrasoundAnalysisProvider.edgeDevice,
          gestationalAgeWeeks: 24,
          measurements: {'QA saved measurement': '18.5 mm'},
          findings: [
            const UltrasoundFinding(
                category: 'QA finding category',
                finding: 'QA saved finding',
                level: FindingLevel.monitor,
                note: 'QA saved finding note.')
          ],
          segmentation: const UltrasoundSegmentation(
              found: true,
              imageWidth: 256,
              imageHeight: 256,
              circumferencePx: 254.8,
              areaPx: 5100)),
    ];
  }

  @override
  Future<UltrasoundScanRecord> saveScanRecord(
      {required PregnantPatient patient,
      required UltrasoundAnalysisResult analysis,
      required ScanType scanType}) {
    saves++;
    throw StateError('Opening a saved examination must not save or analyse.');
  }
}

class _AnemiaRepository implements AnemiaRepository {
  @override
  Future<List<ScreeningPatient>> loadPatients() async => [];
  @override
  Future<List<AnemiaScreeningRecord>> loadRecords() async => [];
  @override
  Future<AnemiaScreeningRecord?> loadRecord(String id) async => null;
  @override
  Future<AnemiaScreeningRecord> saveReviewed(
          {required ScreeningPatient patient,
          required AnemiaResult result,
          required String notes,
          required bool reviewConfirmed}) =>
      throw StateError('Visual review does not save clinical records.');
}

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.llfbandit.app_links/events'),
            (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.llfbandit.app_links/messages'),
            (_) async => null);
    SharedPreferences.setMockInitialValues({});
    await initSupabase();
    await FFAppState().initializePersistedState();
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
  });

  Future<void> pump(WidgetTester tester, String module,
      {Size size = const Size(1440, 1000),
      double scale = 1,
      bool collapsed = false,
      ScreeningPatientRepository? cervicalPatients,
      UltrasoundRepository? ultrasoundRepository,
      void Function(String path)? onDeviceRequest}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    clinicianSidebarCollapsed.value = collapsed;
    clinicianScreeningsExpanded.value = true;
    final active = switch (module) {
      'cacx' => 'cervitriage',
      'ultrasound' => 'ultrasound',
      _ => 'anemia'
    };
    final manager = EdgeDeviceManager(
        client: EdgeDeviceClient(
            config: const EdgeDeviceConfig(baseUrl: 'http://dawa.local'),
            httpClient: MockClient((request) async {
              onDeviceRequest?.call(request.url.path);
              return http.Response(
                  '{"active":"$active","state":"ready","ready":true,"modules":{"cervitriage":{},"ultrasound":{},"anemia":{}}}',
                  200);
            })));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      manager.dispose();
    });
    final child = switch (module) {
      'cacx' => CaCxApp(
          demonstrationMode: cervicalPatients == null,
          patientRepository: cervicalPatients,
          deviceManager: manager),
      'ultrasound' => UltrasoundApp(
          repository: ultrasoundRepository ?? _UltrasoundRepository(),
          edgeDeviceManager: manager),
      'anemia' =>
        HemonixApp(repository: _AnemiaRepository(), deviceManager: manager),
      'ct' => const CtScanApp(),
      _ => BpMonitorApp(now: () => DateTime(2026, 11, 14, 8, 30)),
    };
    final path = switch (module) {
      'cacx' => '/cervical-cancer',
      'anemia' => '/hemonix',
      'ct' => '/ct-scan',
      'bp' => '/bp-monitor',
      _ => '/ultrasound'
    };
    final router = GoRouter(initialLocation: path, routes: [
      GoRoute(
          name: 'Moms',
          path: '/moms',
          builder: (_, __) =>
              const Scaffold(body: Text('Patient registry destination'))),
      GoRoute(
          path: path,
          builder: (context, state) =>
              ClinicalNavigationShell(deviceManager: manager, child: child)),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: FFAppState(),
        child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                fontFamily: 'NavigationQA',
                colorScheme: const ColorScheme.light(
                    primary: Color(0xFF223F91),
                    secondary: Color(0xFF5B73B7),
                    surface: Colors.white)),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!))));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/images/dawa_cross.png'),
        tester.element(find.byType(ClinicalNavigationShell))));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  for (final module in ['cacx', 'ultrasound', 'anemia', 'ct', 'bp']) {
    for (final viewport in [
      'desktop',
      'laptop',
      'collapsed',
      'mobile',
      'large-text'
    ]) {
      testWidgets('$module $viewport clinical workspace has no layout errors',
          (tester) async {
        await pump(tester, module,
            size: viewport == 'laptop'
                ? const Size(1024, 900)
                : viewport == 'mobile'
                    ? const Size(390, 844)
                    : viewport == 'large-text'
                        ? const Size(320, 900)
                        : const Size(1440, 1000),
            scale: viewport == 'large-text' ? 2 : 1,
            collapsed: viewport == 'collapsed');
        expect(tester.takeException(), isNull);
        if (viewport == 'desktop' ||
            viewport == 'laptop' ||
            viewport == 'collapsed') {
          expect(tester.getTopLeft(find.byType(SmallSideNavWidget)).dy, 0);
          expect(
              tester.getSize(find.byType(SmallSideNavWidget)).width,
              viewport == 'collapsed'
                  ? NavigationTokens.collapsedWidth
                  : NavigationTokens.expandedWidth);
        } else {
          expect(find.byTooltip('Open navigation'), findsOneWidget);
        }
        if (const bool.fromEnvironment('CAPTURE_CLINICAL_PHASE5')) {
          await expectLater(find.byType(MaterialApp),
              matchesGoldenFile('../docs/qa/phase5/$module-$viewport.png'));
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }

  for (final viewport in <(String, Size)>[
    ('1440', const Size(1440, 1000)),
    ('1024', const Size(1024, 900)),
  ]) {
    testWidgets('cacx foundations pilot captures ${viewport.$1}px',
        (tester) async {
      await pump(tester, 'cacx', size: viewport.$2);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_CACX_FOUNDATIONS')) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
              '../docs/qa/foundations/cacx-overview-${viewport.$1}.png'),
        );
      }
    });
  }

  testWidgets('cacx overview displays patients and searches existing records',
      (tester) async {
    await pump(tester, 'cacx');
    expect(find.text('Alice Mumba'), findsOneWidget);
    expect(find.text('Showing 5 of 20 matching patients'), findsOneWidget);
    final search = find.byKey(const ValueKey('cacx-overview-patient-search'));
    await tester.enterText(search, 'Chipo');
    await tester.pumpAndSettle();
    expect(find.text('Alice Mumba'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Screen'), findsOneWidget);
    await tester.tap(find.text('View all (20)'));
    await tester.pumpAndSettle();
    expect(find.text('Patient Registry'), findsOneWidget);
    expect(find.text('Chipo Banda'), findsOneWidget);
  });

  testWidgets('cacx overview starts screening with the chosen patient',
      (tester) async {
    await pump(tester, 'cacx');
    await tester.tap(find.widgetWithText(TextButton, 'Screen').first);
    await tester.pumpAndSettle();
    expect(find.text('1. Select patient'), findsOneWidget);
    expect(find.text('Alice Mumba'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cacx recent result opens the matching saved record',
      (tester) async {
    await pump(tester, 'cacx');
    await tester.tap(find.text('View result').first);
    await tester.pumpAndSettle();
    expect(find.text('Screening Results'), findsOneWidget);
    final search = tester.widget<TextField>(
        find.byKey(const ValueKey('cacx-results-search-field')));
    expect(search.controller!.text, isNotEmpty);
    expect(find.text('Beatrice Zulu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cacx review count opens the existing review filter',
      (tester) async {
    await pump(tester, 'cacx');
    await tester.tap(find.text('Needs review'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Needs review'))
            .selected,
        isTrue);
    expect(find.text('Chipo Banda'), findsOneWidget);
  });

  testWidgets('cacx overview gives empty patients a registration destination',
      (tester) async {
    await pump(tester, 'cacx', cervicalPatients: _CervicalPatients());
    expect(find.text('No patients available'), findsOneWidget);
    expect(find.text('No screening activity yet'), findsNothing);
    expect(find.text('No saved screenings yet'), findsNothing);
    await tester.tap(find.text('Open Patients'));
    await tester.pumpAndSettle();
    expect(find.text('Patient registry destination'), findsOneWidget);
  });

  testWidgets(
      'cacx patient loading failure retries without exposing raw errors',
      (tester) async {
    final patients = _CervicalPatients()..fail = true;
    await pump(tester, 'cacx', cervicalPatients: patients);
    expect(find.text('Patient records unavailable'), findsOneWidget);
    expect(find.textContaining('Private database error'), findsNothing);
    patients.fail = false;
    patients.patients = [
      const ScreeningPatient(id: 'qa-patient', name: 'QA patient')
    ];
    await tester.tap(find.text('Retry records'));
    await tester.pumpAndSettle();
    expect(find.text('QA patient'), findsOneWidget);
    expect(find.text('Patient records unavailable'), findsNothing);
    final search = find.byKey(const ValueKey('cacx-overview-patient-search'));
    await tester.enterText(search, 'unmatched');
    await tester.pumpAndSettle();
    expect(find.text('No matching patients'), findsOneWidget);
    await tester.tap(find.text('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('QA patient'), findsOneWidget);
  });

  for (final viewport in [
    'desktop',
    'laptop',
    'collapsed',
    'mobile',
    'large-text'
  ]) {
    testWidgets('ultrasound saved scan opens from the overview at $viewport',
        (tester) async {
      final repository = _SavedUltrasoundRepository();
      final requests = <String>[];
      final size = switch (viewport) {
        'laptop' => const Size(1024, 900),
        'mobile' => const Size(390, 844),
        'large-text' => const Size(390, 1000),
        _ => const Size(1440, 1000),
      };
      await pump(tester, 'ultrasound',
          size: size,
          collapsed: viewport == 'collapsed',
          scale: viewport == 'large-text' ? 2 : 1,
          ultrasoundRepository: repository,
          onDeviceRequest: requests.add);
      expect(tester.getTopLeft(find.text('QA Amina Banda')).dy,
          lessThan(tester.getTopLeft(find.text('QA Chipo Banda')).dy));
      if (const bool.fromEnvironment('CAPTURE_ULTRASOUND_REVIEW')) {
        await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
                '../docs/qa/ultrasound-review/overview-$viewport.png'));
      }
      await tester.ensureVisible(find.text('QA Amina Banda'));
      final reads = repository.reads;
      final deviceCalls = requests.length;
      await tester.tap(find.text('QA Amina Banda'));
      await tester.pumpAndSettle();
      expect(find.text('Saved ultrasound examination'), findsOneWidget);
      expect(find.text('QA saved examination notes.'), findsOneWidget);
      expect(find.text('QA saved analysis description.'), findsOneWidget);
      expect(find.text('QA saved finding'), findsOneWidget);
      expect(find.text('18.5 mm'), findsOneWidget);
      expect(find.text('254.8 px'), findsOneWidget);
      expect(find.textContaining('Pixel spacing is not calibrated.'),
          findsOneWidget);
      expect(find.text('AI estimate — clinician must review'), findsOneWidget);
      expect(repository.reads, reads);
      expect(repository.saves, 0);
      expect(requests.length, deviceCalls);
      expect(
          find.byType(Dialog),
          ['desktop', 'laptop', 'collapsed'].contains(viewport)
              ? findsOneWidget
              : findsNothing);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_ULTRASOUND_REVIEW')) {
        await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
                '../docs/qa/ultrasound-review/saved-scan-$viewport.png'));
      }
      if (viewport == 'desktop') {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      } else {
        await tester.tap(find.byTooltip('Close scan details'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Saved ultrasound examination'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'ultrasound history and patient records open the same saved detail',
      (tester) async {
    final repository = _SavedUltrasoundRepository();
    await pump(tester, 'ultrasound', ultrasoundRepository: repository);
    await tester.tap(find.descendant(
        of: find.byType(ClinicalTabBar), matching: find.text('Scan History')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('QA Amina Banda'));
    await tester.pumpAndSettle();
    expect(find.text('QA saved examination notes.'), findsOneWidget);
    await tester.tap(find.byTooltip('Close scan details'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(ClinicalTabBar),
        matching: find.text('Patient Records')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('QA Amina Banda'));
    await tester.pumpAndSettle();
    expect(find.text('Ultrasound examinations'), findsOneWidget);
    await tester.tap(find.text('View Scan'));
    await tester.pumpAndSettle();
    expect(find.text('QA saved examination notes.'), findsOneWidget);
    expect(repository.saves, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ultrasound saved detail handles absent notes and corrupt images',
      (tester) async {
    await pump(tester, 'ultrasound',
        ultrasoundRepository: _SavedUltrasoundRepository());
    await tester.tap(find.text('QA Chipo Banda'));
    await tester.pumpAndSettle();
    expect(find.text('No examination notes saved.'), findsOneWidget);
    expect(find.textContaining('Image preview unavailable.'), findsOneWidget);
    expect(find.text('Previous saved assessment'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ultrasound overview load failure offers a readable retry',
      (tester) async {
    final repository = _SavedUltrasoundRepository()..fail = true;
    await pump(tester, 'ultrasound', ultrasoundRepository: repository);
    expect(
        find.textContaining('Private ultrasound database trace'), findsNothing);
    expect(find.text('Scan records unavailable'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.text('Retry records'));
    await tester.pumpAndSettle();
    expect(find.text('QA Amina Banda'), findsOneWidget);
    expect(find.text('Scan records unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final module in ['cacx', 'ultrasound']) {
    testWidgets('$module records and history retain return navigation',
        (tester) async {
      await pump(tester, module);
      for (final destination in [
        'Patient Records',
        module == 'cacx' ? 'Screening History' : 'Scan History'
      ]) {
        await tester.tap(find.descendant(
            of: find.byType(ClinicalTabBar), matching: find.text(destination)));
        await tester.pumpAndSettle();
        await tester.tap(find.descendant(
            of: find.byType(ClinicalTabBar), matching: find.text('Overview')));
        await tester.pumpAndSettle();
        expect(
            find.text(
                module == 'cacx' ? 'New Screening' : 'New Ultrasound Scan'),
            findsOneWidget);
      }
    });
  }

  for (final module in ['cacx', 'ultrasound', 'anemia', 'ct']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          '$module secondary views remain usable on mobile at text scale $scale',
          (tester) async {
        await pump(tester, module, size: const Size(320, 900), scale: scale);
        final tabs =
            tester.widget<ClinicalTabBar>(find.byType(ClinicalTabBar)).tabs;
        for (var i = 1; i < tabs.length; i++) {
          final tab = find.descendant(
              of: find.byType(ClinicalTabBar),
              matching: find.text(tabs[i].label));
          await tester.ensureVisible(tab);
          await tester.pumpAndSettle();
          await tester.tap(tab);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: '${tabs[i].label} at $scale');
          expect(
              tester
                  .widget<ClinicalTabBar>(find.byType(ClinicalTabBar))
                  .activeIndex,
              i);
          if ((module == 'cacx' && i == 2) || (module == 'ct' && i >= 2)) {
            final name = module == 'cacx' ? 'Beatrice Zulu' : 'Patricia Gondwe';
            final scroll = find
                .descendant(
                    of: find.byKey(PageStorageKey(
                        module == 'cacx' ? 'cacx-history' : 'ct-scan-results')),
                    matching: find.byType(Scrollable))
                .first;
            await tester.scrollUntilVisible(find.text(name), 250,
                scrollable: scroll);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull,
                reason: 'Scrolled results at $scale');
          }
          if (const bool.fromEnvironment('CAPTURE_CLINICAL_PHASE5')) {
            await expectLater(
                find.byType(MaterialApp),
                matchesGoldenFile(
                    '../docs/qa/phase5/$module-view-$i-scale-$scale.png'));
          }
        }
      });
    }
  }

  for (final module in ['cacx', 'ultrasound']) {
    testWidgets(
        '$module patient search stays visible after leaving and returning',
        (tester) async {
      await pump(tester, module);
      final tab = find.descendant(
          of: find.byType(ClinicalTabBar),
          matching: find.text('Patient Records'));
      await tester.tap(tab);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Alice');
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(ClinicalTabBar), matching: find.text('Overview')));
      await tester.pumpAndSettle();
      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          'Alice');
      if (module == 'cacx') {
        await tester.enterText(
            find.byType(TextField).first, 'no-matching-patient');
        await tester.pumpAndSettle();
        expect(find.text('No patients found'), findsOneWidget);
        await tester.tap(find.text('Clear filters'));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<TextField>(find.byType(TextField).first)
                .controller!
                .text,
            isEmpty);
        expect(find.text('Alice Mumba'), findsOneWidget);
      }
    });
  }

  testWidgets('CaCx results remain usable at 200% text', (tester) async {
    await pump(tester, 'cacx', size: const Size(320, 900), scale: 2);
    final action = find.descendant(
        of: find.byType(ClinicalTabBar),
        matching: find.text('Screening History'));
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cacx-results-search-field')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'CT search remains reachable with the mobile keyboard and large text',
      (tester) async {
    await pump(tester, 'ct', size: const Size(320, 700), scale: 2);
    final tab = find.descendant(
        of: find.byType(ClinicalTabBar), matching: find.text('Search'));
    await tester.ensureVisible(tab);
    await tester.pumpAndSettle();
    await tester.tap(tab);
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final search = find.byKey(const ValueKey('ct-scan-results-search'));
    await tester.enterText(search, 'CT-5402');
    await tester.pumpAndSettle();
    final scroll = find
        .descendant(
            of: find.byKey(const PageStorageKey('ct-scan-results')),
            matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('Olive Mwanza'), 250,
        scrollable: scroll);
    await tester.pumpAndSettle();
    expect(find.text('Patricia Gondwe'), findsNothing);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_CLINICAL_PHASE5')) {
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('../docs/qa/phase5/ct-mobile-keyboard.png'));
    }
  });

  for (final viewport in [
    'desktop',
    'laptop',
    'collapsed',
    'mobile',
    'large-text'
  ]) {
    testWidgets('CT compact records and report work at $viewport',
        (tester) async {
      final size = switch (viewport) {
        'laptop' => const Size(1024, 900),
        'mobile' => const Size(390, 844),
        'large-text' => const Size(390, 1000),
        _ => const Size(1440, 1000),
      };
      await pump(tester, 'ct',
          size: size,
          collapsed: viewport == 'collapsed',
          scale: viewport == 'large-text' ? 2 : 1);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_CT_REVIEW')) {
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('../docs/qa/ct-review/overview-$viewport.png'));
      }
      final patient = find.text('Patricia Gondwe');
      await tester.ensureVisible(patient);
      await tester.tap(patient);
      await tester.pumpAndSettle();
      expect(find.text('Sample CT record CT-5401'), findsOneWidget);
      expect(
          find.text('No acute intracranial finding reported.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_CT_REVIEW')) {
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('../docs/qa/ct-review/report-$viewport.png'));
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Sample CT record CT-5401'), findsNothing);
    });
  }

  testWidgets('CT summary filters records and empty search recovers',
      (tester) async {
    await pump(tester, 'ct');
    await tester.tap(find.text('Needs review').first);
    await tester.pumpAndSettle();
    expect(find.text('Olive Mwanza'), findsOneWidget);
    expect(find.text('Patricia Gondwe'), findsNothing);
    expect(find.text('1 of 3 records'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('ct-scan-results-search')), 'no-match');
    await tester.pumpAndSettle();
    expect(find.text('No matching results'), findsOneWidget);
    await tester.tap(find.text('Clear filters/search'));
    await tester.pumpAndSettle();
    expect(find.text('3 of 3 records'), findsOneWidget);
    expect(find.text('Patricia Gondwe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CT sample status and action are explicit', (tester) async {
    await pump(tester, 'ct');
    expect(find.text('Sample data'), findsAtLeastNWidgets(1));
    expect(
        find.textContaining(
            'Clinical record creation and saving are not connected'),
        findsOneWidget);
    await tester.tap(find.text('View sample records'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<ClinicalTabBar>(find.byType(ClinicalTabBar)).activeIndex,
        1);
  });

  testWidgets(
      'CT sample record action opens read-only sample detail and records remain searchable',
      (tester) async {
    await pump(tester, 'ct');
    await tester.tap(find.text('View sample record').first);
    await tester.pumpAndSettle();
    expect(find.text('Sample CT record CT-5401'), findsOneWidget);
    expect(
        find.textContaining(
            'Clinical saving and radiology review actions are not connected'),
        findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View sample records'));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('ct-scan-records-search'));
    await tester.enterText(field, 'DM-1015');
    await tester.pumpAndSettle();
    expect(find.text('Patricia Gondwe'), findsOneWidget);
    expect(find.text('Olive Mwanza'), findsNothing);
    await tester.enterText(field, 'no-such-record');
    await tester.pumpAndSettle();
    expect(find.text('No matching results'), findsOneWidget);
    await tester.tap(find.text('View sample records'));
    await tester.pumpAndSettle();
    expect(find.text('Olive Mwanza'), findsOneWidget);
    expect(find.text('Ruth Kangwa'), findsOneWidget);
  });

  testWidgets(
      'BP rejects malformed optional age without producing an interpretation',
      (tester) async {
    await pump(tester, 'bp');
    await tester.enterText(find.widgetWithText(TextField, 'Age'), 'invalid');
    await tester.enterText(find.widgetWithText(TextField, 'Systolic'), '120');
    await tester.enterText(find.widgetWithText(TextField, 'Diastolic'), '80');
    await tester.tap(find.text('Interpret Reading'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid age in years, or leave age empty.'),
        findsOneWidget);
    expect(find.textContaining('120/80'), findsNothing);
    expect(find.text('Session only'), findsOneWidget);
  });

  Future<void> enterBp(WidgetTester tester,
      {String systolic = '118',
      String diastolic = '76',
      String patient = 'QA BP Patient'}) async {
    await tester.enterText(
        find.widgetWithText(TextField, 'Patient name'), patient);
    await tester.enterText(
        find.widgetWithText(TextField, 'Systolic'), systolic);
    await tester.enterText(
        find.widgetWithText(TextField, 'Diastolic'), diastolic);
    final action = find.text('Interpret Reading');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
  }

  for (final viewport in [
    'desktop',
    'laptop',
    'collapsed',
    'mobile',
    'large-text'
  ]) {
    testWidgets('BP entry and session review work at $viewport',
        (tester) async {
      final size = switch (viewport) {
        'laptop' => const Size(1024, 900),
        'mobile' => const Size(390, 844),
        'large-text' => const Size(390, 1000),
        _ => const Size(1440, 1000),
      };
      await pump(tester, 'bp',
          size: size,
          collapsed: viewport == 'collapsed',
          scale: viewport == 'large-text' ? 2 : 1);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_BP_REVIEW')) {
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('../docs/qa/bp-review/entry-$viewport.png'));
      }
      await enterBp(tester);
      expect(find.text('118/76 mmHg'), findsOneWidget);
      expect(find.text('Recent Readings (1)'), findsOneWidget);
      final resultTop = tester.getTopLeft(find.text('118/76 mmHg')).dy;
      expect(resultTop, greaterThanOrEqualTo(64));
      expect(resultTop, lessThan(size.height - 40),
          reason: 'Interpreting a reading brings the result into view.');
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Interpretation'));
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('CAPTURE_BP_REVIEW')) {
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('../docs/qa/bp-review/result-$viewport.png'));
      }
      final history = find.text('QA BP Patient - 118/76 mmHg');
      await tester.ensureVisible(history);
      await tester.tap(history);
      await tester.pumpAndSettle();
      expect(find.text('Session reading'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.text('118/76 mmHg')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_BP_REVIEW')) {
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('../docs/qa/bp-review/history-$viewport.png'));
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Session reading'), findsNothing);
    });
  }

  testWidgets('BP focuses invalid fields and accepts corrected values',
      (tester) async {
    await pump(tester, 'bp');
    await enterBp(tester, systolic: '49');
    expect(find.text('Enter systolic pressure from 50 to 260 mmHg.'),
        findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Systolic'))
            .focusNode!
            .hasFocus,
        isTrue);
    expect(find.text('Recent Readings (0)'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Diastolic'))
            .focusNode!
            .hasFocus,
        isTrue);
    if (const bool.fromEnvironment('CAPTURE_BP_REVIEW')) {
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('../docs/qa/bp-review/validation-desktop.png'));
    }
    await enterBp(tester, systolic: '100', diastolic: '100');
    expect(find.text('Diastolic pressure should be lower than systolic.'),
        findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Diastolic'))
            .focusNode!
            .hasFocus,
        isTrue);
    await enterBp(tester);
    expect(find.text('Normal blood pressure'), findsWidgets);
    expect(find.text('Recent Readings (1)'), findsOneWidget);
    expect(find.text('Enter systolic pressure from 50 to 260 mmHg.'),
        findsNothing);
  });

  testWidgets(
      'BP editing and reviewing retain captured patient and interpretation',
      (tester) async {
    await pump(tester, 'bp');
    await enterBp(tester, patient: 'QA First');
    await tester.tap(find.widgetWithText(TextField, 'Systolic'));
    await tester.pumpAndSettle();
    expect(find.text('Entry changed'), findsNothing,
        reason: 'Changing focus or cursor does not change the reading.');
    await tester.enterText(
        find.widgetWithText(TextField, 'Patient name'), 'QA Second');
    await tester.enterText(find.widgetWithText(TextField, 'Systolic'), '145');
    await tester.pumpAndSettle();
    expect(find.text('Entry changed'), findsOneWidget);
    expect(find.text('QA First'), findsOneWidget);
    expect(find.text('118/76 mmHg'), findsOneWidget);
    if (const bool.fromEnvironment('CAPTURE_BP_REVIEW')) {
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('../docs/qa/bp-review/entry-changed-desktop.png'));
    }
    await tester.tap(find.text('Interpret Reading'));
    await tester.pumpAndSettle();
    expect(find.text('Entry changed'), findsNothing);
    expect(find.text('145/76 mmHg'), findsOneWidget);
    expect(find.text('Recent Readings (2)'), findsOneWidget);
    await tester.tap(find.text('QA First - 118/76 mmHg'));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.text('QA First')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Normal blood pressure')),
        findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Patient name'))
            .controller!
            .text,
        'QA Second');
    expect(find.text('145/76 mmHg'), findsOneWidget);
  });

  testWidgets(
      'BP context changes require reinterpretation and clear preserves history',
      (tester) async {
    await pump(tester, 'bp');
    await enterBp(tester, systolic: '160', diastolic: '100');
    await tester.tap(find.text('Pregnant'));
    await tester.pumpAndSettle();
    expect(find.text('Entry changed'), findsOneWidget);
    await tester.tap(find.text('Interpret Reading'));
    await tester.pumpAndSettle();
    expect(find.text('Severe hypertension in pregnancy range'), findsWidgets);
    expect(find.text('Entry changed'), findsNothing);
    if (const bool.fromEnvironment('CAPTURE_BP_REVIEW')) {
      await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
              '../docs/qa/bp-review/pregnancy-result-desktop.png'));
    }
    await tester.tap(find.text('Clear form'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep entry'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Systolic'))
            .controller!
            .text,
        '160');
    await tester.tap(find.text('Clear form'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Clear form')));
    await tester.pumpAndSettle();
    expect(find.text('No interpretation yet'), findsOneWidget);
    expect(find.text('Recent Readings (2)'), findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Systolic'))
            .controller!
            .text,
        isEmpty);
    await tester.tap(find.text('Enter a reading'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Systolic'))
            .focusNode!
            .hasFocus,
        isTrue);
  });

  testWidgets('BP panels fit side by side in the desktop content width',
      (tester) async {
    await pump(tester, 'bp');
    final input = tester.getTopLeft(find.text('Systolic'));
    final interpretation = tester.getTopLeft(find.text('Interpretation'));
    expect(interpretation.dx, greaterThan(input.dx + 300));
    expect(interpretation.dy, lessThan(input.dy));
  });

  testWidgets(
      'clinical mobile drawer opens and closes without covering content afterward',
      (tester) async {
    await pump(tester, 'bp', size: const Size(390, 844));
    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    expect(find.byType(SmallSideNavWidget), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(SmallSideNavWidget), findsNothing);
    expect(find.text('New BP Reading'), findsOneWidget);
  });

  testWidgets(
      'BP reading entry still populates the interpretation and session history',
      (tester) async {
    await pump(tester, 'bp');
    await tester.enterText(
        find.widgetWithText(TextField, 'Patient name'), 'Synthetic QA patient');
    await tester.enterText(find.widgetWithText(TextField, 'Systolic'), '120');
    await tester.enterText(find.widgetWithText(TextField, 'Diastolic'), '80');
    await tester.enterText(find.widgetWithText(TextField, 'Clinical notes'),
        'Synthetic review note');
    await tester.tap(find.text('Interpret Reading'));
    await tester.pumpAndSettle();
    expect(find.textContaining('120/80'), findsWidgets);
    expect(find.textContaining('Recorded '), findsOneWidget);
    expect(find.text('Synthetic review note'), findsWidgets);
    expect(find.text('Synthetic QA patient'), findsWidgets);
    expect(
        find.text(
            'Interpreted readings appear here during this visit to BP Monitor. They are not saved to permanent patient records.'),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'disabled clinical tabs cannot navigate and announce disabled state',
      (tester) async {
    var selected = 0;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ClinicalTabBar(
                tabs: const [
          ClinicalTab('New Screening'),
          ClinicalTab('History')
        ],
                activeIndex: 0,
                enabled: false,
                onSelected: (value) => selected = value))));
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(selected, 0);
    expect(
        tester.getSemantics(find.text('History')),
        matchesSemantics(
            label: 'History',
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hasSelectedState: true,
            isSelected: false));
    semantics.dispose();
  });
}
