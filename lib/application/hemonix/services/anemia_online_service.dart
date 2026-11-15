import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '/services/edge_device/edge_image_input.dart';
import '../models/anemia_result.dart';

abstract final class AnemiaOnlineConfig {
  static const allowFallback =
      bool.fromEnvironment('ALLOW_ANEMIA_ONLINE_FALLBACK', defaultValue: true);
  static const baseUrl = String.fromEnvironment('ANEMIA_ONLINE_BASE_URL',
      defaultValue: 'https://kmunzwa-anemia-screening.hf.space');
}

class AnemiaAnalysisCancelled implements Exception {
  const AnemiaAnalysisCancelled();
}

class AnemiaOnlineException implements Exception {
  const AnemiaOnlineException();
  String get message =>
      'Online screening could not be completed. Check your internet connection and try again.';
}

/// Uses the published NiADA Space API. Only image bytes are transferred:
/// patient identity, review notes and clinical records stay with Dawa.
class AnemiaOnlineService {
  const AnemiaOnlineService(
      {this.baseUrl = AnemiaOnlineConfig.baseUrl, this.httpClient});
  final String baseUrl;
  final http.Client? httpClient;

  Future<AnemiaResult> analyze(
      {required EdgeImageInput image,
      required String examinationId,
      required Duration timeout,
      bool Function()? isCancelled}) async {
    if (examinationId.trim().isEmpty)
      throw const FormatException('Missing examination reference');
    if (isCancelled?.call() == true) throw const AnemiaAnalysisCancelled();
    final base = Uri.tryParse(baseUrl);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        (base.path.isNotEmpty && base.path != '/')) {
      throw const AnemiaOnlineException();
    }
    final client = httpClient ?? http.Client();
    var finished = false;
    try {
      return await _analyze(client, base, image, examinationId,
          () => finished || isCancelled?.call() == true).timeout(timeout);
    } on AnemiaAnalysisCancelled {
      rethrow;
    } catch (_) {
      // Do not expose server bodies, uploaded paths or internal exceptions.
      throw const AnemiaOnlineException();
    } finally {
      finished = true;
      if (httpClient == null) client.close();
    }
  }

  Future<AnemiaResult> _analyze(
      http.Client client,
      Uri base,
      EdgeImageInput image,
      String examinationId,
      bool Function()? isCancelled) async {
    final request =
        http.MultipartRequest('POST', base.resolve('/gradio_api/upload'))
          ..files.add(http.MultipartFile.fromBytes('files', image.bytes,
              filename: 'anemia.${image.extension}',
              contentType: MediaType.parse(image.mimeType)));
    final upload = await http.Response.fromStream(await client.send(request));
    _requireSuccess(upload);
    final paths = jsonDecode(upload.body);
    if (paths is! List ||
        paths.length != 1 ||
        paths.single is! String ||
        (paths.single as String).isEmpty) {
      throw const FormatException('Invalid upload acknowledgement');
    }
    if (isCancelled?.call() == true) throw const AnemiaAnalysisCancelled();
    final prediction =
        await client.post(base.resolve('/gradio_api/call/v2/predict_anaemia'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'image': {
                'path': paths.single,
                'meta': {'_type': 'gradio.FileData'}
              }
            }));
    _requireSuccess(prediction);
    final acknowledgement = jsonDecode(prediction.body);
    final eventId = acknowledgement is Map ? acknowledgement['event_id'] : null;
    if (eventId is! String || !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(eventId)) {
      throw const FormatException('Invalid prediction acknowledgement');
    }
    if (isCancelled?.call() == true) throw const AnemiaAnalysisCancelled();
    final response = await client
        .get(base.resolve('/gradio_api/call/predict_anaemia/$eventId'));
    _requireSuccess(response);
    String? event;
    final data = <String>[];
    for (final line in const LineSplitter().convert('${response.body}\n\n')) {
      if (line.startsWith('event:')) event = line.substring(6).trim();
      if (line.startsWith('data:')) data.add(line.substring(5).trimLeft());
      if (line.isEmpty) {
        if (event == 'error') throw const AnemiaOnlineException();
        if (event == 'complete') {
          return _parseResult(jsonDecode(data.join('\n')), examinationId, base);
        }
        event = null;
        data.clear();
      }
    }
    throw const FormatException('No completed prediction');
  }

  void _requireSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AnemiaOnlineException();
    }
  }

  AnemiaResult _parseResult(dynamic data, String examinationId, Uri base) {
    if (data is! List || data.length != 1 || data.single is! Map) {
      throw const FormatException('Invalid prediction');
    }
    final label = data.single as Map;
    final confidences = label['confidences'];
    if (confidences is! List ||
        confidences.length != AnemiaResult.classes.length) {
      throw const FormatException('Incomplete probabilities');
    }
    final probabilities = <String, dynamic>{};
    for (final item in confidences) {
      if (item is! Map ||
          item['label'] is! String ||
          probabilities.containsKey(item['label'])) {
        throw const FormatException('Invalid probability');
      }
      probabilities[item['label'] as String] = item['confidence'];
    }
    final classification = label['label'];
    return AnemiaResult.fromDeviceJson({
      'classification': classification,
      'class_index': AnemiaResult.classes
          .indexOf(classification is String ? classification : ''),
      'confidence': probabilities[classification],
      'probabilities': probabilities,
      'disclaimer': AnemiaResult.prototypeNotice,
      'analysis_provider': 'online',
      'service_url': base.origin,
    }, examinationId: examinationId, deviceId: 'online:${base.host}');
  }
}
