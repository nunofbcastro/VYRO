import 'dart:convert';

/// A food the assistant proposed, with the amount it suggested.
class ProposedItem {
  const ProposedItem({required this.name, required this.grams});
  final String name;
  final double grams;
}

/// Machine-readable meal suggestion the assistant appends to an answer:
/// `[[MEAL]]{"meal":"dinner","items":[{"name":"…","grams":150}]}[[/MEAL]]`.
class MealProposal {
  const MealProposal({required this.items, this.meal});
  final List<ProposedItem> items;

  /// breakfast | lunch | snack | dinner, when the model said so.
  final String? meal;
}

final _block = RegExp(
  r'\[\[MEAL\]\](.*?)\[\[/MEAL\]\]',
  dotAll: true,
  caseSensitive: false,
);

/// Splits an answer into the text to show and an optional [MealProposal].
/// Invalid blocks are removed from the text and ignored.
({String text, MealProposal? proposal}) extractMealProposal(String answer) {
  final match = _block.firstMatch(answer);
  if (match == null) return (text: answer.trim(), proposal: null);
  final text = answer.replaceAll(_block, '').trim();
  try {
    final json = jsonDecode(match.group(1)!.trim()) as Map<String, dynamic>;
    final rawItems = json['items'];
    if (rawItems is! List) return (text: text, proposal: null);
    final items = <ProposedItem>[];
    for (final raw in rawItems.take(12)) {
      if (raw is! Map) continue;
      final name = (raw['name'] as String? ?? '').trim();
      final grams = (raw['grams'] as num?)?.toDouble();
      if (name.isEmpty || name.length > 60) continue;
      if (grams == null || grams < 1 || grams > 1500) continue;
      items.add(ProposedItem(name: name, grams: grams.roundToDouble()));
    }
    if (items.isEmpty) return (text: text, proposal: null);
    final meal = json['meal'];
    return (
      text: text,
      proposal: MealProposal(
        items: items,
        meal: const {'breakfast', 'lunch', 'snack', 'dinner'}.contains(meal)
            ? meal as String
            : null,
      ),
    );
  } catch (_) {
    return (text: text, proposal: null);
  }
}

/// Nutrients per 100 g from a trusted source.
class NutrientSource {
  const NutrientSource({
    required this.label,
    required this.origin,
    this.kcal,
    this.protein,
    this.carbs,
    this.fat,
    this.sourceKey = 'assistant',
  });

  /// Food name as stored in the source.
  final String label;

  /// local_reference | history | open_food_facts | manual
  final String origin;
  final double? kcal, protein, carbs, fat;

  /// Value stored in `food_entries.source`.
  final String sourceKey;
}

/// Lower-case, accent-free words of a food name.
Set<String> foodTokens(String name) {
  const accents = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'é': 'e',
    'ê': 'e',
    'í': 'i',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ç': 'c',
  };
  final plain = name
      .toLowerCase()
      .split('')
      .map((c) => accents[c] ?? c)
      .join()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  const stop = {
    'de',
    'do',
    'da',
    'com',
    'sem',
    'e',
    'o',
    'a',
    'em',
    'the',
    'of',
    'with',
    'and',
  };
  return {
    for (final w in plain.split(RegExp(r'\s+')))
      if (w.length > 1 && !stop.contains(w)) w,
  };
}

/// Best candidate whose name shares enough words with [name]: every word of
/// the shorter name must appear in the other, and the first word must match.
/// Returns null rather than guessing.
NutrientSource? bestMatch(String name, Iterable<NutrientSource> candidates) {
  final query = foodTokens(name);
  if (query.isEmpty) return null;
  NutrientSource? best;
  var bestScore = 0.0;
  for (final candidate in candidates) {
    final tokens = foodTokens(candidate.label);
    if (tokens.isEmpty) continue;
    final shared = query.intersection(tokens).length;
    final smaller = query.length < tokens.length ? query.length : tokens.length;
    if (shared < smaller) continue;
    if (!tokens.contains(query.first) && !query.contains(tokens.first)) {
      continue;
    }
    final score = shared / (query.length + tokens.length - shared);
    if (score > bestScore) {
      bestScore = score;
      best = candidate;
    }
  }
  return best;
}
