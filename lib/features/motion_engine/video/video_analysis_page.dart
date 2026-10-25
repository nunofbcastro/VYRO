import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/app_services.dart';
import '../../../app/l10n/strings.dart';
import '../../../core/platform/image_temp_file.dart';
import '../../../core/ui/vyro_ui.dart';
import '../movement_patterns/movement_pattern.dart';
import '../workout_analysis_history/motion_history_repository.dart';
import 'local_video_analysis.dart';

class VideoAnalysisPage extends StatefulWidget {
  const VideoAnalysisPage({
    super.key,
    required this.exerciseKey,
    required this.exerciseName,
    required this.pattern,
    this.picker,
    this.sourceFactory,
    this.detectorFactory,
  });
  final String exerciseKey, exerciseName;
  final MovementPattern pattern;
  final ImagePicker? picker;
  final VideoFrameSource Function()? sourceFactory;
  final VideoPoseDetector Function()? detectorFactory;
  @override
  State<VideoAnalysisPage> createState() => _VideoAnalysisPageState();
}

class _VideoAnalysisPageState extends State<VideoAnalysisPage>
    with WidgetsBindingObserver {
  late final _source =
      widget.sourceFactory?.call() ?? PlatformVideoFrameSource();
  late final _picker = widget.picker ?? ImagePicker();
  LocalVideoInfo? _info;
  LocalVideoFrame? _preview;
  VideoAnalysisResult? _result;
  String? _ownedPath, _error;
  RangeValues _range = const RangeValues(0, 1);
  final _full = TextEditingController(), _partial = TextEditingController();
  bool _busy = false, _cancelled = false, _saving = false;
  double _progress = 0;
  int _generation = 0;
  int? _savedId;
  bool get _supported =>
      widget.sourceFactory != null ||
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS));
  VyroStrings get _t => stringsOf(context);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive)
      _cancelled = true;
  }

  @override
  void dispose() {
    _cancelled = true;
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _preview = null;
    _full.dispose();
    _partial.dispose();
    unawaited(_release());
    super.dispose();
  }

  Future<void> _release() async {
    final path = _ownedPath;
    _ownedPath = null;
    try {
      await _source.close();
    } finally {
      if (path != null) await deleteTemporaryImage(path);
    }
  }

  Future<void> _pick() async {
    if (_busy || _saving) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file == null) return;
      if (!mounted || generation != _generation) {
        await deleteTemporaryImage(file.path);
        return;
      }
      await _release();
      _ownedPath = file.path;
      final info = await _source.open(file.path);
      final preview = await _source.frame(Duration.zero);
      if (!mounted || generation != _generation) return;
      setState(() {
        _info = info;
        _preview = preview;
        _range = RangeValues(
          0,
          (info.duration.inMilliseconds / 1000).clamp(.001, 120),
        );
        _result = null;
        _savedId = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = _t.get('vidOpenError'));
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _analyse() async {
    if (_busy || _info == null) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _cancelled = false;
      _progress = 0;
      _error = null;
      _result = null;
      _savedId = null;
    });
    try {
      final detector =
          widget.detectorFactory?.call() ?? MlKitVideoPoseDetector();
      final result = await LocalVideoAnalysis().run(
        source: _source,
        detector: detector,
        pattern: widget.pattern,
        start: Duration(milliseconds: (_range.start * 1000).round()),
        end: Duration(milliseconds: (_range.end * 1000).round()),
        cancelled: () => _cancelled || !mounted || generation != _generation,
        onProgress: (value) {
          if (mounted && generation == _generation)
            setState(() => _progress = value);
        },
      );
      if (mounted && generation == _generation) {
        _full.text = '${result.summary.fullReps}';
        _partial.text = '${result.summary.partialReps}';
        setState(() => _result = result);
      }
    } on VideoAnalysisCancelled {
      if (mounted) setState(() => _error = _t.get('vidCancelled'));
    } catch (_) {
      if (mounted) setState(() => _error = _t.get('vidFailed'));
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _showMoment(VideoMoment moment) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final frame = await _source.frame(moment.at);
      if (mounted) setState(() => _preview = frame);
    } catch (_) {
      if (mounted) setState(() => _error = _t.get('vidMomentError'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final result = _result;
    if (result == null || _saving || _savedId != null) return;
    final full = int.tryParse(_full.text),
        partial = int.tryParse(_partial.text);
    if (full == null ||
        partial == null ||
        full < 0 ||
        partial < 0 ||
        full > 1000 ||
        partial > 1000) {
      setState(() => _error = _t.get('vidInvalidCounts'));
      return;
    }
    final services = AppServicesScope.of(context);
    setState(() => _saving = true);
    try {
      final repository = MotionHistoryRepository(services.database);
      final id = await services.database.transaction(() async {
        final id = await repository.save(
          exerciseKey: widget.exerciseKey,
          startedAt: DateTime.now(),
          summary: result.summary,
        );
        if (full != result.summary.fullReps ||
            partial != result.summary.partialReps)
          await repository.correctCounts(id, full: full, partial: partial);
        await services.localIntelligence.recordMotionPerformance(
          frames: result.frames,
          skipped: 0,
          inferenceMs: result.inferenceMs,
        );
        return id;
      });
      if (mounted) setState(() => _savedId = id);
    } catch (_) {
      if (mounted)
        setState(() => _error = stringsOf(context).get('localError'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _time(Duration time) =>
      '${time.inMinutes.toString().padLeft(2, '0')}:${(time.inSeconds % 60).toString().padLeft(2, '0')}.${(time.inMilliseconds % 1000) ~/ 100}';
  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context), result = _result;
    return VyroSubpageScaffold(
      title: _t.get('vidTitle'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.exerciseName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(_t.get('vidIntro')),
          Text(
            _t.get('vidExperimental'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          if (!_supported) Text(_t.get('vidUnsupported')),
          OutlinedButton.icon(
            onPressed: !_supported || _busy || _saving ? null : _pick,
            icon: const Icon(Icons.video_library_outlined),
            label: Text(_t.get('vidPick')),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_preview != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: Image.memory(_preview!.jpeg, fit: BoxFit.contain),
            ),
            Text(
              '${_preview!.approximate ? "≈ " : ""}${_time(_preview!.time)}',
            ),
          ],
          if (_info != null) ...[
            Text(
              _t.get('vidClip') +
                  '${_time(Duration(milliseconds: (_range.start * 1000).round()))}–${_time(Duration(milliseconds: (_range.end * 1000).round()))}',
            ),
            RangeSlider(
              values: _range,
              min: 0,
              max: _info!.duration.inMilliseconds / 1000,
              onChanged: _busy || _saving
                  ? null
                  : (value) {
                      var start = value.start, end = value.end;
                      if (end - start > 120) {
                        if (start != _range.start)
                          end = start + 120;
                        else
                          start = end - 120;
                      }
                      setState(() {
                        _range = RangeValues(start, end);
                        _result = null;
                        _savedId = null;
                      });
                    },
            ),
            if (_busy) ...[
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              TextButton(
                onPressed: () => setState(() => _cancelled = true),
                child: Text(_t.get('vidCancel')),
              ),
            ] else
              FilledButton.icon(
                onPressed: _range.end > _range.start && !_saving
                    ? _analyse
                    : null,
                icon: const Icon(Icons.analytics_outlined),
                label: Text(_t.get('vidAnalyse')),
              ),
          ],
          if (result != null) ...[
            const SizedBox(height: 20),
            Text(
              _t.get('vidResult'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${(result.summary.observedRatio * 100).round()}% ${_t.get('vidObservable')} · ${result.frames} ${_t.get('vidFrames')}',
            ),
            if (result.approximate) Text(_t.get('vidApproxNote')),
            TextField(
              controller: _full,
              enabled: _savedId == null && !_saving,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: _t.get('vidFull')),
            ),
            TextField(
              controller: _partial,
              enabled: _savedId == null && !_saving,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: _t.get('vidPartial')),
            ),
            if (widget.pattern.mode == PatternMode.hold)
              Text(
                '${(result.summary.holdTime.inMilliseconds / 1000).toStringAsFixed(1)} s ${_t.get('vidHoldObserved')}',
              ),
            const SizedBox(height: 12),
            for (final moment in result.moments.take(100))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_circle_outline),
                title: Text(t.get(moment.messageKey)),
                subtitle: Text(_time(moment.at)),
                onTap: _busy || _saving ? null : () => _showMoment(moment),
              ),
            Text(t.get('maDisclaimer')),
            FilledButton.icon(
              onPressed: _busy || _saving || _savedId != null ? null : _save,
              icon: Icon(_savedId == null ? Icons.check : Icons.done_all),
              label: Text(
                _savedId == null ? _t.get('vidSave') : _t.get('vidSaved'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
