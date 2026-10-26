# Architecture and technical decisions

## Stack (verify availability/version before use)
- Flutter/Dart, Riverpod, go_router, Drift + SQLite, Dio, camera.
- Barcodes: ML Kit scanning (native-backed Flutter plugin) or equivalent supported scanner.
- On-device vision: LiteRT/TFLite model embedded or downloaded with consent. Implement `FoodRecognitionService` adapter, loading, pre/post-processing, class mapping and fallback.
- Pose: ML Kit Pose or MediaPipe compatible solution. Start single-frame landmarks + smoothing + squat repetition state machine; instrument results.
- Open Food Facts product API for barcode data only, with documented User-Agent, request limit, cache and attribution/licence review.

## Boundaries
`Presentation -> State/Use cases -> Domain -> Repositories -> Local/Remote adapters`.
- No service calls directly inside UI widgets.
- Inference separate from nutritional calculations and product lookup.
- Nutrient values normalized to per-100g or per-100ml, provenance and units always stored.
- Nutrition calculation: `kcal = kcal_per_100 * quantity / 100` only for matching units, rounding at presentation layer.
- Unknown product nutrients remain unknown; never default to zero.
- Daily targets are estimates, editable, never medical prescriptions.
- Targets have one source: the `VyroProfile` row in `vyro_preferences`
  (`calorieGoal`, `proteinGoal`, `carbsGoal`, `fatGoal`). `targetMode` is
  `automatic` (default) or `manual`. In automatic mode the database rewrites
  the stored targets on every weight save, delete or restore, and on every
  profile save, using the formula in `features/onboarding/domain/nutrition_targets.dart`
  and the latest logged weight (by measurement time; the profile weight when
  nothing is logged). Manual mode keeps the typed values until the user returns
  to automatic. `targetsWeightKg` records the weight the targets were based on.
  The editor is `features/nutrition/nutrition_targets_page.dart` (route
  `/nutrition-targets`); rules and the weight-change outcome are in
  `features/nutrition/domain/nutrition_targets_rules.dart`. Export and import
  carry the mode and values in `userProfile`.

## Local database entities
UserProfile, UserGoals, FoodProduct, FoodEntry, Meal, DailyNutrition, Exercise, WorkoutPlan, WorkoutDay, WorkoutSession, ExerciseSet, BodyMeasurement, AiAnalysisResult, Settings.

Key/value preferences (`vyro_preferences`) also hold the profile, assistant memory, learned food corrections, user recipes and local quality counters. Export, import and delete-all cover them (`AppDatabase.exportAllData` / `clearUserData`).

## Application id
Android `applicationId`/`namespace` and iOS `PRODUCT_BUNDLE_IDENTIFIER` are `com.nunofbcastro.vyro`. The widget App Group is `group.com.nunofbcastro.vyro`.

## Interfaces
```dart
abstract interface class FoodRecognitionService {
  Future<List<FoodCandidate>> recognize(String imagePath);
}

abstract interface class ProductLookupRepository {
  Future<FoodProduct?> findByBarcode(String barcode);
}
```

`FoodCandidate` includes label, score and optional estimate with uncertainty. Avoid representing estimated grams as fact.

## Testing
Repository tests (missing fields and caching), nutrition math, workout planning invariants, repeat counter transitions, Flutter widget tests, happy-path integration tests; physical-device model benchmarks.
