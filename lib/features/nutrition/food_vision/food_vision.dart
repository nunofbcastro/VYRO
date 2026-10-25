import 'dart:typed_data';

import '../data/food_database.dart';

/// Who identified a food in the photo.
enum VisionSource {
  /// The phone's own multimodal model (Gemini Nano via AICore).
  systemAi,

  /// The bundled dish classifier run over several image regions.
  regionClassifier,

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
  final VisionSource source;

  DetectedFood copyWith({FoodRef? food, double? grams, VisionSource? source}) =>
      DetectedFood(
        label: food?.namePt ?? label,
        grams: grams ?? this.grams,
        source: source ?? this.source,
        food: food ?? this.food,
        confidence: confidence,
        count: count,
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
  });

  final List<DetectedFood> foods;
  final VisionSource source;

  /// Whole-image dish name from the classifier, when available.
  final String? dishGuess;

  /// Why a fallback was used, for display.
  final String? note;
}

/// Finds the foods in a meal photo. Implementations run on the device.
abstract interface class FoodVisionService {
  Future<FoodVisionResult> analyse(Uint8List imageBytes);
}
