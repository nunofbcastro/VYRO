import '../data/food_database.dart';
import 'burger_rules.dart';
import 'food_vision.dart';
import 'food_screening.dart' show normaliseFoodName;
import 'portion_estimate.dart';

/// Companion foods that often go with a dish but are rarely visible in a
/// photo. They are suggestions only (never totals), added after the model
/// answer, and only when the database has them.
class _CompanionRule {
  const _CompanionRule(this.words, this.foods);

  /// Normalised words that trigger the rule when one of them is in a food name.
  final Set<String> words;

  /// Database keys, or exact database names when no key exists (e.g. ketchup).
  final List<String> foods;
}

const _companionRules = [
  // Meat and steak: gravy (also the "molho de cerveja" alias), cream,
  // mayonnaise, ketchup. Burgers have their own rule (_burgerCompanions).
  _CompanionRule(
    {
      'bife',
      'steak',
      'carne',
      'costeleta',
      'picanha',
      'entrecosto',
      'vitela',
      'beef',
      'meat',
    },
    ['brown_gravy', 'cooking_cream', 'mayonnaise', 'ketchup'],
  ),
  // Pasta: cream, tomato sauce, grated cheese (when in the database).
  _CompanionRule(
    {
      'massa',
      'esparguete',
      'espaguete',
      'espaguetes',
      'lasanha',
      'penne',
      'macarrao',
      'pasta',
      'bolonhesa',
      'tagliatelle',
    },
    ['cooking_cream', 'molho de tomate', 'queijo ralado'],
  ),
  // Fries and potatoes: ketchup, mayonnaise.
  _CompanionRule(
    {'batata', 'batatas', 'fries', 'potato', 'potatoes'},
    ['ketchup', 'mayonnaise'],
  ),
  // Salad: olive oil.
  _CompanionRule(
    {'salada', 'alface', 'rucula', 'salad', 'lettuce'},
    ['olive_oil'],
  ),
];

/// Database food for a key or an exact name (normalised, aliases included,
/// or a name that starts with it, e.g. "natas" for "Natas (para cozinha)").
FoodRef? _companionFood(FoodDatabase db, String keyOrName) {
  final byKey = db.byKey(keyOrName);
  if (byKey != null) return byKey;
  final wanted = normaliseFoodName(keyOrName);
  for (final f in db.foods) {
    final names = [
      normaliseFoodName(f.namePt),
      normaliseFoodName(f.nameEn),
      for (final a in f.aliases) normaliseFoodName(a),
    ];
    for (final name in names) {
      if (name == wanted || name.startsWith('$wanted ')) return f;
    }
  }
  return null;
}

/// Context-aware suggestions for a meal, from the names of the foods already
/// found (never from the photo itself). Foods already in [foods] or in
/// [alsoTaken] are not repeated. Pure apart from the database lookups.
List<DetectedFood> mealCompanions(
  List<DetectedFood> foods,
  FoodDatabase db, {
  List<DetectedFood> alsoTaken = const [],
}) {
  final words = <String>{
    for (final f in foods) ...normaliseFoodName(f.label).split(' '),
    for (final f in foods)
      if (f.food != null) ...normaliseFoodName(f.food!.namePt).split(' '),
  };
  final taken = <String>{
    for (final f in [...foods, ...alsoTaken])
      (f.food?.key ?? f.label.toLowerCase()),
  };
  final out = <DetectedFood>[];
  // A patty with no bun: the bun first, then cheese and burger sauce.
  for (final wanted in burgerCompanionKeys(foods, taken: taken)) {
    final food = _companionFood(db, wanted);
    if (food == null || !taken.add(food.key)) continue;
    out.add(_suggestion(food));
  }
  for (final rule in _companionRules) {
    if (!rule.words.any(words.contains)) continue;
    for (final wanted in rule.foods) {
      final food = _companionFood(db, wanted);
      if (food == null || !taken.add(food.key)) continue;
      out.add(_suggestion(food));
    }
  }
  return out;
}

DetectedFood _suggestion(FoodRef food) => DetectedFood(
  food: food,
  label: food.namePt,
  grams: estimatedGrams(food: food, size: PortionSize.medium),
  size: PortionSize.medium,
  source: VisionSource.systemAi,
);
