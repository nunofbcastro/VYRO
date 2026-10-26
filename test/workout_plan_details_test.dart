import 'dart:convert';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/features/workouts/data/workout_repository.dart';
import 'package:vyro/features/workouts/domain/exercise_traits.dart';
import 'package:vyro/features/workouts/domain/plan_details.dart';
import 'package:vyro/features/workouts/domain/plan_generator.dart';
import 'package:vyro/features/workouts/domain/plan_preferences.dart';

/// Equipment requirement per catalogue key, as stored in the database.
final _equipmentOf = {
  for (final entry in exerciseTraits.entries) entry.key: entry.value.equipment,
};

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  const prefs = PlanPreferences(
    goal: 'muscle',
    experience: 'six24m',
    weekdays: const [1, 3, 5],
    blockWeeks: 6,
    equipment: const {'bodyweight', 'dumbbells', 'bands'},
  );

  GeneratedPlan planFor(PlanPreferences answers) =>
      buildPlan(answers, _equipmentOf);

  group('PlanDetails', () {
    test('round-trips the block, warm-ups, notes, warnings and summary', () {
      final plan = planFor(prefs);
      final details = PlanDetails.fromPlan(
        plan,
        startedOn: DateTime(2026, 10, 5, 18, 30),
        summary: '  Três dias por semana, com um bloco de seis semanas.  ',
      );
      final decoded = PlanDetails.decode(details.encode());

      expect(decoded, isNotNull);
      expect(decoded!.startedOn, DateTime(2026, 10, 5));
      expect(decoded.blockWeeks, 6);
      expect(
        decoded.summary,
        'Três dias por semana, com um bloco de seis semanas.',
      );
      expect(decoded.notes.length, plan.notes.length);
      expect(decoded.warnings.length, plan.warnings.length);
      expect(decoded.warmups.length, plan.days.length);
      expect(decoded.warmups[1]!.pt, plan.days.first.warmupPt);
      expect(decoded.warmups[1]!.en, plan.days.first.warmupEn);
    });

    test('blank summaries are dropped and no summary is stored as null', () {
      final details = PlanDetails.fromPlan(
        planFor(prefs),
        startedOn: DateTime(2026, 10, 5),
        summary: '   ',
      );
      expect(details.summary, isNull);
      expect(PlanDetails.decode(details.encode())!.summary, isNull);
    });

    test('block position counts weeks from the start and flags the deload', () {
      final details = PlanDetails(
        startedOn: DateTime(2026, 10, 5),
        blockWeeks: 4,
        notes: const [],
        warnings: const [],
        warmups: const {},
      );

      BlockPosition at(DateTime day) => details.blockPosition(day);

      expect(at(DateTime(2026, 10, 5)).week, 1);
      expect(at(DateTime(2026, 10, 11)).week, 1);
      expect(at(DateTime(2026, 10, 12)).week, 2);
      expect(at(DateTime(2026, 10, 26)).week, 4);
      expect(at(DateTime(2026, 10, 26)).deload, isTrue);
      expect(at(DateTime(2026, 10, 26)).finished, isFalse);
      expect(at(DateTime(2026, 10, 12)).deload, isFalse);
      // Before the start counts as week 1.
      expect(at(DateTime(2026, 10, 1)).week, 1);
      // After the last week the block is finished.
      final after = at(DateTime(2026, 11, 2));
      expect(after.finished, isTrue);
      expect(after.deload, isFalse);
    });

    test('damaged, foreign or unknown-version values decode to null', () {
      expect(PlanDetails.decode(null), isNull);
      expect(PlanDetails.decode(''), isNull);
      expect(PlanDetails.decode('not json'), isNull);
      expect(PlanDetails.decode('[]'), isNull);
      expect(
        PlanDetails.decode('{"version":2,"startedOn":"2026-10-05"}'),
        isNull,
      );
      expect(
        PlanDetails.decode(
          '{"version":1,"startedOn":"2026-10-05","blockWeeks":5}',
        ),
        isNull,
      );
      expect(
        PlanDetails.decode('{"version":1,"startedOn":"nope","blockWeeks":4}'),
        isNull,
      );
    });

    test('bad note entries are skipped, the rest is kept', () {
      final decoded = PlanDetails.decode(
        jsonEncode({
          'version': 1,
          'startedOn': '2026-10-05',
          'blockWeeks': 4,
          'notes': [
            {'pt': 'Bom', 'en': 'Good'},
            {'pt': 3},
            'texto solto',
          ],
          'warnings': 'nao e lista',
          'warmups': {
            'x': {'pt': 'a', 'en': 'b'},
            '2': {'pt': 'c', 'en': 'd'},
          },
        }),
      );
      expect(decoded, isNotNull);
      expect(decoded!.notes.map((n) => n.en), ['Good']);
      expect(decoded.warnings, isEmpty);
      expect(decoded.warmups.keys, [2]);
    });
  });

  group('repository', () {
    late AppDatabase database;
    late WorkoutRepository repository;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = WorkoutRepository(database);
    });

    tearDown(() => database.close());

    test('savePlan stores the details and loadPlan returns them', () async {
      final plan = planFor(prefs);
      final saved = await repository.savePlan(
        plan,
        'muscle',
        summary: 'Um resumo curto.',
      );
      expect(saved.details, isNotNull);
      expect(saved.details!.blockWeeks, 6);
      expect(saved.details!.summary, 'Um resumo curto.');

      final reloaded = await repository.reloadPlan();
      expect(reloaded.details, isNotNull);
      expect(reloaded.details!.notes.length, plan.notes.length);
      expect(reloaded.details!.warmups.length, plan.days.length);
    });

    test(
      'a new plan replaces the active one and keeps its own details',
      () async {
        await repository.savePlan(planFor(prefs), 'muscle');
        final second = await repository.savePlan(
          planFor(prefs.copyWith(blockWeeks: 4)),
          'health',
        );
        expect(second.details!.blockWeeks, 4);
        expect(second.details!.summary, isNull);
      },
    );

    test('export and import keep the plan details', () async {
      await repository.savePlan(planFor(prefs), 'muscle', summary: 'Resumo.');
      final exported =
          jsonDecode(jsonEncode(await database.exportAllData()))
              as Map<String, dynamic>;

      final restored = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(restored.close);
      await restored.importAllData(exported);

      final plan = await restored.getActiveWorkoutPlan();
      final details = PlanDetails.decode(plan?.details);
      expect(details, isNotNull);
      expect(details!.blockWeeks, 6);
      expect(details.summary, 'Resumo.');
    });

    test('an export without the details field still imports', () async {
      await repository.savePlan(planFor(prefs), 'muscle');
      final exported =
          jsonDecode(jsonEncode(await database.exportAllData()))
              as Map<String, dynamic>;
      for (final row in exported['workoutPlans'] as List) {
        (row as Map<String, dynamic>).remove('details');
      }

      final restored = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(restored.close);
      await restored.importAllData(exported);

      final plan = await restored.getActiveWorkoutPlan();
      expect(plan, isNotNull);
      expect(PlanDetails.decode(plan!.details), isNull);
    });
  });
}
