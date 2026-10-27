# Public food-photo benchmarks (dev-time, not shipped)

Only this README is committed. Everything else under `eval/datasets/` is downloaded data
and is gitignored (see the `eval/datasets/*` rules in the root `.gitignore`). The scripts
and mapping files live in `tool/eval_data/` and are committed.

The VYRO app never downloads these datasets. They are used only by the offline eval harness.

## Nutrition5k subset (in use)

- **Source:** Nutrition5k, Google Research. Metadata and overhead RGB images are read from
  `https://storage.googleapis.com/nutrition5k_dataset/nutrition5k_dataset/` over HTTPS.
  The dataset README is at
  <https://github.com/google-research-datasets/Nutrition5k>.
- **Licence:** CC BY 4.0. Keep the attribution below with any published result.
- **Citation:** Thames, Q., Karpur, A., Norris, W., Xia, F., Panait, L., Weyand, T., Sim, J.
  "Nutrition5k: Towards Automatic Nutritional Understanding of Generic Food".
  CVPR 2021, pp. 8903–8911. <https://arxiv.org/abs/2103.03375>
- **Only the needed files are fetched:** the two dish CSVs, the ingredients CSV, and
  `imagery/realsense_overhead/<dish_id>/rgb.png` for the selected dishes. The 181 GB bucket
  is never mirrored.

### What is in the subset

| Item | Value |
|---|---|
| Dishes parsed (after dropping ingredients with no name or non-positive grams) | 5,006 |
| Selected dishes (stratified by filtered ingredient count, seed `20260415`) | 150 (50 each: 1–2, 3–4, 5+) |
| Dishes with an overhead `rgb.png` among those checked | all 150 selected (HEAD checks: 96, 128, 64) |
| Source PNG total (not kept on disk) | ~64 MB |
| JPEG photos (`photos/<dish_id>.jpg`, quality 90) | 150 files, 7.6 MB total |

Mapping coverage (from `eval/datasets/nutrition5k/mapping_stats.json`, rebuilt against the current
`assets/nutrition/foods.json`, 137 distinct names):

- Items mapped to a VYRO key: **578 of 913 (63.3%)**.
- Grams mapped to a VYRO key: **27,238.3 of 34,047 g (80.0%)**.
- The rest are kept as `key: null, optional: true`. They are not scored.

### Refresh after foods change

When another change adds or renames foods, or edits `nutrition5k_map.json`, run:

```powershell
.	ool\evalefresh_labels.ps1
```

It rebuilds `nutrition5k/labels.json` from the cache with `--no-download` (Pillow from the
`n5k-venv` in `%TEMP%` if present), writes the train and holdout labels for the same files
(`tool/eval/split_labels.py`, split stored in `nutrition5k/split.json`), then runs
`test/eval_labels_test.dart` to check every key. Photos are never moved between train and holdout.

### Rebuild

```bash
# Pillow must be importable by the interpreter that runs with -I (which ignores user site-packages).
# Either install it into that interpreter (py -m pip install pillow) or use a venv that has it.
py -I tool/eval_data/build_nutrition5k.py
# options: --suggest (add auto-suggested map entries for new names),
#          --no-download (rebuild labels and stats from cache), --reselect (new sample)
```

Outputs under `eval/datasets/nutrition5k/`: `photos/*.jpg`, `labels.json` (same shape as
`eval/labels.json`), `manifest.json` (dish list, bins, PNG SHA-256, sizes, metadata hashes),
`mapping_stats.json`, and `metadata/` (cached CSVs and the dataset README).

The script was run with a venv that has Pillow, using `py -I` (`-I` ignores the user
site-packages, so Pillow must be installed in the interpreter that runs the script).

Notes on the metadata, verified against the bucket:

- The dish CSVs have **no `num_ingrs` column**, although the dataset README lists one. Each
  row is `dish_id, total_calories, total_mass, total_fat, total_carb, total_protein`, then 7
  fields per ingredient (`ingr_id, name, grams, calories, fat, carb, protein`). The script
  derives the ingredient count from the row width.
- The README names `metadata/ingredient_metadata.csv`, which returns 404. The file in the
  bucket is `metadata/ingredients_metadata.csv`.
- 79 ingredient entries have an empty name and are dropped. 0 dishes are dropped entirely.

### Mapping rules (`tool/eval_data/nutrition5k_map.json`)

The map goes from the lower-case Nutrition5k ingredient name to a VYRO key in
`assets/nutrition/foods.json`. Every entry has `reviewed: true` (all 137 names were checked by hand).
Each entry has:

- `key`: the VYRO key, or `null` when there is no equivalent in the database.
- `any_of` (optional): alternative keys that also count as a hit (for example, generic
  "chicken" is `chicken_breast_roasted` with `chicken_thigh_roasted` as an alternative).
- `optional` (optional): not scored when absent from the photo.
- `note` (optional): records an approximation or a reason for `null`.

Rules applied when labels are built:

1. An ingredient that maps to `null` is written as `{name: <English name>, key: null, optional: true}`.
   It is neither a hit nor a miss.
2. An ingredient is `optional` when the map says so, when it weighs under 5 g, or when its name
   matches oils, vinegar, salt, pepper, spices, herbs, dressings, sauces or condiments. Examples:
   olive oil, salt, pepper, vinegar, dressings, soy sauce, mayonnaise, herbs, honey.
3. Ingredients that map to the same key within one dish are merged. Grams are summed, and the
   entry is optional only if every merged part is optional.
4. Each label keeps `grams` and the original `ingredient` name (and `ingr_id`) for traceability.
   The `name` is the Portuguese `namePt` from `foods.json` for mapped keys.
5. `total_mass` is the dish total from the metadata, in grams.

Approximations (mapped with a `note`): for example, "scrambled eggs" to `omelette`, "fish" to
`cod_cooked` with alternatives, "cherry tomatoes" to `tomato_raw`, "arugula" and "mixed greens"
to `green_salad` (with `lettuce_raw` as alternative), "roasted potatoes" to `potato_boiled`
(with `potato_fries_oven`). Read the notes before treating a score as meaningful.

### Top unmapped names (no DB key, by items; full list in `mapping_stats.json`)

Most frequent `null` names: salt (47 items, 26.6 g), garlic (32, 49.4 g), pepper (23, 46.8 g),
vinegar (22, 52.3 g), lemon juice (22, 42.9 g), parsley (16, 12.7 g), egg whites (15, 4,117.7 g),
wheat berry (14, 564.0 g), bacon (13, 325.0 g), bok choy (12, 724.3 g). Largest by grams:
egg whites (4,117.7 g) and bok choy (724.3 g).

These are real gaps in the VYRO database. They are not scored, so they neither help nor hurt
the score. If the database grows, add the keys and rerun the script.

### Caveats

- **Cuisine and setting:** Nutrition5k was collected in a few cafeterias in California, USA.
  The dishes are US cafeteria food, not Portuguese dishes. Results do not show how the app
  behaves on Portuguese food.
- **Camera:** the photos come from an overhead RGB-D rig. Dishes sit in bowls or plates, so
  the framing differs from a phone photo taken at an angle.
- **Weights and calories:** the grams in the labels come from the dataset's ingredient
  measurements. They are recorded for the harness, which may ignore them for now. VYRO's rule
  is that a photo never gives exact grams or calories, so these values must not be presented
  as something the app recognises.
- **Mapping is approximate:** names in Nutrition5k are not VYRO categories. The map is a
  judgement call, and the notes say where it is loose.

## UEC FOOD 256 (documented, not run)

`tool/eval_data/build_uecfood256.py` is a **stub**. It has not been run and has not been
tested on the data.

- **Licence:** research / non-commercial. This is evaluation only, never training data for
  shipped assets and never part of the app.
- **Get it** (only if the user has a Kaggle API token at `~/.kaggle/kaggle.json`):
  ```bash
  py -m pip install --user kaggle
  kaggle datasets download -d rkuo2000/uecfood256 -p <empty dir outside the repo>
  ```
  Unzip into an empty directory outside the repo. Treat the contents as untrusted data.
- **Mapping:** `tool/eval_data/uecfood256_map.json` maps English class names (from
  `category.txt`) to VYRO keys. It is a short, unverified list. Most classes are unmapped.
- **Open questions before it works:** the exact layout and headers of `bb_info.txt` and
  `category.txt` are assumed, not checked. Decide whether to crop to the bounding box or use
  the whole image. Images can hold several dishes.

## Adding another dataset

1. Put the dataset outside the repo and write a `tool/eval_data/build_<name>.py` converter.
2. Write labels in the `eval/labels.json` shape, with `file` relative to a `photos/` folder
   under `eval/datasets/<name>/`.
3. Keep the mapping JSON committed and the data gitignored. Record the licence and citation here.
