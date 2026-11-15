import 'package:clinician/auth/base_auth_user_provider.dart';
import 'package:clinician/auth/firebase_auth/firebase_user_provider.dart';
import 'package:clinician/services/offline_auth_cache.dart';
import 'package:clinician/application/cacx/cacx_upload_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:clinician/application/cacx/cacx_model.dart';
import 'package:clinician/application/cacx/cacx_widget.dart';
import 'package:clinician/application/cacx/widgets/cacx_second_opinion_dialog.dart';
import 'package:clinician/components/image_source_picker_dialog/image_source_picker_dialog_widget.dart';
import 'package:clinician/services/edge_device/edge_device_client.dart';
import 'package:clinician/services/edge_device/edge_device_config.dart';
import 'package:clinician/services/edge_device/edge_device_manager.dart';
import 'package:clinician/services/offline_connectivity_service.dart';
import 'package:clinician/services/screening_patient_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'clinician_navigation_test.dart' show loadNavigationFonts;

const image =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

class _Patients implements ScreeningPatientRepository {
  _Patients([this.available = true]);
  final bool available;
  @override
  Future<List<ScreeningPatient>> loadPatients() async => available
      ? [const ScreeningPatient(id: 'patient-1', name: 'Synthetic Patient')]
      : [];
}

AnalysisResult result() => AnalysisResult(
    imageUrl: image,
    label: 'Normal / Negative VIA',
    confidence: 90,
    suspicionLevel: SuspicionLevel.low,
    recommendation: 'Synthetic test output.');

void main() {
  final writes = <Map<String, dynamic>>[];
  var failSave = false;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    for (final channel in [
      'com.llfbandit.app_links/events',
      'com.llfbandit.app_links/messages'
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
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
        anonKey: 'synthetic-test-key',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/cacx_screening_results')) {
            if (request.method == 'POST' || request.method == 'PATCH') {
              writes.add({
                'method': request.method,
                ...jsonDecode(request.body) as Map<String, dynamic>
              });
              return http.Response(
                  failSave
                      ? '{"code":"42501","message":"denied"}'
                      : '{"id":"record-1"}',
                  failSave ? 403 : 200,
                  request: request,
                  headers: {'content-type': 'application/json'});
            }
            return http.Response('[]', 200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          return http.Response('{}', 200,
              request: request, headers: {'content-type': 'application/json'});
        }));
  });
  setUp(() {
    writes.clear();
    failSave = false;
    SharedPreferences.setMockInitialValues({});
  });

  Future<EdgeDeviceManager> pump(WidgetTester tester,
      {required Future<AnalysisResult> Function(String) cloud,
      bool internet = true,
      Size size = const Size(1200, 1000),
      double scale = 1,
      bool edgeReady = false,
      Map<String, dynamic>? edgeFields,
      bool hasPatient = true,
      bool cachedPatients = false,
      bool modelReady = true,
      bool cancelImage = false,
      String edgeLabel = 'Normal',
      Object? edgeError,
      bool invalidEdge = false,
      bool rejectedEdge = false,
      bool failRelease = false,
      bool fallbackEnabled = true,
      ValueChanged<String>? onDeviceRequest,
      bool prepareImage = true,
      Completer<http.Response>? pendingEdge}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final manager = EdgeDeviceManager(
        client: EdgeDeviceClient(
            config: const EdgeDeviceConfig(baseUrl: 'http://dawa.local'),
            httpClient: MockClient((request) async {
              onDeviceRequest?.call(request.url.path);
              if (edgeReady) {
                if (request.url.path == '/predict' ||
                    request.url.path == '/upload/cervical') {
                  if (pendingEdge != null) return pendingEdge.future;
                  if (edgeError != null) throw edgeError;
                  return http.Response(
                      jsonEncode(invalidEdge
                          ? {'bad': true}
                          : {
                              'classification': edgeLabel,
                              'confidence': .9,
                              'gatekeeper_flagged': rejectedEdge,
                              ...?edgeFields,
                            }),
                      rejectedEdge ? 422 : 200);
                }
                if (request.url.path == '/api/exam/start')
                  return http.Response(
                      '{"exam_id":"test-lock","ttl_s":120}', 201);
                if (request.url.path == '/api/exam/end') {
                  if (failRelease) {
                    failRelease = false;
                    throw http.ClientException('release failure');
                  }
                  return http.Response('{"ended":true}', 200);
                }
                return http.Response(
                    jsonEncode({
                      'active': 'cervitriage',
                      'state': modelReady ? 'ready' : 'error',
                      'ready': modelReady,
                      'modules': {'cervitriage': {}}
                    }),
                    200);
              }
              expect(request.url.path, '/api/status',
                  reason:
                      'An offline cloud flow must not submit to or lock the device.');
              throw http.ClientException('Synthetic disconnected device');
            })));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      manager.dispose();
    });
    await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            fontFamily: 'NavigationQA',
            colorSchemeSeed: const Color(0xFF223F91)),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: CaCxApp(
            allowOnlineFallback: fallbackEnabled,
            deviceManager: manager,
            patientRepository: cachedPatients ? null : _Patients(hasPatient),
            initialPatient: hasPatient
                ? Patient(
                    id: 'patient-1',
                    name: 'Synthetic Patient',
                    age: 30,
                    contact: '',
                    status: PatientStatus.untested,
                    riskLevel: RiskLevel.low)
                : null,
            pickImage: () async => cancelImage ? null : image,
            checkConnectivity: () async => OfflineConnectivitySnapshot(
                internetAvailable: internet,
                supabaseReachable: internet,
                deviceReachable: false,
                checkedAt: DateTime.utc(2026, 11, 12)),
            requestSecondOpinion: cloud)));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Screening'));
    await tester.pumpAndSettle();
    if (prepareImage) {
      await tester.tap(find.text('Choose image'));
      await tester.pumpAndSettle();
      expect(find.text('Analyze image'),
          cancelImage ? findsNothing : findsOneWidget);
    }
    return manager;
  }

  testWidgets(
      'offline device and internet allow saving a captured scan for later',
      (tester) async {
    await pump(tester,
        internet: false,
        edgeReady: false,
        cloud: (_) async => throw StateError('Offline analysis must not run'));
    final save = find.widgetWithText(OutlinedButton, 'Save scan for later');
    await tester.ensureVisible(save);
    expect(tester.widget<OutlinedButton>(save).onPressed, isNotNull);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Analyze image'))
            .onPressed,
        isNotNull);
  });

  Future<void> approve(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Analyze image'));
    await tester.tap(find.text('Analyze image'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'returned cervical model details are visible on narrow and wide screens',
      (tester) async {
    for (final width in [390.0, 1440.0]) {
      await pump(tester,
          size: Size(width, 1200),
          edgeReady: true,
          edgeFields: {
            'probabilities': {'Normal': .9, 'High Risk': .1},
            'record_id': 'edge-reference-42',
            'timings_ms': {'inference': 135},
            'message': 'Image accepted'
          },
          cloud: (_) async => throw StateError('Must stay local'));
      await approve(tester);
      expect(find.text('Screening details'), findsOneWidget);
      expect(find.text('Local Dawa device output'), findsOneWidget);
      expect(find.text('edge-reference-42'), findsOneWidget);
      expect(find.text('Image accepted'), findsOneWidget);
      expect(find.text('Image suitability check'), findsOneWidget);
      expect(find.text('2 classes'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });

  for (final width in [834.0, 1440.0]) {
    testWidgets(
        'clinician can review all returned class scores without another analysis at ${width.toInt()}px',
        (tester) async {
      var analyses = 0;
      await pump(tester, size: Size(width, 1200), cloud: (_) async {
        analyses++;
        return AnalysisResult(
            imageUrl: image,
            label: 'Normal / Negative VIA',
            confidence: 60,
            suspicionLevel: SuspicionLevel.low,
            recommendation: 'Synthetic review guidance',
            predictionBreakdown: [
              const PredictionBreakdownItem(
                  label: 'Normal',
                  confidence: 60,
                  riskLevel: 'low',
                  isTopPrediction: true),
              const PredictionBreakdownItem(
                  label: 'CIN1',
                  confidence: 20,
                  riskLevel: 'medium',
                  isTopPrediction: false),
              const PredictionBreakdownItem(
                  label: 'CIN2',
                  confidence: 10,
                  riskLevel: 'high',
                  isTopPrediction: false),
              const PredictionBreakdownItem(
                  label: 'CIN3',
                  confidence: 5,
                  riskLevel: 'high',
                  isTopPrediction: false),
              const PredictionBreakdownItem(
                  label: 'Cancer',
                  confidence: 4,
                  riskLevel: 'high',
                  isTopPrediction: false),
              const PredictionBreakdownItem(
                  label: 'Other',
                  confidence: 1,
                  riskLevel: null,
                  isTopPrediction: false),
            ]);
      });
      await approve(tester);
      expect(find.text('6 classes'), findsWidgets);
      expect(find.text('60.0%'), findsWidgets);
      if (width < 1024) {
        expect(find.text('CIN3'), findsNothing);
        await tester.ensureVisible(find.text('Show all 6'));
        await tester.tap(find.text('Show all 6'));
        await tester.pumpAndSettle();
        expect(find.text('CIN3'), findsOneWidget);
        expect(find.text('Other / Unknown'), findsOneWidget);
        await tester.ensureVisible(find.text('Show top 3'));
        await tester.tap(find.text('Show top 3'));
        await tester.pumpAndSettle();
        expect(find.text('CIN3'), findsNothing);
      } else {
        expect(find.text('CIN3'), findsOneWidget);
        expect(find.text('Show all 6'), findsNothing);
      }
      expect(analyses, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'a silent cervical device falls back after one minute and ignores a late result',
      (tester) async {
    var onlineCalls = 0;
    final pending = Completer<http.Response>();
    await pump(tester, edgeReady: true, pendingEdge: pending, cloud: (_) async {
      onlineCalls++;
      return result();
    });
    await tester.ensureVisible(find.text('Analyze image'));
    await tester.tap(find.text('Analyze image'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 59));
    expect(onlineCalls, 0);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(onlineCalls, 1);
    expect(find.text('Analysed online (device unavailable)'), findsWidgets);
    pending.complete(
        http.Response('{"classification":"CIN3","confidence":0.95}', 200));
    await tester.pumpAndSettle();
    expect(onlineCalls, 1);
    expect(find.text('Analysed online (device unavailable)'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new screening keeps patient, image, and analysis distinct',
      (tester) async {
    await pump(
      tester,
      prepareImage: false,
      cloud: (_) async => result(),
    );

    expect(find.text('Back to overview'), findsOneWidget);
    expect(find.text('1. Select patient'), findsOneWidget);
    expect(find.text('2. Prepare cervical image'), findsOneWidget);
    expect(find.text('3. AI-assisted analysis'), findsOneWidget);
    expect(find.text('Synthetic Patient'), findsOneWidget);
    expect(find.text('Choose or capture an image before continuing.'),
        findsOneWidget);
    expect(find.text('Use online second opinion'), findsNothing);
    if (const bool.fromEnvironment('CAPTURE_CACX_PHASE7')) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
            '../docs/qa/phase7/cacx-screening-workspace-desktop.png'),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'offline device automatically uses online once and preserves the patient',
      (tester) async {
    var calls = 0;
    await pump(tester, cloud: (selected) async {
      expect(selected, image);
      calls++;
      return result();
    });
    expect(calls, 0);
    expect(writes, isEmpty);
    await approve(tester);
    expect(calls, 1);
    expect(writes.first['patient_id'], 'patient-1');
    expect(writes.first['device_status'], 'failed');
    expect(writes.last['second_opinion_status'], 'completed');
    expect(writes.last['second_opinion_required'], true);
    expect(find.text('Analysis Results'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('an in-flight online request cannot be submitted twice',
      (tester) async {
    final pending = Completer<AnalysisResult>();
    var calls = 0;
    await pump(tester, cloud: (_) {
      calls++;
      return pending.future;
    });
    await tester.tap(find.text('Analyze image'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(calls, 1);
    final button = find.widgetWithText(FilledButton, 'Analyze image');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.tap(find.text('Analyze image'), warnIfMissed: false);
    await tester.pump();
    expect(calls, 1);
    pending.complete(result());
    await tester.pumpAndSettle();
    expect(find.text('Analysis Results'), findsOneWidget);
  });

  testWidgets(
      'offline scans use the edge device and queue results without cloud or database writes',
      (tester) async {
    final previousUser = currentUser;
    currentUser = ClinicianCachedUser(CachedAuthSession(
        uid: 'clinician-offline',
        email: 'offline@example.test',
        cachedAt: DateTime.now()));
    final previousStatus = OfflineConnectivityService.statusNotifier.value;
    OfflineConnectivityService.statusNotifier.value =
        OfflineConnectivitySnapshot(
            internetAvailable: false,
            supabaseReachable: false,
            deviceReachable: true,
            checkedAt: DateTime.now());
    addTearDown(() {
      currentUser = previousUser;
      OfflineConnectivityService.statusNotifier.value = previousStatus;
    });
    await SupabaseScreeningPatientRepository.cachePatients(
        'clinician-offline', [
      {'id': 'patient-1', 'name': 'Synthetic Patient'}
    ]);
    var cloudCalls = 0;
    var deviceCalls = 0;
    await pump(tester, internet: false, edgeReady: true, cachedPatients: true,
        onDeviceRequest: (path) {
      if (path == '/predict' || path == '/upload/cervical') deviceCalls++;
    }, cloud: (_) async {
      cloudCalls++;
      return result();
    });
    final beforeWrites = writes.length;
    await tester.ensureVisible(find.text('Analyze image'));
    await tester.tap(find.text('Analyze image'));
    await tester.pumpAndSettle();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(deviceCalls, 1);
    expect(cloudCalls, 0);
    expect(writes.length, beforeWrites);
    expect(await CacxScreeningResultsRepository.pendingCount(), 1);
    expect(find.text('Analysis Results'), findsOneWidget);
  });

  testWidgets('cloud exception stays retryable without automatic retry loops',
      (tester) async {
    var calls = 0;
    await pump(tester, cloud: (_) async {
      if (++calls == 1) throw http.ClientException('failed');
      return result();
    });
    await approve(tester);
    expect(find.text('Online second opinion unavailable'), findsOneWidget);
    expect(find.text('Analysis Results'), findsNothing);
    expect(calls, 1);
    await approve(tester);
    expect(calls, 2);
    expect(find.text('Analysis Results'), findsOneWidget);
  });
  testWidgets('failed cloud response does not present a successful diagnosis',
      (tester) async {
    await pump(tester,
        cloud: (_) async => AnalysisResult(
            imageUrl: image,
            label: 'Analysis Failed',
            confidence: 0,
            suspicionLevel: SuspicionLevel.low,
            recommendation: 'Synthetic failure',
            error: 'Unavailable'));
    await approve(tester);
    expect(find.text('Analysis Results'), findsNothing);
    expect(find.text('Second opinion failed - manual review required'),
        findsOneWidget);
    expect(writes.last['second_opinion_status'], 'failed');
  });
  testWidgets('a completed but unsaved cloud result is explicitly marked',
      (tester) async {
    var calls = 0;
    await pump(tester, cloud: (_) async {
      calls++;
      failSave = true;
      return result();
    });
    await approve(tester);
    expect(find.text('Analysis Results'), findsOneWidget);
    expect(find.textContaining('result could not be saved'), findsWidgets);
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
    expect(find.textContaining('second opinion has not been saved'),
        findsOneWidget);
    failSave = false;
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
    expect(calls, 1,
        reason: 'Retrying persistence must not resubmit the clinical image.');
    expect(find.text('Record Saved Successfully!'), findsOneWidget);
    expect(writes.last['second_opinion_status'], 'completed');
  });

  for (final label in ['Normal', 'High Risk']) {
    testWidgets('completed edge $label result never runs online',
        (tester) async {
      var online = 0, edge = 0;
      await pump(tester, edgeReady: true, edgeLabel: label,
          onDeviceRequest: (path) {
        if (path == '/predict' || path == '/upload/cervical') edge++;
      }, cloud: (_) async {
        online++;
        return result();
      });
      await approve(tester);
      expect(edge, 1);
      expect(online, 0);
      expect(find.text('Analysed on Dawa device'), findsWidgets);
      expect(writes.first['second_opinion_required'], false);
    });
  }
  for (final failure in [
    TimeoutException('synthetic timeout'),
    http.ClientException('unreachable')
  ]) {
    testWidgets('edge ${failure.runtimeType} falls back once', (tester) async {
      var online = 0, edge = 0;
      await pump(tester, edgeReady: true, edgeError: failure,
          onDeviceRequest: (path) {
        if (path == '/predict' || path == '/upload/cervical') edge++;
      }, cloud: (_) async {
        online++;
        return result();
      });
      await approve(tester);
      expect(edge, 1);
      expect(online, 1);
      expect(find.text('Analysed online (device unavailable)'), findsWidgets);
    });
  }
  for (final rejected in [false, true]) {
    testWidgets('edge validation or rejection ($rejected) does not fall back',
        (tester) async {
      var online = 0;
      await pump(tester,
          edgeReady: true,
          invalidEdge: !rejected,
          rejectedEdge: rejected, cloud: (_) async {
        online++;
        return result();
      });
      await approve(tester);
      expect(online, 0);
      expect(find.text('Analysis Results'), findsNothing);
    });
  }
  testWidgets(
      'completed edge result survives failed session release without online',
      (tester) async {
    var online = 0;
    final manager = await pump(tester, edgeReady: true, failRelease: true,
        cloud: (_) async {
      online++;
      return result();
    });
    await approve(tester);
    expect(online, 0);
    expect(find.text('Analysis Results'), findsOneWidget);
    expect(manager.activeExaminationId, isNotNull);
    await manager.completeExamination(manager.activeExaminationId!);
  });
  testWidgets('configuration disables online fallback', (tester) async {
    var online = 0;
    await pump(tester, fallbackEnabled: false, cloud: (_) async {
      online++;
      return result();
    });
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Analyze image'))
            .onPressed,
        isNotNull);
    await approve(tester);
    expect(online, 0);
  });

  testWidgets('model initialization failure uses online without edge inference',
      (tester) async {
    var online = 0, predictions = 0;
    await pump(tester, edgeReady: true, modelReady: false,
        onDeviceRequest: (path) {
      if (path.contains('upload')) predictions++;
    }, cloud: (_) async {
      online++;
      return result();
    });
    await approve(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(online, 1);
    expect(predictions, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
  testWidgets('cancelled image selection sends nothing', (tester) async {
    var online = 0;
    await pump(tester, cancelImage: true, cloud: (_) async {
      online++;
      return result();
    });
    expect(online, 0);
    expect(writes, isEmpty);
    expect(find.text('Analyze image'), findsNothing);
  });
  testWidgets('edge timeout and online failure end without a retry loop',
      (tester) async {
    var online = 0, predictions = 0;
    await pump(tester, edgeReady: true, edgeError: TimeoutException('timeout'),
        onDeviceRequest: (path) {
      if (path.contains('upload')) predictions++;
    }, cloud: (_) async {
      online++;
      throw http.ClientException('server failure');
    });
    await approve(tester);
    expect(online, 1);
    expect(predictions, 1);
    expect(find.text('Analysis Results'), findsNothing);
    expect(find.text('Analyze image'), findsOneWidget);
  });

  testWidgets('missing patient keeps Analyze disabled and sends nothing',
      (tester) async {
    var online = 0;
    await pump(tester, hasPatient: false, cloud: (_) async {
      online++;
      return result();
    });
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Analyze image'))
            .onPressed,
        isNull);
    expect(online, 0);
    expect(writes, isEmpty);
  });

  for (final desktop in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      for (final kind in ['consent', 'image-source']) {
        testWidgets(
            '$kind modal fits ${desktop ? 'desktop' : 'mobile'} with text scale $scale',
            (tester) async {
          tester.view.physicalSize =
              desktop ? const Size(1280, 900) : const Size(320, 520);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                  fontFamily: 'NavigationQA',
                  colorSchemeSeed: const Color(0xFF223F91)),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: Builder(
                  builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => kind == 'consent'
                                  ? const CacxSecondOpinionDialog(
                                      reason: 'The Dawa hub is disconnected.',
                                      canRetry: true)
                                  : ImageSourcePickerDialogWidget(
                                      title: 'Select image source',
                                      subtitle:
                                          'Choose a camera or an existing image.',
                                      takePhotoLabel: 'Take photo',
                                      takePhotoSubtitle: 'Use the camera',
                                      uploadLabel: 'Upload image',
                                      uploadSubtitle: 'Choose an image',
                                      onTakePhoto: () async {},
                                      onUploadImage: () async {})),
                          child: const Text('Open'))))));
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('CAPTURE_CACX_MODAL_QA')) {
            await expectLater(
                find.byType(MaterialApp),
                matchesGoldenFile(
                    '../docs/qa/second-opinion/$kind-${desktop ? 'desktop-' : ''}$scale.png'));
          }
          final close = find.text(kind == 'consent' ? 'Do not send' : 'Cancel');
          await tester.ensureVisible(close);
          await tester.tap(close);
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsNothing);
        });
      }
    }
  }

  testWidgets(
      'image selection prevents duplicate callbacks while a picker is pending',
      (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: ImageSourcePickerDialogWidget(
            title: 'Select image',
            subtitle: 'Synthetic picker',
            takePhotoLabel: 'Camera',
            takePhotoSubtitle: 'Camera source',
            uploadLabel: 'Gallery',
            uploadSubtitle: 'Gallery source',
            onTakePhoto: () async {
              calls++;
              await pending.future;
            },
            onUploadImage: () async {
              calls++;
            })));
    await tester.tap(find.text('Camera'));
    await tester.pump();
    await tester.tap(find.text('Camera'));
    await tester.tap(find.text('Gallery'));
    await tester.pump();
    expect(calls, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
