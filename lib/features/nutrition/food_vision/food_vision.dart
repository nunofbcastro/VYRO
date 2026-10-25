import 'dart:typed_data';

import '../data/food_database.dart';
import 'portion_estimate.dart';

/// Who identified a food in the photo.
enum VisionSource {
  /// The phone's own multimodal model (Gemini Nano via AICore).
  systemAi,

  /// The bundled dish classifier run over several image regions.
  regionClassifier,

  /// System model plus the offline classifier, merged on device.
  fused,

  /// Added or corrected by the user.
  user,
}

/// Which pass of the analysis a result belongs to.
enum VisionStage {
  /// First usable list from the phone's model, before verification. Its items
  /// are [DetectedFood.pending]; the final result may remove some of them.
  draft,

  /// Verified and merged result. This is what `analyse` returns.
  final_,
}

/// Why the phone's model could not give a usable answer.
enum VisionFailure {
  /// The model is busy or over its quota; trying again later may work.
  busy,

  /// The model is not supported, turned off or still downloading.
  unavailable,

  /// Any other error.
  other;

  /// Maps a platform or model error text to a failure kind (pure).
  static VisionFailure fromError(Object? error) {
    final text = '$error'.toLowerCase();
    if (text.contains('busy') ||
        text.contains('quota') ||
        text.contains('exhaust') ||
        text.contains('too many') ||
        text.contains('occupied')) {
      return busy;
    }
    if (text.contains('unsupported') ||
        text.contains('unavailable') ||
        text.contains('not available') ||
        text.contains('downloadable') ||
        text.contains('downloading') ||
        text.contains('not supported')) {
      return unavailable;
    }
    return other;
  }
}

/// One food found (or added) for the meal being reviewed.
class DetectedFood {
  const DetectedFood({
    required this.label,
    required this.grams,
    required this.source,
    this.food,
    this.confidence,
    this.count,
    this.size,
    this.where,
    this.needsChoice = false,
    this.corroborated = false,
    this.pending = false,
  });

  /// Matched database food; null when nothing matched (needs correction).
  final FoodRef? food;

  /// What the detector called it ("Peito de frango", "Feijoada").
  final String label;

  /// Suggested amount. Always an estimate the user must confirm.
  final double grams;

  /// Detector confidence (0–1) when it provides one.
  final double? confidence;

  /// Pieces counted by the detector (e.g. 2 chicken fillets).
  final int? count;

  /// Relative portion size used to scale the typical grams.
  final PortionSize? size;

  /// Where the model saw it in the photo ("centro do prato"), when given.
  final String? where;

  /// A generic name ("bebida", "sanduíche"): the user must name the food.
  /// Such an item has no database match and contributes nothing to totals.
  final bool needsChoice;
  final VisionSource source;
  final bool corroborated;

  /// True on items of a [VisionStage.draft] result: not verified yet.
  final bool pending;

  DetectedFood copyWith({
    FoodRef? food,
    double? grams,
    VisionSource? source,
    double? confidence,
    int? count,
    PortionSize? size,
    String? where,
    bool? needsChoice,
    bool? corroborated,
    bool? pending,
  }) => DetectedFood(
    label: food?.namePt ?? label,
    grams: grams ?? this.grams,
    source: source ?? this.source,
    food: food ?? this.food,
    confidence: confidence ?? this.confidence,
    count: count ?? this.count,
    size: size ?? this.size,
    where: where ?? this.where,
    needsChoice: needsChoice ?? (food == null ? this.needsChoice : false),
    corroborated: corroborated ?? this.corroborated,
    pending: pending ?? this.pending,
  );

  double? get kcal => food == null ? null : food!.kcal * grams / 100;
  double? get protein => food == null ? null : food!.protein * grams / 100;
  double? get carbs => food == null ? null : food!.carbs * grams / 100;
  double? get fat => food == null ? null : food!.fat * grams / 100;
}

class FoodVisionResult {
  const FoodVisionResult({
    required this.foods,
    required this.source,
    this.dishGuess,
    this.note,
    this.detail,
    this.confirmedEmpty = false,
    this.suggestions = const [],
    this.failure,
    this.stage = VisionStage.final_,
    this.timings = const {},
  });

  /// Foods in the meal totals (when matched). In a draft, pending items.
  final List<DetectedFood> foods;
  final VisionSource source;

  /// Set when the phone's model failed, so the review can explain why.
  final VisionFailure? failure;

  /// Whole-image dish name from the classifier, when available.
  final String? dishGuess;

  /// Why a fallback was used, for display.
  final String? note;

  /// Technical detail for the review screen: the model's raw answer, the
  /// error that caused a fallback, and a `timing:` line when known.
  final String? detail;
  final bool confirmedEmpty;

  /// Additional hypotheses, never included in meal totals until selected.
  final List<DetectedFood> suggestions;

  /// Draft or final (see [VisionStage]).
  final VisionStage stage;

  /// Duration per stage, in the order they ran. Keys: `first`,
  /// `second` (second chance), `verify`, `regions`.
  final Map<String, Duration> timings;

  Set<String> get notes =>
      (note ?? '').split(',').where((s) => s.isNotEmpty).toSet();

  FoodVisionResult copyWith({
    List<DetectedFood>? foods,
    List<DetectedFood>? suggestions,
    VisionStage? stage,
    Map<String, Duration>? timings,
    String? note,
    String? detail,
    VisionFailure? failure,
  }) => FoodVisionResult(
    foods: foods ?? this.foods,
    source: source,
    dishGuess: dishGuess,
    note: note ?? this.note,
    detail: detail ?? this.detail,
    confirmedEmpty: confirmedEmpty,
    suggestions: suggestions ?? this.suggestions,
    failure: failure ?? this.failure,
    stage: stage ?? this.stage,
    timings: timings ?? this.timings,
  );

  FoodVisionResult withNote(
    String? note, {
    String? detail,
    VisionFailure? failure,
  }) => copyWith(note: note, detail: detail, failure: failure);
}

/// One line for "Detalhes da análise", e.g.
/// `timing: first 2.1 s, verify 1.8 s, regions 0.9 s`; null when empty.
String? timingLine(Map<String, Duration> timings) {
  if (timings.isEmpty) return null;
  const labels = {
    'first': 'first',
    'second': 'second chance',
    'verify': 'verify',
    'regions': 'regions',
  };
  final parts = [
    for (final entry in timings.entries)
      '${labels[entry.key] ?? entry.key} '
          '${(entry.value.inMilliseconds / 1000).toStringAsFixed(1)} s',
  ];
  return 'timing: ${parts.join(', ')}';
}

/// Finds the foods in a meal photo. Implementations run on the device.
abstract interface class FoodVisionService {
  Future<FoodVisionResult> analyse(Uint8List imageBytes);
}

abstract interface class MultiPhotoFoodVisionService
    implements FoodVisionService {
  Future<FoodVisionResult> analyseViews(Uint8List primary, Uint8List secondary);
}

/// A service that reports its first usable list before the final result.
/// [onDraft] is called at most once, before [analyseStaged] completes, with a
/// [VisionStage.draft] result whose foods are [DetectedFood.pending].
abstract interface class StagedFoodVisionService implements FoodVisionService {
  Future<FoodVisionResult> analyseStaged(
    Uint8List imageBytes, {
    Uint8List? secondaryImage,
    void Function(FoodVisionResult draft)? onDraft,
  });
}

/// Union of the system model and the offline region classifier.
/// Names from the system model stay first; offline foods it missed are added
/// with their typical portion. Grams always come from the local database.
FoodVisionResult fuseVisionResults(
  FoodVisionResult system,
  FoodVisionResult regions, {
  String? qualityNote,
}) {
  final foods = [...system.foods];
  final seen = <String>{
    for (final f in foods) (f.food?.key ?? f.label.toLowerCase()),
  };
  // System suggestions (duplicate coffees, companions) come first; never in
  // totals. Each suggested food appears once.
  final suggestions = <DetectedFood>[...system.suggestions];
  final suggestionKeys = <String>{
    for (final s in suggestions) (s.food?.key ?? s.label.toLowerCase()),
  };
  var offlineSuggestions = 0;
  for (final extra in regions.foods) {
    final key = extra.food?.key ?? extra.label.toLowerCase();
    if (!seen.add(key)) {
      final i = foods.indexWhere(
        (f) => (f.food?.key ?? f.label.toLowerCase()) == key,
      );
      final prev = foods[i];
      foods[i] = prev.copyWith(corroborated: true);
      continue;
    }
    // Offline foods are hypotheses even when the system confirmed an empty
    // photo: they stay outside the totals until the user adds them.
    if (!suggestionKeys.add(key)) continue;
    suggestions.add(extra);
    offlineSuggestions++;
  }
  final usedSystem = system.foods.isNotEmpty;
  final usedRegions = regions.foods.isNotEmpty;
  final source = usedSystem && usedRegions ? VisionSource.fused : system.source;
  final notes = [
    if (qualityNote != null) qualityNote,
    if (offlineSuggestions > 0) 'fusedOffline',
    if (system.note != null) system.note!,
  ];
  return FoodVisionResult(
    foods: foods.take(10).toList(),
    suggestions: suggestions,
    confirmedEmpty: system.confirmedEmpty,
    failure: system.failure,
    source: source,
    dishGuess: regions.dishGuess ?? system.dishGuess,
    note: notes.isEmpty ? null : notes.join(','),
    timings: {...system.timings, ...regions.timings},
    detail: [
      if (system.detail != null) system.detail!,
      if (regions.dishGuess != null) 'offlineDish=${regions.dishGuess}',
      if (offlineSuggestions > 0) 'offlineSuggestions=$offlineSuggestions',
    ].join('\n'),
  );
}
