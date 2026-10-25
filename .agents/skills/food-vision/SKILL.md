---
name: food-vision
description: How VYRO recognises several foods in one or two meal photos on-device (Gemini Nano multimodal + offline AIY region classifier), how the review, portions, quality warnings, region re-analysis and correction learning work, and how to improve it or plug in a real detection model
---

# Food photo recognition

The photo flow suggests foods and portions; nutrients come from the offline
database (skill `nutrition-database`) and the user confirms everything. No
cloud, no paid API, the photo stays in memory. Full details:
`docs/FOOD_VISION.md`.

## Pieces

- `lib/features/nutrition/food_vision/food_vision.dart`: `FoodVisionService`
  and `MultiPhotoFoodVisionService` interfaces; `DetectedFood` (label, food,
  grams, count, size, `where`, `needsChoice`, `VisionSource`, `corroborated`,
  `confidence` kept in the model but not shown); `FoodVisionResult` (foods,
  suggestions, typed `confirmedEmpty`, `failure` (`VisionFailure`: busy,
  unavailable, other), `notes` set, `detail` for diagnostics); `fuseVisionResults`.
- `food_screening.dart`: pure trust rules: `dropNonFood`, `isNonFoodName`,
  `genericKindOf`, `mentionsContainer`, `isDrinkItem`, `decideDraft` (verdicts,
  missing where, drinks without container → suggestions), `normaliseFoodName`.
- `portion_estimate.dart`: `PortionSize` (small 0.6, medium 1, large 1.5),
  `estimatedGrams`, the only place where grams are computed from a food;
  `isWholeDish` (pizza, burger, francesinha, `pratos`) never shrinks below 1.
- `system_food_vision.dart`: `SystemFoodVision` (Gemini Nano via
  `vyro/on_device_llm` → `describeImage`), `buildFoodPhotoPrompt`,
  `buildFoodVerifyPrompt`, `parseFoodVerifyAnswer` (per-index, null when
  omitted), `parseFoodPhotoAnswer`, `applyDrinkSanity`, and `FoodVisionPipeline`.
- `region_food_vision.dart`: `RegionFoodVision`, AIY Food V1 dish classifier
  over 26 crops in a persistent worker isolate; labels → foods via
  `vision_labels`; `interpretRegions` (pure, testable).
- `photo_quality.dart`: `PhotoQuality` warnings (too small, dark, bright,
  low detail). Warnings only, never a rejection.
- `lib/features/nutrition/photo_food_page.dart`: review screen (list, totals,
  second angle, region re-analysis, corrections, save, learning counters).
- `widgets/photo_region_sheet.dart`: pick a crop of the photo to re-analyse.
- `widgets/food_picker_sheet.dart`: database picker; shows learned suggestions
  first when the user changes a food.
- `lib/core/ai/local_intelligence_repository.dart`: correction learning
  (`food_corrections_v1`) and photo review counters (`quality_metrics_v1`).
- `android/.../llm/OnDeviceLlmChannel.kt`: `describeImage` with
  `generateContentRequest(ImagePart(...), TextPart(prompt))`, temperature 0.1,
  one candidate; optional second image.
- `ios/Runner/AppDelegate.swift`: no `describeImage`; iOS always uses the
  offline classifier for photos.

## Workflow: improve recognition

1. Reproduce with a real photo on the host:
   `VYRO_FOOD_IMAGE=path flutter test test/food_model_probe_test.dart`
   (prints the dish guess and the foods with grams and kcal).
2. Offline classifier misses or mislabels a food: check which AIY labels it
   produces, then add exact label names to that food's `vision_labels` in
   `tool/nutrition/foods_pt.tsv` (or remove a misleading one), rebuild the
   database, re-run the probe on several photos (not just one). Tune the
   thresholds in `RegionFoodVision` only with evidence from multiple images.
3. Portion looks wrong: check `portion_g` and `portion_units` for that row
   (see `nutrition-database`). Piece counts scale `portion_g` only when
   `portion_units` is set; otherwise the count is ignored.
4. System model answers badly: open "Detalhes da análise" on the review
   screen to read the raw answers (or the error). Adjust `buildFoodPhotoPrompt`
   (no category checklist: it makes the small model fill every slot; keep
   Portuguese names, JSON only) or `buildFoodVerifyPrompt` (yes/no per item,
   never add foods), and add missing aliases in the TSV so free names match. Do not paste the whole
   database into the prompt: it biases the small model. Extend
   `test/system_food_vision_test.dart` and `test/food_database_test.dart`.
5. Run `dart format`, `flutter analyze`, `flutter test`.

## Rules

- Recognition is probabilistic: show the source (phone AI, offline, both),
  allow changing, removing and adding foods and editing grams before saving.
- Grams are estimates: typical portion of the matched food × pieces (only if
  `portion_units` is set) × size factor, clamped to 5–1500 g. A model-provided
  `grams` is used only for unmatched names. Never describe grams as measured.
- Typed results, not text parsing: decisions use `confirmedEmpty`, `notes` and
  `VisionSource`. `detail` is for the user to read, never for logic.
- Independent branches: system and offline run independently; one failure keeps
  the other result (note `systemFailed`). Both failing shows
  `photoModelError`. iOS `MissingPluginException` is not shown as a failure.
- Conflicts and hypotheses: offline foods the system did not name are
  *suggestions* (outside the totals) until the user accepts them. A confirmed
  empty review never brings offline foods back.
- Verification, not review: after the first answer the same photo is checked
  once with `buildFoodVerifyPrompt`, which lists the kept draft items by index
  and asks for `{"checks":[{"i":0,"visible":true}]}`. It never adds or renames
  foods. `visible: false` drops an item; an omitted index or non-boolean verdict
  sends it to suggestions ("verify: incomplete"). An answer that is not valid
  JSON or has no `checks` list keeps the first list ("verify: unparsed").
  All items explicitly rejected is a confirmed empty meal.
- Trust rules (`food_screening.dart`, pure, see `docs/FOOD_VISION.md`), in order:
  1. Non-food names (towel, napkin, plate alone, cup alone, table, menu...) are
     dropped before verification and listed as `dropped non-food:` in detail.
  2. Generic names (bebida, comida, sanduíche, molho, carne, drink, food...) stay
     in the review with `needsChoice`, no database match, no nutrients. The
     card asks "Que bebida?" and opens the picker pre-filled with the name.
  3. A drink (category `bebidas` or drink words) stays only when its `where`
     names a container (copo, chávena, caneca, garrafa, lata, taça, jarro, cup,
     glass, mug, bottle, can); otherwise it goes to suggestions.
  4. An item with no `where` goes to suggestions (generic names excepted).
  Rules 1, 2, 3 and 4 also apply when verification is unparsed.
- Failure UX: `VisionFailure.fromError` maps busy/quota to `busy` and
  unsupported/unavailable/downloadable to `unavailable`. An empty review that is
  not a confirmed empty meal shows a card with the reason and "Tentar de novo"
  (re-runs the same photo). A "only non-food items" answer is not confirmed empty.
- Sanity rules after verification (`applyDrinkSanity`, pure Dart): one cup is
  one drink. If an espresso-type and a coffee-with-milk-type are both listed,
  only the first one listed is kept. Count only applies to foods with
  `portion_units`; others count as 1.
- Second photo: the system model receives both views; the offline classifier
  analyses each view and fuses them (`secondViewOffline`). Counts are never
  summed across views.
- Region re-analysis: the user selects a crop of the first photo; the crop is
  analysed with the same pipeline and only foods matched in the database are
  offered, with the "Hipótese a confirmar" label.
- Correction-based ranking: when a user changes an offline or system suggestion,
  the (original label → chosen food) pair is stored locally (counts only, no
  photo). Future picker results for the same label show the top 4 learned
  foods first. The user can turn learning off or clear it; it never confirms a
  food by itself.
- Quality warnings: `photoTooSmall` (shortest side < 96 px), `photoTooDark`,
  `photoTooBright`, `photoTooBlurry` (global Laplacian variance on a 128 px
  sample, a heuristic). They appear as notices; the user decides.
- Confidence is not shown as a percentage. The UI labels offline and uncertain
  items as "Hipótese a confirmar"; the stored peak value is not calibrated.
- Unmatched names stay visible without nutrients until the user picks a food;
  they are never saved with invented values.
- Do not retain or transmit photos. Temporary files are deleted after reading.

## Plugging in a real multi-food model

Implement `FoodVisionService` for a licensed TFLite detection/segmentation
model (verify input shape, dtype, normalisation, output decoding, NMS), map
its classes to database keys, return `DetectedFood` with confidence, and
wire it into `FoodVisionPipeline`. Document model, labels, licence, size and
speed in `assets/models/NOTICE.md` and `docs/FOOD_VISION.md`. Never bundle a
model whose licence or classes you cannot verify, and label any demo model
clearly. Any new source must go through `fuseVisionResults` with its own
`VisionSource` and provenance, and must be calibrated before showing
percentages.

## Testing

- `test/vision_resilience_test.dart`: piece counts, confirmed empty review,
  independent failures, offline-only suggestions, region coordinates, quality.
- `test/food_screening_test.dart`: non-food list, generic names, container
  rule, verdict rules, whole-dish portions, failure mapping, pipeline failure.
- `test/food_database_test.dart`, `test/system_food_vision_test.dart` (croissant
  and pasta cases), `test/region_food_vision_test.dart`,
  `test/photo_food_page_test.dart` (generic prompt, failure card, retry).
- `test/food_model_probe_test.dart` runs the real model on a host image when
  `VYRO_FOOD_IMAGE` is set.
- Tests use simulated model answers and fakes. They do not measure accuracy on
  real photos; that has not been done yet.
