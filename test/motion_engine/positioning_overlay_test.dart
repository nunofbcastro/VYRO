import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/app/l10n/strings.dart';
import 'package:vyro/features/motion_engine/movement_patterns/pattern_library.dart';
import 'package:vyro/features/motion_engine/workout_camera/positioning_guide.dart';
import 'package:vyro/features/motion_engine/workout_camera/positioning_overlay.dart';

void main() {
  final squat = PositioningGuide.forPattern(PatternLibrary.squat);
  final plank = PositioningGuide.forPattern(PatternLibrary.horizontalPush);
  final front = PositioningGuide.forPattern(PatternLibrary.verticalPush);

  PositioningOverlayPainter painter({
    PositioningGuide? guide,
    bool aligned = false,
    bool mirror = false,
  }) => PositioningOverlayPainter(
    guide: guide ?? squat,
    aligned: aligned,
    accent: const Color(0xFFB8F36B),
    neutral: Colors.white,
    mirror: mirror,
  );

  group('PositioningOverlayPainter', () {
    test('repaints when alignment, guide, view or mirror change', () {
      final base = painter();
      expect(base.shouldRepaint(painter()), isFalse);
      expect(base.shouldRepaint(painter(aligned: true)), isTrue);
      expect(base.shouldRepaint(painter(guide: plank)), isTrue);
      expect(base.shouldRepaint(painter(guide: front)), isTrue);
      expect(base.shouldRepaint(painter(mirror: true)), isTrue);
    });

    testWidgets('paints the standing, plank and mirrored guides', (
      tester,
    ) async {
      for (final p in [
        painter(),
        painter(aligned: true, mirror: true),
        painter(guide: plank, aligned: true),
        painter(guide: front, mirror: true),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 240,
                  height: 320,
                  child: CustomPaint(painter: p),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });
  });

  testWidgets('status pill and tips card show their text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const FramingStatusPill(text: 'Afasta-te um pouco', ready: false),
              const FramingStatusPill(text: 'Enquadrado', ready: true),
              const PositioningTipsCard(
                rows: [(Icons.directions_walk_rounded, 'De lado')],
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Afasta-te um pouco'), findsOneWidget);
    expect(find.text('Enquadrado'), findsOneWidget);
    expect(find.text('De lado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'every framing issue and tip maps to a string key in both languages',
    () {
      final pt = VyroStrings(const Locale('pt', 'PT'));
      final en = VyroStrings(const Locale('en'));
      for (final issue in FramingIssue.values) {
        for (final guide in [squat, front]) {
          final key = framingMessageKey(issue, guide);
          expect(pt.get(key), isNot(key), reason: '$key (pt)');
          expect(en.get(key), isNot(key), reason: '$key (en)');
        }
      }
      for (final tip in GuideTip.values) {
        final key = guideTipKey(tip);
        expect(pt.get(key), isNot(key), reason: '$key (pt)');
        expect(en.get(key), isNot(key), reason: '$key (en)');
        expect(guideTipIcon(tip), isA<IconData>());
      }
      for (final key in [
        'maPrepare',
        'maShowGuide',
        'maHideGuide',
        'frBack',
        'frStart',
        'frWaiting',
        'frHold',
        'frReady',
        'frGuideNote',
      ]) {
        expect(pt.get(key), isNot(key), reason: '$key (pt)');
        expect(en.get(key), isNot(key), reason: '$key (en)');
      }
    },
  );
}
