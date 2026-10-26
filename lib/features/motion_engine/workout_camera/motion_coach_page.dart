import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../app/app_services.dart';
import '../../../app/l10n/strings.dart';
import '../../../core/ai/on_device_llm.dart';
import '../../../core/platform/orientation_lock.dart';
import '../../../core/ui/vyro_ui.dart';
import '../exercise_analysis/exercise_analysis_engine.dart';
import '../exercise_registry/exercise_analysis_registry.dart';
import '../feedback_engine/coach_llm_phrases.dart';
import '../feedback_engine/coach_voice_settings.dart';
import '../feedback_engine/coach_voice_tts.dart';
import '../feedback_engine/feedback_engine.dart';
import '../feedback_engine/voice_coach.dart';
import '../movement_patterns/movement_pattern.dart';
import '../repetition_counter/rep_counter_engine.dart';
import '../pose_detection/pose_detection_service.dart';
import '../pose_detection/pose_models.dart';
import '../workout_analysis_history/motion_history_repository.dart';
import 'positioning_guide.dart';
import 'positioning_overlay.dart';
import 'coach_voice_sheet.dart';
import 'preview_geometry.dart';
import 'skeleton_painter.dart';
import 'motion_sampling_policy.dart';
import '../video/video_analysis_page.dart';

/// [positioning]: camera open, ghost guide and framing check, no counting.
enum _Stage { setup, positioning, running, paused, done }

/// Preference key for the spoken coach ("Modo PT"), stored in the local
/// key/value table. Value `'on'` or `'off'`; absent means off.
const kVoiceCoachPreferenceKey = 'motion_voice_coach_v1';

/// Camera set with live rep counting and feedback for one exercise.
///
/// Camera frames are analysed on the device (ML Kit) at most ~15 times per
/// second, one at a time; nothing visual is stored. The camera is released
/// when the set ends, the screen closes or the app goes to background.
class MotionCoachPage extends StatefulWidget {
  const MotionCoachPage({
    super.key,
    required this.exerciseKey,
    required this.exerciseName,
    this.registry,
    this.detectorFactory,
    this.targetReps,
  });

  final String exerciseKey;
  final String exerciseName;
  final ExerciseAnalysisRegistry? registry;

  /// Planned reps for the set, used by the spoken coach for milestones
  /// ("Metade feita!", "Última!"). Null or <= 0 means no target: the coach
  /// then announces every five reps instead.
  final int? targetReps;

  /// Override for tests or alternative detectors.
  final PoseDetectionService Function()? detectorFactory;

  @override
  State<MotionCoachPage> createState() => _MotionCoachPageState();
}

class _MotionCoachPageState extends State<MotionCoachPage>
    with WidgetsBindingObserver {
  final _sampling = MotionSamplingPolicy();
  final _readiness = PoseReadinessGate();
  int _runId = 0, _frames = 0, _skipped = 0;
  double _totalInferenceMs = 0;
  bool _finishing = false, _userCorrected = false;
  int? _savedId;

  late final ExerciseAnalysisConfig _config =
      (widget.registry ?? ExerciseAnalysisRegistry()).configFor(
        widget.exerciseKey,
      );
  late final MovementPattern? _pattern = _config.resolve();

  /// The planned target, or null when absent or not positive.
  int? get _plannedReps {
    final target = widget.targetReps;
    return target != null && target > 0 ? target : null;
  }

  _Stage _stage = _Stage.setup;
  CameraController? _camera;
  List<CameraDescription> _cameras = const [];
  CameraLensDirection _lens = CameraLensDirection.front;
  PoseDetectionService? _detector;
  ExerciseAnalysisEngine? _engine;
  final _feedback = FeedbackEngine();
  final _clock = Stopwatch();
  final _tts = FlutterTts();
  late final CoachVoiceTts _voiceTts = CoachVoiceTts(_tts);
  // Spoken coach: `_coach` queues phrases; `_speaking` is true while one
  // phrase is playing and the next one starts when it completes.
  VoiceCoach? _coach;
  bool _coachOn = false, _coachLoaded = false, _speaking = false;
  // Voice, speed, pitch and the on-device phrase toggle (see coach_voice_settings).
  CoachVoiceSettings _voiceSettings = const CoachVoiceSettings();
  // Generated encouragement phrases for one exercise and target, reused across
  // sets on this screen.
  String? _phraseBankKey;
  List<String>? _phraseBank;
  bool _busy = false;
  Duration _lastFrame = Duration.zero;
  BodyPose? _pose;
  AnalysisUpdate? _update;
  FeedbackMessage? _message;
  SetSummary? _summary;
  DateTime? _startedAt;
  double _latencyMs = 0;
  String? _error;
  Timer? _ticker;

  // Positioning guide: framing checks run in positioning and while counting.
  // `_setOffset` is the clock value when counting started, so the set timer
  // starts at 0 while the clock (also used by the voice coach) keeps running.
  FramingTracker? _framingTracker;
  FramingAssessment? _framing;
  bool _guideVisible = false;
  bool? _tipsOpen;
  Duration _setOffset = Duration.zero;

  // True while this page holds the landscape allowance; see OrientationLock.
  bool _holdsOrientation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _acquireOrientation();
    _tts.setCompletionHandler(_onSpeechEnded);
    _tts.setCancelHandler(_onSpeechEnded);
    _tts.setErrorHandler((_) => _onSpeechEnded());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_coachLoaded) return;
    _coachLoaded = true;
    unawaited(_loadCoachPreference());
  }

  Future<void> _loadCoachPreference() async {
    final database = AppServicesScope.of(context).database;
    try {
      final stored = await database.getPreference(kVoiceCoachPreferenceKey);
      if (mounted && stored == 'on') setState(() => _coachOn = true);
    } catch (_) {
      // Preference unavailable: keep the default (off).
    }
    final settings = await coachVoicePreferencesFor(database).load();
    if (mounted) _voiceSettings = settings;
  }

  /// Applies the saved voice, speed and pitch to the set's engine.
  Future<void> _applyVoice(VyroStrings t) => _voiceTts.apply(
    _voiceSettings,
    t.isEnglish ? VoiceLanguage.english : VoiceLanguage.portuguese,
  );

  /// "Voz do treinador" sheet. Settings are reloaded when it closes.
  Future<void> _openVoiceSheet() async {
    _silence(clearQueue: true);
    await showCoachVoiceSheet(context);
    if (!mounted) return;
    final database = AppServicesScope.of(context).database;
    _voiceSettings = await coachVoicePreferencesFor(database).load();
    if (mounted) {
      await _applyVoice(stringsOf(context));
    }
  }

  void _acquireOrientation() {
    if (_holdsOrientation) return;
    _holdsOrientation = true;
    // Best effort: a failed orientation request must not break the camera.
    unawaited(OrientationLock.allowAllOrientations().catchError((Object _) {}));
  }

  void _releaseOrientation() {
    if (!_holdsOrientation) return;
    _holdsOrientation = false;
    unawaited(
      OrientationLock.releaseAllOrientations().catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    _runId++;
    _releaseOrientation();
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    unawaited(_releaseCamera());
    unawaited(_detector?.close());
    unawaited(_tts.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_stage == _Stage.positioning) {
      if (state == AppLifecycleState.inactive ||
          state == AppLifecycleState.paused) {
        unawaited(_cancelPositioning());
      }
      return;
    }
    if (_stage != _Stage.running && _stage != _Stage.paused) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _pause();
      unawaited(_releaseCamera());
    }
  }

  Future<void> _releaseCamera() async {
    final camera = _camera;
    _camera = null;
    if (camera == null) return;
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
    } catch (_) {}
    await camera.dispose();
  }

  Future<void> _openCamera() async {
    final detector = _detector ??=
        (widget.detectorFactory ?? MlKitPoseDetectionService.new)();
    if (_cameras.isEmpty) _cameras = await availableCameras();
    if (_cameras.isEmpty) throw CameraException('no_camera', '');
    final description = _cameras.firstWhere(
      (c) => c.lensDirection == _lens,
      orElse: () => _cameras.first,
    );
    final controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: detector.imageFormat,
    );
    await controller.initialize();
    // Also stop when the user left positioning while the camera was starting.
    if (!mounted || _stage == _Stage.setup || _stage == _Stage.done) {
      await controller.dispose();
      return;
    }
    await controller.startImageStream((image) => _onFrame(image, description));
    setState(() => _camera = controller);
  }

  /// Opens the camera before the set. The ghost guide and the framing check
  /// run on the live preview; nothing is counted until [_start].
  Future<void> _openPositioning() async {
    final pattern = _pattern;
    if (pattern == null) return;
    final t = stringsOf(context);
    setState(() {
      _error = null;
      _stage = _Stage.positioning;
      _framingTracker = FramingTracker(pattern);
      _framing = null;
      _guideVisible = true;
      _tipsOpen = null;
      _setOffset = Duration.zero;
    });
    final coach = VoiceCoach(
      language: t.isEnglish ? VoiceLanguage.english : VoiceLanguage.portuguese,
      enabled: _coachOn,
      cueText: t.get,
    )..startSet(targetReps: _plannedReps);
    _coach = coach;
    _silence(clearQueue: true);
    _clock
      ..reset()
      ..start();
    final llm = AppServicesScope.of(context).llm;
    try {
      await _applyVoice(t);
      await _openCamera();
    } catch (_) {
      await _releaseCamera();
      _clock
        ..stop()
        ..reset();
      if (mounted) {
        setState(() {
          _stage = _Stage.setup;
          _error = 'maCameraError';
        });
      }
    }
    // Background request: the set does not wait for it, and the fixed
    // milestone phrases are used until (and unless) the bank arrives.
    if (_coachOn && _voiceSettings.llmPhrases != false) {
      unawaited(_loadPhraseBank(coach, t, llm));
    }
  }

  /// Asks the on-device model for encouragement phrases. Ignored when the
  /// screen has moved on, when the coach is off, or when the model fails.
  Future<void> _loadPhraseBank(
    VoiceCoach coach,
    VyroStrings t,
    OnDeviceLlm llm,
  ) async {
    final target = _plannedReps;
    final language = t.isEnglish
        ? VoiceLanguage.english
        : VoiceLanguage.portuguese;
    final key = '${widget.exerciseKey}|$target|${language.name}';
    final cached = _phraseBank;
    if (_phraseBankKey == key && cached != null) {
      coach.setEncouragementBank(cached);
      return;
    }
    final bank = await CoachLlmPhrases(llm).generatePhraseBank(
      exerciseName: widget.exerciseName,
      targetReps: target,
      language: language,
    );
    if (!mounted || !identical(_coach, coach) || bank.isEmpty) return;
    _phraseBankKey = key;
    _phraseBank = bank;
    coach.setEncouragementBank(bank);
  }

  /// Back to setup without counting; releases the camera.
  Future<void> _cancelPositioning() async {
    if (_stage != _Stage.positioning) return;
    _runId++;
    _silence(clearQueue: true);
    _clock
      ..stop()
      ..reset();
    _framingTracker = null;
    if (mounted) {
      setState(() {
        _stage = _Stage.setup;
        _framing = null;
      });
    }
    await _releaseCamera();
  }

  /// Starts counting. The camera is already open from [_openPositioning].
  Future<void> _start() async {
    final pattern = _pattern;
    if (pattern == null || _stage != _Stage.positioning) return;
    _silence(clearQueue: true);
    if (_camera == null) {
      try {
        await _openCamera();
      } catch (_) {
        await _releaseCamera();
        if (mounted) {
          setState(() {
            _stage = _Stage.setup;
            _error = 'maCameraError';
          });
        }
        return;
      }
    }
    _coach?.setTarget(_plannedReps);
    _setOffset = _clock.elapsed;
    _clock.start();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _stage == _Stage.running) setState(() {});
    });
    setState(() {
      _error = null;
      _runId++;
      _readiness.reset();
      _lastFrame = Duration.zero;
      _frames = 0;
      _skipped = 0;
      _totalInferenceMs = 0;
      _savedId = null;
      _userCorrected = false;
      _engine = ExerciseAnalysisEngine(pattern: pattern);
      _feedback.reset();
      _summary = null;
      _message = null;
      _update = null;
      _startedAt = DateTime.now();
      _guideVisible = false;
      _stage = _Stage.running;
    });
  }

  void _toggleGuide() => setState(() => _guideVisible = !_guideVisible);

  /// Framing check on one pose. Updates the status line and the ghost, hides
  /// the ghost once the body is ready and stable, and (before a set only)
  /// speaks the top framing issue or the start cue.
  void _checkFraming(BodyPose? pose, Duration now) {
    final tracker = _framingTracker;
    if (tracker == null) return;
    final assessment = tracker.update(pose);
    final wasReady = _framing?.status == FramingStatus.ready;
    final ready = assessment.status == FramingStatus.ready;
    setState(() {
      _pose = pose;
      _framing = assessment;
      if (ready && !wasReady) _guideVisible = false;
    });
    if (_stage != _Stage.positioning) return;
    if (ready) {
      _voice(VoiceObservation(at: now, ready: true));
    } else {
      final top = assessment.top;
      if (top != null) {
        _voice(
          VoiceObservation(
            at: now,
            framingKey: framingMessageKey(
              top,
              PositioningGuide.forPattern(_pattern!),
            ),
          ),
        );
      }
    }
  }

  // ------------------------------------------------------------ voice coach

  void _onSpeechEnded() {
    if (!_speaking) return;
    _speaking = false;
    _speakNext();
  }

  /// Plays the next queued phrase if nothing is being said.
  void _speakNext() {
    final coach = _coach;
    if (coach == null || !_coachOn || _speaking || !mounted) return;
    final phrase = coach.next(_clock.elapsed);
    if (phrase == null) return;
    _speaking = true;
    unawaited(
      _tts.speak(phrase.text).catchError((_) {
        _onSpeechEnded();
        return 0;
      }),
    );
  }

  /// Stops the current phrase at once; [clearQueue] also drops queued ones.
  /// The set itself keeps running.
  void _silence({required bool clearQueue}) {
    if (clearQueue) _coach?.clear();
    _speaking = false;
    unawaited(_tts.stop().catchError((_) => 0));
  }

  void _voice(VoiceObservation observation) {
    final coach = _coach;
    if (coach == null || !_coachOn) return;
    coach.observe(observation);
    _speakNext();
  }

  Future<void> _setCoachOn(bool on) async {
    _coachOn = on;
    _coach?.setEnabled(on);
    if (!on) _silence(clearQueue: true);
    if (mounted) setState(() {});
    try {
      await AppServicesScope.of(
        context,
      ).database.setPreference(kVoiceCoachPreferenceKey, on ? 'on' : 'off');
    } catch (_) {
      // The toggle still works for this session.
    }
  }

  void _pause() {
    if (_stage != _Stage.running) return;
    _clock.stop();
    _runId++;
    _engine?.interrupt();
    _readiness.reset();
    setState(() => _stage = _Stage.paused);
  }

  Future<void> _resume() async {
    if (_camera == null) {
      try {
        await _openCamera();
      } catch (_) {
        setState(() => _error = 'maCameraError');
        return;
      }
    }
    _clock.start();
    setState(() => _stage = _Stage.running);
  }

  Future<void> _flip() async {
    _runId++;
    _engine?.interrupt();
    _readiness.reset();
    _framingTracker?.reset();
    _lens = _lens == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    await _releaseCamera();
    try {
      await _openCamera();
    } catch (_) {
      if (mounted) setState(() => _error = 'maCameraError');
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _runId++;
    if (mounted) setState(() => _stage = _Stage.paused);
    _clock.stop();
    _ticker?.cancel();
    await _releaseCamera();
    final engine = _engine;
    if (engine == null || !mounted) {
      _finishing = false;
      return;
    }
    final summary = engine.summary();
    final services = AppServicesScope.of(context);
    final t = stringsOf(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (summary.fullReps + summary.partialReps > 0 ||
        summary.holdTime > Duration.zero) {
      _savedId = await MotionHistoryRepository(services.database).save(
        exerciseKey: widget.exerciseKey,
        startedAt: _startedAt ?? DateTime.now(),
        summary: summary,
      );
      messenger?.showSnackBar(SnackBar(content: Text(t.get('maSaved'))));
    }
    await services.localIntelligence.recordMotionPerformance(
      frames: _frames,
      skipped: _skipped,
      inferenceMs: _totalInferenceMs,
    );
    _finishing = false;
    if (mounted) {
      setState(() {
        _summary = summary;
        _stage = _Stage.done;
      });
      _voice(VoiceObservation(at: _clock.elapsed, summary: summary));
      if (_coachOn && _voiceSettings.llmPhrases != false) {
        _requestCommentary(summary, t, services.llm);
      }
    }
  }

  /// Asks the on-device model for a short comment on the finished set. The
  /// factual summary is already spoken; the comment is queued after it only
  /// if it arrives in time and the coach is still on.
  void _requestCommentary(SetSummary summary, VyroStrings t, OnDeviceLlm llm) {
    final coach = _coach;
    if (coach == null) return;
    final facts = CoachSetFacts.fromSummary(
      summary,
      exerciseName: widget.exerciseName,
      targetReps: _plannedReps,
      observations: {
        for (final event in summary.events) t.get(event.messageKey),
      }.toList(),
    );
    final language = t.isEnglish
        ? VoiceLanguage.english
        : VoiceLanguage.portuguese;
    unawaited(() async {
      final text = await CoachLlmPhrases(
        llm,
      ).generateCommentary(facts: facts, language: language);
      if (text == null ||
          !mounted ||
          _stage != _Stage.done ||
          !_coachOn ||
          !identical(_coach, coach)) {
        return;
      }
      coach.addCommentary(text, _clock.elapsed);
      _speakNext();
    }());
  }

  /// Camera callback: drops frames while busy or within [_frameInterval].
  void _onFrame(CameraImage image, CameraDescription description) {
    final camera = _camera;
    if (camera == null ||
        (_stage != _Stage.running && _stage != _Stage.positioning)) {
      return;
    }
    if (_busy) {
      _skipped++;
      return;
    }
    final now = _clock.elapsed;
    final interval = _sampling.interval(
      phase: _update?.phase ?? RepPhase.waitingForStart,
      quality: _update?.detectionQuality ?? 0,
      latencyMs: _latencyMs,
    );
    if (now - _lastFrame < interval) {
      _skipped++;
      return;
    }
    final run = _runId;
    _busy = true;
    _lastFrame = now;
    final watch = Stopwatch()..start();
    _detector!
        .detect(image, description, camera.value.deviceOrientation, now)
        .then((pose) {
          watch.stop();
          _frames++;
          _totalInferenceMs += watch.elapsedMilliseconds;
          _latencyMs = _latencyMs == 0
              ? watch.elapsedMilliseconds.toDouble()
              : _latencyMs * 0.9 + watch.elapsedMilliseconds * 0.1;
          if (!mounted || run != _runId) return;
          if (_stage == _Stage.positioning) {
            _checkFraming(pose, now);
            return;
          }
          if (_stage != _Stage.running) return;
          _checkFraming(pose, now);
          if (!_readiness.accept(pose, _pattern!.requiredLandmarks, now)) {
            final message = _feedback.offer(const [
              FeedbackCandidate('mfAdjustCamera', FeedbackLevel.setup),
            ], now);
            setState(() {
              _pose = pose;
              if (message != null) _message = message;
            });
            _voice(VoiceObservation(at: now, feedback: message));
            return;
          }
          final update = _engine!.process(pose, now);
          final message = _feedback.offer(update.feedback, now);
          setState(() {
            _pose = pose;
            _update = update;
            if (message != null) _message = message;
          });
          _voice(
            VoiceObservation(
              at: now,
              ready: true,
              repEvent: update.repEvent?.type,
              fullReps: update.fullReps,
              partialReps: update.partialReps,
              feedback: message,
            ),
          );
          if (update.setEnded) unawaited(_finish());
        })
        .catchError((_) {})
        .whenComplete(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => switch (_stage) {
    _Stage.setup => _setupView(context),
    _Stage.done => _summaryView(context),
    _ => _cameraView(context),
  };

  // ---------------------------------------------------------------- setup

  Widget _setupView(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final pattern = _pattern;
    return VyroSubpageScaffold(
      title: t.get('maTitle'),
      footer: pattern == null || kIsWeb
          ? null
          : VyroPrimaryButton(
              label: t.get('maPrepare'),
              icon: Icons.videocam_rounded,
              onPressed: _openPositioning,
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          VyroCard(
            tint: theme.colorScheme.primary.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.exerciseName, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (_config.support == AnalysisSupport.limited)
                      _Badge(t.get('maLimited'), theme.colorScheme.tertiary),
                    if (pattern?.experimental ?? false)
                      _Badge(
                        t.get('maExperimental'),
                        theme.colorScheme.tertiary,
                      ),
                  ],
                ),
                if (_config.noteKey != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    t.get('maSetupTitle'),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.get(_config.noteKey!),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (kIsWeb)
            Text(t.get('maNotSupported'), style: theme.textTheme.bodyMedium),
          if (_error != null)
            Text(
              t.get(_error!),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          _InfoRow(Icons.lock_outline_rounded, t.get('maPrivacy')),
          if (pattern != null && !kIsWeb)
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => VideoAnalysisPage(
                    exerciseKey: widget.exerciseKey,
                    exerciseName: widget.exerciseName,
                    pattern: pattern,
                  ),
                ),
              ),
              icon: const Icon(Icons.video_library_outlined),
              label: Text(t.get('vidEntry')),
            ),
          const SizedBox(height: 8),
          _InfoRow(Icons.info_outline_rounded, t.get('maDisclaimer')),
          const SizedBox(height: 22),
          VyroSectionTitle(label: t.get('maHistory')),
          _HistoryList(exerciseKey: widget.exerciseKey),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- camera

  static const _sidePanelWidth = 280.0;

  Widget _cameraView(BuildContext context) {
    final t = stringsOf(context);
    final camera = _camera;
    final update = _update;
    final pattern = _pattern!;
    final elapsed = _clock.elapsed - _setOffset;
    final hold = pattern.mode == PatternMode.hold;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final positioning = _stage == _Stage.positioning;
    final guide = PositioningGuide.forPattern(pattern);
    final framing = _framing;
    final framingTop = framing?.top;
    final framingReady = framing?.status == FramingStatus.ready;
    final framingText = framing == null
        ? t.get('frWaiting')
        : framingReady
        ? t.get('frReady')
        : framingTop == null
        ? t.get('frHold')
        : t.get(framingMessageKey(framingTop, guide));
    final showPill = positioning || _guideVisible;
    // Landscape: the controls move to a side panel so the preview keeps the
    // full height. The preview, top bar and banner stop at the panel edge.
    final sideInset = landscape ? _sidePanelWidth : 0.0;
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            right: sideInset,
            child: camera != null && camera.value.isInitialized
                ? _Preview(
                    camera: camera,
                    pose: _pose,
                    mirror:
                        camera.description.lensDirection ==
                        CameraLensDirection.front,
                    guide: _guideVisible ? guide : null,
                    guideAligned: framing?.issues.isEmpty ?? false,
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          // Top bar.
          Positioned(
            left: 0,
            top: 0,
            right: sideInset,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    _GlassIcon(
                      icon: Icons.close_rounded,
                      tooltip: t.get(positioning ? 'frBack' : 'maFinish'),
                      onTap: positioning ? _cancelPositioning : _finish,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.exerciseName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          if (!positioning)
                            _QualityPill(
                              quality: update?.detectionQuality ?? 0,
                              latencyMs: _latencyMs,
                            ),
                        ],
                      ),
                    ),
                    if (_coachOn) ...[
                      _GlassIcon(
                        icon: Icons.speaker_notes_off_rounded,
                        tooltip: t.isEnglish ? 'Silence' : 'Silenciar',
                        onTap: () => _silence(clearQueue: true),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _GlassIcon(
                      icon: _coachOn
                          ? Icons.record_voice_over_rounded
                          : Icons.voice_over_off_rounded,
                      tooltip: t.isEnglish ? 'Trainer voice' : 'Modo PT (voz)',
                      onTap: () => _setCoachOn(!_coachOn),
                    ),
                    const SizedBox(width: 8),
                    if (_coachOn) ...[
                      _GlassIcon(
                        icon: Icons.tune_rounded,
                        tooltip: t.get('coachVoiceTitle'),
                        onTap: _openVoiceSheet,
                      ),
                      const SizedBox(width: 8),
                    ],
                    _GlassIcon(
                      icon: Icons.accessibility_new_rounded,
                      tooltip: t.get(
                        _guideVisible ? 'maHideGuide' : 'maShowGuide',
                      ),
                      onTap: _toggleGuide,
                    ),
                    const SizedBox(width: 8),
                    _GlassIcon(
                      icon: Icons.cameraswitch_rounded,
                      tooltip: t.get('maFlip'),
                      onTap: _flip,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Framing status line: before a set, and while the guide is shown.
          if (showPill)
            Positioned(
              left: 16,
              right: 16 + sideInset,
              top: topInset + 76,
              child: FramingStatusPill(text: framingText, ready: framingReady),
            ),
          // Feedback banner.
          Positioned(
            left: 16,
            right: 16 + sideInset,
            top: topInset + 76 + (showPill ? 60 : 0),
            child: AnimatedSwitcher(
              duration: VyroMotion.normal,
              child:
                  _message == null ||
                      elapsed - _message!.at > const Duration(seconds: 3)
                  ? const SizedBox.shrink()
                  : _FeedbackBanner(
                      key: ValueKey(_message!.at),
                      message: _message!,
                    ),
            ),
          ),
          // Controls: bottom panel (portrait) or side panel (landscape).
          if (landscape)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: _sidePanelWidth,
              child: VyroGlass(
                borderRadius: BorderRadius.zero,
                child: SafeArea(
                  left: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: positioning
                        ? _positioningPanel(
                            context,
                            t: t,
                            guide: guide,
                            landscape: true,
                          )
                        : _controlsPanel(
                            context,
                            t: t,
                            hold: hold,
                            elapsed: elapsed,
                            update: update,
                            landscape: true,
                          ),
                  ),
                ),
              ),
            )
          else
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VyroGlass(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                    child: positioning
                        ? _positioningPanel(
                            context,
                            t: t,
                            guide: guide,
                            landscape: false,
                          )
                        : _controlsPanel(
                            context,
                            t: t,
                            hold: hold,
                            elapsed: elapsed,
                            update: update,
                            landscape: false,
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Before a set: a collapsible tips card, the framing note, and the start and
  /// back buttons. Collapsed by default in portrait so the ghost stays visible.
  Widget _positioningPanel(
    BuildContext context, {
    required VyroStrings t,
    required PositioningGuide guide,
    required bool landscape,
  }) {
    final theme = Theme.of(context);
    final open = _tipsOpen ?? landscape;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _tipsOpen = !open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.get('maSetupTitle'),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Icon(
                  open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                ),
              ],
            ),
          ),
        ),
        if (open) ...[
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.3,
            ),
            child: SingleChildScrollView(
              child: PositioningTipsCard(
                rows: [
                  for (final tip in guide.tips)
                    (guideTipIcon(tip), t.get(guideTipKey(tip))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(t.get('frGuideNote'), style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(t.get('frStart')),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _cancelPositioning,
          icon: const Icon(Icons.arrow_back_rounded),
          label: Text(t.get('frBack')),
        ),
      ],
    );
  }

  /// Count, clock, status and buttons. Shared by the portrait bottom panel and
  /// the landscape side panel.
  Widget _controlsPanel(
    BuildContext context, {
    required VyroStrings t,
    required bool hold,
    required Duration elapsed,
    required AnalysisUpdate? update,
    required bool landscape,
  }) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VyroAnimatedNumber(
                    value: hold
                        ? (update?.holdTime.inMilliseconds ?? 0) / 1000
                        : (update?.fullReps ?? 0).toDouble(),
                    suffix: hold ? ' s' : '',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontSize: landscape ? 40 : 54,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    hold
                        ? t.get('maHold')
                        : '${t.get('maReps')} · ${update?.partialReps ?? 0} ${t.get('maPartial')}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _clockText(elapsed),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 6),
                _StatusChip(status: update?.status ?? AnalysisStatus.waiting),
              ],
            ),
          ],
        ),
        if (!hold) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (update?.progress ?? 0).clamp(0.0, 1.0),
              minHeight: 6,
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (landscape) ...[
          OutlinedButton.icon(
            onPressed: _stage == _Stage.running ? _pause : _resume,
            icon: Icon(
              _stage == _Stage.running
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
            ),
            label: Text(
              t.get(_stage == _Stage.running ? 'maPause' : 'maResume'),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _finish,
            icon: const Icon(Icons.stop_rounded),
            label: Text(t.get('maFinish')),
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _stage == _Stage.running ? _pause : _resume,
                  icon: Icon(
                    _stage == _Stage.running
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    t.get(_stage == _Stage.running ? 'maPause' : 'maResume'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _finish,
                  icon: const Icon(Icons.stop_rounded),
                  label: Text(t.get('maFinish')),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _correctCounts() async {
    final original = _summary;
    if (original == null) return;
    final services = AppServicesScope.of(context);
    final t = stringsOf(context);
    final full = TextEditingController(text: '${original.fullReps}');
    final partial = TextEditingController(text: '${original.partialReps}');
    final value = await showDialog<(int, int)>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          t.isEnglish ? 'Confirm your count' : 'Confirma a tua contagem',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: full,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: t.isEnglish
                    ? 'Complete reps'
                    : 'Repetições completas',
              ),
            ),
            TextField(
              controller: partial,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: t.isEnglish ? 'Partial reps' : 'Repetições parciais',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(t.get('cancel')),
          ),
          FilledButton(
            onPressed: () {
              final f = int.tryParse(full.text);
              final p = int.tryParse(partial.text);
              if (f != null &&
                  p != null &&
                  f >= 0 &&
                  p >= 0 &&
                  f <= 1000 &&
                  p <= 1000)
                Navigator.pop(c, (f, p));
            },
            child: Text(t.get('save')),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      full.dispose();
      partial.dispose();
    });
    if (value == null || !mounted) return;
    try {
      final repository = MotionHistoryRepository(services.database);
      final corrected = original.withUserCounts(value.$1, value.$2);
      _savedId ??= await repository.save(
        exerciseKey: widget.exerciseKey,
        startedAt: _startedAt ?? DateTime.now(),
        summary: original,
      );
      await repository.correctCounts(
        _savedId!,
        full: value.$1,
        partial: value.$2,
        originalFull: original.fullReps,
        originalPartial: original.partialReps,
      );
      if (mounted)
        setState(() {
          _summary = corrected;
          _userCorrected = true;
        });
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.get('localError'))));
    }
  }

  static String _clockText(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  // -------------------------------------------------------------- summary

  Widget _summaryView(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final s = _summary!;
    final counts = <String, int>{};
    for (final e in s.events) {
      counts[e.messageKey] = (counts[e.messageKey] ?? 0) + 1;
    }
    final hold = _pattern?.mode == PatternMode.hold;
    return VyroSubpageScaffold(
      title: t.get('maSummary'),
      footer: VyroPrimaryButton(
        label: t.get('maStart'),
        icon: Icons.replay_rounded,
        onPressed: _openPositioning,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          VyroCard(
            tint: theme.colorScheme.primary.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.exerciseName, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  hold
                      ? '${(s.holdTime.inMilliseconds / 1000).toStringAsFixed(0)} s'
                      : '${s.fullReps} ${t.get('maReps')}',
                  style: theme.textTheme.displaySmall,
                ),
                if (!hold)
                  Text(
                    '${s.partialReps} ${t.get('maPartial')}',
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: 10),
                _StatusChip(status: s.status),
              ],
            ),
          ),
          if (!hold)
            TextButton.icon(
              onPressed: _correctCounts,
              icon: const Icon(Icons.edit_outlined),
              label: Text(
                t.isEnglish ? 'Correct repetitions' : 'Corrigir repetições',
              ),
            ),
          if (_userCorrected)
            Text(
              t.isEnglish
                  ? 'Counts confirmed by you; observation quality is unchanged.'
                  : 'Contagens confirmadas por ti; a qualidade da observação mantém-se.',
            ),
          const SizedBox(height: 14),
          VyroGroupedSection(
            children: [
              VyroListRow(
                icon: Icons.timer_outlined,
                title: t.get('maDuration'),
                value: _clockText(s.duration),
              ),
              VyroListRow(
                icon: Icons.visibility_outlined,
                title: t.get('maObserved'),
                value: '${(s.observedRatio * 100).round()}%',
              ),
              VyroListRow(
                icon: Icons.verified_outlined,
                title: t.get('maConfidence'),
                value: '${(s.meanConfidence * 100).round()}%',
              ),
            ],
          ),
          const SizedBox(height: 18),
          VyroSectionTitle(label: t.get('maEvents')),
          if (counts.isEmpty)
            Text(t.get('maNoEvents'), style: theme.textTheme.bodyMedium)
          else
            VyroGroupedSection(
              children: [
                for (final entry in counts.entries)
                  VyroListRow(
                    icon: Icons.warning_amber_rounded,
                    iconColor: theme.colorScheme.tertiary,
                    title: t.get(entry.key),
                    value: '${entry.value}×',
                  ),
              ],
            ),
          const SizedBox(height: 14),
          Text(
            s.techniqueScore == null
                ? t.get('maScoreNote')
                : '${(s.techniqueScore! * 100).round()}%',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Text(t.get('maDisclaimer'), style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.camera,
    required this.pose,
    required this.mirror,
    this.guide,
    this.guideAligned = false,
  });
  final CameraController camera;
  final BodyPose? pose;
  final bool mirror;

  /// Ghost positioning guide, drawn in the same box as the image.
  final PositioningGuide? guide;
  final bool guideAligned;

  @override
  Widget build(BuildContext context) {
    final value = camera.value;
    // Same orientation source as CameraPreview, so both pick the same ratio.
    final orientation =
        value.previewPauseOrientation ??
        value.lockedCaptureOrientation ??
        value.deviceOrientation;
    final box = uprightPreviewSize(
      value.previewSize ?? const Size(640, 480),
      landscape: isLandscapePreview(orientation),
    );
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: box.width,
          height: box.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(camera),
              if (guide case final positioning?)
                IgnorePointer(
                  child: CustomPaint(
                    painter: PositioningOverlayPainter(
                      guide: positioning,
                      aligned: guideAligned,
                      accent: Theme.of(context).colorScheme.primary,
                      neutral: Colors.white,
                      mirror: mirror,
                    ),
                  ),
                ),
              CustomPaint(
                painter: SkeletonPainter(
                  pose: pose,
                  mirror: mirror,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({super.key, required this.message});
  final FeedbackMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (message.level) {
      FeedbackLevel.success => (Icons.check_circle_rounded, scheme.primary),
      FeedbackLevel.info => (Icons.info_rounded, Colors.white),
      FeedbackLevel.warning => (Icons.warning_amber_rounded, scheme.tertiary),
      FeedbackLevel.setup => (Icons.videocam_off_rounded, scheme.error),
    };
    return VyroGlass(
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                stringsOf(context).get(message.key),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final AnalysisStatus status;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final scheme = Theme.of(context).colorScheme;
    final (key, color) = switch (status) {
      AnalysisStatus.withinCriteria => ('maStatusWithin', scheme.primary),
      AnalysisStatus.possibleIssue => ('maStatusIssue', scheme.tertiary),
      AnalysisStatus.notObservable => ('maStatusNotObservable', scheme.error),
      AnalysisStatus.inconclusive => ('maStatusInconclusive', Colors.grey),
      AnalysisStatus.waiting => ('maStatusWaiting', Colors.grey),
    };
    return _Badge(t.get(key), color);
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
    ),
  );
}

class _QualityPill extends StatelessWidget {
  const _QualityPill({required this.quality, required this.latencyMs});
  final double quality;
  final double latencyMs;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final scheme = Theme.of(context).colorScheme;
    final color = quality >= 0.7
        ? scheme.primary
        : quality >= 0.45
        ? scheme.tertiary
        : scheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            '${t.get('maDetection')} ${(quality * 100).round()}%'
            '${latencyMs > 0 ? ' · ${latencyMs.round()} ms' : ''}',
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _GlassIcon extends StatelessWidget {
  const _GlassIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: VyroGlass(
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: Theme.of(context).textTheme.bodySmall?.color),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
    ],
  );
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.exerciseKey});
  final String exerciseKey;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final repository = MotionHistoryRepository(
      AppServicesScope.of(context).database,
    );
    return StreamBuilder(
      stream: repository.watch(exerciseKey: exerciseKey, limit: 10),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const [];
        if (rows.isEmpty) {
          return Text(
            t.get('maHistoryEmpty'),
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        return VyroGroupedSection(
          children: [
            for (final r in rows)
              VyroListRow(
                icon: Icons.history_rounded,
                title: r.holdMs > 0 && r.fullReps == 0
                    ? '${(r.holdMs / 1000).round()} s'
                    : '${r.fullReps} ${t.get('maReps')} · ${r.partialReps} ${t.get('maPartial')}',
                subtitle:
                    '${r.startedAt.day.toString().padLeft(2, '0')}/${r.startedAt.month.toString().padLeft(2, '0')} · '
                    '${t.get(switch (r.status) {
                      'withinCriteria' => 'maStatusWithin',
                      'possibleIssue' => 'maStatusIssue',
                      'notObservable' => 'maStatusNotObservable',
                      _ => 'maStatusInconclusive',
                    })}',
                value: '${(r.observedRatio * 100).round()}%',
              ),
          ],
        );
      },
    );
  }
}
