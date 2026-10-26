/// Scoring for the offline food-vision evaluation. Pure Dart (no Flutter), so
/// it is shared by the host harness (`tool/eval/food_vision_eval_test.dart`),
/// the on-device run (`integration_test/food_vision_eval_test.dart`) and the
/// unit tests (`test/eval_scoring_test.dart`).
library;

import 'dart:convert';

/// One expected food of a photo.
///
/// A food with a database row has [key] (a `foods.json` key) and optional
/// [anyOf] alternatives. A food with no database row has [text] instead (the
/// name the photo shows, matched against unmatched predictions by name).
class LabelFood {
  const LabelFood({
    required this.name,
    this.key,
    this.anyOf = const [],
    this.text,
    this.optional = false,
  }) : assert((key == null) != (text == null), 'use exactly one of key/text');

  /// Human name for reports.
  final String name;

  /// `foods.json` key, or null for an unmatched label.
  final String? key;

  /// Other keys that count as the same food.
  final List<String> anyOf;

  /// Name of a food with no database row (matched by normalised name).
  final String? text;

  /// A missed optional food does not count against recall.
  final bool optional;

  Set<String> get acceptedKeys => {if (key != null) key!, ...anyOf};

  factory LabelFood.fromJson(Map<String, Object?> json) {
    final key = json['key'] as String?;
    final text = json['text'] as String?;
    if ((key == null) == (text == null)) {
      throw FormatException(
        'label food needs exactly one of "key" or "text": $json',
      );
    }
    final anyOfRaw = json['any_of'];
    return LabelFood(
      name: (json['name'] as String?) ?? key ?? text!,
      key: key,
      text: text,
      anyOf: [
        if (anyOfRaw is List)
          for (final a in anyOfRaw) '$a',
      ],
      optional: json['optional'] == true,
    );
  }
}

/// One entry of `eval/labels.json`: a photo and the foods it shows.
class LabelEntry {
  const LabelEntry({required this.file, required this.foods, this.notes = ''});

  final String file;
  final List<LabelFood> foods;
  final String notes;

  factory LabelEntry.fromJson(Map<String, Object?> json) {
    final file = json['file'];
    if (file is! String || file.isEmpty) {
      throw FormatException('label entry without "file": $json');
    }
    final foods = json['foods'];
    if (foods is! List) {
      throw FormatException('label entry "$file" without "foods" list');
    }
    return LabelEntry(
      file: file,
      foods: [
        for (final f in foods) LabelFood.fromJson(f as Map<String, Object?>),
      ],
      notes: (json['notes'] as String?) ?? '',
    );
  }
}

/// Parses the whole `labels.json` document (`{"photos":[...]}` or a bare list).
List<LabelEntry> parseLabels(String source) {
  final decoded = jsonDecode(source);
  final list = switch (decoded) {
    List<Object?>() => decoded,
    Map<String, Object?>() => decoded['photos'] as List<Object?>? ?? const [],
    _ => throw const FormatException('labels must be a list or {"photos":[]}'),
  };
  return [for (final e in list) LabelEntry.fromJson(e as Map<String, Object?>)];
}

/// Returns one message per label key that is not in [databaseKeys].
List<String> validateLabelKeys(
  List<LabelEntry> labels,
  Set<String> databaseKeys,
) => [
  for (final entry in labels)
    for (final food in entry.foods)
      for (final key in food.acceptedKeys)
        if (!databaseKeys.contains(key))
          '${entry.file}: "$key" is not a key in foods.json',
];

/// One food the system predicted for a photo.
class Prediction {
  const Prediction({required this.name, this.key});

  /// Name shown in the app (or as the model wrote it).
  final String name;

  /// Database key when the name matched a database food, else null.
  final String? key;

  Map<String, Object?> toJson() => {'name': name, 'key': key};
}

/// Normalised name: lower case, no accents, single spaces, no punctuation.
String normaliseName(String raw) {
  const accents = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };
  final buffer = StringBuffer();
  for (final rune in raw.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(accents[ch] ?? ch);
  }
  return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// Whether [prediction] can be the same food as [label].
bool compatible(LabelFood label, Prediction prediction) {
  if (label.key != null) {
    return prediction.key != null &&
        label.acceptedKeys.contains(prediction.key);
  }
  // Unmatched label: only a prediction with no database row can match it,
  // by name (exact, or one contains the other after normalisation).
  if (prediction.key != null) return false;
  final predicted = normaliseName(prediction.name);
  final expected = normaliseName(label.text!);
  if (predicted.isEmpty || expected.isEmpty) return false;
  return predicted == expected ||
      predicted.contains(expected) ||
      expected.contains(predicted);
}

/// One-to-one matching between labels and predictions (maximum cardinality).
/// Required labels are matched first so an optional label never takes a
/// prediction a required label needs.
class MatchResult {
  const MatchResult({
    required this.matched,
    required this.misses,
    required this.optionalMisses,
    required this.falsePositives,
  });

  final List<(LabelFood, Prediction)> matched;

  /// Required labels with no prediction (false negatives).
  final List<LabelFood> misses;

  /// Optional labels with no prediction (not counted).
  final List<LabelFood> optionalMisses;

  /// Predictions matched to no label (false positives).
  final List<Prediction> falsePositives;
}

MatchResult matchPredictions(
  List<LabelFood> labels,
  List<Prediction> predictions,
) {
  final order = [
    for (var i = 0; i < labels.length; i++)
      if (!labels[i].optional) i,
    for (var i = 0; i < labels.length; i++)
      if (labels[i].optional) i,
  ];
  // predictionOwner[p] = label index matched to prediction p, or -1.
  final predictionOwner = List<int>.filled(predictions.length, -1);
  final labelPrediction = List<int>.filled(labels.length, -1);

  bool augment(int label, List<bool> seen) {
    for (var p = 0; p < predictions.length; p++) {
      if (seen[p] || !compatible(labels[label], predictions[p])) continue;
      seen[p] = true;
      final owner = predictionOwner[p];
      if (owner < 0 || augment(owner, seen)) {
        predictionOwner[p] = label;
        labelPrediction[label] = p;
        return true;
      }
    }
    return false;
  }

  for (final label in order) {
    augment(label, List<bool>.filled(predictions.length, false));
  }

  final matched = <(LabelFood, Prediction)>[];
  final misses = <LabelFood>[];
  final optionalMisses = <LabelFood>[];
  for (var l = 0; l < labels.length; l++) {
    final p = labelPrediction[l];
    if (p >= 0) {
      matched.add((labels[l], predictions[p]));
    } else if (labels[l].optional) {
      optionalMisses.add(labels[l]);
    } else {
      misses.add(labels[l]);
    }
  }
  return MatchResult(
    matched: matched,
    misses: misses,
    optionalMisses: optionalMisses,
    falsePositives: [
      for (var p = 0; p < predictions.length; p++)
        if (predictionOwner[p] < 0) predictions[p],
    ],
  );
}

/// Score of one photo.
class ImageScore {
  ImageScore({
    required this.file,
    required this.labels,
    required this.predicted,
    required this.match,
    this.latencyMs,
    this.error,
    this.rawAnswers = const [],
    this.suggestions = const [],
    this.notes = '',
    this.appDetail,
  });

  final String file;
  final List<LabelFood> labels;
  final List<Prediction> predicted;
  final MatchResult match;

  /// Wall time of the analysis, null when it was not measured.
  final double? latencyMs;

  /// Exception text when the analysis threw (scored as no predictions).
  final String? error;

  /// Raw model answers, one per call (`first:`, `second:`, `verify:` ...).
  final List<String> rawAnswers;

  /// Names of suggestions the app shows outside the totals (not scored).
  final List<String> suggestions;

  final String notes;

  /// The app's own "Detalhes da análise" text (decisions per item), if any.
  final String? appDetail;

  int get tp => match.matched.length;
  int get fp => match.falsePositives.length;
  int get fn => match.misses.length;

  /// Every required food found and nothing extra.
  bool get exactMeal => fn == 0 && fp == 0 && error == null;

  Map<String, Object?> toJson() => {
    'file': file,
    'notes': notes,
    'error': error,
    'latency_ms': latencyMs,
    'exact_meal': exactMeal,
    'tp': tp,
    'fp': fp,
    'fn': fn,
    'predicted': [for (final p in predicted) p.toJson()],
    'matched': [
      for (final (label, prediction) in match.matched)
        {'label': label.name, 'predicted': prediction.name},
    ],
    'misses': [for (final m in match.misses) m.name],
    'optional_misses': [for (final m in match.optionalMisses) m.name],
    'false_positives': [for (final p in match.falsePositives) p.name],
    'suggestions': suggestions,
    'app_detail': appDetail,
    'raw_answers': rawAnswers,
  };
}

/// Scores one photo. [predicted] are the foods of the main list only.
ImageScore scoreImage({
  required String file,
  required List<LabelFood> labels,
  required List<Prediction> predicted,
  double? latencyMs,
  String? error,
  List<String> rawAnswers = const [],
  List<String> suggestions = const [],
  String notes = '',
  String? appDetail,
}) => ImageScore(
  file: file,
  labels: labels,
  predicted: predicted,
  match: matchPredictions(labels, predicted),
  latencyMs: latencyMs,
  error: error,
  rawAnswers: rawAnswers,
  suggestions: suggestions,
  notes: notes,
  appDetail: appDetail,
);

/// Micro-averaged metrics over all photos. Ratios are null when undefined.
class EvalSummary {
  EvalSummary._({
    required this.photos,
    required this.errors,
    required this.tp,
    required this.fp,
    required this.fn,
    required this.exactMeals,
    required this.precision,
    required this.recall,
    required this.f1,
    required this.exactMealRate,
    required this.meanFalsePositives,
    required this.meanLatencyMs,
    required this.medianLatencyMs,
  });

  factory EvalSummary.of(List<ImageScore> images) {
    final tp = images.fold<int>(0, (s, i) => s + i.tp);
    final fp = images.fold<int>(0, (s, i) => s + i.fp);
    final fn = images.fold<int>(0, (s, i) => s + i.fn);
    final exact = images.where((i) => i.exactMeal).length;
    final latencies = [
      for (final i in images)
        if (i.latencyMs != null) i.latencyMs!,
    ]..sort();
    final n = images.length;
    return EvalSummary._(
      photos: n,
      errors: images.where((i) => i.error != null).length,
      tp: tp,
      fp: fp,
      fn: fn,
      exactMeals: exact,
      precision: _ratio(tp, tp + fp),
      recall: _ratio(tp, tp + fn),
      f1: _ratio(2 * tp, 2 * tp + fp + fn),
      exactMealRate: n == 0 ? null : exact / n,
      meanFalsePositives: n == 0 ? null : fp / n,
      meanLatencyMs: latencies.isEmpty
          ? null
          : latencies.reduce((a, b) => a + b) / latencies.length,
      medianLatencyMs: _median(latencies),
    );
  }

  final int photos;
  final int errors;
  final int tp, fp, fn;
  final int exactMeals;
  final double? precision, recall, f1;
  final double? exactMealRate;
  final double? meanFalsePositives;
  final double? meanLatencyMs;
  final double? medianLatencyMs;

  Map<String, Object?> toJson() => {
    'photos': photos,
    'errors': errors,
    'tp': tp,
    'fp': fp,
    'fn': fn,
    'exact_meals': exactMeals,
    'precision': precision,
    'recall': recall,
    'f1': f1,
    'exact_meal_rate': exactMealRate,
    'mean_false_positives_per_photo': meanFalsePositives,
    'mean_latency_ms': meanLatencyMs,
    'median_latency_ms': medianLatencyMs,
  };

  static double? _ratio(int numerator, int denominator) =>
      denominator == 0 ? null : numerator / denominator;

  static double? _median(List<double> sorted) {
    if (sorted.isEmpty) return null;
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }
}

String formatRatio(double? value) =>
    value == null ? '-' : value.toStringAsFixed(2);

String formatMs(double? value) =>
    value == null ? '-' : '${(value / 1000).toStringAsFixed(1)} s';

/// Markdown table row set for a summary: one row per run.
String summaryMarkdownTable(List<(String label, EvalSummary summary)> runs) {
  final b = StringBuffer()
    ..writeln(
      '| Run | Photos | Precision | Recall | F1 | Exact meals | FP / photo | Mean latency | Median latency | Errors |',
    )
    ..writeln('|---|---|---|---|---|---|---|---|---|---|');
  for (final (label, s) in runs) {
    b.writeln(
      '| $label | ${s.photos} | ${formatRatio(s.precision)} | '
      '${formatRatio(s.recall)} | ${formatRatio(s.f1)} | '
      '${s.exactMeals}/${s.photos} | ${formatRatio(s.meanFalsePositives)} | '
      '${formatMs(s.meanLatencyMs)} | ${formatMs(s.medianLatencyMs)} | '
      '${s.errors} |',
    );
  }
  return b.toString();
}

/// Plain-text table for the console.
String summaryConsoleTable(List<(String label, EvalSummary summary)> runs) {
  final rows = [
    ['run', 'photos', 'P', 'R', 'F1', 'exact', 'FP/photo', 'mean', 'median'],
    for (final (label, s) in runs)
      [
        label,
        '${s.photos}',
        formatRatio(s.precision),
        formatRatio(s.recall),
        formatRatio(s.f1),
        '${s.exactMeals}/${s.photos}',
        formatRatio(s.meanFalsePositives),
        formatMs(s.meanLatencyMs),
        formatMs(s.medianLatencyMs),
      ],
  ];
  final widths = [
    for (var c = 0; c < rows.first.length; c++)
      rows.map((r) => r[c].length).reduce((a, b) => a > b ? a : b),
  ];
  return [
    for (final row in rows)
      [
        for (var c = 0; c < row.length; c++) row[c].padRight(widths[c]),
      ].join('  '),
  ].join('\n');
}
