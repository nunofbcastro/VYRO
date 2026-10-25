import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/app/splash_page.dart';
import 'package:vyro/app/theme/vyro_chrome.dart';
import 'package:vyro/app/theme/vyro_shell.dart';
import 'package:vyro/app/theme/vyro_theme.dart';

void main() {
  Widget app(Widget child, {bool reduceMotion = false}) => MaterialApp(
    theme: VyroTheme.dark,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: child,
    ),
  );

  testWidgets('header keeps only the first V monogram', (tester) async {
    await tester.pumpWidget(app(const Scaffold(body: VyroWordmark())));
    expect(find.text('VYRO'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(VyroWordmark),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('VYRO'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('splash keeps the complete mark and fades in once', (
    tester,
  ) async {
    await tester.pumpWidget(app(const SplashPage()));
    expect(
      tester.widget<VyroBrandTile>(find.byType(VyroBrandTile)).markProgress,
      1,
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
    await tester.pump(SplashPage.introDuration);
    expect(find.text('VYRO'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion stops the intro and loading animation', (
    tester,
  ) async {
    await tester.pumpWidget(app(const SplashPage(), reduceMotion: true));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.5,
    );
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('splash error remains readable and retry works', (tester) async {
    var retries = 0;
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        SplashPage(error: Exception('storage'), onRetry: () => retries++),
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
}
