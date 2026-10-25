---
name: offline-ai
description: On-device food AI for the VYRO Flutter project
---

# On-device food AI

No external vision API. Train/validate model outside app, document data licensing, architecture, eval split, failure cases, mobile conversion and size/perf. Return food confidence, allow correction, never assert image-derived exact grams.

Current implementation (Gemini Nano multimodal + AIY region classifier fallback) and how to plug in a detection/segmentation model: `food-vision` skill and `docs/FOOD_VISION.md`.

## Workflow
1. Read `AGENTS.md`, `docs/PRODUCT_SPEC.md` and related brand docs.
2. Draft the smallest testable change; prefer real behavior to placeholders.
3. Implement and add tests for failures, permissions and offline cases.
4. Run checks where available and report honest results.
