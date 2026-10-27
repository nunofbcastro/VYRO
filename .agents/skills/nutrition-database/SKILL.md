---
name: nutrition-database
description: How VYRO's offline nutrition database (USDA, Ciqual, TACO) was built and how to update calories, add foods, aliases, portions and image labels
---

# Offline nutrition database

VYRO never invents calories. Every food in the app comes from
`assets/nutrition/foods.json`, generated from official composition tables by
`tool/nutrition/build_food_db.py`. Calories for a portion are always
`grams × kcal_per_100g / 100` (same for protein, carbs, fat). Read
`docs/NUTRITION_DATA.md` for sources, licences and conventions.

## How it was built

1. A curated list, `tool/nutrition/foods_pt.tsv`, has one row per VYRO food:
   `key, name_pt, name_en, source, source_ref, region, category, portion_g,
   portion_pt, portion_en, aliases, vision_labels, portion_units` (lists
   separated by `|`). `portion_units` is optional (87 of 193 rows): the number
   of pieces that `portion_g` represents (3 sardines = 120 g ⇒ `3`). Leave it
   empty for foods that are not counted in pieces (rice, soups, sauces); the app
   then ignores piece counts for that food. The build copies it to
   `portionUnits` in `foods.json`; it is read by `estimatedGrams` in
   `portion_estimate.dart`.
2. For each row the script reads the values per 100 g from the chosen table:
   - `usda`: USDA FoodData Central SR Legacy 2018-04 (CC0). `source_ref` = the
     exact `description` in `food.csv`. Nutrients 1008 kcal, 1003 protein,
     1005 carbs, 1004 fat, 1079 fibre.
   - `ciqual`: Ciqual 2025, ANSES (etalab-2.0). `source_ref` = `alim_code`.
     The xlsx is read by `xlsx_reader.py` (stdlib only).
   - `taco`: TACO 4.ª ed., NEPA/UNICAMP (citation required). `source_ref` = the
     food number in Table 1. The PDF is parsed by `taco_parser.py` (needs
     `pypdf` at build time), which rejects rows failing kJ/kcal or Atwater checks.
3. It writes `foods.json` (schema 2) with the values, `source`, `sourceRef`,
   `sourceLabel` (original name in the table), `region`, the licence block and
   the TSV's SHA-256. Missing energy/macros or unknown refs fail the build.
4. The app loads it with `FoodDatabase.load()`
   (`lib/features/nutrition/data/food_database.dart`): `byKey`, `match(name)`
   (no guessing), `search(text)` (whole-phrase hits first) and
   `forVisionLabel(label)`. Saved diary entries use `FoodRef.sourceKey`
   (`usda_171477`, `ciqual_26024`, `taco_561`).

## Workflow: update or add a food

1. Find the food in the source table:
   - USDA: search `build/usda/.../food.csv` for the exact description (prefer
     cooked/prepared forms that match how people eat it).
   - Ciqual: search the xlsx by French name (`alim_nom_fr`), copy `alim_code`.
   - TACO: find the number in the PDF's Table 1.
   Prefer Ciqual for Portuguese/European foods, TACO for Brazilian ones, USDA
   for generic ones. Do not use INSA/PortFIR data until its licence allows
   redistribution (see docs).
2. Add or edit the TSV row: unique snake_case `key`; PT-PT `name_pt`;
   realistic `portion_g` with a clear `portion_pt` ("1 bife", "1 concha");
   `portion_units` only when the portion really is N pieces (check that
   `portion_g ÷ portion_units` is one piece's weight);
   aliases people would type or an LLM would answer (PT and EN, no aliases
   that belong to another food: `alface` is not `salada`); `vision_labels`
   only with exact names from `assets/models/aiy_food_v1_labels.csv`.
   Whole dishes vs. slices (pizza): see "Whole dishes and slices" below.
   Alias matching is by words (`FoodDatabase.match`): a query matches a
   phrase when every word of the shorter one is in the other. So a multi-word
   alias with a generic word captures that word: "mostarda de mesa" made the
   table name "Mesa" match mustard, which broke a non-food test. Keep aliases
   specific and run `test/system_food_vision_test.dart` after adding one.
   Matching uses word sets after accent removal, and `de/do/da/com/sem/e/o/a/em`
   and one-letter words are dropped. So "fatia de pizza" and "fatia pizza" are
   the same alias, and "creme de leite" equals "leite-creme". The test "no name
   or alias maps to two different foods" fails on any such clash. A bare
   "refrigerante" must not match: do not add "refrigerante de X" aliases, since
   they contain the word. Singular and plural are different words ("fatia" vs
   "fatias", "pizza slice" vs "pizza slices"): add both.
3. Rebuild and verify:
   ```bash
   python -I tool/nutrition/build_food_db.py
   python -I tool/nutrition/build_food_db.py --check
   flutter test test/food_database_test.dart
   ```
   TACO rows need pypdf. `-I` ignores `PYTHONPATH`, so install pypdf into a
   scratch folder and add it to `sys.path` in a wrapper that runs the builder
   with `runpy` (the build itself is unchanged). The eval builder
   (`tool/eval_data/build_nutrition5k.py`) needs Pillow, which the eval venv has.
4. Sanity-check the new values against the source (kcal plausible, Atwater
   test passes) and commit the TSV **and** the regenerated `foods.json`
   together. Never edit `foods.json` by hand.
5. Updating a source edition (e.g. a new Ciqual release): change the URL and
   file name in `SOURCES`, delete the cached file in `build/`, rebuild, review
   the diff of `foods.json` value by value, and update the citation in
   `docs/NUTRITION_DATA.md`.

## Whole dishes and slices

A row is either one **piece of a dish** or **the whole dish**, never both
under the same name:

- Pizza slices (`pizza_cheese`, `pizza_pepperoni`): `portion_g` 110 = one
  slice of a large pizza (8 slices ≈ 880 g). Names "Fatia de pizza de …",
  aliases "fatia de pizza …", "pizza slice". Count = slices.
- Whole individual pizzas (`pizza_cheese_whole`, `pizza_pepperoni_whole`):
  `portion_g` 350 = one individual pizza (about 3 large-pizza slices, 300–400 g
  range), `portion_units` 1. The bare names ("pizza", "pizza inteira",
  "pizza individual", "pizza de queijo", "pizza de pepperoni", "pepperoni")
  and the photo labels of pizzas belong to these rows, because a bare
  "pizza" in a photo is usually one whole pizza. Both rows reuse the source
  reference of the slice row, so their `sourceKey` is the same; the grams
  make the difference.
- `cheeseburger_whole` (`hambúrguer no pão`) is a whole dish with
  `portion_units` 1, so "2 hambúrgueres no pão" counts two (300 g). English
  "hamburger", "burger", "cheeseburger", "big mac" and the AIY labels
  Hamburger/Cheeseburger belong to this row (the photo model answers in
  English). The bare Portuguese "hambúrguer", "patty" and "beef patty"
  stay on the raw beef patty row (`beef_ground_patty`).
- Chicken: `chicken_fried_patty` (USDA FDC 170718, breaded fried boneless
  pieces, 100 g) and `chicken_sandwich` (USDA FDC 170295, fast-food chicken
  fillet sandwich, 150 g, `pratos`). Bare "chicken" and "grilled chicken" stay
  on `chicken_breast_roasted`; the breaded aliases must not contain
  "chicken fillet" (taken by the grilled row). The vision rule that turns a bare
  "chicken" into the patty or sandwich is in `burger_rules.dart`.
- Francesinha is not in the database (no suitable source row yet).

`estimatedGrams` (`lib/features/nutrition/food_vision/portion_estimate.dart`):
a whole dish with `portion_units` 1 is one item, so its size does not scale
it (`count` is the amount). Slices are never treated as whole dishes, so a
slice still scales with size. Model output `{"name":"pizza","count":1,
"size":"large"}` gives 350 g; `{"name":"fatia de pizza","count":2}` gives
220 g.

## User recipes (not in the database)

Recipes created in the app (`LocalRecipe`, `lib/core/ai/local_intelligence_repository.dart`)
are stored in preferences (`recipes_v1`), never in `foods.json`. Nutrients per
100 g = Σ(ingredient nutrient × ingredient grams) ÷ **final cooked weight**
(`yieldGrams`). Ingredients snapshot the per-100 g values of the database food
and must be entered in the state they were weighed in. `validateLocalData`
checks imports; limits are 100 recipes and 100 ingredients each.

## Rules

- Portions are VYRO estimates; the user always confirms grams.
- Keep attribution: sources block in `foods.json`, `nutritionSourcesNote` in
  the UI, and the docs table.
- Adding a new source: write `load_<source>(refs) -> {ref: {id, label, kcal,
  protein, carbs, fat, fiber}}`, register it in `LOADERS` and `SOURCES` with
  its licence, then document it.
- Do not claim photo calories are exact; nutrients come from the table, the
  amount is the user's estimate.
