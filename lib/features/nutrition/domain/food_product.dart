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
  });

  final String barcode;
  final String name;
  final String? brand;
  final String? quantity;
  final double? kcalPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;
  final String? nutriScore;
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
