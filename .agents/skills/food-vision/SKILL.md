---
name: food-vision
description: How VYRO recognises several foods in a meal photo on-device (Gemini Nano multimodal + offline region classifier) and how to improve it or plug in a real detection model
---

# Food photo recognition

The photo flow suggests foods and grams; nutrients come from the offline
database (skill `nutrition-database`) and the user confirms everything. No
cloud, no paid API, the photo stays in memory. Full details:
`docs/FOOD_VISION.md`.

## Pieces

- `lib/features/nutrition/food_vision/food_vision.dart`: `FoodVisionService`
  interface, `DetectedFood` (food, label, grams, confidence, count, source;
  kcal/macros = grams × per-100 g), `FoodVisionResult`.
- `system_food_vision.dart`: `SystemFoodVision` (Gemini Nano via
  `vyro/on_device_llm` → `describeImage`), `buildFoodPhotoPrompt`,
  `parseFoodPhotoAnswer`, and `FoodVisionPipeline` (system model when
  available, region classifier otherwise or on failure).
- `region_food_vision.dart`: `RegionFoodVision`, AIY Food V1 dish classifier
  over 26 crops in an isolate; labels → foods via `vision_labels`.
- `android/.../llm/OnDeviceLlmChannel.kt`: `describeImage` with
  `generateContentRequest(ImagePart(bytes), TextPart(prompt))`.
- `lib/features/nutrition/photo_food_page.dart`: review UI;
  `widgets/food_picker_sheet.dart`: reusable database picker.

## Workflow: improve recognition

1. Reproduce with a real photo on the host:
   `VYRO_FOOD_IMAGE=path flutter test test/food_model_probe_test.dart`
   (prints the dish guess and the foods with confidence, grams, kcal).
2. Offline classifier misses or mislabels a food: check which AIY labels it
   produces, then add exact label names to that food's `vision_labels` in
   `tool/nutrition/foods_pt.tsv` (or remove a misleading one), rebuild the
   database, re-run the probe on several photos (not just one). Tune the
   thresholds in `RegionFoodVision` only with evidence from multiple images.
3. System model answers badly: adjust `buildFoodPhotoPrompt` (keep it short,
   JSON only, names from the database list, portion references) and extend
   `parseFoodPhotoAnswer` tests in `test/food_database_test.dart`.
4. Run `dart format`, `flutter analyze`, `flutter test`.

## Plugging in a real multi-food model

Implement `FoodVisionService` for a licensed TFLite detection/segmentation
model (verify input shape, dtype, normalisation, output decoding, NMS), map
its classes to database keys, return `DetectedFood` with confidence and
estimated grams, and wire it into `FoodVisionPipeline`. Document model,
labels, licence, size and speed in `assets/models/NOTICE.md` and
`docs/FOOD_VISION.md`. Never bundle a model whose licence or classes you
cannot verify, and label any demo model clearly.

## Rules

- Recognition is probabilistic: show the source (phone AI / offline), allow
  changing, removing and adding foods and editing grams before saving.
- Unmatched names stay visible without nutrients until the user picks a food;
  they are never saved with invented values.
- Do not retain or transmit photos.
