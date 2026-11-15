// Development-only CORS proxy so a Flutter Web build in Chrome can reach the
// Dawa edge device, which sends no CORS headers. See tool/run_web_dev.sh.
//
//   dart run tool/edge_dev_proxy.dart --device 10.127.36.206 \
//       --allow-origin http://localhost:5000
//
// Not a general proxy: it binds to loopback only, forwards to the one
// configured device, allows exactly one browser origin (never "*"), and only
// the routes listed in [kAllowedRoutes]. Anything else is answered 404/405
// locally and never reaches the device. It adds no authentication and is not a
// production gateway.
import 'dart:async';
import 'dart:io';

/// Device routes exposed to the configured development origin.
const Map<String, Set<String>> kAllowedRoutes = {
  '/api/status': {'GET'},
  '/api/select': {'POST'},
  '/health': {'GET'},
  '/predict': {'POST'},
  '/upload/cervical': {'POST'},
  '/upload/ultrasound': {'POST'},
  '/upload/anemia': {'POST'},
  '/hub/health': {'GET'},
  '/api/exam/start': {'POST'},
  '/api/exam/heartbeat': {'POST'},
  '/api/exam/end': {'POST'},
  '/api/stop': {'POST'},
};

/// Which device ports expose which routes.
const Set<String> kHubRoutes = {
  '/api/status',
  '/api/select',
  '/health',
  '/hub/health',
  '/upload/cervical',
  '/upload/ultrasound',
  '/upload/anemia',
  '/api/exam/start',
  '/api/exam/heartbeat',
  '/api/exam/end',
  '/api/stop',
};

const Map<int, Set<String>> kPortRoutes = {
  80: kHubRoutes,
  8080: kHubRoutes,
  8085: {'/health', '/predict'},
  8086: {'/health', '/predict'},
  8087: {'/health', '/predict'},
};

class EdgeDevProxy {
  EdgeDevProxy._(this._servers, this._client);

  final List<HttpServer> _servers;
  final HttpClient _client;

  List<int> get ports => [for (final s in _servers) s.port];

  /// [portMap] maps local listen port -> device port. Defaults to identity on
  /// the hub and module ports.
  static Future<EdgeDevProxy> start({
    required String device,
    required String allowOrigin,
    Map<int, int>? portMap,
    Map<int, Set<String>> portRoutes = kPortRoutes,
    Duration upstreamTimeout = const Duration(seconds: 330),
  }) async {
    final origin = Uri.tryParse(allowOrigin);
    if (origin == null ||
        origin.scheme != 'http' ||
        origin.host != 'localhost' ||
        !origin.hasPort ||
        origin.userInfo.isNotEmpty ||
        origin.path.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment) {
      throw ArgumentError('allow-origin must be one http://localhost origin');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    final map = portMap ?? const {8080: 80, 8085: 8085, 8086: 8086, 8087: 8087};
    final servers = <HttpServer>[];
    try {
      for (final entry in map.entries) {
        final server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          entry.key,
        );
        final routes = portRoutes[entry.value] ?? const <String>{};
        server.listen(
          (request) => _handle(
            request,
            client,
            device,
            entry.value,
            allowOrigin,
            routes,
            upstreamTimeout,
          ),
        );
        servers.add(server);
      }
    } catch (_) {
      client.close(force: true);
      for (final server in servers) {
        await server.close(force: true);
      }
      rethrow;
    }
    return EdgeDevProxy._(servers, client);
  }

  Future<void> close() async {
    _client.close(force: true);
    for (final s in _servers) {
      await s.close(force: true);
    }
  }
}

Future<void> _handle(
  HttpRequest request,
  HttpClient client,
  String device,
  int devicePort,
  String origin,
  Set<String> routes,
  Duration timeout,
) async {
  final response = request.response;
  final path = request.uri.path;
  final allowed = kAllowedRoutes[path];
  final routeKnown = allowed != null && routes.contains(path);

  Future<void> reply(int status, [String? body]) async {
    response.statusCode = status;
    if (body != null) response.write(body);
    await response.close();
  }

  final requestOrigin = request.headers.value('origin');
  if (requestOrigin != origin) {
    return reply(HttpStatus.forbidden, 'origin not allowed');
  }
  response.headers
    ..set('Access-Control-Allow-Origin', origin)
    ..set('Vary', 'Origin');

  if (!routeKnown) return reply(HttpStatus.notFound, 'route not proxied');

  if (request.method == 'OPTIONS') {
    final wanted = request.headers.value('access-control-request-method');
    if (wanted == null || !allowed.contains(wanted)) {
      return reply(HttpStatus.methodNotAllowed, 'method not allowed');
    }
    response.headers
      ..set('Access-Control-Allow-Methods', allowed.join(', '))
      ..set('Access-Control-Allow-Headers', 'Content-Type, X-API-Version')
      ..set('Access-Control-Allow-Private-Network', 'true')
      ..set('Access-Control-Max-Age', '600');
    return reply(HttpStatus.noContent);
  }
  if (!allowed.contains(request.method)) {
    return reply(HttpStatus.methodNotAllowed, 'method not allowed');
  }

  try {
    final upstream = await client.openUrl(
      request.method,
      Uri(
        scheme: 'http',
        host: device,
        port: devicePort,
        path: path,
        query: request.uri.hasQuery ? request.uri.query : null,
      ),
    );
    final contentType = request.headers.contentType;
    if (contentType != null) upstream.headers.contentType = contentType;
    // Keep the original length so the multipart body is not re-chunked.
    if (request.contentLength >= 0) {
      upstream.contentLength = request.contentLength;
    }
    await upstream.addStream(request);
    final upstreamReply = await upstream.close().timeout(timeout);
    response.statusCode = upstreamReply.statusCode;
    final replyType = upstreamReply.headers.contentType;
    if (replyType != null) response.headers.contentType = replyType;
    await response.addStream(upstreamReply);
  } on TimeoutException {
    response.statusCode = HttpStatus.gatewayTimeout;
    response.write('device timeout');
  } on Object catch (error) {
    response.statusCode = HttpStatus.badGateway;
    response.write('device unreachable: ${error.runtimeType}');
  }
  await response.close();
}

Future<void> main(List<String> args) async {
  String? device;
  String? origin;
  final listenPorts = {8080: 8080, 8085: 8085, 8086: 8086, 8087: 8087};
  var hubRemotePort = 80;
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--device') device = args[i + 1];
    if (args[i] == '--allow-origin') origin = args[i + 1];
    if (args[i] == '--hub-remote-port') {
      final port = int.tryParse(args[i + 1]);
      if (port == null || port < 1 || port > 65535) {
        stderr.writeln('[Proxy] invalid hub remote port');
        exitCode = 64;
        return;
      }
      hubRemotePort = port;
    }
    final targetPort = switch (args[i]) {
      '--hub-listen-port' => 8080,
      '--cervical-listen-port' => 8085,
      '--ultrasound-listen-port' => 8086,
      '--anemia-listen-port' => 8087,
      _ => null,
    };
    if (targetPort != null) {
      final port = int.tryParse(args[i + 1]);
      if (port == null || port < 1 || port > 65535) {
        stderr.writeln('[Proxy] invalid listen port for ${args[i]}');
        exitCode = 64;
        return;
      }
      listenPorts[targetPort] = port;
    }
  }
  if (device == null || origin == null) {
    stderr.writeln('Usage: dart run tool/edge_dev_proxy.dart '
        '--device <host> --allow-origin http://localhost:<port>');
    exitCode = 64;
    return;
  }
  try {
    if (listenPorts.values.toSet().length != listenPorts.length) {
      throw ArgumentError('Proxy listen ports must be distinct.');
    }
    if (hubRemotePort == 8085 ||
        hubRemotePort == 8086 ||
        hubRemotePort == 8087) {
      throw ArgumentError('Hub and module remote ports must be distinct.');
    }
    final proxy = await EdgeDevProxy.start(
      device: device,
      allowOrigin: origin,
      portMap: {
        for (final entry in listenPorts.entries)
          entry.value: entry.key == 8080 ? hubRemotePort : entry.key,
      },
      portRoutes: {
        hubRemotePort: kPortRoutes[8080]!,
        8085: kPortRoutes[8085]!,
        8086: kPortRoutes[8086]!,
        8087: kPortRoutes[8087]!,
      },
    );
    stdout.writeln('[Proxy] listening on 127.0.0.1 ports ${proxy.ports} '
        '-> $device (origin $origin)');
  } on Object catch (error) {
    stderr.writeln('[Proxy] failed to start: $error');
    exitCode = 1;
  }
}
