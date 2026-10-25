import '../data/food_database.dart';

/// How large the visible portion looks, relative to a typical serving.
enum PortionSize {
  small,
  medium,
  large;

  double get factor => switch (this) {
    PortionSize.small => 0.6,
    PortionSize.medium => 1,
    PortionSize.large => 1.5,
  };

  static PortionSize parse(Object? raw) {
    if (raw is String) {
      switch (raw.trim().toLowerCase()) {
        case 'small':
        case 'pequeno':
        case 'pequena':
          return PortionSize.small;
        case 'large':
        case 'grande':
          return PortionSize.large;
      }
    }
    return PortionSize.medium;
  }
}

/// Dishes that are eaten whole (one pizza, one burger, one plate). The photo
/// shows the whole thing. Slices ("fatia de pizza") are not whole dishes: a
/// slice is one piece of a pizza and is scaled by size like any other food.
bool isWholeDish(FoodRef food) {
  final name = '${food.namePt} ${food.nameEn}'.toLowerCase();
  if (name.contains('fatia') || name.contains('slice')) return false;
  if (food.category == 'pratos') return true;
  return name.contains('pizza') ||
      name.contains('hambúrguer') ||
      name.contains('hamburguer') ||
      name.contains('burger') ||
      name.contains('francesinha');
}

/// Grams from the offline typical portion, not from a model "weight".
/// Unmatched names may keep a clamped fallback from the model.
///
/// A whole dish counted in pieces (one whole pizza, `portionUnits` 1) is one
/// item, so its size does not scale it: `count` is the amount. A whole dish
/// without pieces keeps its size rule (small = one typical serving, never
/// shrunk; large = 1.5 times).
double estimatedGrams({
  FoodRef? food,
  int count = 1,
  PortionSize size = PortionSize.medium,
  double? fallbackGrams,
}) {
  final pieces = count.clamp(1, 20);
  if (food != null) {
    final units = food.portionUnits;
    final multiplier = units != null && units > 0 ? pieces / units : 1.0;
    final wholeDish = isWholeDish(food);
    final onePiece = units == 1;
    final factor = (wholeDish && (onePiece || size.factor < 1))
        ? 1.0
        : size.factor;
    return (food.portionG * multiplier * factor).clamp(5, 1500).roundToDouble();
  }
  if (fallbackGrams != null && fallbackGrams.isFinite && fallbackGrams > 0) {
    return fallbackGrams.clamp(5, 1500).roundToDouble();
  }
  return (100.0 * pieces * size.factor).clamp(5, 1500).roundToDouble();
}
