import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/app/app.dart';
import 'package:vyro/app/app_services.dart';
import 'package:vyro/app/l10n/strings.dart';
import 'package:vyro/app/theme/vyro_theme.dart';
import 'package:vyro/core/ai/on_device_llm.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/features/onboarding/setup_wizard_page.dart';
import 'package:vyro/features/workouts/plan_wizard_page.dart';

class _Llm implements OnDeviceLlm {
  _Llm(this.result);

  final LlmStatus result;

  @override
  Future<LlmStatus> status() async => result;

  @override
  Future<LlmStatus> download() async => result;

  @override
  Future<String> generate(String prompt) async => '';
}

VyroStrings get _t => VyroStrings(const Locale('pt', 'PT'));

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(executor: NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<void> pumpSetup(WidgetTester tester, LlmStatus llm) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final services = AppServices(database: database, llm: _Llm(llm));
    final settings = AppSettings(services);
    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          theme: VyroTheme.dark,
          locale: const Locale('pt', 'PT'),
          supportedLocales: VyroStrings.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SettingsScope(
            settings: settings,
            child: const SetupWizardPage(),
          ),
        ),
      ),
    );
    // Let the stored preferences and the model check finish.
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }

  Future<void> goToReview(WidgetTester tester) async {
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.text(_t.get('continue')));
      await tester.pumpAndSettle();
    }
  }

  Future<void> chooseManualTargets(WidgetTester tester) async {
    await tester.ensureVisible(find.text(_t.get('setupTargetsManual')));
    await tester.tap(find.text(_t.get('setupTargetsManual')));
    await tester.pump();
  }

  testWidgets('manual targets show the mismatch warning and its fix', (
    tester,
  ) async {
    await pumpSetup(tester, LlmStatus.unavailable);
    await goToReview(tester);
    await chooseManualTargets(tester);

    // The automatic values match the macros, so no warning yet.
    expect(find.text(_t.get('targetsAdjustKcal')), findsNothing);

    await tester.enterText(find.byType(TextField).at(0), '1500');
    await tester.pump();

    expect(find.text(_t.get('targetsAdjustKcal')), findsOneWidget);
    expect(
      find.textContaining(_t.get('targetsMismatch').split('{diff}').first),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text(_t.get('targetsAdjustKcal')));
    await tester.tap(find.text(_t.get('targetsAdjustKcal')));
    await tester.pump();

    expect(find.text(_t.get('targetsAdjustKcal')), findsNothing);
    final kcalField = tester.widget<TextField>(find.byType(TextField).at(0));
    expect(kcalField.controller!.text, isNot('1500'));
  });

  testWidgets('automatic targets never show the mismatch warning', (
    tester,
  ) async {
    await pumpSetup(tester, LlmStatus.unavailable);
    await goToReview(tester);

    expect(find.text(_t.get('targetsAdjustKcal')), findsNothing);
  });

  testWidgets(
    'phrase toggle appears under Modo PT and is disabled without the model',
    (tester) async {
      await pumpSetup(tester, LlmStatus.unavailable);
      await goToReview(tester);

      final phrases = find.byKey(const ValueKey('setupLlmPhrases'));
      expect(phrases, findsNothing);

      await tester.ensureVisible(find.text(_t.get('setupVoiceTitle')));
      await tester.tap(find.text(_t.get('setupVoiceTitle')));
      await tester.pump();

      expect(phrases, findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(phrases).onChanged,
        isNull,
        reason: 'the model is unavailable, so the switch cannot be turned on',
      );
      expect(find.text(_t.get('coachVoiceLlmUnavailable')), findsOneWidget);
    },
  );

  testWidgets('phrase toggle can be switched when the model is available', (
    tester,
  ) async {
    await pumpSetup(tester, LlmStatus.available);
    await goToReview(tester);
    await tester.ensureVisible(find.text(_t.get('setupVoiceTitle')));
    await tester.tap(find.text(_t.get('setupVoiceTitle')));
    await tester.pump();

    final phrases = find.byKey(const ValueKey('setupLlmPhrases'));
    expect(tester.widget<SwitchListTile>(phrases).onChanged, isNotNull);
    expect(tester.widget<SwitchListTile>(phrases).value, isTrue);

    await tester.tap(phrases);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(phrases).value, isFalse);
  });

  testWidgets('the plan action saves setup and opens the plan wizard', (
    tester,
  ) async {
    await pumpSetup(tester, LlmStatus.unavailable);
    await goToReview(tester);

    final planNow = find.text(_t.get('setupPlanNow'));
    expect(planNow, findsOneWidget);
    await tester.ensureVisible(planNow);
    await tester.tap(planNow);

    // Saving uses the real database, so let the platform I/O finish.
    for (
      var i = 0;
      i < 100 && find.byType(PlanWizardPage).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.byType(PlanWizardPage), findsOneWidget);
    final profile = await tester.runAsync(() => database.getUserProfile());
    expect(profile?.onboardingCompleted, isTrue);
    // Setup never creates the plan: it is created only when the wizard saves.
    final plan = await tester.runAsync(() => database.getActiveWorkoutPlan());
    expect(plan, isNull);
  });

  testWidgets('skipping the plan finishes setup without creating a plan', (
    tester,
  ) async {
    await pumpSetup(tester, LlmStatus.unavailable);
    await goToReview(tester);

    final skip = find.text(_t.get('setupSkipPlan'));
    expect(skip, findsOneWidget);
    expect(find.text(_t.get('setupPlanNow')), findsOneWidget);
    await tester.ensureVisible(skip);
    await tester.tap(skip);

    // Saving uses the real database, so let the platform I/O finish.
    for (
      var i = 0;
      i < 100 &&
          (await tester.runAsync(
                () => database.getUserProfile(),
              ))?.onboardingCompleted !=
              true;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }

    final profile = await tester.runAsync(() => database.getUserProfile());
    expect(profile?.onboardingCompleted, isTrue);
    expect(find.byType(PlanWizardPage), findsNothing);
    final plan = await tester.runAsync(() => database.getActiveWorkoutPlan());
    expect(plan, isNull);
    final days = await tester.runAsync(
      () => database.select(database.workoutDays).get(),
    );
    expect(days, isEmpty);
  });
}
