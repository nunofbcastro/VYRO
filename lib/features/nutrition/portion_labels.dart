import '../../app/l10n/strings.dart';
import '../../core/database/app_database.dart';
import 'domain/portion.dart';

/// Chip label for a portion kind ("Porção", "Unidade", "Gramas").
String portionKindName(
  VyroStrings t,
  PortionKind kind, {
  bool liquid = false,
}) => switch (kind) {
  PortionKind.serving => t.get('portionServing'),
  PortionKind.unit => t.get('portionUnit'),
  PortionKind.package => t.get('portionPackage'),
  PortionKind.grams => t.get(liquid ? 'portionMl' : 'portionGrams'),
};

/// Unit suffix for weights: g or ml.
String massUnit({bool liquid = false}) => liquid ? 'ml' : 'g';

/// Noun for a count: "unidades", "porção", "g".
String portionNoun(
  VyroStrings t,
  PortionKind kind,
  double count, {
  bool liquid = false,
}) {
  if (kind == PortionKind.grams) return massUnit(liquid: liquid);
  final many = count > 1;
  return t.get(switch (kind) {
    PortionKind.serving => many ? 'portionServingMany' : 'portionServingOne',
    PortionKind.unit => many ? 'portionUnitMany' : 'portionUnitOne',
    _ => many ? 'portionPackageMany' : 'portionPackageOne',
  });
}

/// "2 unidades", "1 porção", "150 g".
String portionCountLabel(
  VyroStrings t,
  PortionKind kind,
  double count, {
  bool liquid = false,
}) {
  final amount = formatAmount(count, english: t.isEnglish);
  return '$amount ${portionNoun(t, kind, count, liquid: liquid)}';
}

/// Amount shown in the diary: "2 unidades · 50 g" or "120 g".
String entryAmountLabel(VyroStrings t, FoodEntryRecord entry) {
  final grams =
      '${formatAmount(entry.quantityGrams.roundToDouble(), english: t.isEnglish)} g';
  final kind = PortionKind.fromKey(entry.portionUnit);
  final count = entry.portionCount;
  if (kind == null ||
      kind == PortionKind.grams ||
      count == null ||
      count <= 0) {
    return grams;
  }
  return '${portionCountLabel(t, kind, count)} · $grams';
}
