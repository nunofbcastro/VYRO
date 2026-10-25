# VYRO motion engine

Camera-based rep counting and technique feedback built from **reusable movement patterns** instead of one engine per exercise. Everything runs on the device. Camera frames are analysed and discarded; only numbers and events are stored. Gallery video import is **experimental** (see below).

## Layers

| Layer | Module (`lib/features/motion_engine/`) | Role |
| --- | --- | --- |
| 1. Pose detection | `pose_detection/` | `PoseDetectionService` interface. `MlKitPoseDetectionService` uses `google_mlkit_pose_detection` (BlazePose, 33 landmarks, base model, stream mode). It converts NV21 (Android) or BGRA (iOS) frames, applies rotation and lens direction, and outputs `BodyPose` in normalised upright coordinates. |
| 2. Biomechanics | `biomechanics/` | Aspect-corrected geometry (`angleAt`, inclination, line angles) and One Euro filtering per metric. `BiomechanicsEngine` produces knee, hip, elbow and shoulder angles, trunk lean, body line, trunk rotation and wrist height, each with a confidence value. Missing joints are never guessed. |
| 3. Exercise context | `exercise_registry/` | `ExerciseAnalysisRegistry` maps catalogue keys to a pattern plus variant overrides (thresholds, disabled checks, phase direction, camera view). Configs are versioned (`schemaVersion`), validated (`validate()`) and serialisable to JSON. |
| 4. Movement analysis | `movement_patterns/`, `repetition_counter/`, `exercise_analysis/` | `PatternLibrary` holds 12 patterns. `RepCounterEngine` is a hysteresis state machine. `ExerciseAnalysisEngine` combines the two with technique checks over time. |
| 5. Feedback | `feedback_engine/` | `FeedbackEngine` ranks candidates (setup > warning > info > success), drops low-confidence technique messages, rate-limits repeats (6 s per message, 2.2 s between messages), and has optional PT/EN voice (flutter_tts). |
| UI | `workout_camera/` | `MotionCoachPage`: setup (advice, privacy, history), camera with skeleton, reps or hold time, timer, status, detection quality and latency, pause, finish, camera flip, voice toggle, count correction; then a summary. |
| Video (experimental) | `video/` | `VideoAnalysisPage` and `LocalVideoAnalysis`: a gallery video is analysed frame by frame with the same engine. |
| History | `workout_analysis_history/` | `MotionHistoryRepository` writes to the Drift table `motion_analyses`. It is included in export, import and "delete all data". Stores counts, duration, observed ratio, status and events; no frames or video. |

Entry points: on a workout day, each compatible exercise card has **"Analisar com câmara"**; the in-progress session shows a camera icon. The camera screen also offers **"Analisar vídeo da galeria"** when the exercise has a pattern (not on web). The older MoveNet squat demo (`/motion`) now opens `MotionCoachPage` for `goblet_squat`.

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
- **Technique checks** are provisional (`validated: false`). A check fires only after its violation has lasted a minimum time (see Continuity), at most once per rep, and is worded as a possible issue. A **technique score is only computed when every check of the pattern is validated** by a qualified professional; today no score is shown.

## Rep counter rules
- Arms only after seeing the start position.
- A full rep reaches the end of range and returns. A reversal covering at least `partialFraction` of the range is a partial. Smaller movements are ignored.
- Reps faster than `minRep` **or slower than `maxRep` are not counted** (the maximum is checked on the return to rest, so a long gap in sampling cannot produce an accepted overlong rep).
- Tracking lost mid-rep: under 1.5 s the rep continues; longer, the rep is abandoned and the counter re-arms at the start position.
- 8 s idle at rest after at least one rep ends the set automatically.
- `interrupt()` drops only the rep in progress; completed reps are kept. It is called on pause, camera switch and finish.

## Continuity (time gaps)
- Timestamps that go backwards return `inconclusive` for that frame.
- A gap longer than 500 ms between analysed samples resets the in-progress rep, the technique timers and the isometric hold timer.
- **Hold (isometric) time** adds a step only when both consecutive samples are in range and are less than 500 ms apart. A sample outside the range or without a pose clears the timer, so unobserved intervals are never counted.
- **Technique checks** are time-based: a violation must persist for about `(minFrames − 1) × 66 ms` of observed time (the old frame count at 15 fps). A check resets when the violation stops, when confidence drops or when the joint is not visible.

## Framing gate
`PoseReadinessGate` (`workout_camera/motion_sampling_policy.dart`) requires the pattern's required landmarks to be visible (likelihood ≥ 0.6, inside 2 %–98 % of the frame) for 500 ms before counting starts. Until then the coach shows the "adjust camera" message and counts nothing. This checks visibility only; it does not verify camera angle or distance.

## Adaptive sampling
`MotionSamplingPolicy.interval` chooses the time between analysed frames:
- 66 ms while moving (going to peak, returning, or progress changing by more than 0.025);
- 120 ms at rest with low detection quality (< 0.45), otherwise 166 ms;
- always at least the latency of the last inference (66–220 ms) and at most 250 ms.

Frames that arrive while the previous frame is still being analysed are skipped and counted. At the end of a session the number of analysed frames, skipped frames and inference time are added to the local counters (`quality_metrics_v1`). They do not include images.

## Manual count correction
After a set, **"Corrigir repetições"** lets the user enter complete and partial counts (0–1000). The original detected counts are kept in the history record as a `user_count_correction` event. The summary then shows that the count was corrected. Corrected counts do not change technique events and never create a technique score. The same flow applies to gallery video results before they are saved.

## Gallery video import (experimental)
- `VideoAnalysisPage` picks a video with the system gallery picker, copies it to a temporary file and deletes it when the page releases it or when the analysis ends. The original file is never changed.
- Frames are decoded locally through the channel `vyro/local_video`:
  - Android: `MediaMetadataRetriever` (`LocalVideoChannel.kt`). It only accepts files inside the app's cache or files directory.
  - iOS: `AVAssetImageGenerator` (`AppDelegate.swift`, `LocalVideoDecoder`).
  Both return a JPEG of at most 640 px per requested time. They are **not verified on a device**. Frame timestamps are the requested positions, not the real presentation times (`approximate: true`); rotation handling is not verified.
- The user picks a range of up to **2 minutes**. Frames are taken every 100 ms, one at a time, and sent to ML Kit pose detection in single-image mode with the accurate model.
- Results are counts, moments (partial reps and moments when the body was lost) and the usual provisional events. The user confirms or corrects the counts before saving to `motion_analyses`.
- Frames and video are not saved.
- Accuracy on real videos has **not** been measured.

## Outcomes
`withinCriteria`, `possibleIssue`, `notObservable` (joints not visible: the app says which ones), and `inconclusive` (less than 60 % of frames observable).

## Performance
- Adaptive sampling, at most one inference at a time (see above).
- `ResolutionPreset.medium`, no audio.
- The camera is released on finish, on dispose and when the app goes to background.
- Latency (exponential moving average) is shown next to detection quality. Measure it on real devices; it has not been profiled yet.

## Assistant summary
The last analysed set is described locally (`MotionHistoryRepository.describe`) and can be read by the assistant's "última série" question. It states the counts, duration, observed coverage and that the result is not a technique or safety certification. Per-repetition amplitude or timing is not stored, and the engine version is not recorded. See `docs/ASSISTANT.md`.

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
- rep counting: full, partial, accidental, too fast, too slow after a gap, arming, tracking loss, end of set and phase direction;
- continuity: late return to rest, hold time across unobserved samples, readiness requiring continuous landmarks, adaptive sampling, manual counts (`motion_continuity_test.dart`);
- biomechanics with hidden joints;
- analysis outcomes and visibility messages;
- registry validation and JSON round-trip;
- feedback priority and cooldowns;
- persistence, history and the setup screen;
- video analysis with a fake frame source and fake detector (`local_video_analysis_test.dart`). It does not test the native decoders.

## Limitations (not implemented or not validated)
- **Not tested on a physical device yet.** Rotation, mirroring, latency, heat and battery use must be checked on real Android and iOS phones.
- **Gallery video import is experimental**: native decoders are unverified on devices; no accuracy measurement on real videos exists.
- 2D analysis: depth, rotation and knee tracking in the frontal plane are not reliable. Side or front placement matters, and each exercise shows advice.
- The "low light" message (`mfLowLight`) is shown when detection quality is low; the camera does not measure light, so the message may name the wrong cause.
- Load is unknown; a camera cannot judge weight or effort.
- Criteria need professional review before any validated score is shown.
- The older `MotionPage` (`lib/features/pose/motion_page.dart`) still exists in the code, but the `/motion` route now opens `MotionCoachPage`. Its removal or unification with the engine is pending.
- iOS: ML Kit needs iOS 15.5 or later in the Podfile. This was not built here (no Mac).
- No raw camera frames or videos are stored. Adding that would require explicit consent first.
- No machine-learning classifier of errors is used. Every check is an explicit, reviewable rule.
