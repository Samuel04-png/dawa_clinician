import 'dart:convert';
import 'dart:typed_data';

import 'package:clinician/flutter_flow/uploaded_file.dart';

import 'package:clinician/backend/api_requests/api_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('query encoding preserves identifiers and existing query parameters',
      () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.queryParameters, {'page': '2', 'ref': 'QA + 4/7'});
      expect(request.headers['x-count'], '3');
      return http.Response('{"records":[]}', 200);
    });
    final response = await ApiManager.instance.makeApiCall(
        callName: 'registry',
        apiUrl: 'https://unit.invalid/records?page=2',
        callType: ApiCallType.GET,
        params: {'ref': 'QA + 4/7'},
        headers: {'x-count': 3},
        client: client);
    expect(response.succeeded, isTrue);
    expect(response.jsonBody, {'records': []});
  });

  for (final method in [
    ApiCallType.POST,
    ApiCallType.PUT,
    ApiCallType.PATCH,
    ApiCallType.DELETE
  ]) {
    test('$method sends the supplied JSON and preserves server rejection',
        () async {
      final client = MockClient((request) async {
        expect(request.method, method.name);
        expect(request.headers['content-type'], contains('application/json'));
        expect(jsonDecode(request.body), {'patient_id': 'synthetic-id'});
        return http.Response('{"error":"not authorized"}', 403,
            headers: {'x-request-id': 'qa-request'});
      });
      final response = await ApiManager.instance.makeApiCall(
          callName: 'save',
          apiUrl: 'unit.invalid/save',
          callType: method,
          headers: <String, dynamic>{},
          params: {'patient_id': 'synthetic-id'},
          bodyType: BodyType.JSON,
          alwaysAllowBody: true,
          client: client);
      expect(response.succeeded, isFalse);
      expect(response.statusCode, 403);
      expect(response.getHeader('x-request-id'), 'qa-request');
      expect(response.getHeader('absent'), isEmpty);
      expect(jsonDecode(response.bodyText), {'error': 'not authorized'});
    });
  }

  test('transport failures retain an exception and never become success',
      () async {
    final response = await ApiManager.instance.makeApiCall(
        callName: 'unreachable',
        apiUrl: 'https://unit.invalid',
        callType: ApiCallType.GET,
        client: MockClient((_) async => throw http.ClientException('offline')));
    expect(response.statusCode, -1);
    expect(response.succeeded, isFalse);
    expect(response.exception, isA<http.ClientException>());
    expect(response.exceptionMessage, contains('offline'));
  });

  test(
      'cache keys include parameters and clearCache invalidates the named call',
      () async {
    var requests = 0;
    final client = MockClient(
        (_) async => http.Response('{"version":${++requests}}', 200));
    final options = ApiCallOptions(
        callName: 'cache-qa',
        callType: ApiCallType.GET,
        apiUrl: 'https://unit.invalid',
        headers: {},
        params: {'patient': 'one'},
        cache: true);
    ApiManager.clearCache('cache-qa');
    final first = await ApiManager.instance.call(options, client: client);
    expect(
        (await ApiManager.instance.call(options.clone(), client: client))
            .jsonBody,
        first.jsonBody);
    expect(requests, 1);
    await ApiManager.instance
        .call(options.copyWith(params: {'patient': 'two'}), client: client);
    expect(requests, 2);
    ApiManager.clearCache('unrelated');
    await ApiManager.instance.call(options, client: client);
    expect(requests, 2);
    ApiManager.clearCache('cache-qa');
    await ApiManager.instance.call(options, client: client);
    expect(requests, 3);
  });

  test('body encodings honor an explicit content type and UTF-8 text', () {
    final headers = <String, dynamic>{'content-type': 'application/custom'};
    expect(
        utf8.decode(
            ApiManager.createBody(headers, null, 'café', BodyType.TEXT, true)),
        'café');
    expect(headers, {'content-type': 'application/custom'});
    expect(
        ApiManager.createBody(
            {}, {'n': 2}, null, BodyType.X_WWW_FORM_URL_ENCODED, false),
        {'n': '2'});
    expect(ApiManager.createBody({}, {'n': 2}, null, BodyType.MULTIPART, false),
        {'n': 2});
    expect(ApiManager.createBody({}, null, null, BodyType.NONE, false), isNull);
    expect(ApiManager.createBody({}, null, null, BodyType.JSON, false), '{}');
  });

  for (final status in [201, 503]) {
    test('multipart upload preserves image bytes and server status $status',
        () async {
      var requests = 0;
      final client = MockClient.streaming((request, body) async {
        requests++;
        expect(request.method, 'POST');
        expect(request, isA<http.MultipartRequest>());
        final multipart = request as http.MultipartRequest;
        expect(multipart.fields, {'patient_id': 'synthetic-patient'});
        expect(multipart.files.map((file) => file.field),
            ['image', 'attachments']);
        expect(multipart.files.first.filename, 'screening.png');
        expect(multipart.files.first.contentType.toString(), 'image/png');
        final encoded = await body.toBytes();
        expect(latin1.decode(encoded), contains('synthetic-image-bytes'));
        return http.StreamedResponse(
            Stream.value(utf8.encode('{"stored":${status == 201}}')), status);
      });
      final result = await http.runWithClient(
          () => ApiManager.instance.makeApiCall(
                callName: 'synthetic-upload',
                apiUrl: 'https://unit.invalid/upload',
                callType: ApiCallType.POST,
                headers: <String, dynamic>{},
                bodyType: BodyType.MULTIPART,
                params: {
                  'patient_id': 'synthetic-patient',
                  'image': FFUploadedFile(
                      name: 'screening.png',
                      bytes: Uint8List.fromList(
                          utf8.encode('synthetic-image-bytes'))),
                  'attachments': [
                    const FFUploadedFile(name: 'note.unknown-extension')
                  ],
                },
              ),
          () => client);
      expect(requests, 1);
      expect(result.statusCode, status);
      expect(result.succeeded, status == 201);
      expect(result.jsonBody, {'stored': status == 201});
    });
  }

  test('response decoding handles non-JSON and omitted response bodies', () {
    final text = ApiCallResponse.fromHttpResponse(
        http.Response('maintenance', 503), true, false);
    expect(text.jsonBody, isNull);
    expect(text.bodyText, 'maintenance');
    expect(text.succeeded, isFalse);
    final omitted = ApiCallResponse.fromHttpResponse(
        http.Response('{"ok":true}', 204), false, true);
    expect(omitted.jsonBody, isNull);
    expect(omitted.succeeded, isTrue);
    final cloud = ApiCallResponse.fromCloudCallResponse({
      'body': {'ok': true},
      'headers': {'attempt': 2},
      'statusCode': 201
    });
    expect(cloud.getHeader('attempt'), '2');
    expect(cloud.bodyText, '{"ok":true}');
    expect(cloud.copyWith(statusCode: 500).succeeded, isFalse);
    expect(
        cloud.copyWith(jsonBody: 'updated', headers: {}).bodyText, 'updated');
  });
}
