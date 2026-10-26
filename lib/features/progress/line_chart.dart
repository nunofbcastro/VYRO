import 'package:flutter/material.dart';

/// Thin line chart with one point per value, spaced evenly on the x axis.
/// When [onIndexTap] is set, a tap reports the nearest point's index.
class LineChart extends StatelessWidget {
  const LineChart({
    super.key,
    required this.values,
    required this.color,
    this.height = 130,
    this.onIndexTap,
  });

  final List<double> values;
  final Color color;
  final double height;
  final ValueChanged<int>? onIndexTap;

  @override
  Widget build(BuildContext context) {
    final painter = CustomPaint(
      painter: LineChartPainter(color, values),
      child: const SizedBox.expand(),
    );
    final tap = onIndexTap;
    return SizedBox(
      height: height,
      child: tap == null || values.isEmpty
          ? painter
          : LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final width = constraints.maxWidth;
                  if (values.length == 1 || width <= 0) return tap(0);
                  final fraction = (details.localPosition.dx / width).clamp(
                    0.0,
                    1.0,
                  );
                  tap((fraction * (values.length - 1)).round());
                },
                child: painter,
              ),
            ),
    );
  }
}

class LineChartPainter extends CustomPainter {
  LineChartPainter(this.color, this.values);
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
  bool shouldRepaint(covariant LineChartPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.values != values;
}
