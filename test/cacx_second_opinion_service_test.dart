import 'dart:convert';
import 'package:clinician/application/cacx/cacx_second_opinion_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const image = 'data:image/png;base64,AAECAw==';
  test(
      'online service uses its existing upload, prediction and completion protocol',
      () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      expect(request.url.host, 'kmunzwa-medsiglip-demo.hf.space');
      paths.add(request.url.path);
      if (request.url.path == '/gradio_api/upload') {
        final multipart = latin1.decode(request.bodyBytes);
        expect(multipart, contains('image/png'));
        expect(multipart, isNot(contains('patient_id')));
        return http.Response('["/tmp/synthetic/image.png"]', 200);
      }
      if (request.method == 'POST') {
        final payload = jsonDecode(request.body) as Map;
        expect((payload['data'] as List).single['path'],
            '/tmp/synthetic/image.png');
        return http.Response('{"event_id":"synthetic-event"}', 200);
      }
      return http.Response(
          'event: heartbeat\ndata: null\n\nevent: complete\ndata: [{"label":"negative","confidences":[{"label":"negative","confidence":0.9},{"label":"positive","confidence":0.1}]}]\n\n',
          200);
    });
    final result =
        await HuggingFaceService.analyzeVIAImage(image, httpClient: client);
    expect(result.error, isNull);
    expect(result.label, 'Normal / Negative VIA');
    expect(result.confidence, 90);
    expect(result.rawOutput?['confidences'], hasLength(2));
    expect(result.imageUrl, image);
    expect(paths, [
      '/gradio_api/upload',
      '/gradio_api/call/predict',
      '/gradio_api/call/predict/synthetic-event'
    ]);
  });
  for (final failure in [
    'upload-error',
    'prediction-error',
    'invalid-result',
    'sse-error',
    'transport-error'
  ]) {
    test('$failure returns an explicit failure without replaying the image',
        () async {
      var uploads = 0;
      final client = MockClient((request) async {
        if (failure == 'transport-error')
          throw http.ClientException('Unavailable');
        if (request.url.path == '/gradio_api/upload') {
          uploads++;
          return http.Response(
              failure == 'upload-error'
                  ? 'unavailable'
                  : '["/tmp/synthetic.png"]',
              failure == 'upload-error' ? 503 : 200);
        }
        if (request.method == 'POST')
          return http.Response(
              failure == 'prediction-error'
                  ? 'unavailable'
                  : '{"event_id":"event"}',
              failure == 'prediction-error' ? 503 : 200);
        return http.Response(
            failure == 'sse-error'
                ? 'event: error\ndata: "unavailable"\n\n'
                : 'event: complete\ndata: [{}]\n\n',
            200);
      });
      final result =
          await HuggingFaceService.analyzeVIAImage(image, httpClient: client);
      expect(result.error, isNotNull);
      expect(result.label, 'Analysis Failed');
      expect(uploads, lessThanOrEqualTo(1));
      expect(result.error, isNot(contains('/tmp/')));
    });
  }
}
