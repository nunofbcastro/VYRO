import 'dart:math' as math;

import 'meal_math.dart';

/// Result of checking the numbers in a model answer against local totals.
class ProseCheck {
  const ProseCheck({
    required this.text,
    required this.removedLines,
    required this.verifiedClaims,
  });

  /// Text with the lines that carry unverified nutrient numbers removed.
  final String text;
  final int removedLines;
  final int verifiedClaims;
}

enum NutrientKind { kcal, protein, carbs, fat }

const _keywords = {
  NutrientKind.kcal: r'kcal|calorias|calories',
  NutrientKind.protein: r'prote[ií]nas?|protein',
  NutrientKind.carbs:
      r'hidratos(?:\s+de\s+carbono)?|carboidratos?|carbs?|carbohydrates?',
  NutrientKind.fat: r'gorduras?|fats?',
};

/// Every keyword as one group, whole words only: "Carbonara" must not match
/// "carb".
const _kw =
    r'(?:(?:kcal|calorias|calories)|(?:prote[ií]nas?|protein)|'
    r'(?:hidratos(?:\s+de\s+carbono)?|carboidratos?|carbs?|carbohydrates?)|'
    r'(?:gorduras?|fats?))\b';

final _anyKeyword = RegExp(r'\b' + _kw, caseSensitive: false, unicode: true);
final _number = RegExp(r'\d+(?:[.,]\d+)?');

/// A keyword right after a number, optionally after a range ("250-300 kcal")
/// or a gram unit ("30 g de proteína").
final _after = RegExp(
  r'^(?:\s*[-–]\s*\d+(?:[.,]\d+)?)?\s*(?:(?:gramas?|grams?|g|mg|ml)\b\s*)?'
          r'(?:de\s+|of\s+)?(' +
      _kw +
      r')',
  caseSensitive: false,
  unicode: true,
);

/// A keyword shortly before a number ("Proteína: 30").
final _before = RegExp(
  '(' + _kw + r')[^0-9]{0,15}\$',
  caseSensitive: false,
  unicode: true,
);

NutrientKind? _kindOf(String word) {
  for (final entry in _keywords.entries) {
    final full = RegExp(
      '^(?:${entry.value})\$',
      caseSensitive: false,
      unicode: true,
    );
    if (full.hasMatch(word)) return entry.key;
  }
  return null;
}

/// Nutrient numbers paired with a keyword on one line.
List<(NutrientKind, double)> _claimsIn(String line) {
  final claims = <(NutrientKind, double)>[];
  for (final m in _number.allMatches(line)) {
    final value = double.parse(m.group(0)!.replaceAll(',', '.'));
    NutrientKind? kind;
    final after = _after.firstMatch(line.substring(m.end));
    if (after != null) kind = _kindOf(after.group(1)!);
    if (kind == null) {
      final before = _before.firstMatch(line.substring(0, m.start));
      if (before != null) kind = _kindOf(before.group(1)!);
    }
    if (kind != null) claims.add((kind, value));
  }
  return claims;
}

/// Kcal may differ by 15 kcal or 10 %, whichever is smaller; grams by 2 g or
/// 10 %, with at least 1 g for rounding.
bool _agrees(NutrientKind kind, double value, MealTotals totals) {
  final local = switch (kind) {
    NutrientKind.kcal => totals.kcal,
    NutrientKind.protein => totals.protein,
    NutrientKind.carbs => totals.carbs,
    NutrientKind.fat => totals.fat,
  };
  final tolerance = kind == NutrientKind.kcal
      ? math.min(15.0, 0.10 * local)
      : math.max(1.0, math.min(2.0, 0.10 * local));
  return (value - local).abs() <= tolerance;
}

/// Checks the nutrient numbers written in a model answer.
///
/// The app is the only source of nutrient numbers, so a line with a keyword
/// (kcal, proteína, hidratos, gordura) and a number is kept only when every
/// such number agrees with [totals]. Without complete totals (no meal, or a
/// partial one) nothing can be verified, so those lines are removed. Lines
/// without nutrient numbers are kept as written. The text is returned
/// unchanged when nothing is removed.
ProseCheck checkProseNumbers(String prose, {MealTotals? totals}) {
  final kept = <String>[];
  var removed = 0;
  var verified = 0;
  for (final line in prose.split('\n')) {
    if (!_anyKeyword.hasMatch(line)) {
      kept.add(line);
      continue;
    }
    final claims = _claimsIn(line);
    if (claims.isEmpty) {
      kept.add(line);
      continue;
    }
    final ok =
        totals != null && claims.every((c) => _agrees(c.$1, c.$2, totals));
    if (ok) {
      verified += claims.length;
      kept.add(line);
    } else {
      removed++;
    }
  }
  if (removed == 0) {
    return ProseCheck(
      text: prose.trim(),
      removedLines: 0,
      verifiedClaims: verified,
    );
  }
  final text = kept.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  return ProseCheck(
    text: text,
    removedLines: removed,
    verifiedClaims: verified,
  );
}
