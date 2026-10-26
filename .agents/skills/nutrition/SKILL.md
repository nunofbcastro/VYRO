---
name: nutrition
description: Nutrition and barcode for the VYRO Flutter project
---

# Nutrition and barcode

EAN/UPC scan local, fetch Open Food Facts only with identification and respectful limits, cache. Nutrients per 100g and missing-data handling; deterministic portions. Offline/manual entry always available.

Foods without a barcode (photo, assistant, picker) use the offline database built from USDA, Ciqual and TACO: see the `nutrition-database` skill and `docs/NUTRITION_DATA.md`. Photo recognition is covered by the `food-vision` skill.

## Daily targets
- Stored in the profile (`VyroProfile`): kcal, protein, carbs and fat per day, plus `targetMode` (`automatic` or `manual`) and `targetsWeightKg`.
- Automatic (default): Mifflin-St Jeor formula with the profile's sex, age, height, activity and goal, applied to the latest logged weight (or the profile weight when no entry exists). Recomputed on every weight add, edit, delete or restore and on every profile save. Backdated entries that are not the latest change nothing.
- Manual: values typed in the targets editor (`/nutrition-targets`), validated (1000-6000 kcal, macros 0-1000 g, decimal comma accepted). A warning appears when the macro kcal differs from the target by more than 5%. Manual values survive weight changes; a moved weight shows a one-tap "Recalcular metas?" offer.
- Only the stored profile values are read by the dashboard, diary, home widgets, assistant and local answers.

## Workflow
1. Read `AGENTS.md`, `docs/PRODUCT_SPEC.md` and related brand docs.
2. Draft the smallest testable change; prefer real behavior to placeholders.
3. Implement and add tests for failures, permissions and offline cases.
4. Run checks where available and report honest results.
