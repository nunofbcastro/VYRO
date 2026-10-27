import '../data/food_database.dart';
import 'food_screening.dart' show normaliseFoodName;
import 'food_vision.dart';
import 'portion_estimate.dart';

/// Burger and chicken sandwich rules for the photo model's answers (pure
/// Dart, see docs/FOOD_VISION.md). A bare English "hamburger", "burger" or
/// "big mac" in a photo means the whole sandwich (`cheeseburger_whole`, bun
/// included), while "beef patty" and the Portuguese "hambúrguer" mean the
/// meat patty (`beef_ground_patty`). Chicken works the same way: "fried
/// chicken", "crispy chicken" and "chicken patty" are the breaded patty, and
/// "chicken burger", "chicken sandwich" and "McChicken" are the whole
/// sandwich (`chicken_sandwich`). A bare "chicken" stays the grilled breast
/// unless a bun or a sandwich word shows it is a sandwich.

/// Database key of the whole burger sandwich (bun, patty, cheese, sauce).
const burgerSandwichKey = 'cheeseburger_whole';

/// Database key of the raw meat patty only (120 g, no bun).
const burgerPattyKey = 'beef_ground_patty';

/// Database key of the burger bun.
const burgerBunKey = 'hamburger_bun';

/// Database key of the whole breaded chicken sandwich (bun included).
const chickenSandwichKey = 'chicken_sandwich';

/// Database key of the breaded fried chicken patty (no bun).
const chickenPattyKey = 'chicken_fried_patty';

/// Database key of the grilled chicken breast (the default for "chicken").
const grilledChickenKey = 'chicken_breast_roasted';

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

/// Words in a photo's "where" text that mean the chicken is in a sandwich.
const _sandwichWords = {
  'burger',
  'sandwich',
  'sanduiche',
  'sandes',
  'hamburguer',
  'bun',
  'pao',
};

/// Model names that only say "chicken" (no cut, no cooking method).
const _genericChickenNames = {'chicken', 'chicken meat', 'frango'};

bool isBurgerSandwich(DetectedFood food) => food.food?.key == burgerSandwichKey;

bool isBurgerPatty(DetectedFood food) => food.food?.key == burgerPattyKey;

bool isChickenSandwich(DetectedFood food) =>
    food.food?.key == chickenSandwichKey;

bool isChickenPatty(DetectedFood food) => food.food?.key == chickenPattyKey;

/// Whether the model's name is a bare "chicken" (EN or PT), which maps to the
/// grilled breast by default.
bool isGenericChickenName(String name) =>
    _genericChickenNames.contains(normaliseFoodName(name));

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

/// Chicken that the model named only as "chicken" (in [generic], the items
/// that matched the grilled breast by default). With a bun or bread in the
/// list it is the breaded patty (the bun is the separate bread row). Without
/// bread, a sandwich word in its "where" text ("burger", "sandwich") makes it
/// the whole chicken sandwich. Otherwise it stays grilled. Returns [foods]
/// unchanged when [generic] is empty.
List<DetectedFood> reconcileGenericChicken(
  List<DetectedFood> foods,
  FoodDatabase db,
  Set<DetectedFood> generic,
) {
  if (generic.isEmpty) return foods;
  final patty = db.byKey(chickenPattyKey);
  final sandwich = db.byKey(chickenSandwichKey);
  if (patty == null || sandwich == null) return foods;
  final hasBread = foods.any(
    (f) => !generic.contains(f) && !isBurgerSandwich(f) && isBreadItem(f),
  );
  final out = <DetectedFood>[];
  for (final food in foods) {
    if (!generic.contains(food)) {
      out.add(food);
      continue;
    }
    final sandwichWhere = normaliseFoodName(
      food.where ?? '',
    ).split(' ').any(_sandwichWords.contains);
    final target = hasBread
        ? patty
        : sandwichWhere
        ? sandwich
        : null;
    if (target == null) {
      out.add(food);
      continue;
    }
    final count = food.count ?? 1;
    final size = food.size ?? PortionSize.medium;
    out.add(
      DetectedFood(
        food: target,
        label: target.namePt,
        grams: estimatedGrams(food: target, count: count, size: size),
        count: count,
        size: size,
        where: food.where,
        source: food.source,
        corroborated: food.corroborated,
      ),
    );
  }
  return out;
}

/// Rule (a), double count: when the model lists a whole sandwich (burger or
/// chicken) AND a separate bun or bread, the sandwich already contains the
/// bun, so it is turned into the meat or breaded patty. The count is kept
/// ("2 hamburgers" with a bun row is two patties, 240 g, and the bun row is
/// not counted twice).
///
/// A sandwich without any bread in the list stays a sandwich. If a patty row
/// already exists, the two collapse into one patty row with the larger count.
/// Returns [foods] unchanged when no conversion applies.
List<DetectedFood> reconcileBurgerSandwich(
  List<DetectedFood> foods,
  FoodDatabase db,
) => _reconcileSandwich(
  _reconcileSandwich(
    foods,
    db,
    isSandwich: isBurgerSandwich,
    isPatty: isBurgerPatty,
    pattyKey: burgerPattyKey,
  ),
  db,
  isSandwich: isChickenSandwich,
  isPatty: isChickenPatty,
  pattyKey: chickenPattyKey,
);

List<DetectedFood> _reconcileSandwich(
  List<DetectedFood> foods,
  FoodDatabase db, {
  required bool Function(DetectedFood) isSandwich,
  required bool Function(DetectedFood) isPatty,
  required String pattyKey,
}) {
  final sandwiches = foods.where(isSandwich).toList();
  if (sandwiches.isEmpty) return foods;
  final hasBread = foods.any((f) => !isSandwich(f) && isBreadItem(f));
  final patty = db.byKey(pattyKey);
  if (!hasBread || patty == null) return foods;

  final sandwichCount = sandwiches
      .map((s) => s.count ?? 1)
      .reduce((a, b) => a > b ? a : b);
  final pattyRows = foods.where(isPatty).toList();
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
    if (isSandwich(food) || isPatty(food)) {
      if (!placed) out.add(patties);
      placed = true;
      continue;
    }
    out.add(food);
  }
  return out;
}

/// Suggestions for burgers and chicken sandwiches. [taken] holds the keys
/// already in the totals or in the suggestions. Never counted.
///
/// A patty with no bread: the bun first, then bacon, cheese (when not listed),
/// the sauce (burger sauce, or mayonnaise for chicken), then lettuce and
/// tomato as the lowest priority. A whole sandwich already has its bun and
/// (for a burger) its cheese, so it gets bacon, lettuce and tomato only.
List<String> burgerCompanionKeys(
  List<DetectedFood> foods, {
  required Set<String> taken,
}) {
  // A whole sandwich's name says "pão" too, so it does not count as bread.
  final hasBread = foods.any(
    (f) => !isBurgerSandwich(f) && !isChickenSandwich(f) && isBreadItem(f),
  );
  if (hasBread) return const [];
  final chickenPatty = foods.any(isChickenPatty);
  if (foods.any(isBurgerPatty) || chickenPatty) {
    final sauce = chickenPatty ? 'mayonnaise' : 'burger_sauce';
    return [
      burgerBunKey,
      'bacon_cooked',
      if (!hasCheeseItem(foods)) 'cheese_gouda',
      if (!taken.contains(sauce)) sauce,
      'lettuce_raw',
      'tomato_raw',
    ];
  }
  if (foods.any(isBurgerSandwich) || foods.any(isChickenSandwich)) {
    return const ['bacon_cooked', 'lettuce_raw', 'tomato_raw'];
  }
  return const [];
}
