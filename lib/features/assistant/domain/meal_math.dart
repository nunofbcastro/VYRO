import 'dart:math' as math;

import '../../nutrition/data/food_database.dart';
import 'meal_proposal.dart';

/// Shared, deterministic meal calculation. Every number the assistant shows
/// for a meal comes from here (the offline [FoodDatabase] and the quantities
/// in the proposal), never from the model's text.

/// Conservative candidate filter; mixed dishes require recipe-level knowledge.
bool foodFitsDiet(FoodRef food, String? diet) {
  if (diet != 'vegan' && diet != 'vegetarian') return true;
  if ({'carne', 'peixe', 'salgados', 'pratos'}.contains(food.category)) {
    return false;
  }
  if (diet == 'vegetarian') return true;
  if ({'ovos', 'laticínios', 'sobremesas'}.contains(food.category)) {
    return false;
  }
  if ({
    'butter_salted',
    'honey',
    'coffee_with_milk',
    'croissant',
    'pao_de_queijo',
    'tapioca_butter',
    'farofa',
  }.contains(food.key)) {
    return false;
  }
  return true;
}

/// Totals of a meal in the units of the database (kcal and grams).
class MealTotals {
  const MealTotals({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
  final double kcal, protein, carbs, fat;
}

/// What a proposed food name says: the food itself and what it is said to be
/// without (`sem pele`). `com` is neutral and dropped.
class _Phrase {
  const _Phrase(this.words, this.negated);
  final Set<String> words;
  final Set<String> negated;
}

const _skipWords = {'de', 'do', 'da', 'e', 'o', 'a', 'em', 'the', 'of', 'and'};

_Phrase _parsePhrase(String name) {
  final words = foodWords(name);
  final positive = <String>{};
  final negated = <String>{};
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    if (w == 'sem') {
      var j = i + 1;
      while (j < words.length &&
          (_skipWords.contains(words[j]) ||
              words[j] == 'com' ||
              words[j] == 'sem' ||
              words[j].length < 2)) {
        j++;
      }
      if (j < words.length) {
        negated.add(words[j]);
        i = j;
      }
      continue;
    }
    if (w.length < 2 || _skipWords.contains(w) || w == 'com') continue;
    positive.add(w);
  }
  return _Phrase(positive, negated);
}

class _Hit {
  const _Hit(this.score, {required this.exact, required this.unverified});
  final double score;

  /// The phrase and the food name say the same words.
  final bool exact;

  /// The query has words (or "sem" restrictions) the food name does not state.
  final bool unverified;
}

/// Compares a query with one food phrase. Rejects a food that contains what
/// the query excludes (`sem pele` vs `frango com pele`) and the reverse.
_Hit? _compare(_Phrase query, _Phrase candidate) {
  if (query.words.isEmpty) return null;
  if (query.negated.any(candidate.words.contains)) return null;
  if (candidate.negated.any(query.words.contains)) return null;
  final shared = query.words.intersection(candidate.words).length;
  if (shared == 0) return null;
  if (shared < math.min(query.words.length, candidate.words.length)) {
    return null;
  }
  final union = query.words.length + candidate.words.length - shared;
  var score = shared / union;
  final queryCovered = query.words.difference(candidate.words).isEmpty;
  final negationsCovered = query.negated.difference(candidate.negated).isEmpty;
  final unverified = !queryCovered || !negationsCovered;
  final exact =
      !unverified &&
      candidate.words.difference(query.words).isEmpty &&
      candidate.negated.difference(query.negated).isEmpty;
  if (unverified) score *= 0.6;
  return _Hit(score, exact: exact, unverified: unverified);
}

class FoodCandidate {
  const FoodCandidate(
    this.food, {
    required this.score,
    required this.exact,
    required this.unverified,
    required this.order,
  });
  final FoodRef food;
  final double score;
  final bool exact, unverified;

  /// Position in the database, used to keep ties in a stable order.
  final int order;
}

/// Every database food that matches [name], best first. Uses names and
/// aliases; no food is returned for a name with no shared content words.
List<FoodCandidate> rankFoods(String name, FoodDatabase db) {
  final query = _parsePhrase(name);
  final best = <String, FoodCandidate>{};
  for (var i = 0; i < db.foods.length; i++) {
    final food = db.foods[i];
    for (final label in [food.namePt, food.nameEn, ...food.aliases]) {
      final hit = _compare(query, _parsePhrase(label));
      if (hit == null) continue;
      final current = best[food.key];
      if (current == null || hit.score > current.score) {
        best[food.key] = FoodCandidate(
          food,
          score: hit.score,
          exact: hit.exact,
          unverified: hit.unverified,
          order: i,
        );
      }
    }
  }
  return best.values.toList()..sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.order.compareTo(b.order);
  });
}

/// Best database food for a free-text name, or null. Use [resolveItem] when
/// the alternatives or the confirmation state matter.
FoodRef? matchFood(String name, FoodDatabase db) {
  final ranked = rankFoods(name, db);
  return ranked.isEmpty ? null : ranked.first.food;
}

/// How one proposed item was resolved against the database.
class MealItemMatch {
  const MealItemMatch({
    required this.item,
    this.food,
    this.alternatives = const [],
    this.needsConfirmation = false,
    this.dietConflict = false,
  });

  final ProposedItem item;

  /// The food used for the numbers; null means "sem valores na base".
  final FoodRef? food;

  /// Other plausible foods, shown instead of silently choosing one.
  final List<FoodRef> alternatives;

  /// The match is not certain: alternatives exist, or the name states a
  /// restriction or extra word that the database entry does not.
  final bool needsConfirmation;

  /// The best match violates the dietary choice; the whole proposal is refused.
  final bool dietConflict;

  bool get resolved => food != null;
}

MealItemMatch resolveItem(ProposedItem item, FoodDatabase db, {String? diet}) {
  final ranked = rankFoods(item.name, db);
  if (ranked.isEmpty) return MealItemMatch(item: item);
  final top = ranked.first;
  final dietConflict = !foodFitsDiet(top.food, diet);
  // Near scores, or any other covering match when neither is an exact name
  // (a bare "Café" covers both coffees equally).
  final near = [
    for (final c in ranked.skip(1))
      if (foodFitsDiet(c.food, diet) &&
          (c.score >= top.score - 0.1 ||
              (!c.unverified && !top.exact && !c.exact)))
        c,
  ];
  // An exact top match is only ambiguous against an equally good food.
  final ambiguous = near.any((c) => !top.exact || c.score >= top.score);
  return MealItemMatch(
    item: item,
    food: dietConflict ? null : top.food,
    alternatives: ambiguous ? [for (final c in near.take(3)) c.food] : const [],
    needsConfirmation: top.unverified || ambiguous,
    dietConflict: dietConflict,
  );
}

/// A proposal with every item resolved against the database.
class ResolvedMeal {
  ResolvedMeal(this.proposal, this.items);
  final MealProposal proposal;
  final List<MealItemMatch> items;

  List<FoodRef?> get foods => [for (final i in items) i.food];

  /// Every item has database values (totals are not partial).
  bool get complete => items.every((i) => i.resolved);

  /// Complete and no item needs a confirmation.
  bool get confirmed => complete && items.every((i) => !i.needsConfirmation);

  bool get hasDietConflict => items.any((i) => i.dietConflict);

  double total(double Function(FoodRef) nutrient) {
    var value = 0.0;
    for (var i = 0; i < items.length; i++) {
      final food = items[i].food;
      if (food != null) {
        value += nutrient(food) * proposal.items[i].grams / 100;
      }
    }
    return value;
  }

  MealTotals get totals => MealTotals(
    kcal: total((f) => f.kcal),
    protein: total((f) => f.protein),
    carbs: total((f) => f.carbs),
    fat: total((f) => f.fat),
  );

  String label(bool english) {
    final status = complete
        ? (english ? 'Database values' : 'Valores da base')
        : (english
              ? 'Partial values — resolve foods'
              : 'Valores parciais — resolve os alimentos');
    final confirm = confirmed
        ? ''
        : (english ? ' · to confirm' : ' · a confirmar');
    final t = totals;
    return '$status$confirm: ${t.kcal.round()} kcal · P ${t.protein.round()} g · H ${t.carbs.round()} g · G ${t.fat.round()} g';
  }
}

ResolvedMeal resolveMeal(
  MealProposal proposal,
  FoodDatabase db, {
  String? diet,
}) => ResolvedMeal(proposal, [
  for (final item in proposal.items) resolveItem(item, db, diet: diet),
]);
