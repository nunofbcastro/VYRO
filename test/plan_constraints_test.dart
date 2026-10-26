import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/workouts/domain/exercise_traits.dart';
import 'package:vyro/features/workouts/domain/plan_generator.dart';
import 'package:vyro/features/workouts/domain/plan_preferences.dart';

/// Property-style checks: many random answer combinations, and every generated
/// plan must respect the user's rules. A fixed seed keeps failures reproducible.
void main() {
  final equipmentOf = {
    for (final entry in exerciseTraits.entries)
      entry.key: entry.value.equipment,
  };
  final keys = exerciseTraits.keys.toList();

  test('no generated plan breaks a rule, across random answers', () {
    final random = Random(20261026);
    const runs = 400;
    var checkedDays = 0;

    for (var run = 0; run < runs; run++) {
      final equipment = {
        for (final id in PlanPreferences.equipmentIds)
          if (random.nextInt(3) > 0) id,
      };
      if (equipment.isEmpty) equipment.add('bodyweight');
      final days = 1 + random.nextInt(7);
      final weekdays = (List.generate(
        7,
        (i) => i + 1,
      )..shuffle(random)).take(days).toList()..sort();
      final limitAreas = {
        for (final area in PlanPreferences.limitAreaIds)
          if (random.nextInt(4) == 0)
            area: PlanPreferences.limitLevels[random.nextInt(3)],
      };
      final avoided = {
        for (final key in keys)
          if (random.nextInt(6) == 0) key,
      };
      final favourites = {
        for (final key in keys)
          if (random.nextInt(8) == 0) key,
      };
      final ageRange = const [
        null,
        '18to39',
        '40to59',
        '60plus',
      ][random.nextInt(4)];
      final impactAllowed = random.nextBool();
      final prefs = PlanPreferences(
        goal:
            PlanPreferences.goals[random.nextInt(PlanPreferences.goals.length)],
        experience: PlanPreferences
            .experiences[random.nextInt(PlanPreferences.experiences.length)],
        detraining:
            PlanPreferences.detrainingLevels[random.nextInt(
              PlanPreferences.detrainingLevels.length,
            )],
        weekdays: weekdays,
        sessionMinutes:
            PlanPreferences.sessionLengths[random.nextInt(
              PlanPreferences.sessionLengths.length,
            )],
        equipment: equipment,
        priorities: {
          for (final area in PlanPreferences.allPriorities)
            if (random.nextInt(5) == 0) area,
        },
        limitAreas: limitAreas,
        avoidedExercises: avoided,
        favouriteExercises: favourites,
        cardio: PlanPreferences.cardioModes[random.nextInt(3)],
        cardioType: PlanPreferences.cardioTypes[random.nextInt(5)],
        impactAllowed: impactAllowed,
        style: PlanPreferences.styles[random.nextInt(2)],
        rest: PlanPreferences.rests[random.nextInt(3)],
        ageRange: ageRange,
        blockWeeks: PlanPreferences.blockOptions[random.nextInt(3)],
      );
      final context = 'run $run: ${prefs.encode()}';
      final plan = buildPlan(prefs, equipmentOf);
      final impactOk = impactAllowed && ageRange != '60plus';

      expect(plan.days.length, days, reason: context);
      expect(plan.weeks.length, prefs.blockWeeks, reason: context);
      expect(plan.weeks.last.deload, isTrue, reason: context);
      expect(
        plan.weeks.take(prefs.blockWeeks - 1).every((w) => !w.deload),
        isTrue,
        reason: context,
      );

      for (final day in plan.days) {
        checkedDays++;
        final dayKeys = [for (final s in day.exercises) s.exerciseKey];
        expect(
          dayKeys.toSet().length,
          dayKeys.length,
          reason: 'duplicate in ${day.namePt}; $context',
        );
        // A day with fewer than three usable exercises must be reported.
        if (dayKeys.length < 3) {
          expect(plan.warnings, isNotEmpty, reason: '${day.namePt}; $context');
        }

        for (final key in dayKeys) {
          expect(
            equipmentCovers(equipmentOf[key]!, equipment),
            isTrue,
            reason: 'equipment $key; $context',
          );
          expect(
            avoided,
            isNot(contains(key)),
            reason: 'avoided $key; $context',
          );
          expect(
            limitationConflict(
              key,
              limitAreas: limitAreas,
              impactAllowed: impactOk,
            ),
            isNull,
            reason: 'limitation $key; $context',
          );
        }

        // Time: a day may only exceed the session by the tolerance, unless it
        // is already down to the minimum of three exercises.
        final budget =
            prefs.sessionMinutes -
            (day.cardioMinutes > 0 ? day.cardioMinutes : 0);
        if (dayKeys.length > 3) {
          expect(
            day.estimatedMinutes - day.cardioMinutes,
            lessThanOrEqualTo(budget + 5),
            reason: 'time in ${day.namePt}; $context',
          );
        }
      }
    }
    expect(checkedDays, greaterThan(runs));
  });

  test('time fit lands near the requested length for typical answers', () {
    // Documented exceptions (docs/WORKOUT_PLANS.md, "Time fit"):
    // - Upper bound: the fit never goes below three exercises, so short
    //   sessions can run up to the 5 min tolerance over the request. The
    //   ceiling used here is max(105%, request + 5 min).
    // - Lower bound: a day can stay under 80% only when the catalogue has no
    //   accessory left that the equipment covers (the day is out of
    //   accessories). That is checked below for every short day.
    const typicalEquipment = [
      {'bodyweight', 'dumbbells', 'cable'},
      {'bodyweight', 'dumbbells', 'cable', 'bands', 'bench'},
    ];
    final accessoryKeys = [
      for (final e in exerciseTraits.entries)
        if (e.value.accessory) e.key,
    ];
    final outside = <String>[];
    final unexplainedShort = <String>[];
    var checkedDays = 0;
    var shortDays = 0;
    for (final equipment in typicalEquipment) {
      for (final goal in PlanPreferences.goals) {
        for (final experience in PlanPreferences.experiences) {
          for (final days in [1, 2, 3, 4, 5, 6]) {
            for (final session in [20, 30, 45, 60, 75, 90]) {
              final prefs = PlanPreferences(
                goal: goal,
                experience: experience,
                weekdays: defaultWeekdays(days),
                sessionMinutes: session,
                equipment: equipment,
              );
              final plan = buildPlan(prefs, equipmentOf);
              for (final day in plan.days) {
                checkedDays++;
                final minutes = day.estimatedMinutes;
                final label =
                    '${day.namePt} $minutes min for $session min '
                    '($goal, $experience, $days days, $equipment)';
                final ceiling = max(session * 1.05, session + 5);
                if (minutes > ceiling) outside.add(label);
                if (minutes < session * 0.8) {
                  shortDays++;
                  final used = {for (final s in day.exercises) s.exerciseKey};
                  final left = [
                    for (final key in accessoryKeys)
                      if (!used.contains(key) &&
                          equipmentCovers(equipmentOf[key]!, equipment))
                        key,
                  ];
                  if (left.isNotEmpty)
                    unexplainedShort.add('$label, left: $left');
                }
              }
            }
          }
        }
      }
    }
    expect(checkedDays, greaterThan(1000));
    // Short days are rare: most combinations land in the band.
    expect(shortDays, lessThan(checkedDays ~/ 10));
    expect(outside, isEmpty, reason: outside.join('\n'));
    expect(unexplainedShort, isEmpty, reason: unexplainedShort.join('\n'));
  });

  test('under-18 answers never produce a plan, whatever else they chose', () {
    final random = Random(7);
    for (var run = 0; run < 50; run++) {
      final prefs = PlanPreferences(
        ageRange: 'under18',
        goal:
            PlanPreferences.goals[random.nextInt(PlanPreferences.goals.length)],
        equipment: {'bodyweight'},
      );
      expect(() => buildPlan(prefs, equipmentOf), throwsStateError);
    }
  });
}
