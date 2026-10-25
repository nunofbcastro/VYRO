import 'dart:convert';

import '../database/app_database.dart';
import '../../features/nutrition/data/food_database.dart';
import '../../features/assistant/domain/meal_proposal.dart' show foodTokens;

/// Only explicit user facts and numeric aggregates; never stores media.
class LocalIntelligenceRepository {
  LocalIntelligenceRepository(this.database);
  final AppDatabase database;
  static const storageKeys = {
    'assistant_memory_v1',
    'food_corrections_v1',
    'recipes_v1',
    'quality_metrics_v1',
  };

  Future<Map<String, dynamic>> _read(String key) async {
    final raw = await database.getPreference(key);
    if (raw == null) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _change(String key, void Function(Map<String, dynamic>) edit) =>
      database.transaction(() async {
        final data = await _read(key);
        edit(data);
        await database.setPreference(key, jsonEncode(data));
      });
  Future<bool> learningEnabled() async =>
      (await _read('food_corrections_v1'))['enabled'] != false;
  Future<void> setLearningEnabled(bool enabled) =>
      _change('food_corrections_v1', (d) => d['enabled'] = enabled);
  static String _normal(String s) => (foodTokens(s).toList()..sort()).join(' ');
  Future<void> recordCorrection(String original, String chosenKey) =>
      _change('food_corrections_v1', (data) {
        if (data['enabled'] == false ||
            original.trim().isEmpty ||
            chosenKey.isEmpty)
          return;
        final rows = Map<String, dynamic>.from(data['rows'] as Map? ?? {});
        final key = _normal(original);
        final counts = Map<String, dynamic>.from(rows[key] as Map? ?? {});
        counts[chosenKey] = ((counts[chosenKey] as num?)?.toInt() ?? 0) + 1;
        rows[key] = counts;
        if (rows.length > 200) rows.remove(rows.keys.first);
        data['rows'] = rows;
      });
  Future<List<FoodRef>> correctionSuggestions(
    String original,
    FoodDatabase db,
  ) async {
    final data = await _read('food_corrections_v1');
    if (data['enabled'] == false) return [];
    final counts = Map<String, dynamic>.from(
      (data['rows'] as Map?)?[_normal(original)] as Map? ?? {},
    );
    final keys = counts.keys.toList()
      ..sort((a, b) => (counts[b] as num).compareTo(counts[a] as num));
    return [
      for (final key in keys.take(4))
        if (db.byKey(key) != null) db.byKey(key)!,
    ];
  }

  Future<void> clearCorrections() =>
      _change('food_corrections_v1', (d) => d.remove('rows'));
  Future<Map<String, String>> memories() async {
    final data = await _read('assistant_memory_v1');
    return {
      for (final e in data.entries)
        if (e.value is String) e.key: e.value as String,
    };
  }

  Future<void> saveMemory(String id, String text) {
    final value = text.trim();
    if (value.isEmpty || value.length > 240)
      throw const FormatException('Invalid memory');
    return _change('assistant_memory_v1', (d) {
      if (!d.containsKey(id) && d.length >= 20)
        throw const FormatException('Memory limit');
      d[id] = value;
    });
  }

  Future<void> deleteMemory(String id) =>
      _change('assistant_memory_v1', (d) => d.remove(id));
  Future<List<LocalRecipe>> recipes() async => [
    for (final value in (await _read('recipes_v1')).values)
      LocalRecipe.fromJson(Map<String, dynamic>.from(value as Map)),
  ];
  Future<void> saveRecipe(LocalRecipe recipe) => _change('recipes_v1', (d) {
    recipe.validate();
    if (!d.containsKey(recipe.id) && d.length >= 100)
      throw const FormatException('Recipe limit');
    d[recipe.id] = recipe.toJson();
  });
  Future<void> deleteRecipe(String id) =>
      _change('recipes_v1', (d) => d.remove(id));
  Future<Map<String, num>> metrics() async => {
    for (final e in (await _read('quality_metrics_v1')).entries)
      if (e.value is num) e.key: e.value as num,
  };
  Future<void> recordPhotoReview({
    required int corrected,
    required int removed,
    required int added,
    required Duration elapsed,
  }) => _change('quality_metrics_v1', (d) {
    for (final e in {
      'photos': 1,
      'corrected': corrected,
      'removed': removed,
      'added': added,
      'reviewMs': elapsed.inMilliseconds,
    }.entries) {
      d[e.key] = ((d[e.key] as num?) ?? 0) + e.value;
    }
  });
  Future<void> recordAssistantFeedback(bool helpful) =>
      _change('quality_metrics_v1', (d) {
        final key = helpful ? 'helpful' : 'unhelpful';
        d[key] = ((d[key] as num?) ?? 0) + 1;
      });
  Future<void> clearMetrics() =>
      database.setPreference('quality_metrics_v1', '{}');

  Future<void> recordMotionPerformance({
    required int frames,
    required int skipped,
    required double inferenceMs,
  }) => _change('quality_metrics_v1', (d) {
    for (final e in {
      'motionFrames': frames,
      'motionSkipped': skipped,
      'motionInferenceMs': inferenceMs,
    }.entries) {
      d[e.key] = ((d[e.key] as num?) ?? 0) + e.value;
    }
  });
}

class RecipeIngredient {
  const RecipeIngredient({
    required this.key,
    required this.name,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
  factory RecipeIngredient.fromFood(FoodRef food, double grams) =>
      RecipeIngredient(
        key: food.key,
        name: food.namePt,
        grams: grams,
        kcal: food.kcal,
        protein: food.protein,
        carbs: food.carbs,
        fat: food.fat,
      );
  factory RecipeIngredient.fromJson(Map<String, dynamic> j) => RecipeIngredient(
    key: j['key'] as String,
    name: j['name'] as String,
    grams: (j['grams'] as num).toDouble(),
    kcal: (j['kcal'] as num).toDouble(),
    protein: (j['protein'] as num).toDouble(),
    carbs: (j['carbs'] as num).toDouble(),
    fat: (j['fat'] as num).toDouble(),
  );
  final String key, name;

  /// Snapshot of the selected database food, per 100 g.
  final double grams, kcal, protein, carbs, fat;
  Map<String, Object> toJson() => {
    'key': key,
    'name': name,
    'grams': grams,
    'kcal': kcal,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };
}

class LocalRecipe {
  const LocalRecipe({
    required this.id,
    required this.name,
    required this.yieldGrams,
    required this.ingredients,
  });
  final String id, name;
  final double yieldGrams;
  final List<RecipeIngredient> ingredients;
  factory LocalRecipe.fromJson(Map<String, dynamic> j) {
    final recipe = LocalRecipe(
      id: j['id'] as String,
      name: j['name'] as String,
      yieldGrams: (j['yieldGrams'] as num).toDouble(),
      ingredients: [
        for (final i in j['ingredients'] as List)
          RecipeIngredient.fromJson(Map<String, dynamic>.from(i as Map)),
      ],
    );
    recipe.validate();
    return recipe;
  }
  void validate() {
    if (id.isEmpty ||
        id.length > 80 ||
        name.trim().isEmpty ||
        name.length > 80 ||
        !yieldGrams.isFinite ||
        yieldGrams <= 0 ||
        yieldGrams > 100000 ||
        ingredients.isEmpty ||
        ingredients.length > 100)
      throw const FormatException('Invalid recipe');
    for (final i in ingredients) {
      if (i.key.isEmpty ||
          i.name.length > 120 ||
          !i.grams.isFinite ||
          i.grams <= 0 ||
          i.grams > 100000 ||
          [i.kcal, i.protein, i.carbs, i.fat].any((n) => !n.isFinite || n < 0))
        throw const FormatException('Invalid ingredient');
    }
  }

  double per100(double Function(RecipeIngredient) nutrient) =>
      ingredients.fold(0.0, (sum, i) => sum + nutrient(i) * i.grams) /
      yieldGrams;
  FoodRef asFood({double servingGrams = 150}) => FoodRef(
    key: 'recipe_$id',
    namePt: name,
    nameEn: name,
    category: 'pratos',
    source: 'recipe',
    sourceRef: id,
    kcal: per100((i) => i.kcal),
    protein: per100((i) => i.protein),
    carbs: per100((i) => i.carbs),
    fat: per100((i) => i.fat),
    fiber: 0,
    portionG: servingGrams,
    portionPt: 'Porção editável',
    portionEn: 'Editable serving',
  );
  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'yieldGrams': yieldGrams,
    'ingredients': [for (final i in ingredients) i.toJson()],
  };
}
