import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/edge_dev_proxy.dart';

const _origin = 'http://localhost:5000';

void main() {
  late HttpServer device;
  late EdgeDevProxy proxy;
  late HttpClient client;
  late int proxyPort;
  List<int>? receivedBody;
  String? receivedType;
  int? receivedLength;
  var deviceHits = 0;

  setUpAll(() async {
    HttpOverrides.global = null;
    device = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    device.listen((req) async {
      deviceHits++;
      if (req.uri.path == '/predict') {
        receivedType = req.headers.contentType?.toString();
        receivedLength = req.contentLength;
        receivedBody = await req.fold<List<int>>([], (a, b) => a..addAll(b));
        req.response.statusCode =
            req.uri.queryParameters['fail'] == '1' ? 422 : 200;
        req.response.write('{"ok":true}');
      } else {
        req.response.write('{"active":"cervitriage"}');
      }
      await req.response.close();
    });
    // Listen on a free port, forwarding to the fake device's port.
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    proxyPort = probe.port;
    await probe.close();
    proxy = await EdgeDevProxy.start(
      device: '127.0.0.1',
      allowOrigin: _origin,
      portMap: {proxyPort: device.port},
      portRoutes: {
        device.port: {
          '/api/status',
          '/api/select',
          '/predict',
          '/health',
          '/api/exam/start',
          '/api/exam/heartbeat',
          '/api/exam/end',
          '/api/stop',
        },
      },
    );
    client = HttpClient();
  });

  tearDownAll(() async {
    client.close(force: true);
    await proxy.close();
    await device.close(force: true);
  });

  Future<HttpClientResponse> send(
    String method,
    String path, {
    String? origin = _origin,
    Map<String, String> headers = const {},
    List<int>? body,
    ContentType? type,
  }) async {
    final req = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:$proxyPort$path'),
    );
    if (origin != null) req.headers.set('origin', origin);
    headers.forEach(req.headers.set);
    if (type != null) req.headers.contentType = type;
    if (body != null) {
      req.contentLength = body.length;
      req.add(body);
    }
    return req.close();
  }

  Future<String> text(HttpClientResponse r) => utf8.decodeStream(r);

  test('preflight for POST /predict is answered with CORS + PNA headers',
      () async {
    final before = deviceHits;
    final r = await send('OPTIONS', '/predict', headers: {
      'access-control-request-method': 'POST',
    });
    await text(r);
    expect(r.statusCode, 204);
    expect(r.headers.value('access-control-allow-origin'), _origin);
    expect(r.headers.value('access-control-allow-private-network'), 'true');
    expect(r.headers.value('access-control-allow-methods'), 'POST');
    expect(deviceHits, before, reason: 'preflight never reaches the device');
  });

  test('forwards GET /api/status with the CORS origin header', () async {
    final r = await send('GET', '/api/status');
    expect(await text(r), contains('cervitriage'));
    expect(r.statusCode, 200);
    expect(r.headers.value('access-control-allow-origin'), _origin);
  });

  test('multipart bytes arrive at the device unchanged', () async {
    final bytes = List<int>.generate(70000, (i) => i % 256);
    final boundary = 'testboundary';
    final head = utf8.encode('--$boundary\r\nContent-Disposition: form-data; '
        'name="image"; filename="a.jpg"\r\nContent-Type: image/jpeg\r\n\r\n');
    final tail = utf8.encode('\r\n--$boundary--\r\n');
    final body = [...head, ...bytes, ...tail];
    final r = await send(
      'POST',
      '/predict',
      body: body,
      type: ContentType('multipart', 'form-data',
          parameters: {'boundary': boundary}),
    );
    await text(r);
    expect(r.statusCode, 200);
    expect(receivedBody, body);
    expect(receivedLength, body.length);
    expect(receivedType, contains('boundary=$boundary'));
  });

  test('device HTTP errors pass through unchanged', () async {
    final r = await send('POST', '/predict?fail=1', body: [1, 2, 3]);
    await text(r);
    expect(r.statusCode, 422);
  });

  test('hub examination and stop routes are forwarded as JSON', () async {
    for (final path in [
      '/api/exam/start',
      '/api/exam/heartbeat',
      '/api/exam/end',
      '/api/stop',
    ]) {
      final before = deviceHits;
      final r = await send('POST', path,
          body: utf8.encode('{}'), type: ContentType.json);
      await text(r);
      expect(r.statusCode, 200);
      expect(deviceHits, before + 1);
    }
    expect(kPortRoutes[8080], contains('/upload/cervical'));
    expect(kPortRoutes[8085], isNot(contains('/upload/cervical')));
  });

  test('wrong or missing origin is refused before reaching the device',
      () async {
    final before = deviceHits;
    var r = await send('GET', '/api/status', origin: 'http://evil.example');
    await text(r);
    expect(r.statusCode, 403);
    r = await send('GET', '/api/status', origin: null);
    await text(r);
    expect(r.statusCode, 403);
    expect(deviceHits, before);
  });

  test('only allow-listed routes and methods are proxied', () async {
    final before = deviceHits;
    for (final probe in [
      ['GET', '/etc/passwd'],
      ['GET', '/api/select'],
      ['GET', '/predict'],
    ]) {
      final r = await send(probe[0], probe[1]);
      await text(r);
      expect([404, 405], contains(r.statusCode), reason: probe.join(' '));
    }
    expect(deviceHits, before);
  });

  test('refuses wildcard or non-localhost origins at start-up', () {
    expect(
      () => EdgeDevProxy.start(device: '127.0.0.1', allowOrigin: '*'),
      throwsArgumentError,
    );
    expect(
      () => EdgeDevProxy.start(
          device: '127.0.0.1', allowOrigin: 'https://example.org'),
      throwsArgumentError,
    );
    expect(
      () => EdgeDevProxy.start(
          device: '127.0.0.1', allowOrigin: 'http://localhost.evil:5000'),
      throwsArgumentError,
    );
  });

  test('unreachable device yields 502, not a hang', () async {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final deadPort = probe.port;
    await probe.close();
    final probe2 = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final listen = probe2.port;
    await probe2.close();
    final p = await EdgeDevProxy.start(
      device: '127.0.0.1',
      allowOrigin: _origin,
      portMap: {listen: deadPort},
      portRoutes: {
        deadPort: {'/api/status'}
      },
    );
    final req =
        await client.getUrl(Uri.parse('http://127.0.0.1:$listen/api/status'));
    req.headers.set('origin', _origin);
    final r = await req.close();
    await text(r);
    expect(r.statusCode, 502);
    await p.close();
  });
}
