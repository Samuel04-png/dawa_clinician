import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'cacx_model.dart';

// ─── HUGGING FACE / GRADIO SERVICE ────────────────────────────────────────────
class HuggingFaceService {
  static const String _spaceBaseUrl = 'https://kmunzwa-medsiglip-demo.hf.space';

  static Future<AnalysisResult> analyzeVIAImage(String base64Image,
      {http.Client? httpClient}) async {
    final client = httpClient ?? http.Client();
    try {
      final rawBase64 =
          base64Image.contains(',') ? base64Image.split(',').last : base64Image;
      final imageBytes = base64Decode(rawBase64);

      String mimeType = 'image/jpeg';
      String extension = 'jpg';
      if (base64Image.startsWith('data:image/png')) {
        mimeType = 'image/png';
        extension = 'png';
      } else if (base64Image.startsWith('data:image/webp')) {
        mimeType = 'image/webp';
        extension = 'webp';
      }

      // ── Step 1: Upload — note the new /gradio_api/upload path ──────────────
      final uploadUri = Uri.parse('$_spaceBaseUrl/gradio_api/upload');
      final uploadRequest = http.MultipartRequest('POST', uploadUri)
        ..files.add(
          http.MultipartFile.fromBytes(
            'files',
            imageBytes,
            filename: 'image.$extension',
            contentType: MediaType.parse(mimeType),
          ),
        );

      final uploadStreamedResponse =
          await client.send(uploadRequest).timeout(const Duration(seconds: 20));
      final uploadBody = (await http.Response.fromStream(uploadStreamedResponse)
              .timeout(const Duration(seconds: 20)))
          .body;

      if (uploadStreamedResponse.statusCode != 200) {
        throw Exception(
            'Upload failed ${uploadStreamedResponse.statusCode}: $uploadBody');
      }

      final List<dynamic> uploadedPaths =
          jsonDecode(uploadBody) as List<dynamic>;
      final String serverFilePath = uploadedPaths.first as String;

      // ── Step 2: POST to /gradio_api/call/predict — returns an event_id ─────
      final predictUri = Uri.parse('$_spaceBaseUrl/gradio_api/call/predict');
      final predictResponse = await client
          .post(
            predictUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'data': [
                {
                  'path': serverFilePath,
                  'orig_name': 'image.$extension',
                  'meta': {'_type': 'gradio.FileData'},
                }
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (predictResponse.statusCode != 200) {
        throw Exception(
            'Predict failed ${predictResponse.statusCode}: ${predictResponse.body}');
      }

      final Map<String, dynamic> predictJson =
          jsonDecode(predictResponse.body) as Map<String, dynamic>;
      final String eventId = predictJson['event_id'] as String;

      // ── Step 3: GET the result via SSE ─────────────────────────────────────
      final resultUri =
          Uri.parse('$_spaceBaseUrl/gradio_api/call/predict/$eventId');
      final resultResponse =
          await client.get(resultUri).timeout(const Duration(seconds: 60));

      if (resultResponse.statusCode != 200) {
        throw Exception(
            'Result fetch failed ${resultResponse.statusCode}: ${resultResponse.body}');
      }

      // SSE body looks like:
      //   event: complete
      //   data: [{"label": "CIN1", "confidences": [...]}]
      // ── Step 4: Parse the SSE body ─────────────────────────────────────────────
      final String sseBody = resultResponse.body;

// Find the "data:" line that follows "event: complete"
      final lines = sseBody.split('\n');
      String dataLine = '';
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].trim() == 'event: complete' && i + 1 < lines.length) {
          final next = lines[i + 1];
          if (next.startsWith('data:')) {
            dataLine = next;
            break;
          }
        }
      }

      if (dataLine.isEmpty) {
        throw Exception(
            'No complete event data found in SSE response: $sseBody');
      }

      final dynamic resultData =
          (jsonDecode(dataLine.substring(5).trim()) as List<dynamic>).first;

      // ── Step 4: Parse (same logic as before) ───────────────────────────────
      final breakdown = extractPredictionBreakdown(resultData);
      String mappedLabel = breakdown.isNotEmpty
          ? canonicalCacxBaseLabel(breakdown.first.label)
          : '';
      double confidence = breakdown.isNotEmpty ? breakdown.first.confidence : 0;

      if (mappedLabel.isEmpty) {
        if (resultData is Map<String, dynamic>) {
          final String rawLabel =
              (resultData['label'] ?? resultData['prediction'] ?? '')
                  .toString();
          mappedLabel = canonicalCacxBaseLabel(rawLabel);
          confidence = normalizeCacxConfidence(
            resultData['confidence'] ??
                resultData['confidence_percent'] ??
                resultData['probability'] ??
                resultData['score'],
          );
        } else if (resultData is List<dynamic> && resultData.isNotEmpty) {
          final top = resultData.reduce(
            (a, b) {
              final aScore = normalizeCacxConfidence(
                a is Map ? a['score'] ?? a['confidence'] ?? 0 : 0,
              );
              final bScore = normalizeCacxConfidence(
                b is Map ? b['score'] ?? b['confidence'] ?? 0 : 0,
              );
              return aScore >= bScore ? a : b;
            },
          );
          final rawLabel =
              (top is Map ? top['label'] ?? top['class'] ?? '' : '')
                  .toString()
                  .trim();
          mappedLabel = canonicalCacxBaseLabel(rawLabel);
          confidence = normalizeCacxConfidence(
            top is Map ? top['score'] ?? top['confidence'] ?? 0 : 0,
          );
        } else {
          throw Exception('Unexpected Gradio response shape: $resultData');
        }
      }

      if (mappedLabel.trim().isEmpty)
        throw const FormatException('Missing prediction label.');
      return _processResult(
        base64Image,
        mappedLabel,
        confidence,
        predictionBreakdown: breakdown,
        rawOutput: resultData is Map
            ? Map<String, dynamic>.from(resultData)
            : {'predictions': resultData},
      );
    } catch (e) {
      debugPrint('[CaCx online] Request failed (${e.runtimeType}).');
      return AnalysisResult(
        imageUrl: base64Image,
        label: 'Analysis Failed',
        confidence: 0,
        suspicionLevel: SuspicionLevel.low,
        recommendation:
            'Could not connect to AI model. Please check your connection and try again.',
        predictionBreakdown: const [],
        error:
            'The online service did not return a usable result. Please retry.',
      );
    } finally {
      if (httpClient == null) client.close();
    }
  }

  static AnalysisResult _processResult(
    String imageUrl,
    String label,
    double confidence, {
    List<PredictionBreakdownItem> predictionBreakdown = const [],
    Map<String, dynamic>? rawOutput,
  }) {
    SuspicionLevel suspicion;
    String displayLabel;
    String recommendation;
    final key = canonicalCacxBaseLabel(label);

    switch (key) {
      case 'negative':
        suspicion = SuspicionLevel.low;
        displayLabel = 'Normal / Negative VIA';
        recommendation =
            'No acetowhite lesion or other abnormality seen. Routine follow-up: repeat VIA in 3 years per national MoH guidelines. Provide patient education on cervical cancer warning signs (e.g., post-coital bleeding, intermenstrual bleeding, foul discharge). Document findings in patient record. No referral needed.';
        break;
      case 'cin1':
        suspicion = SuspicionLevel.medium;
        displayLabel = 'Low Grade Lesion (CIN1)';
        recommendation =
            'Well-defined, faint/thin acetowhite lesions. Management: Repeat VIA in 12 months. Counsel patient on likely regression, but emphasize importance of returning for repeat screening. Advise smoking cessation if applicable, and discuss HPV transmission. Schedule recall appointment before discharge. No immediate colposcopy unless patient is HIV-positive, immunocompromised, or persistent at 12-24 months.';
        break;
      case 'cin2':
        suspicion = SuspicionLevel.high;
        displayLabel = 'High Grade Lesion (CIN2)';
        recommendation =
            "Distinct, dense, opaque acetowhite lesions with irregular borders. Action: Refer for colposcopy and directed biopsy within 4 weeks. If colposcopy confirms CIN2+ and patient has completed childbearing or lesion is fully visible, proceed with LEEP/cryotherapy same day. Document lesion size, location, and extension onto fornices. Offer HPV testing if available. Exclude pregnancy before treatment.";
        break;
      case 'cin3':
        suspicion = SuspicionLevel.high;
        displayLabel = 'High Grade Lesion (CIN3)';
        recommendation =
            "Dense, acetowhite epithelium with sharp borders. May involve crypts. Action: Urgent colposcopy referral within 2 weeks. Biopsy mandatory. 'See and Treat' acceptable if colposcopy suspicious for invasion. Do not delay for results if lesion is large or concerning. Check HIV status — treat earlier if positive. Discuss risk of progression if untreated. Prepare for possible LEEP or cone biopsy.";
        break;
      case 'positive':
        suspicion = SuspicionLevel.high;
        displayLabel = 'Positive - Cancer Suspected';
        recommendation =
            "Abnormal vessel patterns, irregular surface, ulceration, or friable mass. Likely invasive cancer. Action: URGENT referral — complete oncological referral form immediately. Do not perform LEEP/cryotherapy. Perform guided punch biopsy only if haemorrhage can be controlled. Send biopsy with 'suspicious for invasive cancer' noted. Contact gynaecology oncology team by phone within 24 hours. Advise patient not to wait. Document exam under anaesthesia status and any renal function if contrast imaging planned.";
        break;
      default:
        suspicion = SuspicionLevel.low;
        displayLabel = 'Inconclusive - ${canonicalCacxDisplayLabel(label)}';
        recommendation =
            'Image quality insufficient or interpretation unclear. Likely causes: excess mucus, poor illumination, incomplete acetic acid application, or blurred image. Action: Repeat VIA with clearer visualization. Clean cervix with saline-soaked swab, reapply 5% acetic acid, wait 60 seconds, and reassess. If repeatedly inconclusive, refer for colposcopy. Document reason for inconclusive result in chart.';
    }

    return AnalysisResult(
      imageUrl: imageUrl,
      label: displayLabel,
      confidence: double.parse(confidence.toStringAsFixed(1)),
      suspicionLevel: suspicion,
      recommendation: recommendation,
      predictionBreakdown: predictionBreakdown,
      rawOutput: rawOutput,
    );
  }
}
