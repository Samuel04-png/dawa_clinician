// Opt-in contract check. Uploads a synthetic 1x1 PNG, never a clinical image.
// Does not access Supabase or the LAN device. This is not clinical validation.
import 'dart:io';
import 'package:clinician/application/cacx/cacx_second_opinion_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'configured online service completes its protocol with a synthetic image',
      () async {
    HttpOverrides.global = null;
    const syntheticImage =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
    final result = await HuggingFaceService.analyzeVIAImage(syntheticImage);
    expect(result.error, isNull,
        reason: 'The configured upload/predict/completion API must finish.');
    expect(result.label, isNotEmpty);
    expect(result.predictionBreakdown, isNotEmpty);
    expect(result.confidence.isFinite, isTrue);
    // Deliberately omit classifications: synthetic pixels have no clinical meaning.
    print(
        'LIVE ONLINE CONTRACT PASS: synthetic image only; no patient data, LAN inference or database writes.');
  },
      skip: !const bool.fromEnvironment('RUN_LIVE_CACX_SECOND_OPINION_CHECK'),
      timeout: const Timeout(Duration(minutes: 3)));
}
