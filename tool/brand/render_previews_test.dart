// Renders the app's logo painters to PNG so they can be compared with the
// brand SVGs (see tool/brand/render_icons.py --previews for the SVG side).
//
// Opt-in, so a normal `flutter test` skips it:
//   VYRO_RENDER_ICONS=1 VYRO_PREVIEW_DIR=<dir> flutter test tool/brand/render_previews_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/app/theme/vyro_chrome.dart';

const _ink = Color(0xFF0B0D10);
const _paper = Color(0xFFF8FAF7);

void main() {
  final enabled = Platform.environment['VYRO_RENDER_ICONS'] == '1';
  final outDir =
      Platform.environment['VYRO_PREVIEW_DIR'] ?? 'build/brand-previews';

  Future<void> writePng(
    WidgetTester tester,
    CustomPainter painter,
    Size size,
    Color background,
    String name,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Offset.zero & size);
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
      painter.paint(canvas, size);
      final image = await recorder.endRecording().toImage(
        size.width.round(),
        size.height.round(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(outDir).createSync(recursive: true);
      File('$outDir/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('render wordmark and V mark previews', skip: !enabled, (
    tester,
  ) async {
    const wordSize = Size(1000, 260);
    // Same paint as VyroWordmark: the tight box fitted into the canvas.
    await writePng(
      tester,
      const VyroWordmarkPainter(
        body: VyroLogo.bodyDark,
        accent: VyroLogo.capDark,
      ),
      wordSize,
      _ink,
      'flutter-wordmark-dark.png',
    );
    await writePng(
      tester,
      const VyroWordmarkPainter(
        body: VyroLogo.bodyLight,
        accent: VyroLogo.capLight,
      ),
      wordSize,
      _paper,
      'flutter-wordmark-light.png',
    );
    const markSize = Size(512, 512);
    await writePng(
      tester,
      const VyroMarkPainter(body: VyroLogo.bodyDark, accent: VyroLogo.capDark),
      markSize,
      _ink,
      'flutter-mark-dark.png',
    );
    await writePng(
      tester,
      const VyroMarkPainter(
        body: VyroLogo.bodyLight,
        accent: VyroLogo.capLight,
      ),
      markSize,
      _paper,
      'flutter-mark-light.png',
    );
    // Mid-animation frame: body partly drawn, cap not yet in place.
    await writePng(
      tester,
      const VyroMarkPainter(
        body: VyroLogo.bodyDark,
        accent: VyroLogo.capDark,
        progress: 0.4,
      ),
      markSize,
      _ink,
      'flutter-mark-dark-progress40.png',
    );
  });
}
