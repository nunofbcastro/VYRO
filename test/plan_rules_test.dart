import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/workouts/domain/exercise_traits.dart';
import 'package:vyro/features/workouts/domain/plan_generator.dart';
import 'package:vyro/features/workouts/domain/plan_preferences.dart';

/// Equipment requirement per catalogue key, as stored in the database.
final equipmentOf = {
  for (final entry in exerciseTraits.entries) entry.key: entry.value.equipment,
};

const home = {'bodyweight', 'dumbbells', 'cable'};

GeneratedPlan planFor(PlanPreferences prefs) => buildPlan(prefs, equipmentOf);

Set<String> keysOf(GeneratedPlan plan) => {
  for (final day in plan.days)
    for (final slot in day.exercises) slot.exerciseKey,
};

void main() {
  group('split', () {
    test('beginners keep whole-body sessions up to four days', () {
      for (final days in [1, 2, 3, 4]) {
        final plan = planFor(
          PlanPreferences(
            experience: 'under6m',
            weekdays: List.generate(days, (i) => i + 1),
            equipment: home,
          ),
        );
        expect(
          plan.days.every((d) => d.namePt.startsWith('Corpo inteiro')),
          isTrue,
          reason: '$days days',
        );
      }
    });

    test('experienced users with four days get upper/lower', () {
      final plan = planFor(
        const PlanPreferences(
          experience: 'six24m',
          weekdays: [1, 2, 4, 5],
          equipment: home,
        ),
      );
      expect(plan.days.map((d) => d.nameEn), [
        'Upper A',
        'Lower A',
        'Upper B',
        'Lower B',
      ]);
    });

    test('five and six days: push/pull/legs for experienced users', () {
      final six = planFor(
        const PlanPreferences(
          experience: 'over2y',
          weekdays: [1, 2, 3, 4, 5, 6],
          equipment: home,
        ),
      );
      expect(six.days.map((d) => d.nameEn).take(3), ['Push', 'Pull', 'Legs']);
    });
  });

  group('limitations and substitutions', () {
    test('knee with avoid impact: no reverse lunges anywhere', () {
      final plan = planFor(
        const PlanPreferences(
          weekdays: [1, 3, 5],
          equipment: home,
          limitAreas: {'knee': avoidImpact},
        ),
      );
      expect(keysOf(plan), isNot(contains('reverse_lunge')));
      expect(keysOf(plan), contains('split_squat'));
    });

    test(
      'knee with avoid heavy load: goblet squat is replaced by leg press',
      () {
        final plan = planFor(
          const PlanPreferences(
            weekdays: [1, 3, 5],
            equipment: {'bodyweight', 'dumbbells', 'cable', 'machines'},
            limitAreas: {'knee': avoidHeavyLoad},
          ),
        );
        expect(keysOf(plan), isNot(contains('goblet_squat')));
        expect(keysOf(plan), contains('leg_press'));
        expect(
          plan.notes.any((n) => n.en.contains('We swapped')),
          isTrue,
          reason: 'the swap is explained',
        );
      },
    );

    test('shoulder with avoid heavy load: no overhead or heavy pressing', () {
      final plan = planFor(
        const PlanPreferences(
          weekdays: [1, 2, 3, 4],
          equipment: {'bodyweight', 'dumbbells', 'cable', 'barbell', 'bench'},
          limitAreas: {'shoulder': avoidHeavyLoad},
          experience: 'six24m',
        ),
      );
      final keys = keysOf(plan);
      expect(keys, isNot(contains('shoulder_press')));
      expect(keys, isNot(contains('dumbbell_press')));
      expect(keys, isNot(contains('bench_press')));
      expect(keys, isNot(contains('pike_push_up')));
    });

    test(
      'lower back with avoid heavy load: no heavy hinge, glute work instead',
      () {
        final plan = planFor(
          const PlanPreferences(
            weekdays: [1, 3, 5],
            equipment: {'bodyweight', 'dumbbells', 'cable', 'bench'},
            limitAreas: {'lower_back': avoidHeavyLoad},
          ),
        );
        final keys = keysOf(plan);
        expect(keys, isNot(contains('hip_hinge')));
        expect(keys.intersection({'glute_bridge', 'hip_thrust'}), isNotEmpty);
      },
    );

    test('avoid completely on wrist/elbow removes every loaded push', () {
      final plan = planFor(
        const PlanPreferences(
          weekdays: [1, 3, 5],
          equipment: home,
          limitAreas: {'wrist_elbow': avoidCompletely},
        ),
      );
      expect(keysOf(plan), isNot(contains('push_up')));
      expect(keysOf(plan), isNot(contains('plank')));
    });

    test('avoided exercises never appear and favourites come first', () {
      final avoided = planFor(
        const PlanPreferences(
          weekdays: [1, 3, 5],
          equipment: home,
          avoidedExercises: {'goblet_squat'},
        ),
      );
      expect(keysOf(avoided), isNot(contains('goblet_squat')));

      final favourite = planFor(
        const PlanPreferences(
          weekdays: [1, 3, 5],
          equipment: {'bodyweight'},
          favouriteExercises: {'push_up'},
        ),
      );
      expect(
        favourite.days.first.exercises.map((e) => e.exerciseKey),
        contains('push_up'),
      );
    });

    test('no impact removes jumps and dynamic lunges', () {
      final plan = planFor(
        const PlanPreferences(
          weekdays: [1, 3, 5],
          equipment: home,
          impactAllowed: false,
        ),
      );
      expect(keysOf(plan), isNot(contains('reverse_lunge')));
    });
  });

  group('age and under 18', () {
    test('60 plus: low impact and a balance exercise on every day', () {
      final plan = planFor(
        const PlanPreferences(
          ageRange: '60plus',
          weekdays: [1, 3, 5],
          equipment: home,
          goal: 'strength',
        ),
      );
      expect(keysOf(plan), isNot(contains('reverse_lunge')));
      for (final day in plan.days) {
        expect(
          day.exercises.map((e) => e.exerciseKey),
          contains('single_leg_balance'),
        );
      }
    });

    test('under 18 is not generated', () {
      expect(
        () => planFor(
          const PlanPreferences(ageRange: 'under18', equipment: home),
        ),
        throwsStateError,
      );
    });
  });

  group('prescription and comeback', () {
    test('goal changes the prescription of main lifts', () {
      final strength = prescriptionFor('strength', 'over2y');
      final fatLoss = prescriptionFor('fat_loss', 'over2y');
      expect(strength.reps, lessThan(fatLoss.reps));
      expect(strength.restSeconds, greaterThan(fatLoss.restSeconds));
    });

    test('more than six months away lowers starting volume by one set', () {
      final normal = prescriptionFor('muscle', 'over2y');
      final back = prescriptionFor('muscle', 'over2y', detraining: 'gt6m');
      expect(back.sets, normal.sets - 1);
      expect(
        prescriptionFor('muscle', 'over2y', detraining: 'lt1m').sets,
        normal.sets,
      );
    });

    test('the generated main lifts follow the reduced volume', () {
      final plan = planFor(
        const PlanPreferences(
          goal: 'muscle',
          experience: 'over2y',
          detraining: 'gt6m',
          weekdays: [1, 3, 5],
          equipment: home,
        ),
      );
      final expected = prescriptionFor(
        'muscle',
        'over2y',
        detraining: 'gt6m',
      ).sets;
      final main = plan.days.first.exercises.where((s) => !s.timed);
      expect(main.where((s) => s.sets == expected), isNotEmpty);
    });

    test('rest preference scales rest in 15 s steps', () {
      final short = prescriptionFor('muscle', 'six24m', rest: 'short');
      final normal = prescriptionFor('muscle', 'six24m');
      expect(short.restSeconds % 15, 0);
      expect(short.restSeconds, lessThan(normal.restSeconds));
    });
  });

  group('time fit, style and cardio', () {
    test('a short session is trimmed towards its length', () {
      final plan = planFor(
        const PlanPreferences(
          goal: 'strength',
          sessionMinutes: 30,
          weekdays: [1, 3, 5],
          equipment: home,
        ),
      );
      for (final day in plan.days) {
        expect(
          day.estimatedMinutes,
          lessThanOrEqualTo(30 + 5),
          reason: day.namePt,
        );
      }
    });

    test('circuits pair consecutive accessories into supersets', () {
      final plan = planFor(
        const PlanPreferences(
          style: 'circuits',
          weekdays: [1, 3, 5],
          equipment: home,
          priorities: {'arms', 'shoulders'},
          sessionMinutes: 60,
        ),
      );
      final grouped = [
        for (final day in plan.days)
          for (final slot in day.exercises)
            if (slot.supersetGroup != null) slot,
      ];
      expect(grouped, isNotEmpty);
      for (final day in plan.days) {
        final groups = [
          for (final slot in day.exercises)
            if (slot.supersetGroup != null) slot.supersetGroup,
        ];
        for (final g in groups.toSet()) {
          expect(groups.where((x) => x == g).length, 2, reason: day.namePt);
        }
      }
    });

    test('finisher cardio adds 10 minutes; dedicated adds 20', () {
      final finisher = planFor(
        const PlanPreferences(
          cardio: 'finisher',
          weekdays: [1, 3, 5],
          equipment: home,
        ),
      );
      expect(finisher.days.first.cardioMinutes, 10);
      final dedicated = planFor(
        const PlanPreferences(
          cardio: 'dedicated',
          cardioType: 'run',
          impactAllowed: false,
          weekdays: [1, 3, 5],
          equipment: home,
        ),
      );
      expect(dedicated.days.first.cardioMinutes, 20);
      // Running is swapped for walking when impact is not allowed.
      expect(dedicated.days.first.cardioType, 'walk');
    });
  });

  group('block and progression', () {
    test('the last week is a deload with about 40% less volume', () {
      for (final weeks in [4, 6, 8]) {
        final schedule = blockSchedule(weeks);
        expect(schedule.length, weeks);
        expect(schedule.last.deload, isTrue);
        expect(schedule.last.volumeFactor, closeTo(0.6, 0.001));
        expect(schedule.take(weeks - 1).every((w) => !w.deload), isTrue);
        expect(schedule.first.volumeFactor, 1.0);
      }
    });

    test('the plan carries the block and the progression rule text', () {
      final plan = planFor(
        const PlanPreferences(
          blockWeeks: 6,
          weekdays: [1, 3, 5],
          equipment: home,
        ),
      );
      expect(plan.blockWeeks, 6);
      expect(plan.weeks.length, 6);
      final slot = plan.days.first.exercises.firstWhere((s) => !s.timed);
      expect(
        progressionRule(slot, english: true),
        contains('${slot.reps} reps'),
      );
      expect(plan.notes, isNotEmpty);
    });

    test('a degenerate rep range reads as one number, in both languages', () {
      expect(
        repRangeText(top: 10, bottom: 10, english: false),
        '10 repetições',
      );
      expect(repRangeText(top: 10, english: true), '10 reps');
      expect(
        repRangeText(top: 12, bottom: 10, english: false),
        '10–12 repetições',
      );
      expect(repRangeText(top: 15, bottom: 12, english: true), '12–15 reps');
    });

    test('health goal rationale and progression never show 10–10', () {
      final plan = planFor(
        const PlanPreferences(
          goal: 'health',
          experience: 'under6m',
          weekdays: [1, 3, 5],
          equipment: home,
        ),
      );
      final pt = plan.notes.map((n) => n.pt).join(' ');
      final en = plan.notes.map((n) => n.en).join(' ');
      expect(pt, isNot(contains('10–10')));
      expect(en, isNot(contains('10–10')));
      expect(pt, contains('de 10 repetições'));
      expect(en, contains('of 10 reps'));

      final slot = plan.days.first.exercises.firstWhere((s) => !s.timed);
      expect(
        progressionRule(slot, english: false),
        contains('${slot.reps} repetições'),
      );
      expect(
        progressionRule(slot, english: true),
        contains('${slot.reps} reps'),
      );
    });

    test('consecutive identical weeks are grouped into one line', () {
      final expected = {
        4: ['Semanas 1–3', 'Semana 4'],
        6: ['Semanas 1–5', 'Semana 6'],
        8: ['Semanas 1–7', 'Semana 8'],
      };
      for (final entry in expected.entries) {
        final phases = blockPhases(blockSchedule(entry.key));
        expect(phases.length, 2, reason: '${entry.key} weeks');
        expect(
          phases.first.text(false),
          startsWith('${entry.value[0]}: progressão normal. '),
        );
        expect(
          phases.last.text(false),
          startsWith('${entry.value[1]}: descarga. '),
        );
        expect(
          phases.first.text(true),
          startsWith('Weeks 1–${entry.key - 1}: normal progression. '),
        );
        expect(
          phases.last.text(true),
          startsWith('Week ${entry.key}: deload. '),
        );
        expect(phases.last.deload, isTrue);
        expect(phases.first.deload, isFalse);
      }
    });

    test('the 4 week block shows one progression line and one deload line', () {
      final phases = blockPhases(blockSchedule(4));
      final text = [for (final p in phases) p.text(false)].join('\n');
      expect(text, isNot(contains('Semana 2')));
      expect(RegExp('progressão normal').allMatches(text).length, 1);
    });
  });

  group('time fit', () {
    test('a 45 min beginner session lands within 80–105% of the request', () {
      final plan = planFor(
        const PlanPreferences(
          goal: 'health',
          experience: 'under6m',
          sessionMinutes: 45,
          weekdays: [1, 3, 5],
          equipment: home,
        ),
      );
      for (final day in plan.days) {
        expect(
          day.estimatedMinutes,
          inInclusiveRange(36, 47),
          reason: day.namePt,
        );
      }
      // Days 1–3 share one fill note, so it is written once for the range.
      final pt = plan.notes
          .map((n) => n.pt)
          .firstWhere((t) => t.contains('45 min pedidos'));
      expect(pt, startsWith('Dias 1–3: '));
      expect(pt, contains('séries a mais nos principais'));
    });

    test('added sets stop at the goal cap and are reported per day', () {
      final plan = planFor(
        const PlanPreferences(
          goal: 'strength',
          experience: 'never',
          sessionMinutes: 60,
          weekdays: [1, 3, 5],
          equipment: home,
        ),
      );
      final maxMainSets = plan.days
          .expand((d) => d.exercises)
          .where((s) => !s.timed && s.reps <= 8)
          .map((s) => s.sets)
          .reduce((a, b) => a > b ? a : b);
      expect(maxMainSets, lessThanOrEqualTo(5));
    });

    test(
      'a day that is already long enough is not padded past the tolerance',
      () {
        final plan = planFor(
          const PlanPreferences(
            goal: 'fat_loss',
            experience: 'over2y',
            sessionMinutes: 60,
            weekdays: [1, 3, 5],
            equipment: home,
          ),
        );
        for (final day in plan.days) {
          expect(
            day.estimatedMinutes,
            lessThanOrEqualTo(65),
            reason: day.namePt,
          );
        }
      },
    );
  });
}
