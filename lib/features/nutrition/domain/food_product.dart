class FoodProduct {
  const FoodProduct({
    required this.barcode,
    required this.name,
    this.brand,
    this.quantity,
    this.kcalPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
    this.nutriScore,
    this.servingSize,
    this.servingGrams,
    this.packageGrams,
    this.liquid = false,
  });

  final String barcode;
  final String name;
  final String? brand;

  /// Pack description as printed by Open Food Facts, e.g. "6 x 25 g".
  final String? quantity;
  final double? kcalPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;
  final String? nutriScore;

  /// Serving description declared by the producer, e.g. "1 barra (25 g)".
  final String? servingSize;

  /// Serving weight in grams (or millilitres for drinks).
  final double? servingGrams;

  /// Whole pack weight in grams (or millilitres for drinks).
  final double? packageGrams;

  /// True when the pack is declared in ml/cl/l. Nutrients stay per 100 ml,
  /// which Open Food Facts reports in the same `_100g` fields.
  final bool liquid;
}

double? nutrientForPortion(double? per100g, double quantityGrams) {
  if (per100g == null || !quantityGrams.isFinite || quantityGrams <= 0) {
    return null;
  }
  return per100g * quantityGrams / 100;
}

String dayKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
