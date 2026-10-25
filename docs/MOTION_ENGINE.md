# VYRO motion engine

Camera-based rep counting and technique feedback built from **reusable movement patterns** instead of one engine per exercise. Everything runs on the device. Frames are analysed and discarded; only numbers are stored.

## Layers

| Layer | Module (`lib/features/motion_engine/`) | Role |
| --- | --- | --- |
| 1. Pose detection | `pose_detection/` | `PoseDetectionService` interface. `MlKitPoseDetectionService` uses `google_mlkit_pose_detection` (BlazePose, 33 landmarks, base model, stream mode). It converts NV21 (Android) or BGRA (iOS) frames, applies rotation and lens direction, and outputs `BodyPose` in normalised upright coordinates. |
| 2. Biomechanics | `biomechanics/` | Aspect-corrected geometry (`angleAt`, inclination, line angles) and One Euro filtering per metric. `BiomechanicsEngine` produces knee, hip, elbow and shoulder angles, trunk lean, body line, trunk rotation and wrist height, each with a confidence value. Missing joints are never guessed. |
| 3. Exercise context | `exercise_registry/` | `ExerciseAnalysisRegistry` maps catalogue keys to a pattern plus variant overrides (thresholds, disabled checks, phase direction, camera view). Configs are versioned (`schemaVersion`), validated (`validate()`) and serialisable to JSON. |
| 4. Movement analysis | `movement_patterns/`, `repetition_counter/`, `exercise_analysis/` | `PatternLibrary` holds 12 patterns. `RepCounterEngine` is a hysteresis state machine. `ExerciseAnalysisEngine` combines the two with technique checks over consecutive frames. |
| 5. Feedback | `feedback_engine/` | `FeedbackEngine` ranks candidates (setup > warning > info > success), drops low-confidence technique messages, rate-limits repeats (6 s per message, 2.2 s between messages), and has optional PT/EN voice (flutter_tts). |
| UI | `workout_camera/` | `MotionCoachPage`: setup (advice, privacy, history), camera with skeleton, reps or hold time, timer, status, detection quality and latency, pause, finish, camera flip and voice toggle; then a summary. |
| History | `workout_analysis_history/` | `MotionHistoryRepository` writes to the Drift table `motion_analyses` (schema v5). It is included in export, import and "delete all data". |

Entry points: on a workout day, each compatible exercise card has **"Analisar com câmara"**; the in-progress session shows a camera icon. The older MoveNet squat demo (`/motion`) is unchanged.

## Patterns
`squat`, `hip_hinge`, `horizontal_push`, `vertical_push`, `horizontal_pull`, `vertical_pull`, `elbow_flexion`, `elbow_extension`, `shoulder_abduction`, `lunge`, `trunk_rotation` (experimental, 2D), and `core_stabilization` (hold mode).

Each pattern has:
- a primary signal (metric + left/right combination: bilateral, best side, minimum or maximum);
- required landmarks;
- counting thresholds (`rest`, `peak`, hysteresis, partial fraction, min/max rep time);
- which half of the rep is eccentric;
- an optional minimum eccentric time;
- technique checks.

### Thresholds and criteria
- **Counting thresholds** are camera estimates used to detect reps. They are configurable per exercise and are **not** technique recommendations.
- **Technique checks** are provisional (`validated: false`). They fire only after several consecutive confident frames, at most once per rep, and are worded as possible issues. A **technique score is only computed when every check of the pattern is validated** by a qualified professional; today no score is shown.

## Rep counter rules
- Arms only after seeing the start position.
- A full rep reaches the end of range and returns. A reversal covering at least `partialFraction` of the range is a partial. Smaller movements are ignored.
- Reps faster than `minRep` or slower than `maxRep` are not counted.
- Tracking lost mid-rep: under 1.5 s the rep continues; longer, the rep is abandoned and the counter re-arms at the start position.
- 8 s idle at rest after at least one rep ends the set automatically.

## Outcomes
`withinCriteria`, `possibleIssue`, `notObservable` (joints not visible: the app says which ones), and `inconclusive` (less than 60 % of frames observable).

## Performance
- At most ~15 analysed frames per second, one at a time (frames arriving while busy are dropped).
- `ResolutionPreset.medium`, no audio.
- The camera is released on finish, on dispose and when the app goes to background.
- Latency (exponential moving average) is shown next to detection quality. Measure it on real devices; it has not been profiled yet.

## Adding an exercise
1. Pick the pattern that matches the movement. Do not write a new class.
2. Add an `ExerciseAnalysisConfig` to `defaultConfigs`. Override thresholds or disable checks only when the variant needs it, and add a `noteKey` for camera placement.
3. If no pattern fits, mark it `AnalysisSupport.unsupported`; never invent rules.
4. Run `ExerciseAnalysisRegistry().validate()` (covered by tests).

Currently supported: goblet squat, split squat, reverse lunge, push-up, shoulder press, seated row, lat pulldown, biceps curl, triceps pushdown, lateral raise, hip hinge, plank.
Limited: pike push-up, dumbbell press, dumbbell row, face pull, glute bridge, side plank.
Unsupported: dead bug, bird dog, superman, calf raise.

## Tests
`test/motion_engine/` uses reproducible synthetic landmark sequences (`synthetic_poses.dart`). It covers:
- geometry, aspect correction and filtering;
- rep counting: full, partial, accidental, too fast, arming, tracking loss, end of set and phase direction;
- biomechanics with hidden joints;
- analysis outcomes and visibility messages;
- registry validation and JSON round-trip;
- feedback priority and cooldowns;
- persistence and the setup screen.

## Limitations (not implemented or not validated)
- **Not tested on a physical device yet.** Rotation, mirroring, latency, heat and battery use must be checked on real Android and iOS phones.
- 2D analysis: depth, rotation and knee tracking in the frontal plane are not reliable. Side or front placement matters, and each exercise shows advice.
- Load is unknown; a camera cannot judge weight or effort.
- Criteria need professional review before any validated score is shown.
- iOS: ML Kit needs iOS 15.5 or later in the Podfile. This was not built here (no Mac).
- No raw video is stored. Adding that would require explicit consent first.
- No machine-learning classifier of errors is used. Every check is an explicit, reviewable rule.
