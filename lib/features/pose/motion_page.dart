import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/l10n/strings.dart';
import '../../app/theme/vyro_shell.dart';
import 'domain/movenet_service.dart';

class MotionPage extends StatefulWidget {
  const MotionPage({super.key});

  @override
  State<MotionPage> createState() => _MotionPageState();
}

class _MotionPageState extends State<MotionPage> {
  final _recognizer = MoveNetService();
  final _counter = SquatRepCounter();
  CameraController? _camera;
  CameraDescription? _description;
  PoseFrame? _frame;
  SquatUpdate? _update;
  String? _error;
  bool _starting = false;
  bool _processing = false;
  DateTime _lastFrameAt = DateTime(2000);

  @override
  void dispose() {
    unawaited(_camera?.dispose());
    unawaited(_recognizer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final camera = _camera;
    return VyroSubpageScaffold(
      title: t.get('motion'),
      body: camera == null
          ? SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.accessibility_new,
                            size: 42,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            t.get('motionSquat'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(t.get('motionPrivacy')),
                          const SizedBox(height: 16),
                          Text(
                            t.get('motionLimit'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: Text(t.get(_error!)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton.icon(
                    onPressed: _starting ? null : _start,
                    icon: _starting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.videocam_outlined),
                    label: Text(t.get('motionStart')),
                  ),
                ],
              ),
            )
          : _cameraView(camera, t),
    );
  }

  Widget _cameraView(CameraController camera, VyroStrings t) {
    final update = _update;
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          _preview(camera),
          Positioned(
            top: 14,
            left: 16,
            right: 16,
            child: Card(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: .9),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      update == null || update.state != 'ready'
                          ? Icons.center_focus_weak
                          : Icons.check_circle_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_statusText(update, t))),
                    if (update != null)
                      Text('${(update.confidence * 100).round()}%'),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Card(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: .94),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.get('motionSquat'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '${_counter.repetitions}',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Text(t.get('motionReps')),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      update?.kneeAngle == null
                          ? t.get('motionAngleUnknown')
                          : '${t.get('motionKneeAngle')}: ${update!.kneeAngle!.round()}°',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.get('motionNoSafety'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _stop,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: Text(t.get('motionStop')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(CameraController camera) {
    final previewSize = camera.value.previewSize!;
    final portraitWidthToHeight = previewSize.height / previewSize.width;
    const width = 360.0;
    final frame = _frame;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: width,
          height: width / portraitWidthToHeight,
          child: CameraPreview(
            camera,
            child: CustomPaint(
              painter: _PosePainter(
                frame,
                Theme.of(context).colorScheme.primary,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    CameraController? controller;
    try {
      await _recognizer.initialize();
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('no_camera', '');
      final description = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final format = defaultTargetPlatform == TargetPlatform.iOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420;
      controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: format,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _description = description;
        _camera = controller;
      });
      await controller.startImageStream(_onFrame);
    } catch (error) {
      await controller?.dispose();
      if (mounted) {
        setState(() {
          _camera = null;
          _error = error is CameraException
              ? 'cameraError'
              : 'motionUnavailable';
        });
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _onFrame(CameraImage image) {
    final now = DateTime.now();
    if (_processing ||
        now.difference(_lastFrameAt) < const Duration(milliseconds: 200)) {
      return;
    }
    _lastFrameAt = now;
    _processing = true;
    unawaited(_analyzeFrame(image));
  }

  Future<void> _analyzeFrame(CameraImage image) async {
    try {
      final frame = await _recognizer.detect(
        image,
        _description?.sensorOrientation ?? 0,
      );
      final update = _counter.update(frame);
      if (mounted) {
        setState(() {
          _frame = frame;
          _update = update;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'motionUnavailable');
    } finally {
      _processing = false;
    }
  }

  Future<void> _stop() async {
    final camera = _camera;
    if (camera == null) return;
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
      await camera.dispose();
    } finally {
      if (mounted)
        setState(() {
          _camera = null;
          _frame = null;
        });
    }
  }

  String _statusText(SquatUpdate? update, VyroStrings t) =>
      switch (update?.state) {
        'ready' => t.get('motionReady'),
        'low_confidence' => t.get('motionLowConfidence'),
        'out_of_frame' => t.get('motionOutOfFrame'),
        _ => t.get('motionPosition'),
      };
}

class _PosePainter extends CustomPainter {
  const _PosePainter(this.frame, this.color);
  final PoseFrame? frame;
  final Color color;

  static const _edges = [
    (5, 6),
    (5, 11),
    (6, 12),
    (11, 12),
    (5, 7),
    (7, 9),
    (6, 8),
    (8, 10),
    (11, 13),
    (13, 15),
    (12, 14),
    (14, 16),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final points = frame?.points;
    if (points == null) return;
    final line = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final joint = Paint()..color = color;
    for (final (a, b) in _edges) {
      if (points[a].confidence < .3 || points[b].confidence < .3) continue;
      canvas.drawLine(
        Offset(points[a].x * size.width, points[a].y * size.height),
        Offset(points[b].x * size.width, points[b].y * size.height),
        line,
      );
    }
    for (final point in points) {
      if (point.confidence < .3) continue;
      canvas.drawCircle(
        Offset(point.x * size.width, point.y * size.height),
        math.max(3, size.shortestSide * .007),
        joint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PosePainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.color != color;
}
