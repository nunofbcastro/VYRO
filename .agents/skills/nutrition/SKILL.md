---
name: nutrition
description: Nutrition and barcode for the VYRO Flutter project
---

# Nutrition and barcode

EAN/UPC scan local, fetch Open Food Facts only with identification and respectful limits, cache. Nutrients per 100g and missing-data handling; deterministic portions. Offline/manual entry always available.

Foods without a barcode (photo, assistant, picker) use the offline database built from USDA, Ciqual and TACO: see the `nutrition-database` skill and `docs/NUTRITION_DATA.md`. Photo recognition is covered by the `food-vision` skill.

## Workflow
1. Read `AGENTS.md`, `docs/PRODUCT_SPEC.md` and related brand docs.
2. Draft the smallest testable change; prefer real behavior to placeholders.
3. Implement and add tests for failures, permissions and offline cases.
4. Run checks where available and report honest results.
