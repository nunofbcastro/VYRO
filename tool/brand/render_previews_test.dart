// Renders the app's logo painters to PNG so they can be compared with the
// brand SVGs (see tool/brand/render_icons.py --previews for the SVG side).
//
// Opt-in, so a normal `flutter test` skips it:
//   VYRO_RENDER_ICONS=1 VYRO_PREVIEW_DIR=<dir> flutter test tool/brand/render_previews_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Side-by-side comparison of the wordmark layouts, dark and light, at the
  // in-app height (22 logical px at 3x) and at 120 px.
  testWidgets('render wordmark layout variants', skip: !enabled, (
    tester,
  ) async {
    const layouts = [
      VyroWordmarkLayout.current,
      VyroWordmarkLayout.a,
      VyroWordmarkLayout.b,
      VyroWordmarkLayout.c,
    ];
    const cellWidth = 700.0;
    const labelHeight = 56.0;
    const rowPad = 40.0;
    const smallHeight = 66.0; // 22 logical px at 3x
    const largeHeight = 120.0;
    final rows = [
      (_ink, VyroLogo.bodyDark, VyroLogo.capDark, smallHeight),
      (_paper, VyroLogo.bodyLight, VyroLogo.capLight, smallHeight),
      (_ink, VyroLogo.bodyDark, VyroLogo.capDark, largeHeight),
      (_paper, VyroLogo.bodyLight, VyroLogo.capLight, largeHeight),
    ];
    final rowHeights = [for (final row in rows) labelHeight + row.$4 + rowPad];
    final totalHeight = rowHeights.reduce((a, b) => a + b);
    const totalWidth = cellWidth * 4;

    await tester.runAsync(() async {
      // Labels need a real font; the test default (Ahem) draws blocks. Set
      // VYRO_PREVIEW_FONT to a .ttf such as roboto-bold.ttf from the SDK cache.
      final fontPath = Platform.environment['VYRO_PREVIEW_FONT'];
      if (fontPath != null) {
        final loader = FontLoader('PreviewLabel')
          ..addFont(
            File(fontPath).readAsBytes().then(
              (bytes) => ByteData.view(Uint8List.fromList(bytes).buffer),
            ),
          );
        await loader.load();
      }
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      var top = 0.0;
      for (var r = 0; r < rows.length; r++) {
        final (background, body, cap, height) = rows[r];
        canvas.drawRect(
          Rect.fromLTWH(0, top, totalWidth, rowHeights[r]),
          Paint()..color = background,
        );
        for (var c = 0; c < layouts.length; c++) {
          final layout = layouts[c];
          final left = c * cellWidth;
          final label = TextPainter(
            text: TextSpan(
              text: layout.name == 'current'
                  ? 'Current'
                  : 'Variant ${layout.name}',
              style: TextStyle(
                color: background == _ink ? _paper : _ink,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                fontFamily: fontPath == null ? null : 'PreviewLabel',
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          label.paint(canvas, Offset(left + 24, top + 14));
          final width = height * VyroWordmarkPainter.aspectRatioOf(layout);
          canvas
            ..save()
            ..translate(left + 24, top + labelHeight)
            ..clipRect(Rect.fromLTWH(0, 0, cellWidth - 48, height));
          VyroWordmarkPainter(
            body: body,
            accent: cap,
            layout: layout,
          ).paint(canvas, Size(width, height));
          canvas.restore();
        }
        top += rowHeights[r];
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        totalWidth.round(),
        totalHeight.round(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(outDir).createSync(recursive: true);
      File(
        '$outDir/compact-variants.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });

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
