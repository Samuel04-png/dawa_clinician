import 'dart:ui' as ui;
import 'package:clinician/components/clinical_image_frame.dart';
import 'package:clinician/components/navigation_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('frame badge follows fitted pixels rather than letterbox',
      (tester) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
    final picture = recorder.endRecording();
    final image = (await tester.runAsync(() => picture.toImage(400, 100)))!;
    final bytes = await tester
        .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: SizedBox(
      key: const ValueKey('frame'),
      width: 400,
      height: 300,
      child: ClinicalImageFrame(
          bytes: bytes!.buffer.asUint8List(),
          badge: const Text('Frame loaded', key: ValueKey('badge'))),
    )))));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    final frame = tester.getTopLeft(find.byKey(const ValueKey('frame')));
    final badge = tester.getTopLeft(find.byKey(const ValueKey('badge')));
    expect(badge.dx - frame.dx, 8);
    expect(badge.dy - frame.dy, 108);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    image.dispose();
    picture.dispose();
  });

  test('clinical text roles meet AA on their actual neutral surfaces', () {
    double contrast(Color text, Color surface) {
      final a = text.computeLuminance(), b = surface.computeLuminance();
      return ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05);
    }

    for (final color in [
      NavigationTokens.text,
      NavigationTokens.secondary,
      NavigationTokens.brand
    ]) {
      expect(
          contrast(color, NavigationTokens.surface), greaterThanOrEqualTo(4.5));
      expect(
          contrast(color, NavigationTokens.canvas), greaterThanOrEqualTo(4.5));
    }
  });
}
