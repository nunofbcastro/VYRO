import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/ai/on_device_llm.dart';
import 'package:vyro/features/assistant/domain/meal_math.dart';
import 'package:vyro/features/assistant/domain/meal_proposal.dart';
import 'package:vyro/features/assistant/domain/model_answer.dart';
import 'package:vyro/features/assistant/domain/prose_numbers.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';

/// Fake on-device model: returns a fixed reply and records the prompt.
class FakeLlm implements OnDeviceLlm {
  FakeLlm(this.reply);
  final String reply;
  String? lastPrompt;

  @override
  Future<LlmStatus> status() async => LlmStatus.available;

  @override
  Future<LlmStatus> download() async => LlmStatus.available;

  @override
  Future<String> generate(String prompt) async {
    lastPrompt = prompt;
    return reply;
  }
}

FoodRef _food(
  String key,
  String namePt, {
  double kcal = 100,
  double protein = 10,
  double carbs = 10,
  double fat = 1,
  String category = 'teste',
  List<String> aliases = const [],
}) => FoodRef(
  key: key,
  namePt: namePt,
  nameEn: namePt,
  category: category,
  source: 'taco',
  sourceRef: key,
  kcal: kcal,
  protein: protein,
  carbs: carbs,
  fat: fat,
  fiber: 0,
  portionG: 100,
  portionPt: '100 g',
  portionEn: '100 g',
  aliases: aliases,
);

String _proposalBlock(Map<String, Object> json) =>
    '[[MEAL]]${jsonEncode(json)}[[/MEAL]]';

void main() {
  final realDb = FoodDatabase.parse(
    File('assets/nutrition/foods.json').readAsStringSync(),
  );

  group('composition with the on-device model (fake LLM)', () {
    test(
      'model kcal in the prose and in the proposal never reach the card',
      () async {
        final chicken = realDb.byKey('chicken_breast_roasted')!;
        final rice = realDb.byKey('rice_white_cooked')!;
        final expectedKcal = chicken.kcal * 150 / 100 + rice.kcal * 120 / 100;
        final llm = FakeLlm(
          'Grelha o frango e cozinha o arroz. Tem cerca de 900 kcal e 80 g de proteína.\n'
          '${_proposalBlock({
            'meal': 'dinner',
            'items': [
              {'name': 'Peito de frango grelhado', 'grams': 150},
              {'name': 'Arroz branco cozido', 'grams': 120},
            ],
          })}',
        );
        final answer = await answerFromModel(
          llm: llm,
          prompt: 'O que janto?',
          db: realDb,
          english: false,
        );

        expect(llm.lastPrompt, contains('O que janto?'));
        final meal = answer.meal!;
        expect(meal.complete, isTrue);
        expect(meal.totals.kcal, closeTo(expectedKcal, 1e-6));
        expect(meal.label(false), startsWith('Valores da base'));
        // The model's conflicting sentence is not shown as a fact.
        expect(answer.text, isNot(contains('900')));
        expect(answer.text, isNot(contains('80 g')));
        expect(answer.text, isNot(contains('[[MEAL]]')));
        expect(answer.text, isNot(contains('Valores calculados')));
        expect(answer.footnote, contains('retiradas'));
      },
    );

    test(
      'an unresolved item is shown as missing and totals are partial',
      () async {
        final llm = FakeLlm(
          'Uma refeição simples.\n'
          '${_proposalBlock({
            'meal': 'lunch',
            'items': [
              {'name': 'Peito de frango grelhado', 'grams': 100},
              {'name': 'Prato secreto desconhecido', 'grams': 200},
            ],
          })}',
        );
        final answer = await answerFromModel(
          llm: llm,
          prompt: 'p',
          db: realDb,
          english: false,
        );
        final meal = answer.meal!;
        expect(meal.complete, isFalse);
        expect(meal.items[1].food, isNull);
        expect(meal.items[1].resolved, isFalse);
        final chicken = realDb.byKey('chicken_breast_roasted')!;
        expect(meal.totals.kcal, closeTo(chicken.kcal, 1e-6));
        expect(meal.label(false), contains('parcia'));
        expect(meal.label(true), startsWith('Partial values'));
      },
    );

    test(
      'prose numbers that conflict with the local totals are not shown',
      () async {
        final llm = FakeLlm(
          'Lentilhas com legumes.\n'
          'Tem 500 kcal no total.\n'
          'Mantém a porção pequena.\n'
          '${_proposalBlock({
            'meal': 'dinner',
            'items': [
              {'name': 'Lentilhas cozidas', 'grams': 150},
            ],
          })}',
        );
        final answer = await answerFromModel(
          llm: llm,
          prompt: 'p',
          db: realDb,
          english: false,
        );
        expect(answer.text, isNot(contains('500')));
        expect(answer.text, contains('Lentilhas com legumes.'));
        expect(answer.text, contains('Mantém a porção pequena.'));
      },
    );

    test('prose numbers that agree with the local totals are kept', () async {
      final lentils = realDb.byKey('lentils_cooked')!;
      final expected = (lentils.kcal * 150 / 100).round();
      final llm = FakeLlm(
        'Tem $expected kcal, uma boa escolha.\n'
        '${_proposalBlock({
          'meal': 'dinner',
          'items': [
            {'name': 'Lentilhas cozidas', 'grams': 150},
          ],
        })}',
      );
      final answer = await answerFromModel(
        llm: llm,
        prompt: 'p',
        db: realDb,
        english: false,
      );
      expect(answer.text, contains('Tem $expected kcal, uma boa escolha.'));
      expect(answer.text, isNot(contains('removidas')));
    });

    test('an answer without numbers is unchanged', () async {
      const reply =
          'Experimenta frango com arroz.\n\n1. Grelha o frango.\n2. Serve com arroz.';
      final answer = await answerFromModel(
        llm: FakeLlm(reply),
        prompt: 'p',
        db: realDb,
        english: false,
      );
      expect(answer.text, reply);
      expect(answer.meal, isNull);
    });

    test(
      'nutrient numbers without any meal cannot be verified and are removed',
      () async {
        final answer = await answerFromModel(
          llm: FakeLlm('Um almoço tem cerca de 600 kcal.\nBebe água.'),
          prompt: 'p',
          db: realDb,
          english: false,
        );
        expect(answer.text, isNot(contains('600')));
        expect(answer.text, contains('Bebe água.'));
      },
    );

    test('a proposal that breaks the vegan profile is refused', () async {
      final answer = await answerFromModel(
        llm: FakeLlm(
          _proposalBlock({
            'meal': 'dinner',
            'items': [
              {'name': 'Peito de frango grelhado', 'grams': 150},
            ],
          }),
        ),
        prompt: 'p',
        db: realDb,
        diet: 'vegan',
        english: false,
      );
      expect(answer.rejected, isTrue);
      expect(answer.meal, isNull);
    });
  });

  group('matching: negation and ambiguity', () {
    final db = FoodDatabase([
      _food('cafe_sem', 'Café sem açúcar', kcal: 2),
      _food('cafe_com', 'Café com açúcar', kcal: 40),
      _food('iogurte_natural', 'Iogurte natural', kcal: 60),
      _food('frango', 'Frango assado', kcal: 200),
      _food('arroz', 'Arroz cozido', kcal: 130),
    ]);

    test('"sem" and "com" are not dropped when choosing a food', () {
      expect(matchFood('Café sem açúcar', db)!.key, 'cafe_sem');
      expect(matchFood('Café com açúcar', db)!.key, 'cafe_com');
      final sem = resolveItem(
        const ProposedItem(name: 'Café sem açúcar', grams: 100),
        db,
      );
      expect(sem.food!.key, 'cafe_sem');
      expect(sem.needsConfirmation, isFalse);
      expect(sem.alternatives, isEmpty);
    });

    test('a food that contains the excluded word is never chosen', () {
      final ranked = rankFoods('Café sem açúcar', db).map((c) => c.food.key);
      expect(ranked, isNot(contains('cafe_com')));
    });

    test(
      '"sem" without a database entry is flagged, not silently confirmed',
      () {
        final item = resolveItem(
          const ProposedItem(name: 'Iogurte sem lactose', grams: 150),
          db,
        );
        expect(item.food!.key, 'iogurte_natural');
        expect(item.needsConfirmation, isTrue);
      },
    );

    test('a bare name that matches two foods shows alternatives', () {
      final item = resolveItem(
        const ProposedItem(name: 'Café', grams: 100),
        db,
      );
      expect(item.needsConfirmation, isTrue);
      expect(item.alternatives.map((f) => f.key), contains('cafe_com'));
    });

    test('a combined dish is not read as one of its parts', () {
      // "com arroz" is not in the chicken entry: no silent chicken-only value.
      final item = resolveItem(
        const ProposedItem(name: 'Frango com arroz', grams: 200),
        db,
      );
      expect(item.food, isNull);
      expect(item.resolved, isFalse);
    });

    test('an unrelated name has no database values', () {
      final item = resolveItem(
        const ProposedItem(name: 'Pizza de ananás', grams: 200),
        db,
      );
      expect(item.food, isNull);
      expect(item.resolved, isFalse);
    });
  });

  group('checkProseNumbers', () {
    const totals = MealTotals(kcal: 400, protein: 30, carbs: 50, fat: 10);

    test('no nutrient words means the text is returned as written', () {
      final check = checkProseNumbers(
        'Passo 1: aquece.\n2 colheres de azeite.',
      );
      expect(check.removedLines, 0);
      expect(check.text, 'Passo 1: aquece.\n2 colheres de azeite.');
    });

    test('kcal within tolerance is kept, outside it is removed', () {
      expect(
        checkProseNumbers('Total: 410 kcal', totals: totals).removedLines,
        0,
      );
      final off = checkProseNumbers('Total: 480 kcal', totals: totals);
      expect(off.removedLines, 1);
      expect(off.text, isEmpty);
    });

    test('protein in either word order is validated', () {
      expect(
        checkProseNumbers('Proteína: 30 g', totals: totals).removedLines,
        0,
      );
      expect(
        checkProseNumbers('50 g de proteína', totals: totals).removedLines,
        1,
      );
    });

    test('a range is checked on both ends', () {
      expect(checkProseNumbers('350-450 kcal', totals: totals).removedLines, 1);
    });

    test('lines without totals are removed, other lines stay', () {
      final check = checkProseNumbers(
        'Boa escolha.\nTem 300 kcal.\nAté amanhã.',
      );
      expect(check.removedLines, 1);
      expect(check.text, 'Boa escolha.\nAté amanhã.');
    });

    test('a word that only contains a keyword does not trigger a check', () {
      final check = checkProseNumbers('Carbonara: 2 ovos e 40 g de queijo.');
      expect(check.removedLines, 0);
    });
  });
}
