# VYRO product spec

## Audience and proposition
People tracking fitness and nutrition who want one polished app with offline-first privacy. Locale: pt-PT by default, i18n-ready.

## Features / acceptance criteria
### Nutrition
- Onboarding: basic profile, goal, activity level, dietary choices, workout experience; editable later.
- Dashboard: consumed/target/remaining kcal; macro totals; next workout.
- Meal diary: breakfast/lunch/dinner/snacks; add, edit, remove foods and quantities; deterministic macro totals.
- Barcode scan: EAN-13/EAN-8/UPC where supported, Open Food Facts lookup, missing-field/error/offline states; cache and allow manual products.
- Food photo: model runs on phone; returns food hypotheses and confidence, NOT a claimed accurate serving mass. UI requests confirmation/edits. Nutrient values from curated local database; provenance visible.

### Training
- Equipment, schedule and goal filters; conservative rule-driven editable workout programming.
- Catalog with instructions and difficulty; session logger with sets, reps, weight, rest timer and resume.
- Charts: workouts completed, weight logs, volume, kcal history.
- Optional offline posture estimation for a supported exercise only (e.g., squat). Show confidence / framing errors; never claim safety validation.

### Privacy / robustness
- Local Drift/SQLite; import/export/delete. Offline for all local features except uncached barcode lookups.
- Explicit camera access, no automatic image upload, avoid retaining snapshots by default.
- No diagnosis or medical claims; relevant safety warnings and professional referral for concerning limitations.

## Out of scope for MVP
Cloud sync, social feed, subscriptions, meal photo gram precision, fully reliable form correction, unrestricted AI coach.

## Definition of done
Functional flows (not static mocks), automated tests, accessible pt-PT text, smooth degraded offline behaviour, documented model limits.
