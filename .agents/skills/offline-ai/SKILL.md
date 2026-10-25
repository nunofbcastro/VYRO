---
name: offline-ai
description: On-device food AI for the VYRO Flutter project
---

# On-device food AI

No external vision API. Train/validate model outside app, document data licensing, architecture, eval split, failure cases, mobile conversion and size/perf. Return food confidence, allow correction, never assert image-derived exact grams.

Current implementation (Gemini Nano multimodal + AIY region classifier fallback) and how to plug in a detection/segmentation model: `food-vision` skill and `docs/FOOD_VISION.md`.

The assistant (`docs/ASSISTANT.md`) answers factual questions with deterministic local code first (`lib/features/assistant/domain/local_assistant.dart`); the on-device LLM is used only when no local answer applies, and its meal numbers are recomposed from the database. Local memory is user-editable and never created by the model. Movement analysis (`docs/MOTION_ENGINE.md`) is also rule-based; no model writes its conclusions.

Rules shared by all of these:
- Numbers shown to the user come from local code and the database, never from model prose.
- Unknown values stay unknown (for example, unknown allergies are not "none"; unknown nutrients are not zero).
- Every model answer and every visual or motion result is a suggestion to confirm, not a measurement.
- Local data is validated on import (`lib/core/ai/local_data_validation.dart`) and exported and deleted with the rest of the app data.

## Workflow
1. Read `AGENTS.md`, `docs/PRODUCT_SPEC.md` and related brand docs.
2. Draft the smallest testable change; prefer real behavior to placeholders.
3. Implement and add tests for failures, permissions and offline cases.
4. Run checks where available and report honest results.
