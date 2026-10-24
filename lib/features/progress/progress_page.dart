import 'package:flutter/material.dart';

import '../../app/l10n/strings.dart';
import '../../core/widgets/vyro_widgets.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    return ContentPage(
      title: t.get('progress'),
      children: [
        SegmentedButton<String>(
          segments: [
            const ButtonSegment(value: '7', label: Text('7D')),
            const ButtonSegment(value: '30', label: Text('30D')),
            const ButtonSegment(value: '90', label: Text('90D')),
            ButtonSegment(value: '365', label: Text(t.isEnglish ? '1Y' : '1A')),
          ],
          selected: const {'30'},
          onSelectionChanged: (_) {},
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: t.get('sessions'),
                value: '12',
                unit: t.get('completed'),
                icon: Icons.fitness_center,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: t.get('volume'),
                value: '18.4k',
                unit: 'kg',
                icon: Icons.show_chart,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        MetricCard(
          label: t.get('weight'),
          value: '68.4',
          unit: 'kg',
          progress: .68,
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.get('weight'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 150,
                  child: CustomPaint(
                    painter: _ChartPainter(
                      Theme.of(context).colorScheme.primary,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children:
                      (t.isEnglish
                              ? ['Oct 1', 'Oct 8', 'Oct 15', 'Oct 24']
                              : ['1 out', '8 out', '15 out', '24 out'])
                          .map(
                            (e) => Text(
                              e,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const DemoBadge(),
        const SizedBox(height: 8),
        Text(
          t.get('previewDataCaveat'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color.withValues(alpha: .1)
      ..style = PaintingStyle.fill;
    final points = [
      Offset(0, size.height * .72),
      Offset(size.width * .67, size.height * .40),
      Offset(size.width * .34, size.height * .54),
      Offset(size.width, size.height * .22),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, fill);
    canvas.drawPath(path, line);
    for (final p in points) {
      canvas.drawCircle(p, 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) =>
      oldDelegate.color != color;
}
