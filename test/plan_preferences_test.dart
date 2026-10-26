import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/workouts/domain/plan_preferences.dart';

/// Exactly what version 0.6.x stored in the `plan_preferences` row.
const _version1 =
    '{"goal":"nutrition","experience":"intermediate","weekdays":[1,3,5],'
    '"sessionMinutes":60,"equipment":["bodyweight","cable","unknown"],'
    '"priorities":["legs","chest"],"limitations":"dor no joelho"}';

void main() {
  group('decode version 1 (migration)', () {
    test('old values map to the new vocabulary', () {
      final prefs = PlanPreferences.decode(_version1);
      expect(prefs.goal, 'fat_loss');
      expect(prefs.experience, 'six24m');
      expect(prefs.weekdays, [1, 3, 5]);
      expect(prefs.sessionMinutes, 60);
      expect(prefs.equipment, {'bodyweight', 'cable'});
      expect(prefs.priorities, {'legs', 'chest'});
      expect(prefs.limitations, 'dor no joelho');
    });

    test('new fields get safe defaults', () {
      final prefs = PlanPreferences.decode(_version1);
      expect(prefs.detraining, 'none');
      expect(prefs.location, 'mixed');
      expect(prefs.limitAreas, isEmpty);
      expect(prefs.cardio, 'none');
      expect(prefs.impactAllowed, isTrue);
      expect(prefs.style, 'traditional');
      expect(prefs.rest, 'normal');
      expect(prefs.ageRange, isNull);
      expect(prefs.activityLevel, isNull);
      expect(prefs.blockWeeks, 4);
    });

    test('routine and strength and the beginner/advanced labels migrate', () {
      expect(PlanPreferences.decode('{"goal":"routine"}').goal, 'health');
      expect(PlanPreferences.decode('{"goal":"strength"}').goal, 'strength');
      expect(
        PlanPreferences.decode('{"experience":"beginner"}').experience,
        'under6m',
      );
      expect(
        PlanPreferences.decode('{"experience":"advanced"}').experience,
        'over2y',
      );
    });

    test('version 0.3 emphasis still migrates', () {
      expect(PlanPreferences.decode('{"emphasis":"core"}').priorities, {
        'core',
      });
    });
  });

  group('version 2', () {
    test('encode then decode keeps every answer', () {
      const prefs = PlanPreferences(
        goal: 'muscle',
        secondaryGoal: 'endurance',
        experience: 'over2y',
        detraining: 'gt6m',
        weekdays: [2, 4, 6],
        sessionMinutes: 75,
        location: 'gym',
        equipment: {'barbell', 'rack', 'machines', 'dumbbells'},
        dumbbellMaxKg: 24,
        priorities: {'back'},
        limitAreas: {'knee': 'avoid_heavy_load', 'lower_back': 'avoid_impact'},
        limitations: 'joelho',
        avoidedExercises: {'burpee'},
        favouriteExercises: {'push_up'},
        cardio: 'finisher',
        cardioType: 'bike',
        impactAllowed: false,
        style: 'circuits',
        rest: 'short',
        ageRange: '40to59',
        activityLevel: 'light',
        blockWeeks: 6,
      );
      final decoded = PlanPreferences.decode(prefs.encode());
      expect(decoded.encode(), prefs.encode());
      expect(decoded.dumbbellMaxKg, 24);
      expect(decoded.limitAreas['knee'], 'avoid_heavy_load');
      expect(decoded.blockWeeks, 6);
    });

    test('unknown or out-of-range values fall back, never throw', () {
      final prefs = PlanPreferences.decode(
        jsonEncode({
          'goal': 'lose-everything',
          'sessionMinutes': 500,
          'blockWeeks': 5,
          'dumbbellMaxKg': 999,
          'limitAreas': {'knee': 'destroy', 'elbow': 'avoid_impact'},
          'ageRange': 'alien',
          'equipment': ['laser'],
        }),
      );
      expect(prefs.goal, 'health');
      expect(prefs.sessionMinutes, 90, reason: 'nearest allowed value');
      expect(prefs.blockWeeks, 4, reason: 'nearest allowed value (4 or 6)');
      expect(prefs.dumbbellMaxKg, isNull);
      expect(prefs.limitAreas, isEmpty);
      expect(prefs.ageRange, isNull);
      expect(prefs.equipment, isNotEmpty, reason: 'fallback equipment');
    });

    test('under 18 is flagged as blocked', () {
      expect(
        PlanPreferences.decode('{"ageRange":"under18"}').isBlocked,
        isTrue,
      );
      expect(
        PlanPreferences.decode('{"ageRange":"60plus"}').isBlocked,
        isFalse,
      );
    });

    test('session lengths snap to the wizard options', () {
      expect(
        PlanPreferences.decode('{"sessionMinutes":35}').sessionMinutes,
        30,
      );
      expect(
        PlanPreferences.decode('{"sessionMinutes":20}').sessionMinutes,
        20,
      );
    });
  });
}
