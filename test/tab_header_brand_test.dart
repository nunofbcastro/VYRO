import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/app/theme/vyro_shell.dart';
import 'package:vyro/app/theme/vyro_theme.dart';

void main() {
  const title = 'Olá, Ana';
  const longTitle = 'O teu dia, ao teu ritmo';

  Widget app({String text = title}) => MaterialApp(
    theme: VyroTheme.dark,
    home: VyroPageScaffold(
      eyebrow: 'Hoje',
      title: text,
      body: VyroPageBody(
        animate: false,
        children: [
          for (var i = 0; i < 40; i++)
            SizedBox(height: 90, child: Text('cartão $i')),
        ],
      ),
    ),
  );

  Future<void> useWidth(WidgetTester tester, double width) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> scrollPastLargeTitle(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('top shows the full wordmark, scrolled shows only the mark', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 300));

    // Expanded header: full lettering, no mark, no compact title.
    expect(find.byType(VyroWordmark), findsOneWidget);
    expect(find.byType(VyroMark), findsNothing);
    expect(find.bySemanticsLabel('VYRO'), findsOneWidget);
    final topOpacities = tester
        .widgetList<Opacity>(
          find.ancestor(
            of: find.text(title).last,
            matching: find.byType(Opacity),
          ),
        )
        .map((o) => o.opacity);
    expect(topOpacities, everyElement(0.0));

    // Scroll past the large title so the compact title is fully shown.
    await scrollPastLargeTitle(tester);

    expect(find.byType(VyroMark), findsOneWidget);
    expect(find.byType(VyroWordmark), findsNothing);
    expect(find.bySemanticsLabel('VYRO'), findsOneWidget);
    final compactOpacities = tester
        .widgetList<Opacity>(
          find.ancestor(
            of: find.text(title).last,
            matching: find.byType(Opacity),
          ),
        )
        .map((o) => o.opacity);
    expect(compactOpacities, contains(1.0));
    expect(find.text(title), findsWidgets);
    semantics.dispose();
  });

  testWidgets('scrolled title starts right after the mark, no large gap', (
    tester,
  ) async {
    await useWidth(tester, 412);
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 300));
    await scrollPastLargeTitle(tester);

    final markRect = tester.getRect(find.byType(VyroMark));
    final titleRect = tester.getRect(find.text(title).last);
    // The title begins one brand gap (12 dp) after the mark's right edge.
    expect(titleRect.left - markRect.right, closeTo(12, 1));
    // The brand slot has shrunk to the mark's width: no empty space left.
    expect(markRect.width, closeTo(VyroMark.widthFor(22), 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the swap cross-fades without errors and settles on the mark', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 300));

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    // Mid cross-fade and width animation both brand glyphs may be in the tree.
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(VyroMark), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long title fits at 360 dp without overflow or ellipsis loss', (
    tester,
  ) async {
    await useWidth(tester, 360);
    await tester.pumpWidget(app(text: longTitle));
    await tester.pump(const Duration(milliseconds: 300));
    await scrollPastLargeTitle(tester);

    expect(tester.takeException(), isNull);
    final titleRect = tester.getRect(find.text(longTitle).last);
    final markRect = tester.getRect(find.byType(VyroMark));
    expect(titleRect.left, greaterThan(markRect.right));
    // Ends before the right-hand actions slot (12 dp padding + 38 dp minimum).
    expect(titleRect.right, lessThanOrEqualTo(360 - 12 - 38));
    // Text was shrunk to fit rather than cut to the bare minimum.
    final text = tester.widget<Text>(find.text(longTitle).last);
    expect(text.style?.fontSize, inInclusiveRange(17 * 0.85, 17));
  });
}
