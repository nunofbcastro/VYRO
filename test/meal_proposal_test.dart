import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/assistant/domain/meal_proposal.dart';

void main() {
  test('meal block is parsed and removed from the visible text', () {
    const answer = '''Sugestão: frango com arroz.
1. Grelha o frango.
[[MEAL]]{"meal":"dinner","items":[{"name":"Peito de frango","grams":150},{"name":"Arroz cozido","grams":120.4},{"name":"","grams":10},{"name":"Azeite","grams":5000}]}[[/MEAL]]''';
    final result = extractMealProposal(answer);
    expect(result.text, isNot(contains('[[MEAL]]')));
    expect(result.text, startsWith('Sugestão'));
    final proposal = result.proposal!;
    expect(proposal.meal, 'dinner');
    // Empty names and absurd amounts are dropped; grams rounded.
    expect(proposal.items.map((i) => i.name), [
      'Peito de frango',
      'Arroz cozido',
    ]);
    expect(proposal.items.last.grams, 120);
  });

  test('answers without a valid block have no proposal', () {
    expect(extractMealProposal('Qual é a tua fome?').proposal, isNull);
    final broken = extractMealProposal('Ok [[MEAL]]{not json}[[/MEAL]]');
    expect(broken.proposal, isNull);
    expect(broken.text, 'Ok');
  });

  group('bestMatch', () {
    const sources = [
      NutrientSource(
        label: 'Arroz branco cozido',
        origin: 'local_reference',
        kcal: 130,
      ),
      NutrientSource(
        label: 'Peito de frango assado, sem pele',
        origin: 'local_reference',
        kcal: 165,
      ),
      NutrientSource(label: 'Banana crua', origin: 'local_reference', kcal: 89),
    ];

    test('matches when every word of the shorter name is shared', () {
      expect(bestMatch('Arroz cozido', sources)?.kcal, 130);
      expect(bestMatch('peito de frango', sources)?.kcal, 165);
      expect(bestMatch('Banana', sources)?.kcal, 89);
    });

    test('does not guess for unrelated foods', () {
      expect(bestMatch('Arroz de pato', sources), isNull);
      expect(bestMatch('Salmão grelhado', sources), isNull);
      expect(bestMatch('', sources), isNull);
    });
  });
}
