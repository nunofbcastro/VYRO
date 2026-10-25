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
   portion_pt, portion_en, aliases, vision_labels` (lists separated by `|`).
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
   aliases people would type or an LLM would answer (PT and EN, no aliases
   that belong to another food: `alface` is not `salada`); `vision_labels`
   only with exact names from `assets/models/aiy_food_v1_labels.csv`.
3. Rebuild and verify:
   ```bash
   python -I tool/nutrition/build_food_db.py
   python -I tool/nutrition/build_food_db.py --check
   flutter test test/food_database_test.dart
   ```
   On Windows without pypdf: install it in a separate folder and point
   `PYTHONPATH` at it (TACO rows need it).
4. Sanity-check the new values against the source (kcal plausible, Atwater
   test passes) and commit the TSV **and** the regenerated `foods.json`
   together. Never edit `foods.json` by hand.
5. Updating a source edition (e.g. a new Ciqual release): change the URL and
   file name in `SOURCES`, delete the cached file in `build/`, rebuild, review
   the diff of `foods.json` value by value, and update the citation in
   `docs/NUTRITION_DATA.md`.

## Rules

- Portions are VYRO estimates; the user always confirms grams.
- Keep attribution: sources block in `foods.json`, `nutritionSourcesNote` in
  the UI, and the docs table.
- Adding a new source: write `load_<source>(refs) -> {ref: {id, label, kcal,
  protein, carbs, fat, fiber}}`, register it in `LOADERS` and `SOURCES` with
  its licence, then document it.
- Do not claim photo calories are exact; nutrients come from the table, the
  amount is the user's estimate.
