import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/workouts/domain/ai_plan.dart';
import 'package:vyro/features/workouts/domain/plan_generator.dart';
import 'package:vyro/features/workouts/domain/plan_preferences.dart';

void main() {
  const prefs = PlanPreferences(
    goal: 'strength',
    weekdays: [2, 4],
    sessionMinutes: 45,
    equipment: {'bodyweight', 'dumbbells'},
  );
  const allowed = {
    'goblet_squat',
    'push_up',
    'dumbbell_row',
    'plank',
    'hip_hinge',
    'glute_bridge',
  };
  const fallback = GeneratedPlan(
    titlePt: 'Força · 2 dias',
    titleEn: 'Strength · 2 days',
    days: [
      PlannedDay(
        namePt: 'Corpo inteiro A',
        nameEn: 'Full body A',
        weekday: 2,
        exercises: [],
      ),
      PlannedDay(
        namePt: 'Corpo inteiro B',
        nameEn: 'Full body B',
        weekday: 4,
        exercises: [],
      ),
    ],
  );

  test('valid JSON becomes a plan with clamped values and user weekdays', () {
    const raw = '''Here you go:
{"days":[
 {"name":"Pernas","exercises":[{"key":"goblet_squat","sets":9,"reps":2},{"key":"hip_hinge","sets":3,"reps":8},{"key":"glute_bridge","sets":3,"reps":12},{"key":"leg_press","sets":3,"reps":10}]},
 {"name":"Tronco","exercises":[{"key":"push_up","sets":3,"reps":10},{"key":"dumbbell_row","sets":3,"reps":10},{"key":"plank","sets":3,"reps":30},{"key":"push_up","sets":3,"reps":10}]}
],"notes":"Foco em técnica."}''';
    final result = parseAiPlan(
      raw,
      prefs: prefs,
      allowedKeys: allowed,
      fallbackTitles: fallback,
    )!;
    final first = result.plan.days.first;
    expect(first.namePt, 'Pernas');
    expect(first.weekday, 2);
    // Unknown key dropped, sets/reps clamped, rest from the goal.
    expect(first.exercises.map((e) => e.exerciseKey), [
      'goblet_squat',
      'hip_hinge',
      'glute_bridge',
    ]);
    expect(first.exercises.first.sets, 5);
    expect(first.exercises.first.reps, 5);
    expect(first.exercises.first.restSeconds, 150);
    // Duplicate removed, reps capped at 20.
    final second = result.plan.days[1];
    expect(second.exercises.length, 3);
    expect(second.exercises.last.reps, 20);
    expect(result.notes, 'Foco em técnica.');
  });

  test('wrong number of days or too few valid exercises is rejected', () {
    expect(
      parseAiPlan(
        '{"days":[{"name":"A","exercises":[]}]}',
        prefs: prefs,
        allowedKeys: allowed,
        fallbackTitles: fallback,
      ),
      isNull,
    );
    expect(
      parseAiPlan(
        'not json at all',
        prefs: prefs,
        allowedKeys: allowed,
        fallbackTitles: fallback,
      ),
      isNull,
    );
  });

  test('prompt lists only allowed exercises and the chosen days', () {
    final prompt = buildPlanPrompt(prefs, const [
      CatalogChoice(key: 'push_up', name: 'Flexão', muscleGroup: 'chest'),
    ], english: false);
    expect(prompt, contains('push_up (Flexão, chest)'));
    expect(prompt, contains('Terça-feira, Quinta-feira'));
    expect(prompt, contains('exactly 2 items'));
  });

  test('session length changes the number of exercises', () {
    PlanPreferences p(int minutes) => prefs.copyWith(sessionMinutes: minutes);
    expect(exercisesForMinutes(p(30).sessionMinutes), 4);
    expect(exercisesForMinutes(p(75).sessionMinutes), 7);
  });

  test('preferences round-trip and reject bad values', () {
    final decoded = PlanPreferences.decode(prefs.encode());
    expect(decoded.weekdays, [2, 4]);
    expect(decoded.goal, 'strength');
    final bad = PlanPreferences.decode('{"goal":"x","weekdays":[9]}');
    expect(bad.goal, 'routine');
    expect(bad.weekdays, [1, 3, 5]);
  });
}
