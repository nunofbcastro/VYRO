import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/app/app.dart';
import 'package:vyro/app/app_services.dart';
import 'package:vyro/app/l10n/strings.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/features/nutrition/nutrition_targets_page.dart';
import 'package:vyro/features/onboarding/domain/nutrition_targets.dart';
import 'package:vyro/features/progress/progress_page.dart';

const _profile = VyroProfile(
  name: 'Ana',
  sex: 'female',
  age: 32,
  heightCm: 168,
  weightKg: 80,
  goal: 'routine',
  activityLevel: 'moderate',
  onboardingCompleted: true,
);

double _kcalFor(double kg) => NutritionTargets.calculate(
  sex: 'female',
  age: 32,
  heightCm: 168,
  weightKg: kg,
  activityLevel: 'moderate',
  goal: 'routine',
).kcal;

/// Lets drift and the snackbar animations finish.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Finds the text field labelled [label] in the targets editor.
Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

String _text(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).controller!.text;

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<T> db<T>(WidgetTester tester, Future<T> Function() action) async =>
      (await tester.runAsync(action)) as T;

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final services = AppServices(database: database);
    final settings = AppSettings(services);
    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('pt', 'PT'),
          supportedLocales: VyroStrings.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SettingsScope(settings: settings, child: page),
        ),
      ),
    );
    await settle(tester);
  }

  void flowTest(String description, Future<void> Function(WidgetTester) body) {
    testWidgets(description, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    });
  }

  flowTest('automatic mode shows the formula for the latest weight', (
    tester,
  ) async {
    await db(tester, () async {
      await database.saveUserProfile(_profile);
      await database.saveBodyWeight(
        measuredAt: DateTime(2026, 10, 20, 12),
        weightKg: 76,
      );
    });
    await pump(tester, const NutritionTargetsPage());

    expect(find.text('Calculadas automaticamente'), findsOneWidget);
    expect(
      find.textContaining('Peso do último registo: 76,0 kg'),
      findsOneWidget,
    );
    expect(_text(tester, 'Energia diária'), '${_kcalFor(76).round()}');
    expect(find.text('Voltar ao cálculo automático'), findsNothing);
  });

  flowTest('warns when the macros do not match the kcal target', (
    tester,
  ) async {
    await db(tester, () => database.saveUserProfile(_profile));
    await pump(tester, const NutritionTargetsPage());

    await tester.enterText(_field('Energia diária'), '2600');
    await tester.enterText(_field('Proteína'), '150');
    await tester.enterText(_field('Hidratos'), '200');
    await tester.enterText(_field('Gordura'), '70');
    await settle(tester);

    expect(find.text('As macros dão 2030 kcal.'), findsOneWidget);
    expect(
      find.text(
        'As macros diferem 22% da meta de energia. Ajusta uma das duas.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Ajustar kcal às macros'));
    await settle(tester);
    expect(_text(tester, 'Energia diária'), '2030');
    expect(find.textContaining('diferem'), findsNothing);
  });

  flowTest('rejects kcal outside the range and blocks saving', (tester) async {
    await db(tester, () => database.saveUserProfile(_profile));
    await pump(tester, const NutritionTargetsPage());

    await tester.enterText(_field('Energia diária'), '500');
    await settle(tester);
    expect(find.text('Indica entre 1000 e 6000 kcal.'), findsOneWidget);

    await tester.tap(find.text('Guardar metas'));
    await settle(tester);
    final profile = await db(tester, database.getUserProfile);
    expect(profile!.manualTargets, isFalse);
  });

  flowTest('saving manual targets accepts decimal commas', (tester) async {
    await db(tester, () => database.saveUserProfile(_profile));
    await pump(tester, const NutritionTargetsPage());

    await tester.enterText(_field('Energia diária'), '2100');
    await tester.enterText(_field('Proteína'), '150,5');
    await tester.enterText(_field('Hidratos'), '190');
    await tester.enterText(_field('Gordura'), '65');
    await settle(tester);
    await tester.tap(find.text('Guardar metas'));
    await settle(tester);

    final profile = await db(tester, database.getUserProfile);
    expect(profile!.manualTargets, isTrue);
    expect(profile.calorieGoal, 2100);
    expect(profile.proteinGoal, 150.5);
    expect(find.text('Metas definidas por ti'), findsOneWidget);
    expect(find.text('Voltar ao cálculo automático'), findsOneWidget);
  });

  flowTest('back to automatic recomputes from the latest weight', (
    tester,
  ) async {
    await db(tester, () async {
      await database.saveUserProfile(_profile);
      await database.saveBodyWeight(
        measuredAt: DateTime(2026, 10, 20, 12),
        weightKg: 76,
      );
      await database.saveManualTargets(
        kcal: 1800,
        protein: 120,
        carbs: 150,
        fat: 50,
      );
    });
    await pump(tester, const NutritionTargetsPage());
    expect(_text(tester, 'Energia diária'), '1800');

    await tester.tap(find.text('Voltar ao cálculo automático'));
    await settle(tester);

    final profile = await db(tester, database.getUserProfile);
    expect(profile!.manualTargets, isFalse);
    expect(profile.calorieGoal, _kcalFor(76));
    expect(find.text('Calculadas automaticamente'), findsOneWidget);
    expect(_text(tester, 'Energia diária'), '${_kcalFor(76).round()}');
  });

  flowTest('manual mode offers a recalculation after a weight change', (
    tester,
  ) async {
    await db(tester, () async {
      await database.saveUserProfile(_profile);
      await database.saveManualTargets(
        kcal: 1800,
        protein: 120,
        carbs: 150,
        fat: 50,
      );
      await database.saveBodyWeight(
        measuredAt: DateTime(2026, 10, 24, 12),
        weightKg: 74.5,
      );
    });
    await pump(tester, const NutritionTargetsPage());

    expect(find.text('O teu peso mudou. Recalcular metas?'), findsOneWidget);
    await tester.tap(find.text('Manter as minhas'));
    await settle(tester);
    expect(find.text('O teu peso mudou. Recalcular metas?'), findsNothing);
    expect((await db(tester, database.getUserProfile))!.manualTargets, isTrue);
  });

  flowTest('saving a weight reports the automatic target change', (
    tester,
  ) async {
    await db(tester, () => database.saveUserProfile(_profile));
    await pump(tester, const ProgressPage());

    await tester.tap(find.byTooltip('Registar peso'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '74,5');
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await settle(tester);

    expect(
      find.text(
        'Metas atualizadas: ${_kcalFor(80).round()} → '
        '${_kcalFor(74.5).round()} kcal (peso 74,5 kg)',
      ),
      findsOneWidget,
    );
  });

  flowTest('manual targets offer one tap to recalculate after a weight save', (
    tester,
  ) async {
    await db(tester, () async {
      await database.saveUserProfile(_profile);
      await database.saveManualTargets(
        kcal: 1800,
        protein: 120,
        carbs: 150,
        fat: 50,
      );
    });
    await pump(tester, const ProgressPage());

    await tester.tap(find.byTooltip('Registar peso'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '74,5');
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await settle(tester);

    expect(find.text('O teu peso mudou. Recalcular metas?'), findsOneWidget);
    await tester.tap(find.text('Recalcular'));
    await settle(tester);

    final profile = await db(tester, database.getUserProfile);
    expect(profile!.manualTargets, isFalse);
    expect(profile.calorieGoal, _kcalFor(74.5));
  });
}
