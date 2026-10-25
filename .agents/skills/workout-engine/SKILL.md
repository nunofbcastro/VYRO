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
- `workout_camera/motion_coach_page.dart`: manual count correction keeps the detected counts as an event.
- `lib/features/motion_engine/video/`: gallery video analysis, experimental (native frame decoding on Android and iOS is unverified on devices).

Rules: counts and events are camera estimates, never technique scores or safety statements; a technique score needs every check validated by a professional; a manual correction changes counts only; video frames and files are not kept; label any native or unverified path as experimental.

## Workflow
1. Read `AGENTS.md`, `docs/PRODUCT_SPEC.md` and related brand docs.
2. Draft the smallest testable change; prefer real behavior to placeholders.
3. Implement and add tests for failures, permissions and offline cases.
4. Run checks where available and report honest results.
