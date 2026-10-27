import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/app/l10n/strings.dart';
import 'package:vyro/app/theme/vyro_theme.dart';
import 'package:vyro/features/onboarding/tutorial_page.dart';

void main() {
  final t = VyroStrings(const Locale('pt', 'PT'));

  Future<void> pumpTutorial(WidgetTester tester, {Locale? locale}) async {
    // 480 dp: wider than a phone so the test font (Ahem) does not overflow the footer.
    tester.view.physicalSize = const Size(1260, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: VyroTheme.dark,
        locale: locale ?? const Locale('pt', 'PT'),
        supportedLocales: VyroStrings.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const TutorialPage(preview: true),
      ),
    );
    await tester.pump();
  }

  testWidgets('tutorial has six slides covering the current features', (
    tester,
  ) async {
    await pumpTutorial(tester);

    final titles = [
      t.get('tutorialWelcomeTitle'),
      t.get('tutorialNutritionTitle'),
      t.get('tutorialTargetsTitle'),
      t.get('tutorialTrainingTitle'),
      t.get('tutorialCoachTitle'),
      t.get('tutorialPrivacyTitle'),
    ];
    expect(
      titles.toSet(),
      hasLength(6),
      reason: 'each slide has its own title',
    );

    for (var i = 0; i < titles.length; i++) {
      expect(find.text(titles[i]), findsOneWidget, reason: 'slide ${i + 1}');
      if (i < titles.length - 1) {
        await tester.tap(find.text(t.get('tutorialNext')));
        await tester.pumpAndSettle();
      }
    }

    expect(find.text(t.get('tutorialStart')), findsOneWidget);
  });

  testWidgets('photo slide describes multiple photos and confirmation', (
    tester,
  ) async {
    await pumpTutorial(tester);
    await tester.tap(find.text(t.get('tutorialNext')));
    await tester.pumpAndSettle();

    expect(find.text(t.get('tutorialNutritionBody')), findsOneWidget);
    expect(t.get('tutorialNutritionBody'), contains('três fotos'));
    expect(t.get('tutorialNutritionBody'), contains('confirma'));
  });

  testWidgets('English copy is available for every new slide', (tester) async {
    await pumpTutorial(tester, locale: const Locale('en'));
    final en = VyroStrings(const Locale('en'));

    // VyroStrings returns the key itself when a translation is missing.
    for (final key in const [
      'tutorialNutritionTitle',
      'tutorialNutritionBody',
      'tutorialTargetsTitle',
      'tutorialTargetsBody',
      'tutorialTrainingTitle',
      'tutorialTrainingBody',
      'tutorialCoachTitle',
      'tutorialCoachBody',
      'setupPlanNow',
    ]) {
      expect(en.get(key), isNot(key), reason: key);
    }
    expect(find.text(en.get('tutorialWelcomeTitle')), findsOneWidget);
  });
}
