import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/nutrition/domain/food_recognition_service.dart';
import 'package:vyro/features/workouts/domain/ai_plan.dart';
import 'package:vyro/features/workouts/domain/plan_generator.dart';
import 'package:vyro/features/workouts/domain/plan_preferences.dart';

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
const _group = {
  'goblet_squat': 'legs',
  'split_squat': 'legs',
  'reverse_lunge': 'legs',
  'calf_raise': 'legs',
  'glute_bridge': 'glutes',
  'hip_hinge': 'hamstrings',
  'dumbbell_press': 'chest',
  'push_up': 'chest',
  'seated_row': 'back',
  'lat_pulldown': 'back',
  'dumbbell_row': 'back',
  'superman': 'back',
  'shoulder_press': 'shoulders',
  'lateral_raise': 'shoulders',
  'face_pull': 'shoulders',
  'pike_push_up': 'shoulders',
  'biceps_curl': 'arms',
  'triceps_pushdown': 'arms',
  'plank': 'core',
  'dead_bug': 'core',
  'side_plank': 'core',
  'bird_dog': 'core',
};

void main() {
  test('priorities add volume but every day keeps its full template', () {
    final plan = generatePlan(
      daysPerWeek: 3,
      goal: 'routine',
      experience: 'beginner',
      available: const {'bodyweight', 'dumbbells', 'cable'},
      equipmentOf: _equipment,
      sessionMinutes: 60,
      priorities: const {'arms', 'glutes'},
    );
    final week = {
      for (final day in plan.days)
        for (final e in day.exercises) _group[e.exerciseKey],
    };
    // Whole body still trained across the week…
    expect(week, containsAll(['legs', 'chest', 'back', 'core']));
    // …and the priorities show up as extra work.
    expect(week, containsAll(['arms', 'glutes']));
    for (final day in plan.days) {
      final groups = day.exercises.map((e) => _group[e.exerciseKey]).toSet();
      expect(groups.intersection({'legs', 'glutes', 'hamstrings'}), isNotEmpty);
      expect(groups.intersection({'chest', 'shoulders', 'back'}), isNotEmpty);
      expect(day.exercises.length, 6);
    }
  });

  test('old single emphasis migrates to priorities', () {
    expect(PlanPreferences.decode('{"emphasis":"legs"}').priorities, {
      'legs',
      'glutes',
    });
    expect(
      PlanPreferences.decode(
        '{"priorities":["chest","core","nope"]}',
      ).priorities,
      {'chest', 'core'},
    );
  });

  test('AI plans that only train the priority areas are rejected', () {
    const prefs = PlanPreferences(weekdays: [1, 3], priorities: {'legs'});
    const fallback = GeneratedPlan(
      titlePt: 'Rotina · 2 dias',
      titleEn: 'Routine · 2 days',
      days: [
        PlannedDay(namePt: 'A', nameEn: 'A', weekday: 1, exercises: []),
        PlannedDay(namePt: 'B', nameEn: 'B', weekday: 3, exercises: []),
      ],
    );
    const legsOnly =
        '{"days":[{"name":"Pernas","exercises":[{"key":"goblet_squat"},{"key":"split_squat"},{"key":"calf_raise"}]},'
        '{"name":"Pernas 2","exercises":[{"key":"reverse_lunge"},{"key":"goblet_squat"},{"key":"glute_bridge"}]}]}';
    expect(
      parseAiPlan(
        legsOnly,
        prefs: prefs,
        allowedKeys: _group.keys.toSet(),
        fallbackTitles: fallback,
        muscleGroupOf: _group,
      ),
      isNull,
    );
    const balanced =
        '{"days":[{"name":"A","exercises":[{"key":"goblet_squat"},{"key":"push_up"},{"key":"seated_row"}]},'
        '{"name":"B","exercises":[{"key":"split_squat"},{"key":"shoulder_press"},{"key":"lat_pulldown"}]}]}';
    expect(
      parseAiPlan(
        balanced,
        prefs: prefs,
        allowedKeys: _group.keys.toSet(),
        fallbackTitles: fallback,
        muscleGroupOf: _group,
      ),
      isNotNull,
    );
  });

  test('quantized softmax scores are renormalised, not re-softmaxed', () {
    // Regression: the bundled model's uint8 softmax sums to ~0.89. A second
    // softmax flattened it to ~1/2024 per class and no food was shown.
    final scores = List<double>.filled(2024, 0)
      ..[0] = 0.0
      ..[267] = 49 / 256
      ..[12] = 30 / 256
      ..[99] = 148 / 256;
    final p = toProbabilities(scores);
    expect(p[267], closeTo((49 / 256) / (227 / 256), 1e-9));
    final ranked = rankCandidates(p, {
      12: 'Waffle',
      99: 'Other',
      267: 'Sausage',
    });
    expect(ranked.map((c) => c.label), ['Other', 'Sausage', 'Waffle']);
  });
}
