import 'dart:async';
import 'package:clinician/application/create_mom/create_patient_modal_widget.dart';
import 'package:clinician/application/mom_details2/mom_details2_model.dart';
import 'package:clinician/application/mom_details/mom_details_model.dart';
import 'dart:convert';
import 'package:clinician/flutter_flow/flutter_flow_drop_down.dart';
import 'package:clinician/components/parity_input_component/parity_input_component_widget.dart';
import 'package:clinician/app_state.dart';
import 'package:clinician/backend/backend.dart';
import 'package:clinician/components/clinician_navigation.dart';
import 'package:clinician/components/dawa_design_system.dart';
import 'package:clinician/flutter_flow/flutter_flow_theme.dart';
import 'package:clinician/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'clinician_navigation_test.dart' show loadNavigationFonts;

void main() {
  MomDetailsModel? suppliedMaternalModel;
  MomDetails2Model? suppliedBirthModel;
  final maternalWrites = <http.Request>[];
  var screeningRows = <Map<String, dynamic>>[];
  var failHistory = false;
  var failProfile = false;
  var hasPregnancy = true;
  var admin = false;
  var encounterStatus = 'scheduled';
  var firstClinicalFields = <String, dynamic>{};
  var historyRequests = 0;
  String? queriedPatient;
  var patientReference = 'QA-1042';
  var patientBirthDate = '1994-03-12T00:00:00Z';
  var serviceRows = <Map<String, dynamic>>[];
  Completer<http.Response>? pendingHistory;
  setUp(() {
    suppliedMaternalModel = null;
    suppliedBirthModel = null;
    maternalWrites.clear();
    FFAppState().parity = [];
    FFAppState().ancDates = [];
    FFAppState().makingFIrstEncounter = false;
    screeningRows = [];
    failHistory = false;
    failProfile = false;
    hasPregnancy = true;
    admin = false;
    encounterStatus = 'scheduled';
    firstClinicalFields = {};
    historyRequests = 0;
    queriedPatient = null;
    patientReference = 'QA-1042';
    patientBirthDate = '1994-03-12T00:00:00Z';
    serviceRows = [];
    pendingHistory = null;
  });
  test('patient secondary labels meet AA on all neutral card surfaces', () {
    for (final surface in [
      DawaTokens.surface,
      DawaTokens.surfaceSecondary,
      DawaTokens.surfaceTertiary
    ]) {
      final ratio = (surface.computeLuminance() + .05) /
          (DawaTokens.textMuted.computeLuminance() + .05);
      expect(ratio, greaterThanOrEqualTo(4.5));
    }
  });
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    for (final channel in [
      'com.llfbandit.app_links/events',
      'com.llfbandit.app_links/messages'
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
    await FlutterFlowTheme.initialize();
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
      if (weight.index <= FontWeight.w600.index) {
        GoogleFonts.poppins(fontWeight: weight);
      }
    }
    await GoogleFonts.pendingFonts();
    await Supabase.initialize(
        url: 'http://127.0.0.1:54321',
        anonKey: 'local-test-key',
        httpClient: MockClient((request) async {
          final table = request.url.path.split('/').last;
          if (request.method != 'GET' && !request.url.path.contains('/rpc/'))
            maternalWrites.add(request);
          dynamic result;
          if (table == 'cacx_screening_results') {
            historyRequests++;
            queriedPatient = request.url.queryParameters['patient_id'];
            if (pendingHistory != null) {
              final response = await pendingHistory!.future;
              return http.Response(response.body, response.statusCode,
                  headers: response.headers, request: request);
            }
            if (failHistory) {
              return http.Response(
                  '{"message":"internal private server trace"}', 500,
                  headers: {'content-type': 'application/json'},
                  request: request);
            }
            result = screeningRows;
          } else if (table == 'clinician_services') {
            result = serviceRows;
          } else if (table == 'current_clinician_is_admin') {
            result = admin;
          } else {
            if (table == 'doctor' && failProfile) {
              return http.Response(
                  '{"message":"private profile server trace"}', 500,
                  headers: {'content-type': 'application/json'},
                  request: request);
            }
            final row = switch (table) {
              'mother' => <String, dynamic>{
                  'id':
                      (request.url.queryParameters['id'] ?? 'eq.patient-audit')
                          .replaceFirst('eq.', ''),
                  'name': 'Clinical QA Patient',
                  'dateOfBirth': patientBirthDate,
                  'mother_id': patientReference,
                  'phone_number': '0000000000',
                  'clinic_name': 'QA Clinic',
                  'address': 'Test address',
                  'first_encounter_id': hasPregnancy ? 'first-audit' : null,
                },
              'doctor' => <String, dynamic>{
                  'id': 'doctor-audit',
                  'name': 'QA Clinician',
                  'speciality': 'Midwifery',
                  'clinic_name': 'QA Clinic',
                  'phone_number': '0000000000',
                  'start_time': '08:00',
                  'end_time': '17:00'
                },
              'first_encounter' => <String, dynamic>{
                  'id': 'first-audit',
                  'mother_id': 'patient-audit',
                  ...firstClinicalFields,
                },
              'encounter' => <String, dynamic>{
                  'id': 'encounter-audit',
                  'mother_id': 'patient-audit',
                  'status': encounterStatus,
                  'scheduled_time': '2026-11-13T08:00:00Z'
                },
              _ => <String, dynamic>{},
            };
            final single =
                request.headers['accept']?.contains('vnd.pgrst.object') ??
                    false;
            result = single
                ? row
                : row.isEmpty
                    ? []
                    : [row];
          }
          return http.Response(jsonEncode(result), 200,
              headers: {'content-type': 'application/json'}, request: request);
        }));
    await FFAppState().initializePersistedState();
  });

  Widget page(String name,
      {bool missing = false, String patientId = 'patient-audit'}) {
    final patient = missing ? null : MotherRecord.collection.doc(patientId);
    final first =
        missing ? null : FirstEncounterRecord.collection.doc('first-audit');
    final encounter =
        missing ? null : EncounterRecord.collection.doc('encounter-audit');
    return switch (name) {
      'PatientDetails' =>
        PatientDetailsWidget(momDetails: patient, firstEncounter: first),
      'MomDetails' => suppliedMaternalModel == null
          ? MomDetailsWidget(momDetails: patient, firstEncounter: first)
          : Provider<MomDetailsModel>.value(
              value: suppliedMaternalModel!,
              child:
                  MomDetailsWidget(momDetails: patient, firstEncounter: first)),
      'MomDetails2' => suppliedBirthModel == null
          ? MomDetails2Widget(momDetails: patient, firstEncounter: first)
          : Provider<MomDetails2Model>.value(
              value: suppliedBirthModel!,
              child: MomDetails2Widget(
                  momDetails: patient, firstEncounter: first)),
      'Encounter' => EncounterWidget(momDetails: patient),
      'EncounterDets' =>
        EncounterDetsWidget(momDets: patient, encounterDetails: encounter),
      'EditEncounter' =>
        EditEncounterWidget(momDetails: patient, encounterDetails: encounter),
      'Profile' => const ProfileWidget(),
      'EditProfile' => const EditProfileWidget(),
      'Login' => const LoginWidget(),
      'LoginCopy' => const LoginCopyWidget(),
      'ResetPassword' => const ResetPasswordWidget(),
      'CompleteClincianReg' => const CompleteClincianRegWidget(),
      'AdminCreateAccount' => const AdminCreateAccountWidget(),
      'ClinicianServiceCatalogAdmin' =>
        const ClinicianServiceCatalogAdminWidget(),
      _ => const CreateMomWidget(),
    };
  }

  Future<void> pumpPage(WidgetTester tester, String name, Size size,
      {double scale = 1,
      bool collapsed = false,
      bool missing = false,
      String profileId = 'doctor-audit'}) async {
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      onError?.call(details);
    };
    addTearDown(() => FlutterError.onError = onError);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FFAppState().doctor = missing && name == 'Profile'
        ? null
        : DoctorRecord.collection.doc(profileId);
    // Exercise the authorized account form without the animated PIN gate.
    FFAppState().adminPin = name == 'AdminCreateAccount' ? '123456' : '';
    clinicianSidebarCollapsed.value = collapsed;
    final router = GoRouter(initialLocation: '/$name', routes: [
      GoRoute(
          name: name,
          path: '/$name',
          builder: (_, state) => page(name,
              missing: missing,
              patientId:
                  state.uri.queryParameters['patient'] ?? 'patient-audit')),
      for (final route in [
        'Moms',
        'MomDetails',
        'Home',
        'ScheduledEncounters',
        'CareTools',
        'CervicalCancer',
        'Ultrasound',
        'HemoNix',
        'CtScan',
        'BpMonitor',
        'Login',
        'Profile',
        'EditProfile',
        'ClinicianServiceCatalogAdmin'
      ])
        if (route != name)
          GoRoute(
              name: route,
              path: '/route-$route',
              builder: (_, __) => Text('Destination $route')),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: FFAppState(),
        child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                fontFamily: 'NavigationQA',
                colorSchemeSeed: const Color(0xFF223F91)),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!))));
    await tester.pump();
    await tester.runAsync(() async {
      final context = tester.element(find.byType(MaterialApp));
      await precacheImage(
          const AssetImage('assets/images/dawa_cross.png'), context);
      await precacheImage(
          const AssetImage('assets/images/Frame_41.png'), context);
    });
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
  }

  const pages = [
    'PatientDetails',
    'MomDetails',
    'MomDetails2',
    'Encounter',
    'EncounterDets',
    'EditEncounter',
    'Profile',
    'EditProfile',
    'CreateMom',
    'Login',
    'LoginCopy',
    'ResetPassword',
    'CompleteClincianReg',
    'AdminCreateAccount',
    'ClinicianServiceCatalogAdmin'
  ];
  for (final name in pages) {
    for (final viewport in [
      'desktop',
      'laptop',
      'collapsed',
      'mobile',
      'large-text'
    ]) {
      testWidgets('$name $viewport loaded page has no rendering errors',
          (tester) async {
        final size = switch (viewport) {
          'laptop' => const Size(1024, 900),
          'mobile' => const Size(390, 844),
          'large-text' => const Size(390, 1000),
          _ => const Size(1440, 1000),
        };
        await pumpPage(tester, name, size,
            scale: viewport == 'large-text' ? 2 : 1,
            collapsed: viewport == 'collapsed');
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_PHASE13') &&
            name == 'PatientDetails') {
          await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                  '../coverage/phase13/patient-details-$viewport.png'));
        }
        if (name == 'ClinicianServiceCatalogAdmin') {
          expect(find.text('Destination Profile'), findsOneWidget);
        }
        if (name == 'CompleteClincianReg') {
          expect(find.text('Complete registration'), findsOneWidget);
          expect(find.text('Continue'), findsOneWidget);
        }
        if (const bool.fromEnvironment('CAPTURE_PATIENT_AUDIT') &&
            name != 'ClinicianServiceCatalogAdmin') {
          await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                  '../docs/qa/patient-audit/$name-$viewport.png'));
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }
  for (final name in pages.take(6)) {
    testWidgets('$name incomplete link recovers through Patients',
        (tester) async {
      await pumpPage(tester, name, const Size(1024, 900), missing: true);
      expect(find.text('Choose a patient to continue'), findsOneWidget);
      await tester.tap(find.text('Open Patients'));
      await tester.pumpAndSettle();
      expect(find.text('Destination Moms'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final viewport in ['desktop', 'laptop', 'mobile', 'large-text']) {
    testWidgets('PatientDetails saved results and details at $viewport',
        (tester) async {
      screeningRows = [
        {
          'id': 'screening-newer',
          'created_at': '2026-11-12T09:15:00Z',
          'primary_source': 'arduino_device',
          'primary_result': 'QA result requiring review',
          'primary_confidence': 82.4,
          'risk_level': 'high',
          'device_status': 'success',
        },
        {
          'id': 'screening-older',
          'created_at': '2026-10-10T10:00:00Z',
          'primary_source': 'gradio_server',
          'primary_result': 'QA previous result',
          'risk_level': 'normal',
          'device_status': 'failed',
        }
      ];
      final size = switch (viewport) {
        'laptop' => const Size(1024, 900),
        'mobile' => const Size(390, 844),
        'large-text' => const Size(390, 1000),
        _ => const Size(1440, 1000),
      };
      await pumpPage(tester, 'PatientDetails', size,
          scale: viewport == 'large-text' ? 2 : 1);
      expect(queriedPatient, 'eq.QA-1042');
      expect(find.text('Latest screening'), findsOneWidget);
      expect(find.text('2 saved screenings'), findsOneWidget);
      expect(find.text('No screenings yet'), findsNothing);
      expect(find.text('QA result requiring review'), findsNWidgets(2));
      expect(find.text('QA previous result'), findsOneWidget);
      expect(find.text('AI estimate — clinician must review'), findsOneWidget);
      expect(find.text('Confidence unavailable confidence'), findsNothing);
      if (const bool.fromEnvironment('CAPTURE_PATIENT_AUDIT')) {
        await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
                '../docs/qa/patient-audit/PatientDetails-populated-$viewport.png'));
      }
      await tester.ensureVisible(find.text('Review latest result'));
      await tester.tap(find.text('Review latest result'));
      await tester.pumpAndSettle();
      expect(find.text('Screening Details'), findsOneWidget);
      expect(find.text('82.4%'), findsOneWidget);
      expect(
          find.byType(Dialog),
          viewport == 'desktop' || viewport == 'laptop'
              ? findsOneWidget
              : findsNothing);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_PATIENT_AUDIT')) {
        await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
                '../docs/qa/patient-audit/PatientDetails-result-$viewport.png'));
      }
      if (viewport == 'desktop') {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      } else {
        await tester.tap(find.byTooltip('Close screening details'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Screening Details'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
      'PatientDetails history failure recovers and resize preserves data',
      (tester) async {
    failHistory = true;
    await pumpPage(tester, 'PatientDetails', const Size(1440, 1000));
    expect(find.text('Screening history unavailable'), findsOneWidget);
    expect(find.text('No screenings yet'), findsNothing);
    expect(find.textContaining('internal private server trace'), findsNothing);
    failHistory = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No screenings yet'), findsOneWidget);
    expect(historyRequests, 2);
    tester.view.physicalSize = const Size(1024, 900);
    await tester.pumpAndSettle();
    expect(historyRequests, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('PatientDetails clears previous results when changing patient',
      (tester) async {
    screeningRows = [
      {
        'id': 'first-patient-screening',
        'primary_result': 'First patient result',
        'risk_level': 'normal',
      }
    ];
    await pumpPage(tester, 'PatientDetails', const Size(1440, 1000));
    expect(find.text('First patient result'), findsNWidgets(2));
    patientReference = 'QA-2043';
    final pending = Completer<http.Response>();
    pendingHistory = pending;
    final context = tester.element(find.byType(PatientDetailsWidget));
    GoRouter.of(context).go('/PatientDetails?patient=second-patient');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('First patient result'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(http.Response('[]', 200,
        headers: {'content-type': 'application/json'}));
    await tester.pumpAndSettle();
    expect(queriedPatient, 'eq.QA-2043');
    expect(find.text('No screenings yet'), findsOneWidget);
    expect(find.text('First patient result'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('PatientDetails short reference copies the complete identifier',
      (tester) async {
    patientReference = '1788a6c5-a2c8-42e7-98a5-b0ab8034e700';
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = call.arguments['text'];
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpPage(tester, 'PatientDetails', const Size(1024, 900));
    expect(find.text('Ref 1788a6c5…e700'), findsOneWidget);
    expect(find.textContaining(patientReference), findsNothing);
    await tester.tap(find.byTooltip('Copy full patient reference'));
    await tester.pumpAndSettle();
    expect(copied, patientReference);
    expect(queriedPatient, 'eq.$patientReference');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('patient details opens the full maternal record', (tester) async {
    await pumpPage(tester, 'PatientDetails', const Size(1440, 1000));
    await tester.tap(find.text('Full Maternal Record'));
    await tester.pumpAndSettle();
    expect(find.text('Destination MomDetails'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final entry in {
    'MomDetails2': 'Submit',
    'Encounter': 'Submit',
    'EditEncounter': 'Update',
    'CreateMom': 'Create Patient Record',
    'EditProfile': 'Save changes'
  }.entries) {
    testWidgets('${entry.key} final action is reachable at 200 percent text',
        (tester) async {
      await pumpPage(tester, entry.key, const Size(390, 1000), scale: 2);
      await tester.ensureVisible(find.text(entry.value));
      await tester.pumpAndSettle();
      expect(find.text(entry.value).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_PATIENT_AUDIT')) {
        await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
                '../docs/qa/patient-audit/${entry.key}-form-bottom.png'));
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final viewport in [
    'desktop',
    'laptop',
    'collapsed',
    'mobile',
    'large-text'
  ]) {
    testWidgets('maternal record uses the shared workspace at $viewport',
        (tester) async {
      hasPregnancy = false;
      final size = switch (viewport) {
        'laptop' => const Size(1024, 900),
        'mobile' => const Size(390, 844),
        'large-text' => const Size(390, 1000),
        _ => const Size(1440, 1000),
      };
      await pumpPage(tester, 'MomDetails', size,
          collapsed: viewport == 'collapsed',
          scale: viewport == 'large-text' ? 2 : 1);
      expect(find.text('Full maternal record'), findsOneWidget);
      expect(find.text('Clinical QA Patient'), findsOneWidget);
      expect(find.text('No pregnancy record'), findsOneWidget);
      expect(find.byTooltip('Notifications'), findsOneWidget);
      expect(find.byKey(const ValueKey('edge-device-control')), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_RELIABILITY_QA')) {
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('../docs/qa/reliability/maternal-$viewport.png'));
      }
      await tester.ensureVisible(find.text('Add Pregnancy Data'));
      await tester.tap(find.text('Add Pregnancy Data'));
      await tester.pumpAndSettle();
      expect(find.text('No pregnancy record'), findsNothing);
      expect(find.byType(TextFormField), findsWidgets);
      expect(tester.takeException(), isNull);
      FFAppState().makingFIrstEncounter = false;
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'maternal screening reveals only the selected clinical follow-up fields',
      (tester) async {
    hasPregnancy = false;
    await pumpPage(tester, 'MomDetails', const Size(1440, 1000));
    await tester.ensureVisible(find.text('Add Pregnancy Data'));
    await tester.tap(find.text('Add Pregnancy Data'));
    await tester.pumpAndSettle();
    expect(find.text('Last VL'), findsNothing);
    expect(find.text('Date of Screen'), findsNothing);
    // Exercise the real field callbacks, then verify the conditional form and
    // input formatters. Nothing is submitted to the clinical repository.
    final fields = tester
        .widgetList<FlutterFlowDropDown<String>>(
            find.byType(FlutterFlowDropDown<String>))
        .toList();
    for (final field in fields) {
      if (field.onChanged != null) {
        final value = field.options.contains('Positive')
            ? 'Positive'
            : field.options.contains('Yes')
                ? 'Yes'
                : field.options.first;
        field.controller!.value = value;
        field.onChanged!(value);
      } else if (field.onMultiSelectChanged != null) {
        field.onMultiSelectChanged!([field.options.first]);
      }
    }
    await tester.pumpAndSettle();
    expect(find.text('Last VL'), findsOneWidget);
    expect(find.text('CD4'), findsWidgets);
    expect(find.text('Date of Screen'), findsOneWidget);
    final viralLoad = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Last Vl');
    await tester.ensureVisible(viralLoad);
    await tester.enterText(viralLoad, '12a34');
    expect(tester.widget<TextField>(viralLoad).controller!.text, '1234');
    final hiv = tester
        .widgetList<FlutterFlowDropDown<String>>(
            find.byType(FlutterFlowDropDown<String>))
        .firstWhere((w) => w.options.contains('Declined to Disclose'));
    hiv.controller!.value = 'Negative';
    hiv.onChanged!('Negative');
    await tester.pumpAndSettle();
    expect(find.text('Last VL'), findsNothing);
    expect(find.text('CD4'), findsNothing);
    FFAppState().makingFIrstEncounter = false;
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'birth history fields preserve entered values and selections across rebuilds',
      (tester) async {
    await pumpPage(tester, 'MomDetails', const Size(1440, 1000));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(child: ParityInputComponentWidget()))));
    await tester.pumpAndSettle();
    final year = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '2003');
    final weight = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Birth Weight');
    await tester.enterText(year, '20x19');
    expect(tester.widget<TextField>(year).controller!.text, '2019');
    await tester.enterText(weight, '3200');
    final fields = tester
        .widgetList<FlutterFlowDropDown<String>>(
            find.byType(FlutterFlowDropDown<String>))
        .toList();
    for (final field in fields) {
      if (field.onChanged != null) {
        field.controller!.value = field.options.first;
        field.onChanged!(field.options.first);
      } else {
        field.multiSelectController!.value = ['Postpartum Hemorrhage'];
        field.onMultiSelectChanged!(['Postpartum Hemorrhage']);
      }
    }
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(year).controller!.text, '2019');
    expect(tester.widget<TextField>(weight).controller!.text, '3200');
    expect(find.text('Vaginal'), findsOneWidget);
    expect(find.text('Postpartum Hemorrhage'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final status in ['completed', 'canceled', 'pending']) {
    testWidgets('maternal encounter history presents stored $status state',
        (tester) async {
      encounterStatus = status;
      firstClinicalFields = {
        'HIV_status': 'Positive',
        'cacx': 'Yes',
        'Last_VL': '200',
        'CD4': '600',
        'date_of_screen': '2026-01-01T00:00:00Z'
      };
      await pumpPage(tester, 'MomDetails', const Size(1440, 1000));
      expect(find.text('Clinical QA Patient'), findsOneWidget);
      expect(find.text(status), findsOneWidget);
      if (status != 'completed') expect(find.text('completed'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final withAnc in [false, true]) {
    testWidgets(
        'maternal history saves patient and birth-history links with ANC=$withAnc',
        (tester) async {
      hasPregnancy = false;
      final model = MomDetailsModel()
        ..datePicked1 = DateTime(2026, 5, 1)
        ..datePicked3 = DateTime(2026, 6, 1)
        ..ancValue = withAnc ? 'Yes' : 'No'
        ..hivValue = 'Negative'
        ..cacxValue = 'No'
        ..diabeValue = 'No'
        ..cardiacDiseaseValue = 'No'
        ..foetalmovementsValue = 'Yes';
      suppliedMaternalModel = model;
      FFAppState().parity = [ParityRecord.collection.doc('synthetic-birth')];
      await pumpPage(tester, 'MomDetails', const Size(1440, 1000));
      await tester.ensureVisible(find.text('Add Pregnancy Data'));
      await tester.tap(find.text('Add Pregnancy Data'));
      await tester.pumpAndSettle();
      model.parityTextController!.text = '1';
      model.gravidityTextController!.text = '2';
      final year = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == '2003');
      await tester.ensureVisible(year);
      await tester.enterText(year, '2020');
      final weight = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Birth Weight');
      await tester.enterText(weight, '3000');
      await tester.ensureVisible(find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      final firstWrite = maternalWrites.singleWhere(
          (r) => r.method == 'POST' && r.url.path.endsWith('/first_encounter'));
      final data = jsonDecode(firstWrite.body) as Map;
      expect(data['mother_Id'], 'mother/patient-audit');
      expect(data['gravidity'], '2');
      expect(data['parity'], 1);
      expect(data['parity_id'], ['parity/synthetic-birth']);
      expect(data['anc_dates'],
          withAnc ? [DateTime(2026, 6, 1).toUtc().toIso8601String()] : isNull);
      final birthWrite = maternalWrites.singleWhere(
          (r) => r.method == 'PATCH' && r.url.path.endsWith('/parity'));
      final birth = jsonDecode(birthWrite.body) as Map;
      expect(birth['year_of_birth'], '2020');
      expect(birth['weight'], '3000');
      expect(birth['first_encounter_id'], 'first_encounter/${data['id']}');
      final motherWrite = maternalWrites.singleWhere(
          (r) => r.method == 'PATCH' && r.url.path.endsWith('/mother'));
      expect(jsonDecode(motherWrite.body)['first_encounter_id'],
          'first_encounter/${data['id']}');
      expect(find.text('Maternal history saved successfully'), findsOneWidget);
      expect(FFAppState().parity, isEmpty);
      expect(FFAppState().makingFIrstEncounter, isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'extended maternal form persists entered social and obstetric history',
      (tester) async {
    final model = MomDetails2Model()
      ..maritalValue = 'Married'
      ..momEducationValue = 'Secondary'
      ..dadEducationValue = 'Primary'
      ..laborValue = 'In Hospital'
      ..inducedlaborValue = 'No'
      ..riskFactorsValue = 'High BP in pregnancy';
    suppliedBirthModel = model;
    hasPregnancy = false;
    FFAppState().makingFIrstEncounter = true;
    FFAppState().parity = [ParityRecord.collection.doc('synthetic-birth')];
    await pumpPage(tester, 'MomDetails2', const Size(1440, 1000));
    model.heightTextController!.text = '160';
    model.weightTextController!.text = '60';
    model.fathersageTextController!.text = '32';
    model.aliveTextController!.text = '1';
    model.deadTextController!.text = '0';
    model.miscarriagesTextController!.text = '0';
    model.kidsTextController!.text = '1';
    model.careTextController!.text = '12';
    model.frequencyTextController!.text = '8';
    for (final controller in [
      model.cigTextController,
      model.cig1TextController,
      model.cig2TextController,
      model.cig3TextController
    ]) {
      controller!.text = '0';
    }
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    final write = maternalWrites.singleWhere(
        (r) => r.method == 'PATCH' && r.url.path.endsWith('/parity'));
    final data = jsonDecode(write.body) as Map;
    expect(data['marital_status'], 'Married');
    expect(data['mothers_height'], '160');
    expect(data['prepregnancy_weight'], '60');
    expect(data['fathers_age'], '32');
    expect(data['kids_alive'], 1);
    expect(data['kids_dead'], 0);
    expect(data['cigarettes_before_pregnancy'], 0);
    expect(data['expected_prenatal_visits'], 8);
    expect(data['risk_factors'], 'High BP in pregnancy');
    expect(data['delivery_information'], 'In Hospital');
    expect(find.text('Maternal history saved successfully'), findsOneWidget);
    expect(FFAppState().parity, isEmpty);
    expect(FFAppState().makingFIrstEncounter, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'registration validates fields and opens the exact duplicate without creating an account',
      (tester) async {
    patientBirthDate = '1995-01-01T00:00:00Z';
    await pumpPage(tester, 'MomDetails', const Size(1440, 1000));
    CreatePatientModalResult? result;
    unawaited(showDialog<CreatePatientModalResult>(
            context: tester.element(find.byType(MomDetailsWidget)),
            builder: (_) => const CreatePatientModalWidget())
        .then((value) => result = value));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Patient'));
    await tester.pumpAndSettle();
    expect(find.text('Some required information is missing.'), findsOneWidget);
    expect(maternalWrites, isEmpty);
    Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label);
    await tester.enterText(field('Patient Name *'), 'Clinical QA Patient');
    await tester.enterText(field('Phone Number *'), '0000000000');
    await tester.tap(find.text('Date of Birth *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(field('Patient ID'));
    await tester.enterText(field('Patient ID'), 'QA-1042');
    await tester.tap(find.text('Create Patient'));
    await tester.pumpAndSettle();
    expect(find.text('This patient may already exist.'), findsOneWidget);
    expect(find.textContaining('same patient ID'), findsOneWidget);
    expect(find.textContaining('same phone number'), findsOneWidget);
    expect(find.textContaining('same name and date of birth'), findsOneWidget);
    expect(maternalWrites, isEmpty);
    await tester.ensureVisible(find.text('Open Existing Record'));
    await tester.tap(find.text('Open Existing Record'));
    await tester.pumpAndSettle();
    expect(result?.created, isFalse);
    expect(result?.existingPatientReference?.path, 'mother/patient-audit');
    expect(maternalWrites, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'authorized service catalog validates prices and saves the explicit service identity',
      (tester) async {
    admin = true;

    await pumpPage(
        tester, 'ClinicianServiceCatalogAdmin', const Size(1440, 1000));
    await tester.tap(find.text('Add service'));
    await tester.pumpAndSettle();
    Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label);
    await tester.enterText(field('External service ID'), 'qa-service');
    await tester.enterText(field('Name'), 'Synthetic service');
    await tester.tap(find.text('Paid service'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Price (ZMW)'), '-1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid non-negative amount'), findsOneWidget);
    expect(maternalWrites, isEmpty);
    await tester.enterText(field('Name'), 'Updated synthetic service');
    await tester.enterText(field('Price (ZMW)'), '75.50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final write = maternalWrites
        .singleWhere((r) => r.url.path.endsWith('/clinician_services'));
    final data = jsonDecode(write.body) as Map;
    expect(data['external_service_id'], 'qa-service');
    expect(data['price'], 75.5);
    expect(data['name'], 'Updated synthetic service');
    expect(data['currency'], 'ZMW');
    await tester.tap(find.text('Add service'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(field('External service ID')).controller!.text,
        isEmpty);
    expect(
        tester.widget<TextField>(field('Price (ZMW)')).controller!.text, '0');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(maternalWrites, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  Future<void> captureSettings(WidgetTester tester, String name) async {
    if (const bool.fromEnvironment('CAPTURE_SETTINGS_REVIEW')) {
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('../docs/qa/settings-review/$name.png'));
    }
  }

  for (final viewport in [
    'desktop',
    'laptop',
    'collapsed',
    'mobile',
    'large-text'
  ]) {
    testWidgets('Settings account and dialogs work at $viewport',
        (tester) async {
      final size = switch (viewport) {
        'laptop' => const Size(1024, 900),
        'mobile' => const Size(390, 844),
        'large-text' => const Size(390, 1000),
        _ => const Size(1440, 1000),
      };
      await pumpPage(tester, 'Profile', size,
          collapsed: viewport == 'collapsed',
          scale: viewport == 'large-text' ? 2 : 1);
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('QA Clinician'), findsOneWidget);
      expect(find.text('Services & Pricing'), findsNothing);
      expect(tester.takeException(), isNull);
      await captureSettings(tester, 'overview-$viewport');
      await tester.ensureVisible(find.text('Support'));
      await tester.tap(find.text('Support'));
      await tester.pumpAndSettle();
      expect(find.text('Contact support'), findsOneWidget);
      expect(find.byTooltip('Copy support email'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureSettings(tester, 'support-$viewport');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.ensureVisible(find.text('Sign out'));
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out of Dawa Clinician?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureSettings(tester, 'sign-out-$viewport');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('QA Clinician'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Settings provides one edit-profile destination', (tester) async {
    await pumpPage(tester, 'Profile', const Size(1440, 1000));
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    expect(find.text('Destination EditProfile'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Settings administrator action uses the existing permission check',
      (tester) async {
    admin = true;
    await pumpPage(tester, 'Profile', const Size(1440, 1000));
    expect(find.text('Workspace administration'), findsOneWidget);
    await captureSettings(tester, 'administrator-desktop');
    await tester.tap(find.text('Services & Pricing'));
    await tester.pumpAndSettle();
    expect(
        find.text('Destination ClinicianServiceCatalogAdmin'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Settings profile error offers retry without showing server details',
      (tester) async {
    failProfile = true;
    await pumpPage(tester, 'Profile', const Size(1440, 1000),
        profileId: 'uncached-doctor');
    expect(find.text('Unable to load your profile'), findsOneWidget);
    expect(
        tester
            .getSize(find.ancestor(
                of: find.text('Unable to load your profile'),
                matching: find.byType(DawaCard)))
            .height,
        lessThan(300));
    expect(find.textContaining('private profile server trace'), findsNothing);
    await captureSettings(tester, 'profile-error-desktop');
    failProfile = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('QA Clinician'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Settings missing profile retains navigation and a home destination',
      (tester) async {
    await pumpPage(tester, 'Profile', const Size(390, 844), missing: true);
    expect(find.text('Clinician profile unavailable'), findsOneWidget);
    await tester.tap(find.text('Return Home'));
    await tester.pumpAndSettle();
    expect(find.text('Destination Home'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Settings cached profile stays available during a connection failure',
      (tester) async {
    await pumpPage(tester, 'Profile', const Size(1440, 1000));
    expect(find.text('QA Clinician'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    failProfile = true;
    await pumpPage(tester, 'Profile', const Size(1440, 1000));
    expect(find.text('QA Clinician'), findsOneWidget);
    expect(find.text('Unable to load your profile'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Settings support opens by keyboard and Escape restores focus',
      (tester) async {
    await pumpPage(tester, 'Profile', const Size(1440, 1000));
    final supportFocus = Focus.of(tester.element(find.text('Support')));
    supportFocus.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Contact support'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(supportFocus.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Settings support contacts can be copied', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData')
        copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpPage(tester, 'Profile', const Size(1440, 1000));
    await tester.tap(find.text('Support'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Copy support email'));
    await tester.pumpAndSettle();
    expect(copied, 'developer@thestackone.com');
    await tester.tap(find.byTooltip('Copy support phone number'));
    await tester.pumpAndSettle();
    expect(copied, '+260779406330');
    await tester.pumpWidget(const SizedBox());
  });

  for (final label in ['Support', 'Terms of Service']) {
    testWidgets('$label dialog opens and closes at 200 percent text',
        (tester) async {
      await pumpPage(tester, 'Profile', const Size(390, 1000), scale: 2);
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
