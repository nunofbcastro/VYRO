import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/app/app_services.dart';
import 'package:vyro/app/l10n/strings.dart';
import 'package:vyro/app/theme/vyro_theme.dart';
import 'package:vyro/core/ai/on_device_llm.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/features/dashboard/live_home_page.dart';
import 'package:vyro/features/workouts/plan_wizard_page.dart';
import 'package:vyro/features/workouts/training_home_page.dart';

class _Llm implements OnDeviceLlm {
  @override
  Future<LlmStatus> status() async => LlmStatus.unavailable;

  @override
  Future<LlmStatus> download() async => LlmStatus.unavailable;

  @override
  Future<String> generate(String prompt) async => '';
}

VyroStrings get _t => VyroStrings(const Locale('pt', 'PT'));

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(executor: NativeDatabase.memory()));
  tearDown(() => database.close());

  /// Lets Drift I/O finish on real async, pumping frames in between.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final services = AppServices(database: database, llm: _Llm());
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
          home: page,
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets(
    'training tab without a plan shows the empty state, no plan made',
    (tester) async {
      await pumpPage(tester, const TrainingPage());

      expect(find.text(_t.get('noPlanTitle')), findsOneWidget);
      expect(find.text(_t.get('createTrainingPlan')), findsOneWidget);
      final plan = await tester.runAsync(() => database.getActiveWorkoutPlan());
      expect(plan, isNull);
    },
  );

  testWidgets('the training empty-state CTA opens the plan wizard', (
    tester,
  ) async {
    await pumpPage(tester, const TrainingPage());

    final cta = find.text(_t.get('createTrainingPlan'));
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await settle(tester);

    expect(find.byType(PlanWizardPage), findsOneWidget);
  });

  testWidgets(
    'home next-workout card shows no plan instead of a starter plan',
    (tester) async {
      await pumpPage(tester, const LiveHomePage());

      expect(find.text(_t.get('noPlanShort')), findsOneWidget);
      expect(find.text(_t.get('noPlanTap')), findsOneWidget);
      expect(find.text('Plano base · 3 dias'), findsNothing);
      final plan = await tester.runAsync(() => database.getActiveWorkoutPlan());
      expect(plan, isNull);
      // Unmount and drain timers left by the home screen before the test ends.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
