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

/// Grams from the offline typical portion, not from a model "weight".
/// Unmatched names may keep a clamped fallback from the model.
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
    return (food.portionG * multiplier * size.factor)
        .clamp(5, 1500)
        .roundToDouble();
  }
  if (fallbackGrams != null && fallbackGrams.isFinite && fallbackGrams > 0) {
    return fallbackGrams.clamp(5, 1500).roundToDouble();
  }
  return (100.0 * pieces * size.factor).clamp(5, 1500).roundToDouble();
}
