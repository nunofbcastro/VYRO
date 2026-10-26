import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/nutrition/food_vision/food_vision.dart';
import 'package:vyro/features/nutrition/food_vision/system_food_vision.dart';

import '../tool/eval/variants.dart';

/// The JSON answer line the app's parser expects (system_food_vision.dart).
const _jsonLine =
    'Reply with JSON only, no markdown: '
    '{"items":[{"name":"...","where":"...","count":1,"size":"medium"}]}';

void main() {
  test('en_names is a known strategy and expands on its own', () {
    expect(strategyNames, contains('en_names'));
    expect(expandStrategies(['en_names']), ['en_names']);
  });

  group('legacy_app prompt variant (git HEAD prompts)', () {
    test('is a known strategy and expands on its own', () {
      expect(strategyNames, contains('legacy_app'));
      expect(expandStrategies(['legacy_app']), ['legacy_app']);
    });

    test('first look: HEAD European Portuguese name field, JSON line kept', () {
      final legacy = legacyFirstPrompt();
      expect(legacy, contains('European Portuguese (Portugal)'));
      expect(legacy, contains('"ovo", "cerveja", "bife de vaca grelhado"'));
      expect(legacy, isNot(contains('plain English')));
      expect(legacy, endsWith(_jsonLine));
    });

    test(
      'second look: HEAD European Portuguese name field, JSON line kept',
      () {
        final legacy = legacySecondPrompt();
        expect(legacy, contains('European Portuguese (Portugal)'));
        expect(legacy, contains('"centro da frigideira"'));
        expect(legacy, isNot(contains('plain English')));
        expect(legacy, endsWith(_jsonLine));
      },
    );

    test('differs from the current app prompts', () {
      expect(legacyFirstPrompt(), isNot(buildFoodPhotoPrompt()));
      expect(legacySecondPrompt(), isNot(buildFoodSecondChancePrompt()));
      expect(legacyFirstPrompt(), isNot(enFirstPrompt()));
    });

    test('rewrites only the first and second looks; verify passes through', () {
      final app = buildFoodPhotoPrompt();
      expect(legacyNamesPrompt(kindOf(app), app), legacyFirstPrompt());

      final second = buildFoodSecondChancePrompt();
      expect(legacyNamesPrompt(kindOf(second), second), legacySecondPrompt());

      final verify = buildFoodVerifyPrompt([
        const DetectedFood(
          label: 'ovo',
          grams: 50,
          source: VisionSource.systemAi,
        ),
      ]);
      expect(kindOf(verify), PromptKind.verify);
      expect(legacyNamesPrompt(PromptKind.verify, verify), verify);
      expect(legacyNamesPrompt(PromptKind.other, 'x'), 'x');
    });
  });

  group('en_names prompt variant', () {
    test('the app prompts carry the JSON line the variant must keep', () {
      expect(buildFoodPhotoPrompt(), endsWith(_jsonLine));
      expect(buildFoodSecondChancePrompt(), endsWith(_jsonLine));
    });

    test('first look: the variant is the app prompt (English names)', () {
      final app = buildFoodPhotoPrompt();
      expect(kindOf(app), PromptKind.first);
      expect(enNamesPrompt(kindOf(app), app), app);
      expect(enFirstPrompt(), buildFoodPhotoPrompt());

      expect(app, contains('"name": the specific food'));
      expect(app, contains('plain English'));
      expect(app, contains('"fried egg", "beer", "white rice"'));
      expect(app, isNot(contains('European Portuguese')));
      expect(app, endsWith(_jsonLine));
    });

    test('second look: the variant is the app prompt (English names)', () {
      final app = buildFoodSecondChancePrompt();
      expect(kindOf(app), PromptKind.second);
      expect(enNamesPrompt(kindOf(app), app), app);
      expect(enSecondPrompt(), buildFoodSecondChancePrompt());

      expect(app, contains('plain English'));
      expect(app, contains('"fried egg", "beer", "white rice"'));
      expect(app, isNot(contains('European Portuguese')));
      expect(app, endsWith(_jsonLine));
    });

    test('pt_prompt stays the historical European Portuguese variant', () {
      final pt = ptFirstPrompt();
      expect(pt, contains('português europeu'));
      expect(pt, isNot(contains('plain English')));
      expect(pt, isNot(buildFoodPhotoPrompt()));
    });

    test(
      'verify: no name field, so the app prompt passes through unchanged',
      () {
        final app = buildFoodVerifyPrompt([
          const DetectedFood(
            label: 'ovo',
            grams: 50,
            source: VisionSource.systemAi,
          ),
          const DetectedFood(
            label: 'cerveja',
            grams: 330,
            source: VisionSource.systemAi,
          ),
        ]);
        expect(kindOf(app), PromptKind.verify);
        expect(enNamesPrompt(kindOf(app), app), app);
        expect(app, contains('0: ovo\n1: cerveja'));
        expect(app, endsWith('{"checks":[{"i":0,"visible":true}]}'));
      },
    );

    test('other prompts are never rewritten', () {
      const other = 'Some other prompt';
      expect(kindOf(other), PromptKind.other);
      expect(enNamesPrompt(PromptKind.other, other), other);
    });
  });
}
