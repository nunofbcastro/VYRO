---
name: workout-engine
description: Workout plans and sessions for the VYRO Flutter project
---

# Workout plans and sessions

Use deterministic safe and editable templates first, exercise inventory, schedule constraints, equipment support, logging, rest, progress. Avoid clinical promises and autonomously prescribed rehab.

## Camera motion engine

Full details: `docs/MOTION_ENGINE.md`. Key code:
- `lib/features/motion_engine/repetition_counter/rep_counter_engine.dart`: hysteresis counter; reps shorter than `minRep` or longer than `maxRep` are rejected; `interrupt()` drops only the rep in progress.
- `lib/features/motion_engine/exercise_analysis/exercise_analysis_engine.dart`: technique checks are time-based; a gap over 500 ms resets rep, check and hold timers; hold time never bridges unobserved samples.
- `lib/features/motion_engine/workout_camera/motion_sampling_policy.dart`: `PoseReadinessGate` (required landmarks for 500 ms) and `MotionSamplingPolicy` (adaptive interval, 66–250 ms).
- `workout_camera/motion_coach_page.dart`: manual count correction keeps the detected counts as an event. Landscape: controls move to a side panel; the preview box uses `uprightPreviewSize` (`workout_camera/preview_geometry.dart`) so the image keeps its aspect ratio.
- `feedback_engine/voice_coach.dart`: "Modo PT" spoken coach. Pure Dart: `observe()` queues phrases from rep events, feedback messages and the set summary; `next()` returns the next phrase (rep count > encouragement > cue, stale after 2 s, summary never stale); cues are throttled (4 s between, 10 s per key). Phrases are fixed PT-PT/EN templates, plus optional on-device encouragement (see `docs/MOTION_ENGINE.md`). Toggle is stored in `vyro_preferences` (`motion_voice_coach_v1`), off by default.
- `workout_camera/positioning_guide.dart`: positioning aid before a set. `PositioningGuide.forPattern` gives the ghost template and target frame per camera view (side, front, side-on plank); `assessFraming` reports `notVisible`, `tooClose`, `tooFar`, `wrongView`, `offCentre`; `FramingTracker` gives `ready` after 1 s aligned. `positioning_overlay.dart` draws it over the preview. It is a framing aid only, never a technique or safety check, and it never blocks counting.
- `lib/features/motion_engine/video/`: gallery video analysis, experimental (native frame decoding on Android and iOS is unverified on devices).

Rules: counts and events are camera estimates, never technique scores or safety statements; a technique score needs every check validated by a professional; a manual correction changes counts only; video frames and files are not kept; label any native or unverified path as experimental.

Voice coach rules: the fixed phrases are deterministic templates. The on-device model (`OnDeviceLlm`, never cloud) may write only encouragement phrases for non-count milestones and a post-set comment, validated by `feedback_engine/coach_llm_phrases.dart` (no digits beyond the given facts, no blocked words, 8 s / 6 s timeouts, fixed fallback). Voices come only from local TTS engines (`coach_voice_settings.dart` drops network voices). Never say a movement is correct, safe or well executed; the start cue is spoken once per set; "silence" stops speech and clears the queue but never ends the set; turning the coach off stops speech immediately. Framing prompts (before a set only) are spoken at most every 5 s and use the on-screen text of the issue. The start cue may be given during positioning and is not repeated when the set starts. Landscape, the positioning guide and TTS voices are not verified on devices; say so when reporting.

## Workflow
1. Read `AGENTS.md`, `docs/PRODUCT_SPEC.md` and related brand docs.
2. Draft the smallest testable change; prefer real behavior to placeholders.
3. Implement and add tests for failures, permissions and offline cases.
4. Run checks where available and report honest results.

## Plan generator (questionnaire v2)

Full rules and the substitution table: `docs/WORKOUT_PLANS.md`. Key code: `lib/features/workouts/domain/` (`plan_preferences.dart`, `exercise_traits.dart`, `plan_generator.dart`, `ai_plan.dart`) and `plan_wizard_page.dart`.

Rules:
- Generation is deterministic. The on-device model never chooses exercises, sets, reps or rest; `ai_plan.dart` only checks one rephrased summary sentence (no digits beyond the facts, no safety, technique or medical claims, at most 300 characters). The deterministic notes are always shown.
- Every exercise must pass: equipment (`equipmentCovers`), avoided list, `limitationConflict` (joint levels avoid_impact / avoid_heavy_load / avoid_completely), impact and age rules. Add a property test when a rule changes (`test/plan_constraints_test.dart`).
- Under 18 is never generated (`PlanPreferences.isBlocked`, `buildPlan` throws `StateError`).
- A day with fewer than three usable exercises must produce a `GeneratedPlan.warnings` entry, never a silent empty day.
- Time: warm-up 5 min plus sets × (work + rest); trim accessories first, never the balance exercise for 60+. Supersets only in circuits mode.
- Block: the last week is a deload (sets × 0.6). Preferences are version 2 JSON; version 1 must keep decoding (`test/plan_preferences_test.dart`).
- Plan details (block start, warm-ups, rationale, warnings, accepted summary) are version 1 JSON in `workout_plans.details` (schema v6, `domain/plan_details.dart`). Decoding never throws. Schema changes need a drift migration plus a test in `test/app_database_migration_test.dart`.
- New catalogue exercise: add `exerciseTraits` (equipment, joint loads, impact, timed, accessory) in `exercise_traits.dart`, the row in `_starterExercises` (`data/workout_repository.dart`), and the template slot if it should be picked. Guides are optional.
- Facts for the user are bilingual `PlanNote(pt, en)`; wizard labels live in `lib/app/l10n/strings.dart` under the `w2` keys.
