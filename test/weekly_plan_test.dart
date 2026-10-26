import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/features/workouts/data/workout_repository.dart';
import 'package:vyro/features/workouts/domain/plan_generator.dart';
import 'package:vyro/features/workouts/domain/week_schedule.dart';

const _equipment = {
  'goblet_squat': 'halteres',
  'dumbbell_press': 'halteres',
  'seated_row': 'cabo',
  'glute_bridge': 'peso corporal',
  'plank': 'peso corporal',
  'split_squat': 'peso corporal ou halteres',
  'shoulder_press': 'halteres',
  'lat_pulldown': 'cabo',
  'hip_hinge': 'halteres',
  'dead_bug': 'peso corporal',
  'push_up': 'peso corporal',
  'side_plank': 'peso corporal',
  'reverse_lunge': 'peso corporal ou halteres',
  'dumbbell_row': 'halteres',
  'lateral_raise': 'halteres',
  'biceps_curl': 'halteres',
  'triceps_pushdown': 'cabo',
  'face_pull': 'cabo',
  'pike_push_up': 'peso corporal',
  'superman': 'peso corporal',
  'calf_raise': 'peso corporal',
  'bird_dog': 'peso corporal',
};

GeneratedPlan _plan(
  int days, {
  String goal = 'routine',
  String experience = 'beginner',
  Set<String> available = const {'bodyweight', 'dumbbells', 'cable'},
}) => generatePlan(
  daysPerWeek: days,
  goal: goal,
  experience: experience,
  available: available,
  equipmentOf: _equipment,
);

void main() {
  group('generatePlan', () {
    test('split follows days per week', () {
      expect(_plan(3).days.map((d) => d.namePt), [
        'Corpo inteiro A',
        'Corpo inteiro B',
        'Corpo inteiro C',
      ]);
      // Beginners stay on whole-body sessions up to four days.
      expect(_plan(4).days.map((d) => d.nameEn), [
        'Full body A',
        'Full body B',
        'Full body C',
        'Full body B 2',
      ]);
      expect(_plan(4, experience: 'six24m').days.map((d) => d.nameEn), [
        'Upper A',
        'Lower A',
        'Upper B',
        'Lower B',
      ]);
      expect(
        _plan(6, experience: 'over2y').days.map((d) => d.namePt).toList()[3],
        'Empurrar 2',
      );
    });

    test('weekdays are spread with rest days', () {
      expect(_plan(3).days.map((d) => d.weekday), [1, 3, 5]);
      expect(_plan(2).days.map((d) => d.weekday), [1, 4]);
    });

    test('goal changes sets and reps of main lifts', () {
      final strength = _plan(3, goal: 'strength').days.first.exercises.first;
      final fatLoss = _plan(3, goal: 'nutrition').days.first.exercises.first;
      expect(strength.reps, lessThan(fatLoss.reps));
      expect(strength.restSeconds, greaterThan(fatLoss.restSeconds));
    });

    test('bodyweight-only users only get bodyweight exercises', () {
      final plan = _plan(4, available: {'bodyweight'});
      for (final day in plan.days) {
        expect(day.exercises, isNotEmpty);
        for (final slot in day.exercises) {
          expect(_equipment[slot.exerciseKey], contains('peso corporal'));
        }
      }
    });

    test('a day never repeats the same exercise', () {
      for (var days = 1; days <= 7; days++) {
        for (final day in _plan(days).days) {
          final keys = day.exercises.map((e) => e.exerciseKey).toList();
          expect(keys.toSet().length, keys.length, reason: day.namePt);
        }
      }
    });
  });

  group('buildWeek', () {
    const slots = [
      ScheduleSlot(dayId: 1, weekday: 1, namePt: 'A', nameEn: 'A'),
      ScheduleSlot(dayId: 2, weekday: 3, namePt: 'B', nameEn: 'B'),
      ScheduleSlot(dayId: 3, weekday: 5, namePt: 'C', nameEn: 'C'),
    ];
    // Wednesday 2026-10-21.
    final wednesday = DateTime(2026, 10, 21, 9);

    test('statuses for past, today, future, done and skipped', () {
      final week = buildWeek(
        today: wednesday,
        slots: slots,
        done: const {'2026-10-19': 'A'},
        skipped: const {'2026-10-23'},
      );
      expect(week.first.date, DateTime(2026, 10, 19));
      expect(week.map((d) => d.status), [
        DayStatus.done, // Mon
        DayStatus.rest, // Tue
        DayStatus.today, // Wed
        DayStatus.rest, // Thu
        DayStatus.skipped, // Fri
        DayStatus.rest, // Sat
        DayStatus.rest, // Sun
      ]);
      expect(nextWorkout(week)?.slot?.dayId, 2);
      expect(weekProgress(week), (done: 1, scheduled: 3));
    });

    test('missed workouts and "esta semana não posso"', () {
      final week = buildWeek(
        today: wednesday,
        slots: slots,
        done: const {},
        skipped: const {},
      );
      expect(week[0].status, DayStatus.missed);
      expect(remainingTrainingKeys(week), ['2026-10-21', '2026-10-23']);
    });

    test('week outcome distinguishes done, paused and simply over', () {
      final sunday = DateTime(2026, 10, 25, 10);
      final over = buildWeek(
        today: sunday,
        slots: slots,
        done: const {},
        skipped: const {},
      );
      expect(weekOutcome(over, sunday), WeekOutcome.over);
      expect(firstSlotNextWeek(slots)?.weekday, 1);

      final allDone = buildWeek(
        today: sunday,
        slots: slots,
        done: const {'2026-10-19': 'A', '2026-10-21': 'B', '2026-10-23': 'C'},
        skipped: const {},
      );
      expect(weekOutcome(allDone, sunday), WeekOutcome.allDone);

      final paused = buildWeek(
        today: wednesday,
        slots: slots,
        done: const {},
        skipped: const {'2026-10-21', '2026-10-23'},
      );
      expect(weekOutcome(paused, wednesday), WeekOutcome.paused);
    });

    test('a workout on a rest day counts as done (extra)', () {
      final week = buildWeek(
        today: wednesday,
        slots: slots,
        done: const {'2026-10-20': 'Corrida'},
        skipped: const {},
      );
      expect(week[1].status, DayStatus.done);
      expect(week[1].slot, isNull);
      expect(week[1].doneWorkout, 'Corrida');
    });
  });

  group('repository', () {
    late AppDatabase database;
    late WorkoutRepository repository;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = WorkoutRepository(database);
      await database.saveUserProfile(
        const VyroProfile(
          onboardingCompleted: true,
          trainingDays: 3,
          goal: 'strength',
        ),
      );
    });
    tearDown(() => database.close());

    test('generated plan stores weekdays and goal prescription', () async {
      final plan = await repository.loadOrCreatePlan();
      expect(plan.plan.title, 'Força · 3 dias');
      expect(plan.days.map((d) => d.day.weekday), [1, 3, 5]);
      expect(plan.days.first.exercises.first.planExercise.repTarget, 8);
    });

    test('moving a workout swaps with the one already there', () async {
      final plan = await repository.loadOrCreatePlan();
      final a = plan.days[0].day;
      final b = plan.days[1].day;
      await repository.setWeekday(dayId: a.id, weekday: b.weekday!);
      final reloaded = await repository.reloadPlan();
      expect(reloaded.days[0].day.weekday, 3);
      expect(reloaded.days[1].day.weekday, 1);
    });

    test('skip, unskip and mark as done', () async {
      await repository.loadOrCreatePlan();
      await repository.skipDates(['2026-10-21', '2026-10-23']);
      expect(await repository.watchSkippedDays().first, {
        '2026-10-21',
        '2026-10-23',
      });

      await repository.markDone(
        date: DateTime(2026, 10, 21),
        workoutName: 'Corpo inteiro B',
      );
      expect(await repository.watchDoneDays().first, {
        '2026-10-21': 'Corpo inteiro B',
      });
      // Marking as done clears the "não posso" for that date.
      expect(await repository.watchSkippedDays().first, {'2026-10-23'});

      await repository.clearDone(DateTime(2026, 10, 21));
      expect(await repository.watchDoneDays().first, isEmpty);
      await repository.unskipDates(['2026-10-23']);
      expect(await repository.watchSkippedDays().first, isEmpty);
    });
  });
}
