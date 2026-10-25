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
  Stage and timing: `VisionStage` (`draft`, `final_`), `DetectedFood.pending`
  (true only on draft items), `FoodVisionResult.stage` and `timings`
  (`Map<String, Duration>`: `first`, `second`, `verify`, `regions`),
  `timingLine` (the `timing:` line appended to `detail` by the pipeline),
  `copyWith`. `StagedFoodVisionService.analyseStaged(bytes, {secondaryImage,
  onDraft})` is the only way to receive a draft.
- `food_names.dart`: `foodNameCandidates(raw)` (ordered names to try: as
  written, normalised, English → Portuguese, Portuguese singulars), `singularVariants`,
  `englishFoodName` and the `englishFoodNames` map.
- `food_companions.dart`: `mealCompanions(foods, db, {alsoTaken})`, context
  sauces and sides (steak/meat → gravy, cream, mayonnaise, ketchup; pasta →
  cream; fries/potatoes → ketchup, mayonnaise; salad → olive oil), only when the
  database has them, always as suggestions.
- `food_screening.dart`: pure trust rules: `dropNonFood`, `isNonFoodName`,
  `genericKindOf`, `mentionsContainer`, `isDrinkItem`, `decideDraft` (only
  `visible:false` drops; omitted verdict stays uncertain; `where` and drink
  words are reason text, never a gate), `decisionLine` (one diagnostic line per
  item), `normaliseFoodName`.
- `portion_estimate.dart`: `PortionSize` (small 0.6, medium 1, large 1.5),
  `estimatedGrams`, the only place where grams are computed from a food;
  `isWholeDish` (pizza, burger, francesinha, `pratos`) never shrinks below 1.
- `system_food_vision.dart`: `SystemFoodVision` (Gemini Nano via
  `vyro/on_device_llm` → `describeImage`), `buildFoodPhotoPrompt`,
  `buildFoodVerifyPrompt`, `parseFoodVerifyAnswer` (per-index, null when
  omitted), `parseFoodPhotoAnswer` (matches each name through `matchFoodName`
  over `foodNameCandidates`), `applyDrinkSanity`, `SystemFoodVision.analyseStaged`
  (calls `onDraft` once the first usable list exists), and `FoodVisionPipeline`
  with `analyse`, `analyseViews`, `analyseProgressive` and
  `analyseViewsProgressive` (draft then final on one stream; the offline pass
  starts first and runs alongside the system model).
- `region_food_vision.dart`: `RegionFoodVision`, AIY Food V1 dish classifier
  over 26 crops in a persistent worker isolate; labels → foods via
  `vision_labels`; `interpretRegions` (pure, testable).
- `photo_quality.dart`: `PhotoQuality` warnings (too small, dark, bright,
  low detail). Warnings only, never a rejection.
- `lib/features/nutrition/photo_food_page.dart`: review screen (list, totals,
  second angle, region re-analysis, corrections, save, learning counters).
  UI shape: photo → one row of tonal actions (Zona, 2.º ângulo, Receita, Mais
  fotos) → single-row meal chips → summary ("parcial" while lines are unresolved)
  → Falta algum? / Outras hipóteses chip rows → cards (name + one subtitle line;
  source, kcal/100 g, `where` and clarify live in the card's Detalhes) → CTA counts
  savable lines and "N por escolher" leads to the first unresolved card.
  Progressive: `analyseProgressive` / `analyseViewsProgressive` (draft lines show
  "a confirmar…", the final result replaces them). Several gallery photos: "São da
  mesma refeição?" then a queue ("Foto N de M", next one analysed in background, at
  most two photos in memory) or a two-view merge.
- `photo/review_model.dart`: `ReviewItem`, `ReviewShot` (one photo or two views),
  `mergeReviewItems` (draft → final, collapsing removals), `countReview`.
- `widgets/photo_review_widgets.dart`: scan overlay, action row, summary, food
  card, chip row, collapse animation.
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
   Portuguese names, JSON only; do NOT restore "fewer items is better" or
   "1 to 4 items": that cut true positives on device) or
   `buildFoodVerifyPrompt` (yes/no per item, never add foods; visible if
   partly visible, false only when confident it is absent), and add missing
   aliases in the TSV so free names match. Do not paste the whole
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
  *suggestions* (outside the totals) until the user accepts them. Even a
  confirmed empty review shows them as "Outras hipóteses"; they never enter
  the main list.
- Empty first answer: `{"items":[]}` is not yet a confirmed empty photo. The
  same photo gets one second chance with `buildFoodSecondChancePrompt()` (food
  may be in a pan, pot, tray, box, packaging or partly eaten; name the main
  foods and drinks). Only an empty second answer is `confirmedEmpty`; an
  invalid second answer throws `invalid_foods` (system branch fails, offline
  kept). `detail` records "first: empty → second chance: ...".
- Verification, not review: after the first answer the same photo is checked
  once with `buildFoodVerifyPrompt`, which lists the kept draft items by index
  and asks for `{"checks":[{"i":0,"visible":true}]}`. It never adds or renames
  foods. Only an explicit `visible: false` drops an item. An omitted index or
  non-boolean verdict keeps the item in the main list as uncertain ("verify
  omitted, uncertain"; the review shows "Hipótese a confirmar"). An answer that
  is not valid JSON or has no `checks` list keeps the whole first list ("verify
  unparsed"). If verification rejects EVERY item, all stay as uncertain
  ("verify rejected all — kept as uncertain"): a rejected whole draft is more
  likely a model error than an empty plate. Verification never produces a
  confirmed empty meal. Only an explicit `false` drops an item, and only while
  at least one item survives.
- Trust rules (`food_screening.dart`, pure, see `docs/FOOD_VISION.md`):
  1. Non-food names (towel, napkin, plate alone, cup alone, table, menu...) are
     dropped before verification: `dropped non-food:` plus a per-item line.
  2. Generic names (bebida, comida, sanduíche, molho, carne, drink, food...) stay
     in the review with `needsChoice`, no database match, no nutrients. The
     card asks "Que bebida?" and opens the picker pre-filled with the name.
  3. Drinks are treated like food. `where` and container words are evidence in
     the reason line ("container in where" / "no container in where"), never a
     gate. Items without `where` stay in the main list ("no where").
  4. Only the one-cup-one-drink rule sends an item to suggestions: a second
     coffee of the other kind is `duplicate coffee`, outside totals.
  Rules 1, 2 and 4 also apply when verification is unparsed.
- Trade-off (recall over precision): v0.6.3 sent items without `where`, drinks
  without container words and unverified items to suggestions. On device the
  small model often omits `where`, so those gates removed true positives (beer,
  burger). They were removed. Precision now rests on explicit `visible: false`,
  the non-food list and the one-cup rule. Expect more false positives in review.
- Diagnostics: "Detalhes da análise" has one line per item:
  `name → kept|dropped|suggestion (reason)`. Users can paste it for triage.
- Failure UX: `VisionFailure.fromError` maps busy/quota to `busy` and
  unsupported/unavailable/downloadable to `unavailable`. Any empty review shows
  the card with "Tentar de novo" (re-runs the same photo). A confirmed empty
  photo (both looks empty) uses `photoEmptyConfirmed` ("A IA do telemóvel não
  encontrou comida nesta foto. Tenta outra vez, analisa uma zona ou adiciona
  manualmente."); other empty reviews use `photoNothingFound`. A "only non-food
  items" answer is not confirmed empty.
- Names before matching: the model's name is tried as written, then
  normalised, then an English translation (`englishFoodNames`, e.g. beer →
  cerveja, steak → bife, water → água mineral), then Portuguese singulars
  (ovos → ovo, batatas fritas → batata frita). The first candidate the
  database matches wins, so the original match is never replaced. English
  generic words ("beverage", "dish", "snack") are generic names: "Que bebida?".
  The prompts ask for European Portuguese names and "where" text
  ("centro do prato"); English answers do not match the database.
- Progressive results: `analyseProgressive` emits (a) a `VisionStage.draft`
  result once the first usable list exists (items `pending`; offline
  suggestions only if the offline pass has already finished), then (b) the
  `VisionStage.final_` result, which is what `analyse` returns. Verification can
  only remove draft items, so the final items are the draft items minus the
  removed ones. No system model: only the final event. Errors arrive as stream
  errors. `detail` ends with a `timing:` line, e.g.
  `timing: first 2.1 s, verify 1.8 s, regions 0.9 s`.
- Companion suggestions (`mealCompanions`): sauces and sides implied by the
  verified names go to `suggestions`, never to totals and never asked of the
  model. Keys already in the main list or in the duplicate coffees are not repeated.
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

- `test/vision_resilience_test.dart`: piece counts, confirmed empty review
  (keeps offline suggestions), independent failures, offline-only suggestions,
  region coordinates, quality.
- `test/food_screening_test.dart`: non-food list, generic names, where as
  evidence, verdict rules (one false drops only that item; all false kept as
  uncertain), `bife` + "na frigideira" not non-food, whole-dish portions,
  failure mapping, pipeline failure.
- v0.6.5 pan/second-chance regressions in `test/system_food_vision_test.dart`:
  all-false kept as uncertain; empty first answer + second chance with bife and
  ovo; both empty = confirmed empty; invalid second answer is not confirmed.
  `test/photo_food_page_test.dart`: confirmed empty shows the retry card and
  "Outras hipóteses", and "Tentar de novo" re-runs the photo.
- Regression tests (v0.6.4 recall fix) in `test/system_food_vision_test.dart`:
  burger + beer with no `where` both kept; prose `where` kept; omitted verdict
  kept as uncertain; explicit `visible:false` dropped; prompts never contain
  "Fewer items" or "1 to 4".
- `test/food_names_test.dart`: plural and English candidates (ovos → egg row),
  singular variants, generic "beverage"/"dish", the cider/Somersby alias,
  still vs sparkling water, prompt wording, companion suggestions (steak, pasta,
  fries, salad, dedupe, no companions for unrelated foods).
- `test/food_progressive_test.dart`: draft then final with the same items when
  verify agrees; removals appear only in the final; `analyse` equals the last
  stream event; `timing:` line in detail; no draft without the system model;
  steak sauce suggestions outside totals.
- `test/food_database_test.dart`, `test/system_food_vision_test.dart` (croissant
  and pasta cases), `test/region_food_vision_test.dart`,
  `test/photo_food_page_test.dart` (generic prompt, failure card, retry).
- `test/food_model_probe_test.dart` runs the real model on a host image when
  `VYRO_FOOD_IMAGE` is set.
- Tests use simulated model answers and fakes. They do not measure accuracy on
  real photos; that has not been done yet.
