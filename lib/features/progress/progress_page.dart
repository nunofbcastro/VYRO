import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../core/database/app_database.dart';
import '../../core/widgets/vyro_widgets.dart';
import '../workouts/data/workout_repository.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  int _rangeDays = 30;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final repository = AppServicesScope.of(context).workoutRepository;
    final cutoff = DateTime.now().subtract(Duration(days: _rangeDays));
    return ContentPage(
      title: t.get('progress'),
      children: [
        SegmentedButton<int>(
          segments: [
            const ButtonSegment(value: 7, label: Text('7D')),
            const ButtonSegment(value: 30, label: Text('30D')),
            const ButtonSegment(value: 90, label: Text('90D')),
            ButtonSegment(value: 365, label: Text(t.isEnglish ? '1Y' : '1A')),
          ],
          selected: {_rangeDays},
          onSelectionChanged: (value) =>
              setState(() => _rangeDays = value.first),
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<WorkoutSession>>(
          stream: repository.watchSessions(),
          builder: (context, snapshot) {
            final sessions = (snapshot.data ?? const <WorkoutSession>[])
                .where(
                  (session) =>
                      session.status == 'completed' &&
                      !session.startedAt.isBefore(cutoff),
                )
                .length;
            return MetricCard(
              label: t.get('sessions'),
              value: '$sessions',
              unit: t.get('completed'),
              icon: Icons.fitness_center,
            );
          },
        ),
        const SizedBox(height: 12),
        StreamBuilder<double>(
          stream: repository.watchTrainingVolume(),
          builder: (context, snapshot) => MetricCard(
            label: t.get('volume'),
            value: _compactNumber(snapshot.data ?? 0),
            unit: 'kg · ${t.get('allTime')}',
            icon: Icons.show_chart,
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.get('weight'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: t.get('logWeight'),
                      onPressed: () => _logWeight(context, repository),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<BodyMeasurement>>(
                  stream: repository.watchBodyMeasurements(),
                  builder: (context, snapshot) {
                    final measurements =
                        (snapshot.data ?? const <BodyMeasurement>[])
                            .where(
                              (measurement) =>
                                  !measurement.measuredAt.isBefore(cutoff),
                            )
                            .toList();
                    if (measurements.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          t.get('weightEmpty'),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    final latest = measurements.last.weightKg;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${latest.toStringAsFixed(1)} kg',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 150,
                          child: CustomPaint(
                            painter: _ChartPainter(
                              Theme.of(context).colorScheme.primary,
                              measurements
                                  .map((measurement) => measurement.weightKg)
                                  .toList(),
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [measurements.first, measurements.last]
                              .toSet()
                              .map(
                                (measurement) => Text(
                                  '${measurement.measuredAt.day}/${measurement.measuredAt.month}',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          t.get('progressLocalNote'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _logWeight(
    BuildContext context,
    WorkoutRepository repository,
  ) async {
    final t = stringsOf(context);
    final controller = TextEditingController();
    final weight = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.get('logWeight')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'kg'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.get('cancel')),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(
                controller.text.replaceAll(',', '.'),
              );
              if (parsed != null && parsed > 0 && parsed < 500)
                Navigator.pop(context, parsed);
            },
            child: Text(t.get('save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (weight != null) await repository.addBodyWeight(weight);
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.color, this.values);
  final Color color;
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final low = values.reduce((a, b) => a < b ? a : b);
    final high = values.reduce((a, b) => a > b ? a : b);
    final spread = (high - low).abs();
    final range = spread == 0 ? 1.0 : spread;
    final points = List<Offset>.generate(values.length, (index) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * index / (values.length - 1);
      final y =
          size.height * .85 - (values[index] - low) / range * size.height * .7;
      return Offset(x, y);
    });
    final line = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, line);
    for (final point in points) {
      canvas.drawCircle(point, 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.values != values;
}

String _compactNumber(double value) => value >= 1000
    ? '${(value / 1000).toStringAsFixed(1)}k'
    : value.toStringAsFixed(0);
