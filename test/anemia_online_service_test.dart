import 'dart:async';
import 'dart:convert';
import 'package:clinician/application/hemonix/models/anemia_result.dart';
import 'package:clinician/application/hemonix/services/anemia_analysis_service.dart';
import 'package:clinician/application/hemonix/services/anemia_online_service.dart';
import 'package:clinician/services/edge_device/edge_device_exceptions.dart';
import 'package:clinician/services/edge_device/edge_image_input.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final image = EdgeImageInput.fromBytes(base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='));
Map<String, dynamic> labelOutput() => {
      'label': 'Mild Anemia',
      'confidences': [
        {'label': 'No Anemia', 'confidence': .2},
        {'label': 'Mild Anemia', 'confidence': .4},
        {'label': 'Moderate Anemia', 'confidence': .3},
        {'label': 'Severe Anemia', 'confidence': .1},
      ]
    };

void main() {
  test('only infrastructure failures permit fallback', () {
    for (final failure in EdgeDeviceFailure.values) {
      for (final status in [null, 401, 403, 409, 422, 500, 503]) {
        expect(
            anemiaAllowsOnlineFailure(EdgeDeviceException(
                failure: failure,
                message: 'internal-only',
                statusCode: status)),
            {
                  EdgeDeviceFailure.connection,
                  EdgeDeviceFailure.timeout,
                  EdgeDeviceFailure.modelInitialization
                }.contains(failure) ||
                failure == EdgeDeviceFailure.http &&
                    status != null &&
                    status >= 500,
            reason: '$failure HTTP $status');
      }
    }
  });

  test(
      'published Space API preserves image and validates probabilities and provenance',
      () async {
    final paths = <String>[];
    final service = AnemiaOnlineService(httpClient: MockClient((request) async {
      paths.add(request.url.path);
      expect(request.url.host, 'kmunzwa-anemia-screening.hf.space');
      expect(latin1.decode(request.bodyBytes), isNot(contains('patient_id')));
      expect(latin1.decode(request.bodyBytes), isNot(contains('review_notes')));
      if (paths.length == 1) {
        expect(
            request.headers['content-type'], contains('multipart/form-data'));
        expect(request.bodyBytes, containsAllInOrder(image.bytes));
        return http.Response('["/tmp/synthetic-anemia.png"]', 200);
      }
      if (paths.length == 2) {
        expect(jsonDecode(request.body), {
          'image': {
            'path': '/tmp/synthetic-anemia.png',
            'meta': {'_type': 'gradio.FileData'}
          }
        });
        return http.Response('{"event_id":"synthetic-event"}', 200);
      }
      return http.Response(
          'event: heartbeat\r\ndata: null\r\n\r\nevent: complete\r\ndata: ${jsonEncode([
                labelOutput()
              ])}\r\n\r\n',
          200);
    }));
    final result = await service.analyze(
        image: image,
        examinationId: 'synthetic-exam',
        timeout: const Duration(seconds: 1));
    expect(paths, [
      '/gradio_api/upload',
      '/gradio_api/call/v2/predict_anaemia',
      '/gradio_api/call/predict_anaemia/synthetic-event'
    ]);
    expect(result.classification, 'Mild Anemia');
    expect(result.confidence, .4);
    expect(result.isOnline, isTrue);
    expect(result.disclaimer, AnemiaResult.prototypeNotice);
    expect(result.deviceId, 'online:kmunzwa-anemia-screening.hf.space');
    final reopened = AnemiaResult.fromDeviceJson(result.toDeviceJson(),
        examinationId: result.examinationId, deviceId: result.deviceId);
    expect(reopened.onlineServiceUrl, result.onlineServiceUrl);
    expect(reopened.probabilities, result.probabilities);
    expect(reopened.isOnline, isTrue);
    for (final corrupt in [
      {...result.toDeviceJson(), 'service_url': 'http://untrusted.invalid'},
      {...result.toDeviceJson(), 'analysis_provider': 'invented'},
      {...result.toDeviceJson(), 'analysis_provider': null},
    ]) {
      expect(
          () => AnemiaResult.fromDeviceJson(corrupt,
              examinationId: result.examinationId, deviceId: result.deviceId),
          throwsFormatException);
    }
  });

  for (final stage in [1, 2, 3]) {
    test(
        'server failure at stage $stage stops once and returns a readable recovery message',
        () async {
      var calls = 0;
      final service =
          AnemiaOnlineService(httpClient: MockClient((request) async {
        calls++;
        if (calls == stage)
          return http.Response('RAW_STACK_TRACE_PRIVATE_PATH', 503);
        return http.Response(
            calls == 1 ? '["/tmp/synthetic.png"]' : '{"event_id":"event"}',
            200);
      }));
      await expectLater(
          service.analyze(
              image: image,
              examinationId: 'exam',
              timeout: const Duration(seconds: 1)),
          throwsA(isA<AnemiaOnlineException>().having(
              (e) => e.message,
              'readable recovery',
              allOf(
                  contains('try again'), isNot(contains('RAW_STACK_TRACE'))))));
      expect(calls, stage);
    });
  }

  for (final invalid in <String, dynamic>{
    'missing classes': {'label': 'Mild Anemia', 'confidences': []},
    'invented label': {...labelOutput(), 'label': 'Healthy'},
    'duplicate class': {
      'label': 'Mild Anemia',
      'confidences': List.filled(4, {'label': 'Mild Anemia', 'confidence': .25})
    },
    'inconsistent outcome': {...labelOutput(), 'label': 'Severe Anemia'},
    'invalid value': {
      'label': 'Mild Anemia',
      'confidences': [
        for (final name in AnemiaResult.classes)
          {'label': name, 'confidence': -1}
      ]
    },
    'wrong shape': 'not a prediction',
  }.entries) {
    test('rejects ${invalid.key} without producing a clinical result',
        () async {
      var calls = 0;
      final service = AnemiaOnlineService(httpClient: MockClient((_) async {
        calls++;
        return http.Response(
            switch (calls) {
              1 => '["/tmp/synthetic.png"]',
              2 => '{"event_id":"event"}',
              _ => 'event: complete\ndata: ${jsonEncode([invalid.value])}\n\n'
            },
            200);
      }));
      await expectLater(
          service.analyze(
              image: image,
              examinationId: 'exam',
              timeout: const Duration(seconds: 1)),
          throwsA(isA<AnemiaOnlineException>()));
      expect(calls, 3);
    });
  }

  test('missing reference or cancellation never uploads an image', () async {
    var calls = 0;
    final service = AnemiaOnlineService(httpClient: MockClient((_) async {
      calls++;
      return http.Response('', 500);
    }));
    await expectLater(
        service.analyze(
            image: image,
            examinationId: '',
            timeout: const Duration(seconds: 1)),
        throwsFormatException);
    await expectLater(
        service.analyze(
            image: image,
            examinationId: 'exam',
            timeout: const Duration(seconds: 1),
            isCancelled: () => true),
        throwsA(isA<AnemiaAnalysisCancelled>()));
    expect(calls, 0);
  });

  test('navigation cancellation after upload prevents model invocation',
      () async {
    var cancelled = false, calls = 0;
    final service = AnemiaOnlineService(httpClient: MockClient((_) async {
      calls++;
      cancelled = true;
      return http.Response('["/tmp/synthetic.png"]', 200);
    }));
    await expectLater(
        service.analyze(
            image: image,
            examinationId: 'exam',
            timeout: const Duration(seconds: 1),
            isCancelled: () => cancelled),
        throwsA(isA<AnemiaAnalysisCancelled>()));
    expect(calls, 1);
  });

  test('timeout ends one attempt without a polling or retry loop', () async {
    var calls = 0;
    final gate = Completer<http.Response>();
    final service = AnemiaOnlineService(httpClient: MockClient((_) {
      calls++;
      return gate.future;
    }));
    await expectLater(
        service.analyze(
            image: image,
            examinationId: 'exam',
            timeout: const Duration(milliseconds: 10)),
        throwsA(isA<AnemiaOnlineException>()));
    gate.complete(http.Response('', 503));
    expect(calls, 1);
  });

  test('real Space accepts one synthetic image through the Flutter service',
      () async {
    final result = await const AnemiaOnlineService().analyze(
        image: image,
        examinationId: 'synthetic-connectivity-check',
        timeout: const Duration(seconds: 120));
    expect(result.isOnline, isTrue);
    expect(AnemiaResult.classes, contains(result.classification));
  },
      skip: !const bool.fromEnvironment('RUN_LIVE_ANEMIA_ONLINE_CHECK'),
      timeout: const Timeout(Duration(seconds: 135)));
}
