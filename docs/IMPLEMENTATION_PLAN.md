# Implementation phases

## Phase 1 — UI and foundation
Create Flutter project, pt-PT strings and centralized dark/light theme; implement shell with five tabs (Início, Nutrição, Treinos, Progresso, Perfil), onboarding views, dashboard, and `/design-system` preview of ALL screen states. Functional navigation, reusable widgets, demo data clearly indicated. Build and test.

## Phase 2 — Nutrition without photo model
Drift persistence; meal CRUD; deterministic macros; camera permissions + barcode scanner; Open Food Facts with user-agent, rate handling, attribution, cache, offline/manual fallback. Tests.

## Phase 3 — Trainer engine
Exercise repository; editable weekly plans from rules and personal constraints; session logging, timers, simple progression and history. Validate unsafe combinations and allow manual override.

## Phase 4 — Offline food recognition
Choose a legally usable model and datasets, train/fine-tune outside app, evaluate on Portuguese meals/mixed plates, compress/convert to on-device format, integrate through interface, add corrections and unknown state. Do not conflate ingredient segmentation with mass estimation.

## Phase 5 — Offline motion analysis
Permission flow, pose landmarks, confidence/framing, smoothing, squat phase transitions, rep count, camera overlays, privacy note. Validate against varied bodies/devices; explicitly avoid injury-prevention guarantees.

## Phase 6 — polish & release
Accessibility, performance, analytics only with consent (or none), backup/export, privacy policy, store assets, localization, tests and profiling.

### Release gate per phase
`dart format .` + `flutter analyze` + `flutter test`, on emulator/device if available. Report unavailable checks without pretending to pass.
