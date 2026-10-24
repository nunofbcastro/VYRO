import 'food_product.dart';

/// How a barcode product is measured when it is logged.
///
/// Calories always come from the per-100 g values multiplied by a weight in
/// grams; a portion only converts "2 bars" or "1 serving" into that weight.
enum PortionKind {
  grams('grams'),
  serving('serving'),
  unit('unit'),
  package('package');

  const PortionKind(this.key);

  /// Stable value stored in `food_entries.portion_unit`.
  final String key;

  static PortionKind? fromKey(String? key) {
    for (final kind in values) {
      if (kind.key == key) return kind;
    }
    return null;
  }
}

class PortionOption {
  const PortionOption({
    required this.kind,
    required this.gramsPerUnit,
    this.declared = true,
  });

  final PortionKind kind;

  /// Weight of one portion in grams (or ml). Null means the product does not
  /// declare it and the user has to type it before logging.
  final double? gramsPerUnit;

  /// False when the weight was not declared by the producer.
  final bool declared;

  PortionOption withGrams(double grams) =>
      PortionOption(kind: kind, gramsPerUnit: grams, declared: false);
}

/// Parsed pack description ("6 x 25 g", "1,5 l", "250 g").
class PackInfo {
  const PackInfo({
    this.count,
    this.unitAmount,
    this.totalAmount,
    this.liquid = false,
  });

  /// Number of individual units in the pack, when stated.
  final int? count;

  /// Weight of one unit in grams/ml, when it can be derived.
  final double? unitAmount;

  /// Whole pack weight in grams/ml.
  final double? totalAmount;
  final bool liquid;
}

final _amountPattern = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*(kg|g|gr|mg|ml|cl|dl|l)\b',
  caseSensitive: false,
);
final _multiPattern = RegExp(
  r'(\d+)\s*[x×*]\s*(\d+(?:[.,]\d+)?)\s*(kg|g|gr|ml|cl|dl|l)\b',
  caseSensitive: false,
);
final _countPattern = RegExp(
  r'(\d+)\s*(?:unidades|unidade|un\.?|units?|pcs|pieces?|peças|barras?|barritas?|bars?|saquetas?|sachets?|cápsulas?|capsules?)\b',
  caseSensitive: false,
);

/// Converts an amount + unit into grams (or ml for liquids).
({double amount, bool liquid})? _toBase(String number, String unit) {
  final value = double.tryParse(number.replaceAll(',', '.'));
  if (value == null || value <= 0) return null;
  return switch (unit.toLowerCase()) {
    'kg' => (amount: value * 1000, liquid: false),
    'g' || 'gr' => (amount: value, liquid: false),
    'mg' => (amount: value / 1000, liquid: false),
    'l' => (amount: value * 1000, liquid: true),
    'dl' => (amount: value * 100, liquid: true),
    'cl' => (amount: value * 10, liquid: true),
    'ml' => (amount: value, liquid: true),
    _ => null,
  };
}

PackInfo? parsePackQuantity(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;

  final multi = _multiPattern.firstMatch(text);
  if (multi != null) {
    final count = int.tryParse(multi.group(1)!);
    final unit = _toBase(multi.group(2)!, multi.group(3)!);
    if (count != null && count > 0 && unit != null) {
      return PackInfo(
        count: count,
        unitAmount: unit.amount,
        totalAmount: unit.amount * count,
        liquid: unit.liquid,
      );
    }
  }

  final amount = _amountPattern.firstMatch(text);
  final total = amount == null
      ? null
      : _toBase(amount.group(1)!, amount.group(2)!);
  final countMatch = _countPattern.firstMatch(text);
  final count = countMatch == null ? null : int.tryParse(countMatch.group(1)!);
  if (total == null && count == null) return null;
  return PackInfo(
    count: count,
    totalAmount: total?.amount,
    unitAmount: (total != null && count != null && count > 1)
        ? total.amount / count
        : null,
    liquid: total?.liquid ?? false,
  );
}

/// Reads a weight from a serving label such as "1 barra (25 g)" or "30g".
double? parseServingGrams(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;
  final match = _amountPattern.firstMatch(text);
  if (match == null) return null;
  return _toBase(match.group(1)!, match.group(2)!)?.amount;
}

final _nameCountPattern = RegExp(
  r'(?:\bx\s?(\d{1,3})\b|\b(\d{1,3})\s?(?:x|unidades|units|barras|barritas|bars|pcs|pieces|saquetas|iogurtes|yogurts)\b)',
  caseSensitive: false,
);

/// Unit count written in a product name, e.g. "Biscuits x22" or "4 barras".
int? countFromName(String name) {
  final match = _nameCountPattern.firstMatch(name);
  if (match == null) return null;
  final count = int.tryParse(match.group(1) ?? match.group(2) ?? '');
  return count != null && count > 1 ? count : null;
}

bool _close(double a, double b) => (a - b).abs() <= 0.5;

/// Portion choices for a product, most useful first. Grams are always
/// available. "Unit" is always offered so bars, yoghurts or biscuits can be
/// logged by count even when the producer did not declare a unit weight.
List<PortionOption> portionOptionsFor(FoodProduct product) {
  final pack = parsePackQuantity(product.quantity);
  final serving =
      product.servingGrams ?? parseServingGrams(product.servingSize);
  final packageAmount = product.packageGrams ?? pack?.totalAmount;
  final count = pack?.count ?? countFromName(product.name);

  double? unit = pack?.unitAmount;
  if (unit == null && packageAmount != null && count != null) {
    // "x22 - 304g" → 13.8 g per biscuit; "1 x 45 g" → the whole pack.
    unit = packageAmount / count;
  }
  if (unit == null &&
      packageAmount != null &&
      serving != null &&
      _close(serving, packageAmount)) {
    // Single-serve pack (one bar, one yoghurt): one unit is the pack.
    unit = packageAmount;
  }

  final options = <PortionOption>[];
  if (serving != null && serving > 0) {
    options.add(
      PortionOption(kind: PortionKind.serving, gramsPerUnit: serving),
    );
  }
  options.add(
    unit != null && unit > 0
        ? PortionOption(kind: PortionKind.unit, gramsPerUnit: unit)
        : const PortionOption(
            kind: PortionKind.unit,
            gramsPerUnit: null,
            declared: false,
          ),
  );
  if (packageAmount != null &&
      packageAmount > 0 &&
      !options.any(
        (option) =>
            option.gramsPerUnit != null &&
            _close(option.gramsPerUnit!, packageAmount),
      )) {
    options.add(
      PortionOption(kind: PortionKind.package, gramsPerUnit: packageAmount),
    );
  }
  options.add(const PortionOption(kind: PortionKind.grams, gramsPerUnit: 1));
  return options;
}

/// The option selected when the product screen opens: the declared serving,
/// otherwise a declared unit, otherwise grams (never the whole package).
PortionOption defaultPortion(List<PortionOption> options) => options.firstWhere(
  (option) =>
      (option.kind == PortionKind.serving || option.kind == PortionKind.unit) &&
      option.declared &&
      option.gramsPerUnit != null,
  orElse: () =>
      options.firstWhere((option) => option.kind == PortionKind.grams),
);

/// Default amount for a portion kind: 100 g, otherwise one portion.
double defaultCount(PortionKind kind) => kind == PortionKind.grams ? 100 : 1;

/// Step used by the − / + buttons.
double stepFor(PortionKind kind) => kind == PortionKind.grams ? 10 : 0.5;

/// Grams logged for [count] portions of [option], or null if unknown.
double? gramsFor(PortionOption option, double count) {
  final per = option.gramsPerUnit;
  if (per == null || per <= 0 || !count.isFinite || count <= 0) return null;
  return per * count;
}

/// Formats a count without trailing zeros, using the locale decimal mark.
String formatAmount(double value, {required bool english}) {
  final rounded = (value * 100).round() / 100;
  var text = rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  if (!english) text = text.replaceAll('.', ',');
  return text;
}
