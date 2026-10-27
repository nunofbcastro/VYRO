# Food vision evaluation (offline)

This harness measures how well VYRO's food-photo recognition works, using the
app's real code and a local model. It answers one question: which strategy gives
the best accuracy on our own meal photos.

- The photos are private. `eval/photos/` and `eval/results/` are git-ignored and
  nothing here sends a photo anywhere except to a model on your own machine
  (Ollama on `localhost`, or the phone's own model on the phone).
- The app code under test is `lib/features/nutrition/food_vision/`:
  `SystemFoodVision`, `FoodVisionPipeline`, `RegionFoodVision`, the parser, the
  screening rules and the verifier. The harness only answers the
  `vyro/on_device_llm` channel calls with a model, and scores the foods that
  come out. It never edits the app.

## Run everything (one command)

```powershell
.\tool\eval\run_all.ps1
```

If PowerShell blocks the script, run it as `powershell -ExecutionPolicy Bypass -File .\tool\eval\run_all.ps1`.

The script:

1. Checks Ollama is installed. If `localhost:11434` does not answer, it starts `ollama serve`
   with `OLLAMA_VULKAN=1` and `OLLAMA_IGPU_ENABLE=1` in a hidden window and waits for `/api/version`.
2. Checks `gemma3n:e2b` is pulled (offers `ollama pull` if not).
3. Warns if free RAM is under 4 GB and says how to free it (for example `wsl --shutdown`). You can continue.
4. Runs one `flutter test` process per strategy and dataset:
   `legacy_app` and `pipeline` on `eval/datasets/nutrition5k_50` (train) and
   `eval/datasets/nutrition5k_holdout` (holdout), and `pipeline` on `eval/photos` only when a photo
   there matches `eval/labels.json`. After each run it prints whether Ollama used the GPU or the CPU (`ollama ps`).
   A failed run is reported and the next one still runs.
5. Runs `tool/eval/compare_results.py` and writes **`eval/results_summary.md`**: precision, recall, F1,
   exact meals, FP per photo and mean latency per dataset and strategy, the legacy_app to pipeline
   change for train and holdout, and the most frequent unmatched names, false positives and misses.

Expected duration on this PC (Arc iGPU): **about 2 to 3 hours**. Outputs: `eval/results_summary.md`,
the per-run `.json` and `.md` files in `eval/datasets/<set>/results/` (and `eval/results/` for your own
photos), and the full console log in `eval/results/run_all_<timestamp>.log`.

Preview without starting anything: `.\tool\eval\run_all.ps1 -DryRun`.

To rebuild the Nutrition5k labels after foods change (the photos and the train/holdout split stay the same):
`.\tool\eval\refresh_labels.ps1`.

## What is in this folder

| Path | Committed | What it is |
|---|---|---|
| `eval/labels.json` | yes | Ground truth: one entry per photo, with the expected foods. |
| `eval/README.md` | yes | This file. |
| `eval/photos/` | no (ignored) | Your photos. Names must match `labels.json`. |
| `eval/results/` | no (ignored) | One `.json` and one `.md` per run and strategy. |
| `tool/eval/scoring.dart` | yes | Pure Dart scoring (matching, P/R/F1, exact meals, latency). Shared with the phone run. |
| `tool/eval/report.dart` | yes | Markdown report of one run. |
| `tool/eval/ollama_client.dart` | yes | Minimal HTTP client for Ollama (`/api/generate`, `/api/version`). |
| `tool/eval/variants.dart` | yes | Strategy names, prompt variants (checklist, Portuguese prompts, English names). |
| `tool/eval/food_vision_eval_test.dart` | yes | Host harness, a `flutter test` file gated by `VYRO_EVAL=1`. |
| `integration_test/food_vision_eval_test.dart` | yes | Same scoring on the phone, through the real AICore channel. |
| `test/eval_scoring_test.dart` | yes | Unit tests for the scoring, and a check that every label key exists in `foods.json`. |

## Labels

`eval/labels.json` is a list. Each entry:

```json
{
  "file": "burger.jpg",
  "notes": "free text",
  "foods": [
    {"name": "hambúrguer no pão", "key": "cheeseburger_whole", "any_of": ["beef_ground_patty"]},
    {"name": "molho de cerveja", "key": "brown_gravy", "optional": true},
    {"name": "croquete de queijo", "text": "croquete de queijo", "optional": true}
  ]
}
```

- `key`: a key from `assets/nutrition/foods.json` (the `"key"` field of each food).
  The unit tests fail if a key does not exist.
- `any_of`: other keys that count as the same food (for example a whole pizza or
  a slice). Each prediction can match only one label.
- `optional`: a missed optional food does not count against recall. A found one
  counts as a true positive.
- `text`: a food that has no database row (instead of `key`). It matches a
  predicted name that has no database key, by normalised name (lower case, no
  accents, punctuation removed; the name may contain the label text or be
  contained in it).
- `name`: the label used in the reports only.

Each food is one item. Counts (2 burgers) and grams are not scored.

The entries in the committed file use placeholder file names (`burger.jpg` and
so on). Rename your photos to match, or edit the `file` fields. A label without a
photo is skipped with a message in the log. The run fails only when no photo at
all matches.

## Run on Windows (host, no phone)

Requirements: Flutter (stable), Ollama running at `http://localhost:11434`, and
the models you want to test (`gemma3n:e2b`, `gemma3n:e4b`, `gemma3:4b`).

```powershell
# 1. Put the photos in eval\photos\ and check eval\labels.json
# 2. Run (PowerShell)
$env:VYRO_EVAL = "1"
$env:VYRO_EVAL_MODEL = "gemma3n:e4b"
$env:VYRO_EVAL_STRATEGY = "pipeline,no_verify,sc_union,sc_inter,pt_prompt,checklist,system_only,regions_only"
flutter test --no-pub tool\eval\food_vision_eval_test.dart
```

Bash (Git Bash):

```bash
VYRO_EVAL=1 VYRO_EVAL_MODEL=gemma3n:e4b \
VYRO_EVAL_STRATEGY=pipeline,no_verify,sc_union,sc_inter,pt_prompt,checklist,system_only,regions_only \
flutter test --no-pub tool/eval/food_vision_eval_test.dart
```

Without `VYRO_EVAL=1` the test is skipped, so `flutter test` stays green.

Environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `VYRO_EVAL` | (unset) | Must be `1` to run. |
| `VYRO_EVAL_MODEL` | `gemma3n:e4b` | Ollama model tag. |
| `VYRO_EVAL_STRATEGY` | `pipeline` | Comma-separated list (see below). `self_consistency_2` runs `sc_union` and `sc_inter`. |
| `VYRO_EVAL_TEMP` | `0.1` | Temperature of the single-answer calls (the app uses 0.1). |
| `VYRO_EVAL_MAXSIDE` | (unset) | Longest image side sent to the model, resized with `package:image`. The app already downscales to 768 px before the model, so values above 768 change nothing. |
| `VYRO_EVAL_NUM_CTX` | `4096` | Context size sent to Ollama. |
| `VYRO_EVAL_OLLAMA_URL` | `http://localhost:11434` | Ollama server. |
| `VYRO_EVAL_DIR` | `eval` | Folder with `labels.json`, `photos/` and `results/`. Useful for a scratch run. |

Strategies:

| Name | What it runs |
|---|---|
| `pipeline` | The app's `FoodVisionPipeline` as shipped: system model (first look, second chance, verify) plus the offline region classifier. |
| `system_only` | `SystemFoodVision` alone, as shipped (no regions). |
| `no_verify` | The first look only: parsed and screened by the app, with no second chance and no verification call. |
| `sc_union` | Two first looks at temperature 0.7, combined as a union by database key. No verification. |
| `sc_inter` | Two first looks at temperature 0.7, kept only where both agree. No verification. |
| `checklist` | `system_only`, with the first-look prompt from before 0.6.2 (the category checklist). The prompt is taken from git history (`a7a8778^`). |
| `pt_prompt` | `system_only`, with all three app prompts written in European Portuguese. Same JSON format, so the app's parser and verifier are unchanged. |
| `en_names` | `system_only`, with the first-look and second-chance prompts asking for the item name and location in plain English ("fried egg", "beer") instead of European Portuguese. The verify prompt has no name field and is unchanged. Same JSON format. Isolates whether English names match the database better. |
| `legacy_app` | `pipeline` (same pipeline, offline regions included), with the first-look and second-chance prompts as committed in git HEAD before the English-name change (European Portuguese names, `buildFoodPhotoPrompt()` / `buildFoodSecondChancePrompt()` expanded verbatim, see `legacyFirstPrompt()` / `legacySecondPrompt()` in `tool/eval/variants.dart`). The verify prompt is unchanged. Matching and the database are the current ones, so this isolates the prompt change only and is directly comparable with `pipeline`. |
| `regions_only` | `RegionFoodVision` alone (offline AIY classifier). |

For `no_verify`, `sc_union` and `sc_inter` the harness answers the verify call
and the second-chance call locally (`{"checks":[]}` and `{"items":[]}`), so only
the first look reaches the model. Each report says so in its raw answers.

The variants never change the app code. They are applied where the app calls the
channel: the harness recognises the app's prompt by equality with the app's own
prompt functions and rewrites it. Everything after the answer (parsing,
screening, verification, fusion, companions) is the app's code.

## Outputs

For each strategy, one pair of files in `eval/results/`:

- `<timestamp>_<model>_<strategy>.json`: metadata, the summary, and for each
  photo the predictions, matches, misses, false positives, the app's diagnostic
  text and every raw model answer.
- `<timestamp>_<model>_<strategy>.md`: the same, as a summary table and one
  section per photo (with raw answers in collapsed blocks).

The console prints a summary table at the end.

## Metrics

Scoring uses the foods of the main list only (`foods`). Suggestions ("Outras
hipóteses") are shown in the report but not scored, because the app does not
add them to the totals.

- **TP, FP, FN per photo.** A label matched to a prediction is a TP. A
  prediction matched to no label is an FP. A required label with no prediction
  is an FN. Optional labels with no prediction count nothing.
- **Micro precision** = sum TP / (sum TP + sum FP).
- **Micro recall** = sum TP / (sum TP + sum FN).
- **Micro F1** = 2 sum TP / (2 sum TP + sum FP + sum FN). Ratios that have no
  denominator are shown as `-`.
- **Exact meal**: a photo with no FP and no required FN.
- **FP per photo**: the mean number of FPs per photo.
- **Latency**: wall time of the analysis call, from the start of the call to its
  result. This includes the resize, the model calls and, for `pipeline`, the
  offline classifier that runs alongside. Mean and median are reported.
- **Errors**: photos where the analysis threw. They are scored as no
  predictions, so they lower recall.

Matching is one-to-one (maximum matching). Required labels are matched first so
an optional label cannot take a prediction a required label needs.

## Run on the phone (AICore, real model)

The phone run uses the phone's own model, through the real channel. It supports
the strategies the app can run as shipped: `pipeline` (default), `system_only`
and `regions_only`. The prompt variants need the host harness. The phone part
has been compiled and analysed but not yet run on a device.

1. Install a debug or profile build of the app on the phone, with Gemini Nano
   available (Pixel 9 or later, or Galaxy S25 or later, as in the app notes).
2. Push the photos and labels into the app's external files folder. (Not yet
   verified on a device: if the test cannot read the folder, check the path and
   the Android storage permissions first.)

   ```bash
   adb shell mkdir -p /sdcard/Android/data/com.nunofbcastro.vyro/files/eval/photos
   adb push eval/labels.json /sdcard/Android/data/com.nunofbcastro.vyro/files/eval/
   adb push eval/photos /sdcard/Android/data/com.nunofbcastro.vyro/files/eval/
   ```

   The folder on the phone is `/sdcard/Android/data/com.nunofbcastro.vyro/files/eval/`
   with `labels.json` and `photos/` inside.

3. Run the test on the device (replace `<device-id>` with `adb devices`):

   ```bash
   flutter test integration_test/food_vision_eval_test.dart -d <device-id> \
     --dart-define=VYRO_EVAL_STRATEGY=pipeline
   ```

   Use `--dart-define=VYRO_EVAL_STRATEGY=system_only` or `regions_only` for the
   other two.

4. The summary is printed between `VYRO_EVAL_RESULT_BEGIN` and
   `VYRO_EVAL_RESULT_END` (also in `adb logcat -s flutter`). The same `.json` and
   `.md` files are written to `.../files/eval/results/` on the phone. Pull them
   with `adb pull /sdcard/Android/data/com.nunofbcastro.vyro/files/eval/results`.

## Caveat: Gemma 3n is a proxy, not Gemini Nano

The host runs a Gemma 3n (or Gemma 3) model through Ollama. The phone runs
Gemini Nano through AICore. They differ in size, training, quantisation, prompt
handling and image preprocessing, so the host scores are a **proxy**. Use them
to choose a strategy and to catch regressions in the plumbing, then confirm the
winner on the phone (the integration test) before any claim about the shipped
app. Host latency is also not phone latency.

## Tests

```bash
flutter test --no-pub test/eval_scoring_test.dart test/eval_variants_test.dart test/eval_labels_test.dart
py -I -m unittest discover -s tool/eval -p "test_compare_results.py"   # summary script
flutter analyze --no-pub
```

`test/eval_labels_test.dart` checks that every `key` in `eval/labels.json` and in the Nutrition5k
label files exists in `assets/nutrition/foods.json` (label files that are not on the machine are skipped).
