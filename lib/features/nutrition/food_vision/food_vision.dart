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
    this.corroborated = false,
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
  final VisionSource source;
  final bool corroborated;

  DetectedFood copyWith({
    FoodRef? food,
    double? grams,
    VisionSource? source,
    double? confidence,
    int? count,
    PortionSize? size,
    bool? corroborated,
  }) => DetectedFood(
    label: food?.namePt ?? label,
    grams: grams ?? this.grams,
    source: source ?? this.source,
    food: food ?? this.food,
    confidence: confidence ?? this.confidence,
    count: count ?? this.count,
    size: size ?? this.size,
    corroborated: corroborated ?? this.corroborated,
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
  });

  final List<DetectedFood> foods;
  final VisionSource source;

  /// Whole-image dish name from the classifier, when available.
  final String? dishGuess;

  /// Why a fallback was used, for display.
  final String? note;

  /// Technical detail for the review screen: the model's raw answer, or the
  /// error that caused the fallback.
  final String? detail;
  final bool confirmedEmpty;

  /// Additional hypotheses, never included in meal totals until selected.
  final List<DetectedFood> suggestions;
  Set<String> get notes =>
      (note ?? '').split(',').where((s) => s.isNotEmpty).toSet();

  FoodVisionResult withNote(String? note, {String? detail}) => FoodVisionResult(
    foods: foods,
    source: source,
    dishGuess: dishGuess,
    note: note ?? this.note,
    detail: detail ?? this.detail,
    confirmedEmpty: confirmedEmpty,
    suggestions: suggestions,
  );
}

/// Finds the foods in a meal photo. Implementations run on the device.
abstract interface class FoodVisionService {
  Future<FoodVisionResult> analyse(Uint8List imageBytes);
}

abstract interface class MultiPhotoFoodVisionService
    implements FoodVisionService {
  Future<FoodVisionResult> analyseViews(Uint8List primary, Uint8List secondary);
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
  final suggestions = <DetectedFood>[];
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
    if (!system.confirmedEmpty) suggestions.add(extra);
  }
  final usedSystem = system.foods.isNotEmpty;
  final usedRegions = regions.foods.isNotEmpty;
  final source = usedSystem && usedRegions ? VisionSource.fused : system.source;
  final notes = [
    if (qualityNote != null) qualityNote,
    if (suggestions.isNotEmpty) 'fusedOffline',
    if (system.note != null) system.note!,
  ];
  return FoodVisionResult(
    foods: foods.take(10).toList(),
    suggestions: suggestions,
    confirmedEmpty: system.confirmedEmpty,
    source: source,
    dishGuess: regions.dishGuess ?? system.dishGuess,
    note: notes.isEmpty ? null : notes.join(','),
    detail: [
      if (system.detail != null) system.detail!,
      if (regions.dishGuess != null) 'offlineDish=${regions.dishGuess}',
      if (suggestions.isNotEmpty) 'offlineSuggestions=${suggestions.length}',
    ].join('\n'),
  );
}
