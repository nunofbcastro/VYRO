import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/app/l10n/strings.dart';
import 'package:vyro/features/onboarding/tutorial_page.dart';

void main() {
  testWidgets('tutorial advances through all slides and finishes', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'PT'),
        supportedLocales: VyroStrings.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: TutorialPage(onComplete: () => completed = true),
      ),
    );

    expect(find.text('Bem-vindo ao VYRO'), findsOneWidget);

    for (final title in const [
      'Fotos e refeições',
      'Metas que acompanham o peso',
      'Plano de treino com progressão',
      'Modo PT com voz',
    ]) {
      await tester.tap(find.text('Seguinte'));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    }

    await tester.tap(find.text('Seguinte'));
    await tester.pumpAndSettle();
    expect(find.text('Privacidade por defeito'), findsOneWidget);
    expect(find.text('Configurar o meu perfil'), findsOneWidget);

    await tester.tap(find.text('Configurar o meu perfil'));
    expect(completed, isTrue);
  });

  testWidgets('skip jumps straight to base data setup', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'PT'),
        supportedLocales: VyroStrings.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: TutorialPage(onComplete: () => completed = true),
      ),
    );

    await tester.tap(find.text('Saltar introdução'));
    expect(completed, isTrue);
  });

  testWidgets('back button returns to the previous slide', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'PT'),
        supportedLocales: VyroStrings.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: TutorialPage(onComplete: () {}),
      ),
    );

    await tester.tap(find.text('Seguinte'));
    await tester.pumpAndSettle();
    expect(find.text('Fotos e refeições'), findsOneWidget);

    await tester.tap(find.text('Anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Bem-vindo ao VYRO'), findsOneWidget);
  });
}
