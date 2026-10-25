import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../assistant/domain/meal_proposal.dart' show foodTokens;

/// One food from the bundled nutrition database (values per 100 g from an
/// official composition table: USDA, Ciqual or TACO).
class FoodRef {
  const FoodRef({
    required this.key,
    required this.namePt,
    required this.nameEn,
    required this.category,
    required this.source,
    required this.sourceRef,
    this.sourceLabel = '',
    this.region = 'int',
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.portionG,
    required this.portionPt,
    required this.portionEn,
    this.aliases = const [],
    this.visionLabels = const [],
  });

  final String key;
  final String namePt;
  final String nameEn;
  final String category;

  /// Composition table the values come from: `usda`, `ciqual` or `taco`.
  final String source;

  /// Id of the food in that table (FDC id, Ciqual alim_code, TACO number).
  final String sourceRef;

  /// Original description in the source table (for traceability).
  final String sourceLabel;

  /// Cuisine region: `pt`, `eu`, `br` or `int`.
  final String region;
  final double kcal, protein, carbs, fat, fiber;

  /// Typical portion suggested by VYRO (an estimate, not table data).
  final double portionG;
  final String portionPt;
  final String portionEn;
  final List<String> aliases;

  /// Image-model labels that suggest this food.
  final List<String> visionLabels;

  String name(bool english) => english ? nameEn : namePt;
  String portion(bool english) => english ? portionEn : portionPt;

  /// Display name of the composition table.
  String get sourceName => switch (source) {
    'usda' => 'USDA',
    'ciqual' => 'Ciqual',
    'taco' => 'TACO',
    _ => source,
  };

  /// Value for `food_entries.source`.
  String get sourceKey => '${source}_$sourceRef';

  factory FoodRef.fromJson(Map<String, dynamic> j) => FoodRef(
    key: j['key'] as String,
    namePt: j['namePt'] as String,
    nameEn: j['nameEn'] as String,
    category: j['category'] as String,
    source: j['source'] as String,
    sourceRef: '${j['sourceRef']}',
    sourceLabel: j['sourceLabel'] as String? ?? '',
    region: j['region'] as String? ?? 'int',
    kcal: (j['kcal'] as num).toDouble(),
    protein: (j['protein'] as num).toDouble(),
    carbs: (j['carbs'] as num).toDouble(),
    fat: (j['fat'] as num).toDouble(),
    fiber: (j['fiber'] as num? ?? 0).toDouble(),
    portionG: (j['portionG'] as num).toDouble(),
    portionPt: j['portionPt'] as String,
    portionEn: j['portionEn'] as String,
    aliases: [for (final a in j['aliases'] as List? ?? const []) '$a'],
    visionLabels: [
      for (final a in j['visionLabels'] as List? ?? const []) '$a',
    ],
  );
}

/// Offline nutrition database built by `tool/nutrition/build_food_db.py`
/// from USDA FoodData Central (CC0), Ciqual 2025 (etalab-2.0) and TACO 4
/// (cited). Loaded once from assets; see docs/NUTRITION_DATA.md.
class FoodDatabase {
  FoodDatabase(this.foods)
    : _byKey = {for (final f in foods) f.key: f},
      _byLabel = _indexLabels(foods);

  static const asset = 'assets/nutrition/foods.json';
  static FoodDatabase? _cached;

  final List<FoodRef> foods;
  final Map<String, FoodRef> _byKey;
  final Map<String, List<FoodRef>> _byLabel;

  static Map<String, List<FoodRef>> _indexLabels(List<FoodRef> foods) {
    final map = <String, List<FoodRef>>{};
    for (final f in foods) {
      for (final label in f.visionLabels) {
        map.putIfAbsent(label.toLowerCase(), () => []).add(f);
      }
    }
    return map;
  }

  static FoodDatabase parse(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return FoodDatabase([
      for (final f in json['foods'] as List)
        FoodRef.fromJson(f as Map<String, dynamic>),
    ]);
  }

  static Future<FoodDatabase> load() async =>
      _cached ??= parse(await rootBundle.loadString(asset));

  FoodRef? byKey(String key) => _byKey[key];

  /// Foods an image-model label points to (e.g. "Feijoada" → beans).
  List<FoodRef> forVisionLabel(String label) =>
      _byLabel[label.toLowerCase()] ?? const [];

  /// Best food for a free-text name ("peito de frango grelhado"), using
  /// names and aliases. Returns null instead of guessing.
  FoodRef? match(String name) {
    final query = foodTokens(name);
    if (query.isEmpty) return null;
    FoodRef? best;
    var bestScore = 0.0;
    for (final f in foods) {
      for (final candidate in [f.namePt, f.nameEn, ...f.aliases]) {
        final tokens = foodTokens(candidate);
        if (tokens.isEmpty) continue;
        final shared = query.intersection(tokens).length;
        if (shared == 0) continue;
        // Every word of the shorter phrase must be present.
        final smaller = query.length < tokens.length
            ? query.length
            : tokens.length;
        if (shared < smaller) continue;
        final score = shared / (query.length + tokens.length - shared);
        if (score > bestScore) {
          bestScore = score;
          best = f;
        }
      }
    }
    return best;
  }

  /// Search for the food picker: prefix/word matches on names and aliases.
  List<FoodRef> search(String text, {int limit = 20}) {
    final q = foodTokens(text);
    if (q.isEmpty) return foods.take(limit).toList();
    final scored = <(FoodRef, int)>[];
    for (final f in foods) {
      final phrases = [
        for (final c in [f.namePt, f.nameEn, ...f.aliases]) foodTokens(c),
      ];
      final words = {for (final p in phrases) ...p};
      // Whole-phrase hits first: "pão de queijo" beats "pão" + "queijo".
      var score = phrases.any((p) => p.length == q.length && p.containsAll(q))
          ? 10
          : 0;
      for (final token in q) {
        if (words.contains(token)) {
          score += 3;
        } else if (words.any((w) => w.startsWith(token))) {
          score += 1;
        }
      }
      if (score > 0) scored.add((f, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final s in scored.take(limit)) s.$1];
  }
}
