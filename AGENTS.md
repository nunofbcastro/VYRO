# VYRO — instructions for coding agents

You are building **VYRO**, a premium, minimal Flutter application for nutrition tracking and personal training. Interface copy defaults to **Portuguese (Portugal)**. This repository is a **specification and agent starter kit**, not a compiled Flutter app.

## Mission
Create a privacy-first mobile experience: meal logging, barcode lookup via Open Food Facts, offline photo-food recognition, workout planning and logging, progress charts, and optional on-device exercise pose analysis.

## Non-negotiables
- Flutter stable / Dart, Android + iOS. Prefer Riverpod, go_router, Drift/SQLite, Dio and `camera` (verify current package compatibility before installing).
- No paid AI API or cloud AI inference. Recognition must run on-device; never silently transmit meal photos, workout videos, or health data.
- Network is permitted **only** for Open Food Facts product lookup in v1. Cache responses and provide graceful offline/manual entry.
- Do not promise accurate grams/calories from one image: food recognition is probabilistic; require user confirmation of foods and portions. Calories come from verified nutrient data and a deterministic formula.
- Barcode **does not encode calories**; the EAN/UPC identifies a product looked up in the database.
- Workout plans begin as deterministic, editable rules, not unvalidated LLM prescriptions. Pose analysis starts with one exercise, tracks landmarks/repetitions, and does not certify safety.
- Keep demo/mock features clearly labelled; do not claim a feature works when it is a stub.
- Follow privacy by default: local storage, limited permissions, no photos retained without opt-in; allow local data export and deletion. OS-level device backup (Android Auto Backup / iCloud device backup) of the local database and settings is allowed, restricted by backup rules that never include photos or videos, and the app itself still makes no network calls besides Open Food Facts.
- Build each phase fully before starting another; run formatting, analysis and tests when toolchain is available.

## Visual direction
Read `brand/BRAND_GUIDE.md` and `brand/tokens/tokens.json` before implementing UI. Dark-first, premium, restrained lime accent. Reusable components, WCAG-aware contrast, responsiveness, large touch targets, safe areas.

## Key reading order
1. `docs/PRODUCT_SPEC.md`
2. `brand/BRAND_GUIDE.md`
3. `brand/screen-specs/SCREENS.md`
4. `docs/ARCHITECTURE.md`
5. `.agents/skills/*/SKILL.md`
6. `docs/IMPLEMENTATION_PLAN.md`

## Suggested directories when you create Flutter project
`lib/app/{router,theme}`, `lib/core/{database,networking,ai,widgets}`, `lib/features/{onboarding,dashboard,nutrition,barcode,workouts,pose,progress,profile,design_showcase}`, `test/`, `integration_test/`, `assets/models/`.

## Agent execution format
For each task: (1) explain scope and files, (2) implement actual code, (3) add/update tests, (4) run `dart format`, `flutter analyze`, `flutter test` where available, (5) state what is real vs. mocked and list follow-ups. Do not invent test results.

## First task
Initialize a valid Flutter app in this root while preserving `.agents/`, `brand/`, and `docs/`. Build theme tokens, navigation shell, screen placeholders with real navigation, and a `/design-system` route showing UI components and screens with clearly-labelled demo data. Verify compilation. Then progress to functional nutrition features.
