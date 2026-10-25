import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/app/app_services.dart';
import 'package:vyro/app/l10n/strings.dart';
import 'package:vyro/app/theme/vyro_theme.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/features/motion_engine/exercise_analysis/exercise_analysis_engine.dart';
import 'package:vyro/features/motion_engine/movement_patterns/pattern_library.dart';
import 'package:vyro/features/motion_engine/workout_analysis_history/motion_history_repository.dart';
import 'package:vyro/features/motion_engine/workout_camera/motion_coach_page.dart';

import 'synthetic_poses.dart';

void main() {
  test('a finished set is stored with events and read back', () async {
    final engine = ExerciseAnalysisEngine(pattern: PatternLibrary.squat);
    for (final s in repCurve(
      rest: 172,
      peak: 88,
      reps: 2,
      period: const Duration(milliseconds: 2400),
    )) {
      engine.process(
        syntheticPose(
          at: s.at,
          kneeAngle: s.value,
          trunkLean: s.value < 110 ? 65 : 8,
        ),
        s.at,
      );
    }
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);
    final repository = MotionHistoryRepository(database);
    await repository.save(
      exerciseKey: 'goblet_squat',
      startedAt: DateTime(2026, 10, 25, 9),
      summary: engine.summary(),
    );
    final rows = await repository.watch(exerciseKey: 'goblet_squat').first;
    expect(rows, hasLength(1));
    expect(rows.single.fullReps, 2);
    expect(rows.single.status, 'possibleIssue');
    expect(rows.single.techniqueScore, isNull);
    expect(MotionHistoryRepository.eventIds(rows.single), [
      'trunk_lean_high',
      'trunk_lean_high',
    ]);
    expect(await repository.watch(exerciseKey: 'push_up').first, isEmpty);
  });

  Future<AppDatabase> pump(WidgetTester tester, String key) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppServicesScope(
        services: AppServices(database: database),
        child: MaterialApp(
          theme: VyroTheme.dark,
          locale: const Locale('pt', 'PT'),
          supportedLocales: VyroStrings.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MotionCoachPage(exerciseKey: key, exerciseName: key),
        ),
      ),
    );
    // Drift streams never "settle" in fake time; advance frames explicitly.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return database;
  }

  /// Unmounts the page, lets drift's stream-cleanup timer fire, then closes
  /// the database in real time.
  Future<void> dispose(WidgetTester tester, AppDatabase database) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(database.close);
  }

  testWidgets('supported exercise shows setup advice and a start button', (
    tester,
  ) async {
    final db = await pump(tester, 'goblet_squat');
    expect(find.text('Iniciar série'), findsOneWidget);
    expect(find.textContaining('de lado'), findsOneWidget);
    expect(find.text('Ainda sem análises deste exercício.'), findsOneWidget);
    await dispose(tester, db);
  });

  testWidgets('unsupported exercise says so and offers no start', (
    tester,
  ) async {
    final db = await pump(tester, 'calf_raise');
    expect(find.text('Iniciar série'), findsNothing);
    expect(
      find.text('Ainda não há análise por câmara para este exercício.'),
      findsOneWidget,
    );
    await dispose(tester, db);
  });
}
