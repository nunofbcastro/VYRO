import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/features/workouts/data/workout_repository.dart';
import 'package:vyro/features/workouts/domain/exercise_guides.dart';
import 'package:vyro/features/workouts/domain/exercise_traits.dart';
import 'package:vyro/features/workouts/domain/session_coach.dart';

void main() {
  group('nextLoad', () {
    test('about 5%, in 0.5 kg steps, between +0.5 and +2.5 kg', () {
      expect(nextLoad(10), 10.5);
      expect(nextLoad(20), 21);
      expect(nextLoad(40), 42);
      expect(nextLoad(100), 102.5);
      expect(nextLoad(4), 4.5);
    });
  });

  group('sessionHint', () {
    test('never logged before: no hint', () {
      expect(sessionHint(last: const [], target: 12, timed: false), isNull);
    });

    test('every set at the target: raise the load', () {
      final hint = sessionHint(
        last: const [
          PastSet(reps: 12, weightKg: 20),
          PastSet(reps: 12, weightKg: 20),
          PastSet(reps: 13, weightKg: 20),
        ],
        target: 12,
        timed: false,
      )!;
      expect(hint.advice, LoadAdvice.raise);
      expect(hint.lastKg, 20);
      expect(hint.suggestedKg, 21);
      expect(hint.lastReps, [12, 12, 13]);
    });

    test('one set short: keep the load', () {
      final hint = sessionHint(
        last: const [
          PastSet(reps: 12, weightKg: 20),
          PastSet(reps: 10, weightKg: 20),
        ],
        target: 12,
        timed: false,
      )!;
      expect(hint.advice, LoadAdvice.keep);
      expect(hint.suggestedKg, 20);
    });

    test('no load logged: advice without kilograms', () {
      final hint = sessionHint(
        last: const [PastSet(reps: 15), PastSet(reps: 15)],
        target: 12,
        timed: false,
      )!;
      expect(hint.advice, LoadAdvice.raise);
      expect(hint.lastKg, isNull);
      expect(hint.suggestedKg, isNull);
    });

    test('a timed hold never suggests a heavier load', () {
      final hint = sessionHint(
        last: const [PastSet(reps: 30, weightKg: 5)],
        target: 30,
        timed: true,
      )!;
      expect(hint.advice, LoadAdvice.raise);
      expect(hint.suggestedKg, 5);
    });
  });

  test('formatKg drops a trailing .0', () {
    expect(formatKg(20), '20 kg');
    expect(formatKg(22.5), '22.5 kg');
    expect(formatKg(22.5, comma: true), '22,5 kg');
  });

  test('every catalogue exercise has a how-to guide', () {
    for (final key in exerciseTraits.keys) {
      final guide = guideFor(key);
      expect(guide, isNotNull, reason: key);
      expect(guide!.stepsPt.length, guide.stepsEn.length, reason: key);
      expect(guide.stepsPt, isNotEmpty, reason: key);
    }
  });

  group('repository', () {
    late AppDatabase database;
    late WorkoutRepository repository;
    late int dayId;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = WorkoutRepository(database);
      final planId = await database
          .into(database.workoutPlans)
          .insert(WorkoutPlansCompanion.insert(title: 'Plano', goal: 'health'));
      dayId = await database
          .into(database.workoutDays)
          .insert(
            WorkoutDaysCompanion.insert(
              planId: planId,
              dayNumber: 1,
              namePt: 'Corpo inteiro A',
              nameEn: 'Full body A',
            ),
          );
      await database
          .into(database.planExercises)
          .insert(
            PlanExercisesCompanion.insert(
              dayId: dayId,
              exerciseKey: 'goblet_squat',
              sortOrder: 0,
              sets: const Value(3),
              repTarget: const Value(12),
              restSeconds: const Value(75),
            ),
          );
      await database
          .into(database.planExercises)
          .insert(
            PlanExercisesCompanion.insert(
              dayId: dayId,
              exerciseKey: 'plank',
              sortOrder: 1,
              sets: const Value(2),
              repTarget: const Value(30),
              restSeconds: const Value(60),
            ),
          );
    });
    tearDown(() => database.close());

    Future<List<ExerciseSet>> setsOf(int session, String key) async =>
        (await repository.watchSets(session).first)
            .where((s) => s.exerciseKey == key)
            .toList();

    test('rest comes from the plan, per exercise', () async {
      final session = await repository.startSession(
        dayId: dayId,
        workoutName: 'Corpo inteiro A',
      );
      expect(await repository.plannedRest(session), {
        'goblet_squat': 75,
        'plank': 60,
      });
    });

    test('a first session has no loads and no last performance', () async {
      final session = await repository.startSession(
        dayId: dayId,
        workoutName: 'Corpo inteiro A',
      );
      final squats = await setsOf(session, 'goblet_squat');
      expect(squats, hasLength(3));
      expect(squats.every((s) => s.weightKg == null), isTrue);
      expect(await repository.lastPerformance(session), isEmpty);
    });

    test('a typed load carries to the later open sets only', () async {
      final session = await repository.startSession(
        dayId: dayId,
        workoutName: 'Corpo inteiro A',
      );
      var squats = await setsOf(session, 'goblet_squat');
      await repository.updateSet(
        id: squats[0].id,
        reps: 12,
        weightKg: 20,
        completed: false,
      );
      await repository.carryWeight(squats[0], 20);
      squats = await setsOf(session, 'goblet_squat');
      expect([for (final s in squats) s.weightKg], [20, 20, 20]);
      // A later set with its own load is left alone.
      await repository.updateSet(
        id: squats[2].id,
        reps: 12,
        weightKg: 18,
        completed: false,
      );
      await repository.updateSet(
        id: squats[0].id,
        reps: 12,
        weightKg: 22,
        completed: false,
      );
      await repository.carryWeight(squats[0], 22);
      squats = await setsOf(session, 'goblet_squat');
      expect([for (final s in squats) s.weightKg], [22, 22, 18]);
      expect((await setsOf(session, 'plank')).first.weightKg, isNull);
    });

    test(
      'the next session starts from the last loads and reports them',
      () async {
        final first = await repository.startSession(
          dayId: dayId,
          workoutName: 'Corpo inteiro A',
        );
        final squats = await setsOf(first, 'goblet_squat');
        final reps = [12, 12, 10];
        for (var i = 0; i < squats.length; i++) {
          await repository.updateSet(
            id: squats[i].id,
            reps: reps[i],
            weightKg: 20,
            completed: true,
          );
        }
        await repository.finishSession(first);

        final second = await repository.startSession(
          dayId: dayId,
          workoutName: 'Corpo inteiro A',
        );
        expect(second, isNot(first));
        final next = await setsOf(second, 'goblet_squat');
        expect([for (final s in next) s.weightKg], [20, 20, 20]);
        final last = await repository.lastPerformance(second);
        expect(last.keys, ['goblet_squat']);
        expect([for (final s in last['goblet_squat']!) s.reps], [12, 12, 10]);
        final hint = sessionHint(
          last: last['goblet_squat']!,
          target: 12,
          timed: false,
        )!;
        expect(hint.advice, LoadAdvice.keep);
      },
    );
  });
}
