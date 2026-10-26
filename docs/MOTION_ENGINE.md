# VYRO motion engine

Camera-based rep counting and technique feedback built from **reusable movement patterns** instead of one engine per exercise. Everything runs on the device. Camera frames are analysed and discarded; only numbers and events are stored. Gallery video import is **experimental** (see below).

## Layers

| Layer | Module (`lib/features/motion_engine/`) | Role |
| --- | --- | --- |
| 1. Pose detection | `pose_detection/` | `PoseDetectionService` interface. `MlKitPoseDetectionService` uses `google_mlkit_pose_detection` (BlazePose, 33 landmarks, base model, stream mode). It converts NV21 (Android) or BGRA (iOS) frames, applies rotation and lens direction, and outputs `BodyPose` in normalised upright coordinates. |
| 2. Biomechanics | `biomechanics/` | Aspect-corrected geometry (`angleAt`, inclination, line angles) and One Euro filtering per metric. `BiomechanicsEngine` produces knee, hip, elbow and shoulder angles, trunk lean, body line, trunk rotation and wrist height, each with a confidence value. Missing joints are never guessed. |
| 3. Exercise context | `exercise_registry/` | `ExerciseAnalysisRegistry` maps catalogue keys to a pattern plus variant overrides (thresholds, disabled checks, phase direction, camera view). Configs are versioned (`schemaVersion`), validated (`validate()`) and serialisable to JSON. |
| 4. Movement analysis | `movement_patterns/`, `repetition_counter/`, `exercise_analysis/` | `PatternLibrary` holds 12 patterns. `RepCounterEngine` is a hysteresis state machine. `ExerciseAnalysisEngine` combines the two with technique checks over time. |
| 5. Feedback | `feedback_engine/` | `FeedbackEngine` ranks candidates (setup > warning > info > success), drops low-confidence technique messages, rate-limits repeats (6 s per message, 2.2 s between messages). `VoiceCoach` (`voice_coach.dart`) turns engine events into PT-PT/EN spoken phrases (see "Modo PT"). |
| UI | `workout_camera/` | `MotionCoachPage`: setup (advice, privacy, history), positioning stage with ghost guide, camera with skeleton (portrait and landscape; landscape puts the controls in a side panel), reps or hold time, timer, status, detection quality and latency, pause, finish, camera flip, Modo PT toggle and silence button, count correction; then a summary. `preview_geometry.dart` holds the orientation-dependent preview size. |
| Video (experimental) | `video/` | `VideoAnalysisPage` and `LocalVideoAnalysis`: a gallery video is analysed frame by frame with the same engine. |
| History | `workout_analysis_history/` | `MotionHistoryRepository` writes to the Drift table `motion_analyses`. It is included in export, import and "delete all data". Stores counts, duration, observed ratio, status and events; no frames or video. |

Entry points: on a workout day, each compatible exercise card has **"Analisar com câmara"**; the in-progress session shows a camera icon. The camera screen also offers **"Analisar vídeo da galeria"** when the exercise has a pattern (not on web). The `/motion` route also opens `MotionCoachPage`, for `goblet_squat`.

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
`PoseReadinessGate` (`workout_camera/motion_sampling_policy.dart`) requires the pattern's required landmarks to be visible (likelihood ≥ 0.6, inside 2 %–98 % of the frame) for 500 ms before counting starts. Until then the coach shows the "adjust camera" message and counts nothing. This checks visibility only; it does not verify camera angle or distance. The positioning guide below adds a separate framing check before the set.

## Positioning guide (before a set)
"Preparar posição" opens the camera **before** the set. Nothing is counted in this stage. A ghost silhouette, a dashed target frame and a short setup card show how to stand for the exercise's camera view. The figure button in the top bar shows or hides the guide, also during a set. The guide hides itself once the body is framed and stable. "Começar" starts the set on the already open camera. "Voltar" returns to the setup without counting.

Code: `workout_camera/positioning_guide.dart` (pure Dart: templates, checks, tracker) and `positioning_overlay.dart` (painter and widgets).

- **Templates** (normalised 0–1 image coordinates, origin top-left):
  - side patterns: standing side view, portrait;
  - front patterns and `CameraView.any`: standing front view, portrait;
  - `horizontal_push` and `core_stabilization` (side): side-on plank with the phone on the floor, about 2 m away, landscape.
  - A horizontal pattern seen from the front uses the standing front template.
- **Target frame**: standing side x 0.30–0.70 and front x 0.25–0.75, both y 0.08–0.92 (head near 0.12, feet near 0.90). Plank x 0.05–0.95, y 0.22–0.84.
- **Framing check** (`assessFraming`, one frame). The nose, the pattern's required landmarks and both ankles must be visible (likelihood ≥ 0.6). Thresholds are estimates, not measurements:
  - `notVisible`: a required joint is missing, or there is no pose;
  - `tooClose`: head or feet cut at the image edge (within 0.02), or the body extent is above 0.92 of the image; hidden ankles also count as cut feet;
  - `tooFar`: body extent (head to feet, along the body axis) below 0.45;
  - `wrongView`: shoulder separation divided by torso length is above 0.5 for side patterns (facing the camera) or below 0.3 for front patterns (side-on);
  - `offCentre`: body centre more than 0.15 from the image centre, or a joint cut at the side edge.
  Issues come in that order; the first one is the top issue shown and spoken.
- **Stability** (`FramingTracker`): status `ready` only after the body is aligned for 1 s of pose time. A missing pose, a gap over 500 ms or a timestamp that goes backwards restarts the timer.
- **Setup tips** (card, collapsible; open by default in landscape): side or front view; 2–3 m away with the whole body in frame; phone at hip height on a stable surface (standing); phone upright (portrait). For planks: side-on, phone on the floor about 2 m away, landscape.
- **Preview**: the ghost is painted in the same `FittedBox` box as the camera image, using the same orientation rule as the skeleton, and it is mirrored for the front lens. The preview uses `BoxFit.cover`, so on some phones the screen edges, and parts of the target frame, may be cropped. This is unchanged from the camera preview and is not verified on devices.
- **Voice** (Modo PT): before a set, the top framing issue is spoken at most every 5 s (separate limit; it does not share the cue limit). The start cue is spoken once when the body is ready, and it is not repeated when the set starts. No framing prompts are spoken during a set.
- **Limits**: seated or bent positions are approximated by the standing template, and their feet may be out of frame. The guide then reports "Não te vejo" or "Afasta-te" even though counting still works, because the guide never blocks counting. Frames for the guide are not stored. It is a framing aid only: it is not a technique, range-of-motion or safety check, and it is not verified on devices.

## Camera orientation and preview
- `CameraPreview` (camera 0.12.1) lays its image out with the sensor aspect ratio in landscape and its inverse in portrait, using the orientation it is given (preview pause, locked capture or device orientation).
- The page's preview box must use the same ratio, or the image is stretched. `uprightPreviewSize(previewSize, landscape:)` (`workout_camera/preview_geometry.dart`) returns that box: landscape keeps the sensor frame, portrait swaps width and height. The skeleton is painted in the same box, so its normalised coordinates line up with the image.
- Pose coordinates come from ML Kit in the upright image. On Android the rotation passed to ML Kit is computed from the sensor orientation plus the device orientation (mirrored for the front lens), so landscape uses the rotated frame size. Front-camera mirroring is applied to the skeleton (`1 - x`) in both orientations.
- In landscape the controls move to a 280 px side panel (scrollable, inside `SafeArea`); the preview, top bar and banner stop at the panel edge. In portrait the bottom panel is unchanged.
- **Not verified on a device.** iOS still derives the ML Kit rotation from the sensor orientation only; if the iOS preview is rotated for landscape, the skeleton may not match. Check this on an iPhone before relying on it.

## Screen orientation
- The app is locked to portrait at startup (`lib/main.dart` calls `OrientationLock.lockPortrait()` after `WidgetsFlutterBinding.ensureInitialized()`, before `runApp`). Only `portraitUp` is allowed; upside-down portrait is not.
- `MotionCoachPage` (live exercise camera) is the only screen that rotates. In `initState` it calls `OrientationLock.allowAllOrientations()` (portrait, landscape left and right); in `dispose` it calls `releaseAllOrientations()`. Pop by back gesture, system back or route removal all run `dispose`.
- `OrientationLock` (`lib/core/platform/orientation_lock.dart`) counts landscape holders, so a camera page pushed twice keeps landscape until the last one closes. Portrait is restored only when the count reaches zero.
- The video analysis page (`video/video_analysis_page.dart`) has no live camera and stays portrait.
- Android: `AndroidManifest.xml` sets no `android:screenOrientation`, so the camera page can rotate. The activity already lists `orientation` in `configChanges`, so rotation does not recreate it.
- iOS: `ios/Runner/Info.plist` keeps the landscape entries in `UISupportedInterfaceOrientations` (and the `~ipad` key). Flutter intersects the app request with these, so portrait-only for the rest of the app depends on the runtime lock, not on the plist. Not verified on devices.
- Tests: `test/motion_engine/orientation_lock_test.dart` checks the messages sent on `SystemChannels.platform` for startup, camera page init and dispose, and the two-page hold count.

## Modo PT (voice coach)
An optional spoken coach. It is off by default. The speaker-style toggle in the camera top bar switches it on or off and is stored in the local key/value table (`vyro_preferences`, key `motion_voice_coach_v1`, value `on`/`off`). Turning it off stops speech at once and drops the queue. The silence button (shown while the coach is on) stops the current phrase and clears the queue without ending the set.

Phrases are fixed templates, in PT-PT and EN (EN when the app language is English). Form cues reuse the feedback engine's text; the rest is in `voice_coach.dart`. Two optional additions use the phone's own model (see "Voz do treinador" and "Frases geradas pela IA" below); counts, framing and cues stay deterministic:

| Event | Phrase (PT-PT) | English |
| --- | --- | --- |
| Body framed, first time in a set | Estou a ver-te. Quando quiseres, começa. | I can see you. Start when you are ready. |
| Each full rep | Um, Dois, Três … (digits above 20) | One, Two, Three … |
| Partial rep | Essa foi incompleta. | That one was partial. |
| Target set, two left | Mais duas! | Two more! |
| Target set, one left | Última! | Last one! |
| Target set, halfway (target ≥ 6) | Metade feita! | Halfway there! |
| Target reached | Objetivo atingido! | Target reached! |
| No target, every 5 reps | Já são 5. Boa! | That's 5. Nice! |
| Feedback engine warning or info | the on-screen text, e.g. "Tenta manter o tronco mais direito." | the same text in English |
| Setup problem (not visible, not framed) | Não te vejo bem, afasta-te um pouco. | I can't see you well, step back a little. |
| Set end | Boa! 10 repetições, 2 incompletas. (or "Série terminada…" when nothing was counted; hold patterns say the seconds in position) | Good! 10 reps, 2 partial reps. |

Rules (`VoiceCoach`, pure Dart, unit-tested):
- **Framing prompts** (before a set only, `framingKey`): the text of the top framing issue (for example "Afasta-te um pouco"), at most every 5 s. They never delay a rep count.
- **Priority**: summary > rep count > encouragement > cue. A count is never delayed by a form cue.
- **Form and visibility cues**: at most one every 4 s, and the same key not again within 10 s. The start cue follows the same cue limit, and is spoken once per set.
- **Stale phrases**: a phrase still queued after 2 s is dropped. The summary is never dropped.
- **Summary** replaces anything still queued.
- **Bounded queue**: at most 4 phrases; the lowest priority is dropped first.
- The page speaks one phrase at a time with `flutter_tts` and starts the next when the completion handler fires.
- No phrase claims that a movement is correct, safe or well executed.

### Voz do treinador (voice choice)
- Opened from the speaker-style "Voz do treinador" icon in the camera top bar (shown while Modo PT is on) and from Perfil > Definições. Code: `feedback_engine/coach_voice_settings.dart` (pure Dart), `feedback_engine/coach_voice_tts.dart` (applies settings to `FlutterTts`), `workout_camera/coach_voice_sheet.dart` (UI).
- Voices come from `FlutterTts.getVoices` and are filtered to the app language: pt-PT first, then other Portuguese locales (for example "Português (Brasil)"); English for the English UI. **Voices that need the network are excluded**, so coach text never goes to an online speech service. A voice is excluded when the engine flags it (`network_required` = `1`), when its name contains "network", when a feature mentions the network, or when it is listed as not installed.
- Labels: `Voz 1 · Portugal`, with gender and quality only when the engine reports them. Each voice has a "Ouvir" preview. Speed (0.3–0.8 on the engine's 0–1 scale, 0.5 normal) and pitch (0.7–1.5, 1.0 normal) have sliders with a preview.
- Settings are one JSON value in `vyro_preferences` under `coach_voice_settings_v1`. Unreadable or malformed values fall back to the defaults; numbers are clamped to the engine range. The saved voice is used only when its language matches the app language. Otherwise the language default is used (`setLanguage` is always called first).
- When no local voice exists for the language, the sheet says how to install one in the Android text-to-speech settings. Nothing is downloaded by the app.

### Frases geradas pela IA do telemóvel (encouragement only)
An on-device model (Gemini Nano via ML Kit on Android, Apple Intelligence on iOS 26+; `OnDeviceLlm`) is asked for text in two places. No cloud request is made. Code: `feedback_engine/coach_llm_phrases.dart` (prompts, validation, timeouts; pure Dart apart from the `OnDeviceLlm` call).

- **Phrase bank** (when the positioning stage starts, Modo PT on, model `available`): 10–15 short encouragement phrases for the exercise name and target, in PT-PT (tu form). Timeout 8 s. The request asks for a JSON array of strings only. The phrases are used only in the non-count milestones: "Já são 5. <phrase>" (every 5 reps without a target) and "Metade feita!" with a target. "Mais duas!", "Última!", "Objetivo atingido!" and the rep counts stay fixed. The set does not wait for the bank; fixed templates are used until it arrives, or when it fails.
- **Post-set comment** (after the summary, max two sentences): written from the set's facts. The summary is spoken first. The comment is queued after it only if it arrives within 6 s and the coach is still on.
- **Setting**: "Frases geradas pela IA do telemóvel" in the voice sheet. On by default only where the model is available; switch it off to keep fixed phrases only.

Validation (applied to every model answer; a failing item is dropped, and a failing comment is not spoken):
- Phrases: 2–60 characters, at most 8 words; no digits (any script) and no spelled-out number words; no markdown (`*_#`~<>[]{}|\/"@^=`), no emoji, no line breaks; no blocked words; de-duplicated ignoring case and punctuation; at least 5 valid phrases, at most 15 kept.
- Comment: at most 200 characters and two sentences; no markdown, emoji or blocked words; every number (digits or spelled-out) must be one of the facts the model was given (full reps, partial reps, their total, duration and hold seconds, target).
- Blocked words (PT, matched on accent-free tokens or stems): seguro/segura, lesão/lesões, dor/dores, perfeito/perfeita/perfeitamente, correto/correta/corretamente, médico, técnica/tecnica, você/vocês, pra, tá, galera, beleza. (EN: safe, injur*, pain, hurt, perfect, correct, doctor, medic*, techni*.)
- Prompts ask for no technique verdict and no health advice. The model receives only the set's facts and the exercise name; no video, frames or pose data.

**Not verified:** TTS voice availability and quality per device and language; whether a late completion callback from a stopped phrase can start the next one slightly early on some platforms; the spoken text of form cues depends on the translation of each key; the output quality of the on-device model in PT-PT (no real-device run yet; the tests use a fake model).

**Target reps:** `MotionCoachPage` takes an optional `targetReps`. The workout day and workout session pages pass the planned reps (holds pass none), so the target milestones run there. The `/motion` route passes no target, so its milestones are every five reps.

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
- voice coach (`voice_coach_test.dart`): rep count words, partial reps, milestones, start cue, cue throttling, same-cue cooldown, priority, stale dropping, bounded queue, disabled coach, set summary text;
- voices and settings (`coach_voice_settings_test.dart`): parsing of the engine map, network and not-installed exclusion, language filter and order, labels, settings JSON with clamping, the key/value store with failures; the sheet (`coach_voice_sheet_test.dart`, widget test with fake voices and preview);
- generated phrases (`coach_llm_phrases_test.dart`, fake `OnDeviceLlm`): phrase and comment validation (length, words, digits, blocked words, number check), bank parsing (bare JSON, code fence, invalid JSON, non-string items, duplicates, cap), unavailable model, error, timeout (bank and comment), and the bank and comment inside `VoiceCoach`;
- preview box size and aspect in portrait and landscape (`preview_geometry_test.dart`);
- positioning guide: templates per camera view, each framing issue, aligned poses, the 1 s stability timer and its resets (`positioning_guide_test.dart`); framing prompts and the start cue before a set (`voice_framing_test.dart`); painter and widgets (`positioning_overlay_test.dart`);
- persistence, history and the setup screen;
- video analysis with a fake frame source and fake detector (`local_video_analysis_test.dart`). It does not test the native decoders.

## Limitations (not implemented or not validated)
- **Positioning guide**: not verified on devices; template thresholds are estimates; seated and bent positions are approximated (see "Positioning guide"). The guide is not a technique or safety check.
- **Not tested on a physical device yet.** Rotation (including the landscape layout and skeleton alignment), mirroring, latency, heat, battery use and TTS voices must be checked on real Android and iOS phones.
- **Gallery video import is experimental**: native decoders are unverified on devices; no accuracy measurement on real videos exists.
- 2D analysis: depth, rotation and knee tracking in the frontal plane are not reliable. Side or front placement matters, and each exercise shows advice.
- The "low light" message (`mfLowLight`) is shown when detection quality is low; the camera does not measure light, so the message may name the wrong cause.
- Load is unknown; a camera cannot judge weight or effort.
- Criteria need professional review before any validated score is shown.
- iOS: ML Kit needs iOS 15.5 or later in the Podfile. This was not built here (no Mac).
- No raw camera frames or videos are stored. Adding that would require explicit consent first.
- No machine-learning classifier of errors is used. Every check is an explicit, reviewable rule.
