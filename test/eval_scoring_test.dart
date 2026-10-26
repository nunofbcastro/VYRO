import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/eval/scoring.dart';

Prediction db(String key, [String? name]) =>
    Prediction(name: name ?? key, key: key);
Prediction raw(String name) => Prediction(name: name);

const egg = LabelFood(name: 'ovo', key: 'egg_boiled');
const fried = LabelFood(name: 'ovo', key: 'egg_fried', anyOf: ['egg_boiled']);
const beer = LabelFood(name: 'cerveja', key: 'beer');
const gravy = LabelFood(name: 'molho', key: 'brown_gravy', optional: true);
const cider = LabelFood(name: 'sidra', key: 'cider');
const cheese = LabelFood(
  name: 'croquete de queijo',
  text: 'croquete de queijo',
  optional: true,
);

void main() {
  group('normaliseName', () {
    test('drops accents, case and punctuation', () {
      expect(normaliseName('Água das Pedras, limão!'), 'agua das pedras limao');
      expect(normaliseName('  Croquete   de  QUEIJO '), 'croquete de queijo');
    });
  });

  group('exact keys', () {
    test('perfect photo: every food found, no extras', () {
      final s = scoreImage(
        file: 'a.jpg',
        labels: const [egg, beer],
        predicted: [db('beer', 'cerveja'), db('egg_boiled', 'ovo')],
      );
      expect(s.tp, 2);
      expect(s.fp, 0);
      expect(s.fn, 0);
      expect(s.exactMeal, isTrue);
    });

    test('empty prediction for a non-empty label is all misses', () {
      final s = scoreImage(
        file: 'a.jpg',
        labels: const [egg, beer],
        predicted: const [],
      );
      expect(s.tp, 0);
      expect(s.fn, 2);
      expect(s.fp, 0);
      expect(s.exactMeal, isFalse);
    });

    test('empty label and empty prediction is an exact meal', () {
      final s = scoreImage(
        file: 'a.jpg',
        labels: const [],
        predicted: const [],
      );
      expect(s.exactMeal, isTrue);
      expect(s.tp + s.fp + s.fn, 0);
    });

    test('empty label with a predicted food is one false positive', () {
      final s = scoreImage(
        file: 'a.jpg',
        labels: const [],
        predicted: [db('beer')],
      );
      expect(s.fp, 1);
      expect(s.exactMeal, isFalse);
    });

    test(
      'a food predicted twice matches once; the copy is a false positive',
      () {
        final s = scoreImage(
          file: 'a.jpg',
          labels: const [beer],
          predicted: [db('beer', 'cerveja'), db('beer', 'cerveja 2')],
        );
        expect(s.tp, 1);
        expect(s.fp, 1);
        expect(s.fn, 0);
      },
    );

    test('a wrong database food is a miss and a false positive', () {
      final s = scoreImage(
        file: 'a.jpg',
        labels: const [beer],
        predicted: [db('cider')],
      );
      expect(s.tp, 0);
      expect(s.fn, 1);
      expect(s.fp, 1);
    });
  });

  group('any_of', () {
    test('an accepted alternative counts as the labelled food', () {
      final s = scoreImage(
        file: 'a.jpg',
        labels: const [fried],
        predicted: [db('egg_boiled', 'ovo')],
      );
      expect(s.tp, 1);
      expect(s.exactMeal, isTrue);
    });

    test('the primary key also counts', () {
      final s = scoreImage(
        file: 'a.jpg',
        labels: const [fried],
        predicted: [db('egg_fried')],
      );
      expect(s.tp, 1);
    });

    test('an alternative is used once: two labels need two predictions', () {
      final s = scoreImage(
        file: 'a.jpg',
        labels: const [fried, egg],
        predicted: [db('egg_boiled')],
      );
      expect(s.tp, 1);
      expect(s.fn, 1);
    });
  });

  group('optional labels', () {
    test('missed optional food does not count against recall', () {
      final s = scoreImage(
        file: 'a.jpg',
        labels: const [beer, gravy],
        predicted: [db('beer')],
      );
      expect(s.fn, 0);
      expect(s.tp, 1);
      expect(s.match.optionalMisses.map((l) => l.name), ['molho']);
      expect(s.exactMeal, isTrue);
    });

    test('an optional food that is found counts as a true positive', () {
      final s = scoreImage(
        file: 'a.jpg',
        labels: const [beer, gravy],
        predicted: [db('beer'), db('brown_gravy')],
      );
      expect(s.tp, 2);
      expect(s.fp, 0);
    });

    test(
      'a predicted food that no label asks for is still a false positive',
      () {
        final s = scoreImage(
          file: 'a.jpg',
          labels: const [beer, gravy],
          predicted: [db('beer'), db('cider')],
        );
        expect(s.fp, 1);
      },
    );

    test('required labels win the match over optional ones', () {
      // One prediction could serve either label; the required one must get it.
      const optionalBeer = LabelFood(
        name: 'cerveja',
        key: 'beer',
        optional: true,
      );
      const requiredBeer = LabelFood(name: 'cerveja', key: 'beer');
      final s = scoreImage(
        file: 'a.jpg',
        labels: const [optionalBeer, requiredBeer],
        predicted: [db('beer')],
      );
      expect(s.fn, 0);
      expect(s.match.matched.single.$1.optional, isFalse);
    });
  });

  group('unmatched names (no database row)', () {
    test('a predicted name equal to the label text matches it', () {
      final s = scoreImage(
        file: 'a.jpg',
        labels: const [cheese],
        predicted: [raw('Croquete de Queijo')],
      );
      expect(s.tp, 1);
      expect(s.fp, 0);
    });

    test('a name containing the label text also matches', () {
      final s = scoreImage(
        file: 'a.jpg',
        labels: const [cheese],
        predicted: [raw('croquete de queijo fresco')],
      );
      expect(s.tp, 1);
    });

    test('an unmatched predicted name with no label is a false positive', () {
      final s = scoreImage(
        file: 'a.jpg',
        labels: const [beer],
        predicted: [db('beer'), raw('sopa de cebola')],
      );
      expect(s.fp, 1);
      expect(s.match.falsePositives.single.name, 'sopa de cebola');
    });

    test('an unmatched label that is required and missing is a miss', () {
      const required = LabelFood(name: 'x', text: 'croquete de queijo');
      final s = scoreImage(
        file: 'a.jpg',
        labels: const [required],
        predicted: const [],
      );
      expect(s.fn, 1);
    });

    test(
      'a database food predicted for an unmatched label is a false positive',
      () {
        final s = scoreImage(
          file: 'a.jpg',
          labels: const [cheese],
          predicted: [db('croquete_meat_fried', 'croquete')],
        );
        expect(s.tp, 0);
        expect(s.fp, 1);
        expect(s.match.misses, isEmpty, reason: 'the label is optional');
      },
    );

    test('a generic name with no database row is a false positive', () {
      final s = scoreImage(
        file: 'a.jpg',
        labels: const [beer],
        predicted: [raw('bebida')],
      );
      expect(s.fp, 1);
      expect(s.fn, 1);
    });
  });

  group('summary (micro over items)', () {
    test('precision, recall, F1 and means over several photos', () {
      final images = [
        // 2 TP, 1 FP (cider), 0 FN: not exact because of the extra
        scoreImage(
          file: '1.jpg',
          labels: const [egg, beer],
          predicted: [db('egg_boiled'), db('beer'), db('cider')],
          latencyMs: 1000,
        ),
        // 1 TP (beer), 0 FP, 2 FN (egg, cider): not exact
        scoreImage(
          file: '2.jpg',
          labels: const [egg, beer, cider],
          predicted: [db('beer')],
          latencyMs: 3000,
        ),
        // 1 TP, exact
        scoreImage(
          file: '3.jpg',
          labels: const [beer],
          predicted: [db('beer')],
          latencyMs: 2000,
        ),
      ];
      final s = EvalSummary.of(images);
      expect(s.photos, 3);
      expect(s.tp, 4);
      expect(s.fp, 1);
      expect(s.fn, 2);
      expect(s.precision, closeTo(4 / 5, 1e-9));
      expect(s.recall, closeTo(4 / 6, 1e-9));
      expect(s.f1, closeTo(8 / 11, 1e-9));
      expect(s.exactMeals, 1);
      expect(s.exactMealRate, closeTo(1 / 3, 1e-9));
      expect(s.meanFalsePositives, closeTo(1 / 3, 1e-9));
      expect(s.meanLatencyMs, closeTo(2000, 1e-9));
      expect(s.medianLatencyMs, closeTo(2000, 1e-9));
    });

    test('median of an odd number of latencies is the middle value', () {
      final images = [
        for (final ms in [5000.0, 1000.0, 3000.0])
          scoreImage(
            file: '$ms.jpg',
            labels: const [],
            predicted: const [],
            latencyMs: ms,
          ),
      ];
      expect(EvalSummary.of(images).medianLatencyMs, 3000);
    });

    test('ratios are null when undefined', () {
      final s = EvalSummary.of(const []);
      expect(s.precision, isNull);
      expect(s.recall, isNull);
      expect(s.f1, isNull);
      expect(s.exactMealRate, isNull);
    });

    test('an errored photo is scored with no predictions and is not exact', () {
      final s = EvalSummary.of([
        scoreImage(
          file: 'e.jpg',
          labels: const [beer],
          predicted: const [],
          error: 'LlmException(invalid_foods)',
        ),
      ]);
      expect(s.errors, 1);
      expect(s.fn, 1);
      expect(s.exactMeals, 0);
    });
  });

  group('labels.json and foods.json', () {
    test('labels parse and every key exists in the bundled database', () {
      final labels = parseLabels(File('eval/labels.json').readAsStringSync());
      expect(labels, isNotEmpty);
      final foods = File('assets/nutrition/foods.json').readAsStringSync();
      final keys = RegExp(
        r'"key":\s*"([^"]+)"',
      ).allMatches(foods).map((m) => m.group(1)!).toSet();
      expect(keys, isNotEmpty);
      expect(validateLabelKeys(labels, keys), isEmpty);
    });

    test('a label with neither key nor text is rejected', () {
      expect(
        () => LabelFood.fromJson({'name': 'x'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('validateLabelKeys reports an unknown key', () {
      final labels = parseLabels('[{"file":"a.jpg","foods":[{"key":"nope"}]}]');
      expect(validateLabelKeys(labels, {'beer'}), [
        'a.jpg: "nope" is not a key in foods.json',
      ]);
    });
  });
}
