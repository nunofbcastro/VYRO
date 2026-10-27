import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/assistant/domain/model_answer.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';

void main() {
  final foods = FoodDatabase.parse(
    File('assets/nutrition/foods.json').readAsStringSync(),
  );

  // Shape of the reply the device produced for "Que horas são?".
  const questionnaire =
      'Boa noite! O que é que tens em casa?\n'
      'Fome:\nTempo para cozinhar:\nAlergias:\n'
      'Vamos começar a construir a tua rotina!\n'
      '1. Despertar: 7h\n2. Pequeno-almoço: 200 g de aveia';

  test('a reply without nutrient numbers is shown as written', () {
    final composed = composeModelAnswer(questionnaire, foods, english: false);
    expect(composed.text, questionnaire);
    expect(composed.footnote, isNull);
    expect(composed.meal, isNull);
  });

  test('no footnote and no duplicated note when nothing was removed', () {
    final composed = composeModelAnswer(
      'Podes comer frango com arroz.',
      foods,
      english: false,
    );
    expect(composed.text, 'Podes comer frango com arroz.');
    expect(composed.footnote, isNull);
    expect(composed.text, isNot(contains('Valores calculados')));
  });

  test('removed nutrient lines give one footnote, outside the text', () {
    final composed = composeModelAnswer(
      'Tens cerca de 900 kcal de jantar.\nBoa escolha!',
      foods,
      english: false,
    );
    expect(composed.text, 'Boa escolha!');
    expect(composed.footnote, contains('Algumas frases foram retiradas'));
    expect(composed.text, isNot(contains('*')));
    expect(composed.text, isNot(contains('VYRO')));
  });

  test('English footnote wording', () {
    final composed = composeModelAnswer(
      'It has about 900 kcal.',
      foods,
      english: true,
    );
    expect(composed.text, isEmpty);
    expect(composed.footnote, startsWith('Some sentences were removed'));
  });

  test('an unclosed meal block never leaks into the text', () {
    final composed = composeModelAnswer(
      'Ideia simples: frango com arroz.\n'
      '[[MEAL]]{"meal":"dinner","items":[{"name":"Peito de frango","grams":150}',
      foods,
      english: false,
    );
    expect(composed.text, 'Ideia simples: frango com arroz.');
    expect(composed.text, isNot(contains('[[')));
    expect(composed.text, isNot(contains('{"')));
  });

  test('stray markers and JSON lines are stripped', () {
    expect(
      stripProtocolText('Olá\n[[/MEAL]]\n{"items": []}\n"grams": 10\nFim'),
      'Olá\nFim',
    );
  });
}
