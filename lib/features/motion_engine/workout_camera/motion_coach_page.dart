import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../app/app_services.dart';
import '../../../app/l10n/strings.dart';
import '../../../core/ui/vyro_ui.dart';
import '../exercise_analysis/exercise_analysis_engine.dart';
import '../exercise_registry/exercise_analysis_registry.dart';
import '../feedback_engine/feedback_engine.dart';
import '../movement_patterns/movement_pattern.dart';
import '../pose_detection/pose_detection_service.dart';
import '../pose_detection/pose_models.dart';
import '../workout_analysis_history/motion_history_repository.dart';
import 'skeleton_painter.dart';

enum _Stage { setup, running, paused, done }

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
  });

  final String exerciseKey;
  final String exerciseName;
  final ExerciseAnalysisRegistry? registry;

  /// Override for tests or alternative detectors.
  final PoseDetectionService Function()? detectorFactory;

  @override
  State<MotionCoachPage> createState() => _MotionCoachPageState();
}

class _MotionCoachPageState extends State<MotionCoachPage>
    with WidgetsBindingObserver {
  static const _frameInterval = Duration(milliseconds: 66);

  late final ExerciseAnalysisConfig _config =
      (widget.registry ?? ExerciseAnalysisRegistry()).configFor(
        widget.exerciseKey,
      );
  late final MovementPattern? _pattern = _config.resolve();

  _Stage _stage = _Stage.setup;
  CameraController? _camera;
  List<CameraDescription> _cameras = const [];
  CameraLensDirection _lens = CameraLensDirection.front;
  PoseDetectionService? _detector;
  ExerciseAnalysisEngine? _engine;
  final _feedback = FeedbackEngine();
  final _clock = Stopwatch();
  final _tts = FlutterTts();
  bool _audio = false;
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    unawaited(_releaseCamera());
    unawaited(_detector?.close());
    unawaited(_tts.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
    if (!mounted) {
      await controller.dispose();
      return;
    }
    await controller.startImageStream((image) => _onFrame(image, description));
    setState(() => _camera = controller);
  }

  Future<void> _start() async {
    final pattern = _pattern;
    if (pattern == null) return;
    setState(() {
      _error = null;
      _engine = ExerciseAnalysisEngine(pattern: pattern);
      _feedback.reset();
      _summary = null;
      _message = null;
      _update = null;
      _startedAt = DateTime.now();
    });
    try {
      await _tts.setLanguage(stringsOf(context).isEnglish ? 'en-US' : 'pt-PT');
      await _openCamera();
      _clock
        ..reset()
        ..start();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _stage == _Stage.running) setState(() {});
      });
      setState(() => _stage = _Stage.running);
    } catch (_) {
      await _releaseCamera();
      if (mounted) setState(() => _error = 'maCameraError');
    }
  }

  void _pause() {
    if (_stage != _Stage.running) return;
    _clock.stop();
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
    _clock.stop();
    _ticker?.cancel();
    await _releaseCamera();
    final engine = _engine;
    if (engine == null) return;
    final summary = engine.summary();
    final services = AppServicesScope.of(context);
    final t = stringsOf(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (summary.fullReps + summary.partialReps > 0 ||
        summary.holdTime > Duration.zero) {
      await MotionHistoryRepository(services.database).save(
        exerciseKey: widget.exerciseKey,
        startedAt: _startedAt ?? DateTime.now(),
        summary: summary,
      );
      messenger?.showSnackBar(SnackBar(content: Text(t.get('maSaved'))));
    }
    if (mounted) {
      setState(() {
        _summary = summary;
        _stage = _Stage.done;
      });
    }
  }

  /// Camera callback: drops frames while busy or within [_frameInterval].
  void _onFrame(CameraImage image, CameraDescription description) {
    final camera = _camera;
    if (_busy || camera == null || _stage != _Stage.running) return;
    final now = _clock.elapsed;
    if (now - _lastFrame < _frameInterval) return;
    _busy = true;
    _lastFrame = now;
    final watch = Stopwatch()..start();
    _detector!
        .detect(image, description, camera.value.deviceOrientation, now)
        .then((pose) {
          watch.stop();
          _latencyMs = _latencyMs == 0
              ? watch.elapsedMilliseconds.toDouble()
              : _latencyMs * 0.9 + watch.elapsedMilliseconds * 0.1;
          if (!mounted || _stage != _Stage.running) return;
          final update = _engine!.process(pose, now);
          final message = _feedback.offer(update.feedback, now);
          if (message != null && _audio) {
            unawaited(_tts.speak(stringsOf(context).get(message.key)));
          }
          setState(() {
            _pose = pose;
            _update = update;
            if (message != null) _message = message;
          });
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
              label: t.get('maStart'),
              icon: Icons.videocam_rounded,
              onPressed: _start,
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

  Widget _cameraView(BuildContext context) {
    final t = stringsOf(context);
    final camera = _camera;
    final update = _update;
    final pattern = _pattern!;
    final elapsed = _clock.elapsed;
    final hold = pattern.mode == PatternMode.hold;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (camera != null && camera.value.isInitialized)
            _Preview(
              camera: camera,
              pose: _pose,
              mirror:
                  camera.description.lensDirection == CameraLensDirection.front,
            )
          else
            const Center(child: CircularProgressIndicator()),
          // Top bar.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  _GlassIcon(
                    icon: Icons.close_rounded,
                    tooltip: t.get('maFinish'),
                    onTap: _finish,
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
                        _QualityPill(
                          quality: update?.detectionQuality ?? 0,
                          latencyMs: _latencyMs,
                        ),
                      ],
                    ),
                  ),
                  _GlassIcon(
                    icon: _audio
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    tooltip: t.get('maAudio'),
                    onTap: () => setState(() => _audio = !_audio),
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
          // Feedback banner.
          Positioned(
            left: 16,
            right: 16,
            top: MediaQuery.paddingOf(context).top + 76,
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
          // Bottom panel.
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                                      ? (update?.holdTime.inMilliseconds ?? 0) /
                                            1000
                                      : (update?.fullReps ?? 0).toDouble(),
                                  suffix: hold ? ' s' : '',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        fontSize: 54,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                Text(
                                  hold
                                      ? t.get('maHold')
                                      : '${t.get('maReps')} · ${update?.partialReps ?? 0} ${t.get('maPartial')}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _clockText(elapsed),
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                              const SizedBox(height: 6),
                              _StatusChip(
                                status:
                                    update?.status ?? AnalysisStatus.waiting,
                              ),
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
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _stage == _Stage.running
                                  ? _pause
                                  : _resume,
                              icon: Icon(
                                _stage == _Stage.running
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                              label: Text(
                                t.get(
                                  _stage == _Stage.running
                                      ? 'maPause'
                                      : 'maResume',
                                ),
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
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
        onPressed: _start,
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
  });
  final CameraController camera;
  final BodyPose? pose;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final size = camera.value.previewSize!;
    // Portrait: the preview is rotated, so width/height swap.
    final w = size.height, h = size.width;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(camera),
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
