import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/workouts/domain/ai_plan.dart';
import 'package:vyro/features/workouts/domain/plan_generator.dart';
import 'package:vyro/features/workouts/domain/plan_preferences.dart';

void main() {
  const facts = [
    'Escolhemos treino de corpo inteiro porque treinas 3 dias.',
    'Cada treino usa 3 séries de 10–12 repetições com 90 s de descanso.',
  ];

  group('on-device summary (rationale only)', () {
    test('the prompt contains only the given facts and the language', () {
      final prompt = buildRationalePrompt(facts, english: true);
      expect(prompt, contains('- ${facts.first}'));
      expect(prompt, contains('English'));
      expect(prompt, contains('Use ONLY the facts below'));
    });

    test('a clean sentence that uses only the facts is accepted', () {
      expect(
        parseRationale(
          'Treinas 3 dias por semana com 3 séries de 10–12 repetições.',
          facts,
        ),
        'Treinas 3 dias por semana com 3 séries de 10–12 repetições.',
      );
    });

    test('digits that are not in the facts are rejected', () {
      expect(parseRationale('Faz 5 séries de 20 repetições.', facts), isNull);
    });

    test('safety, technique or medical claims are rejected', () {
      for (final bad in [
        'Este plano é seguro para ti.',
        'A técnica está correta em todos os exercícios.',
        'Garante resultados rápidos.',
        'This plan is safe and correct.',
        'It can cure your knee pain.',
      ]) {
        expect(parseRationale(bad, facts), isNull, reason: bad);
      }
    });

    test(
      'empty, overlong or whitespace-only text is rejected and spaces collapse',
      () {
        expect(parseRationale('   ', facts), isNull);
        expect(parseRationale('a' * 301, facts), isNull);
        expect(
          parseRationale('  Treinas   3 dias\n\n  com calma.  ', facts),
          'Treinas 3 dias com calma.',
        );
      },
    );
  });

  group('session length', () {
    test('session length changes the number of exercises', () {
      expect(exercisesForMinutes(30), 4);
      expect(exercisesForMinutes(75), 7);
    });
  });

  group('preferences round-trip', () {
    test('encode then decode keeps the answers', () {
      const prefs = PlanPreferences(
        goal: 'strength',
        weekdays: [2, 4],
        equipment: {'bodyweight', 'dumbbells'},
      );
      final decoded = PlanPreferences.decode(prefs.encode());
      expect(decoded.weekdays, [2, 4]);
      expect(decoded.goal, 'strength');
      expect(decoded.equipment, {'bodyweight', 'dumbbells'});
    });

    test('bad values fall back to defaults without throwing', () {
      final bad = PlanPreferences.decode('{"goal":"x","weekdays":[9]}');
      expect(bad.goal, 'health');
      expect(bad.weekdays, [1, 3, 5]);
      expect(PlanPreferences.decode('not json').goal, 'health');
    });
  });
}
