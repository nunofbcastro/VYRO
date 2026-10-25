import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/ai/local_intelligence_repository.dart';
import 'package:vyro/core/ai/on_device_llm.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/features/assistant/domain/local_assistant.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';

void main() {
  late AppDatabase database;
  late LocalIntelligenceRepository repo;
  final foods = FoodDatabase.parse(
    File('assets/nutrition/foods.json').readAsStringSync(),
  );
  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    repo = LocalIntelligenceRepository(database);
  });
  tearDown(() async {
    await database.close();
  });
  test(
    'corrections rank suggestions without replacing a food and can be disabled',
    () async {
      await repo.recordCorrection('Carne', 'lentils_cooked');
      await repo.recordCorrection('Carne', 'lentils_cooked');
      await repo.recordCorrection('Carne', 'chicken_breast_roasted');
      expect(
        (await repo.correctionSuggestions('carne', foods)).first.key,
        'lentils_cooked',
      );
      expect(foods.match('carne')?.key, isNot('lentils_cooked'));
      await repo.setLearningEnabled(false);
      expect(await repo.correctionSuggestions('carne', foods), isEmpty);
      await repo.setLearningEnabled(true);
      await repo.clearCorrections();
      expect(await repo.correctionSuggestions('carne', foods), isEmpty);
    },
  );
  test(
    'recipe nutrients use final cooked yield and serving scales consistently',
    () {
      final rice = foods.byKey('rice_white_cooked')!;
      final recipe = LocalRecipe(
        id: 'rice',
        name: 'Arroz',
        yieldGrams: 400,
        ingredients: [RecipeIngredient.fromFood(rice, 200)],
      );
      recipe.validate();
      expect(recipe.asFood().kcal, rice.kcal / 2);
      expect(recipe.asFood().kcal * 150 / 100, closeTo(rice.kcal * 0.75, 1e-8));
      expect(
        () => const LocalRecipe(
          id: 'x',
          name: 'x',
          yieldGrams: 0,
          ingredients: [],
        ).validate(),
        throwsFormatException,
      );
    },
  );
  test(
    'memory recipes and numeric metrics survive export import and delete',
    () async {
      await repo.saveMemory('food', 'Prefiro refeições simples');
      await repo.saveRecipe(
        LocalRecipe(
          id: 'rice',
          name: 'Arroz',
          yieldGrams: 200,
          ingredients: [
            RecipeIngredient.fromFood(foods.byKey('rice_white_cooked')!, 200),
          ],
        ),
      );
      await repo.recordPhotoReview(
        corrected: 1,
        removed: 2,
        added: 1,
        elapsed: const Duration(seconds: 20),
      );
      await repo.recordAssistantFeedback(true);
      final exported = await database.exportAllData();
      final clone = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(clone.close);
      await clone.importAllData(exported);
      final copied = LocalIntelligenceRepository(clone);
      expect((await copied.memories())['food'], 'Prefiro refeições simples');
      expect((await copied.recipes()).single.name, 'Arroz');
      expect((await copied.metrics())['helpful'], 1);
      await clone.clearUserData();
      expect(await copied.memories(), isEmpty);
      expect(await copied.recipes(), isEmpty);
    },
  );
  test('malformed imported local data cannot erase current data', () async {
    await repo.saveMemory('keep', 'Manter');
    final exported = await database.exportAllData();
    exported['localIntelligence'] = {
      'recipes_v1': {
        'bad': {'name': 'broken'},
      },
    };
    await expectLater(database.importAllData(exported), throwsFormatException);
    expect((await repo.memories())['keep'], 'Manter');
  });
  test(
    'offline factual answers carry partial totals and no model dependency',
    () {
      final answer = answerLocally(
        'Quanto me falta hoje?',
        const AssistantContext(
          kcalGoal: 2000,
          kcalToday: 1500,
          proteinGoal: 100,
          proteinToday: 70,
          partialNutrition: true,
        ),
        foods,
      )!;
      expect(answer.text, contains('500 kcal'));
      expect(answer.text, contains('parciais'));
      expect(answer.proposal, isNull);
    },
  );
  test('local meal suggestions and resolver respect vegan profile', () {
    final answer = answerLocally(
      'Sugere um jantar',
      const AssistantContext(dietaryChoice: 'vegan'),
      foods,
    )!;
    expect(
      answer.proposal!.items.map((i) => i.name),
      isNot(contains('Peito de frango')),
    );
    final resolved = resolveMeal(answer.proposal!, foods, diet: 'vegan');
    expect(resolved.complete, true);
    expect(resolved.foods.every((f) => foodFitsDiet(f!, 'vegan')), true);
  });
  test('facts and data remain explicit in prompt', () {
    final prompt = buildAssistantPrompt(
      question: 'Ajuda',
      context: const AssistantContext(
        dietaryChoice: 'vegan',
        carbsGoal: 200,
        carbsToday: 100,
        confirmedPreferences: ['Sem leite'],
        partialNutrition: true,
      ),
    );
    expect(prompt, contains('vegan'));
    expect(prompt, contains('100/200'));
    expect(prompt, contains('Sem leite'));
    expect(prompt, contains('desconhecidos'));
  });
}
