import '../data/food_database.dart';
import 'food_screening.dart' show normaliseFoodName;
import 'food_vision.dart';
import 'portion_estimate.dart';

/// Burger rules for the photo model's answers (pure Dart, see
/// docs/FOOD_VISION.md). A bare English "hamburger", "burger" or "big mac"
/// in a photo means the whole sandwich (`cheeseburger_whole`, bun included),
/// while "beef patty" and the Portuguese "hambúrguer" mean the meat patty
/// (`beef_ground_patty`).

/// Database key of the whole burger sandwich (bun, patty, cheese, sauce).
const burgerSandwichKey = 'cheeseburger_whole';

/// Database key of the raw meat patty only (120 g, no bun).
const burgerPattyKey = 'beef_ground_patty';

/// Database key of the burger bun.
const burgerBunKey = 'hamburger_bun';

const _breadWords = {
  'pao',
  'paes',
  'bread',
  'bun',
  'buns',
  'roll',
  'rolls',
  'torrada',
  'tosta',
  'toast',
};

bool isBurgerSandwich(DetectedFood food) => food.food?.key == burgerSandwichKey;

bool isBurgerPatty(DetectedFood food) => food.food?.key == burgerPattyKey;

/// A bun, a bread or a roll in the list ("pão", "bread", "pão de
/// hambúrguer"). Works on the database key and on the names, so an unmatched
/// "bread roll" also counts.
bool isBreadItem(DetectedFood item) {
  final food = item.food;
  if (food != null &&
      (food.key.startsWith('bread') || food.key == burgerBunKey)) {
    return true;
  }
  final words = <String>{
    for (final name in [item.label, food?.namePt, food?.nameEn])
      if (name != null) ...normaliseFoodName(name).split(' '),
  };
  return words.any(_breadWords.contains);
}

/// Whether a cheese item is already in the list (by key or name).
bool hasCheeseItem(Iterable<DetectedFood> foods) => foods.any((f) {
  final words = <String>{
    for (final name in [f.label, f.food?.namePt, f.food?.nameEn])
      if (name != null) ...normaliseFoodName(name).split(' '),
  };
  return words.contains('queijo') || words.contains('cheese');
});

/// Rule (a), double count: when the model lists a burger sandwich AND a
/// separate bun or bread, the sandwich already contains the bun, so it is
/// turned into the meat patty. The count is kept ("2 hamburgers" with a bun
/// row is two patties, 240 g, and the bun row is not counted twice).
///
/// A sandwich without any bread in the list stays a sandwich. If a patty row
/// already exists, the two collapse into one patty row with the larger count.
/// Returns [foods] unchanged when no conversion applies.
List<DetectedFood> reconcileBurgerSandwich(
  List<DetectedFood> foods,
  FoodDatabase db,
) {
  final sandwiches = foods.where(isBurgerSandwich).toList();
  if (sandwiches.isEmpty) return foods;
  final hasBread = foods.any((f) => !isBurgerSandwich(f) && isBreadItem(f));
  final patty = db.byKey(burgerPattyKey);
  if (!hasBread || patty == null) return foods;

  final sandwichCount = sandwiches
      .map((s) => s.count ?? 1)
      .reduce((a, b) => a > b ? a : b);
  final pattyRows = foods.where(isBurgerPatty).toList();
  final count = pattyRows.isEmpty
      ? sandwichCount
      : pattyRows
            .map((p) => p.count ?? 1)
            .fold(sandwichCount, (a, b) => a > b ? a : b);
  final first = sandwiches.first;
  final size = first.size ?? PortionSize.medium;
  final patties = DetectedFood(
    food: patty,
    label: patty.namePt,
    grams: estimatedGrams(food: patty, count: count, size: size),
    count: count,
    size: size,
    where: first.where,
    source: first.source,
    corroborated: first.corroborated,
  );

  final out = <DetectedFood>[];
  var placed = false;
  for (final food in foods) {
    if (isBurgerSandwich(food) || isBurgerPatty(food)) {
      if (!placed) out.add(patties);
      placed = true;
      continue;
    }
    out.add(food);
  }
  return out;
}

/// Suggestions for a patty with no bun: the bun first, then cheese and burger
/// sauce when they are not already in the list. [taken] holds the keys
/// already in the totals or in the suggestions. Never counted.
List<String> burgerCompanionKeys(
  List<DetectedFood> foods, {
  required Set<String> taken,
}) {
  if (!foods.any(isBurgerPatty) || foods.any(isBreadItem)) return const [];
  return [
    burgerBunKey,
    if (!hasCheeseItem(foods)) 'cheese_gouda',
    if (!taken.contains('burger_sauce')) 'burger_sauce',
  ];
}
