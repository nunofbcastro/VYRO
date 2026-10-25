import 'dart:math' as math;

/// One Euro filter (Casiez, Roussel & Vogel, CHI 2012): an adaptive low-pass
/// filter that smooths jitter at low speed and keeps lag low at high speed.
/// Standard choice for pose landmarks and joint angles.
class OneEuroFilter {
  OneEuroFilter({
    this.minCutoff = 1.2,
    this.beta = 0.02,
    this.derivativeCutoff = 1.0,
  });

  /// Lower → smoother when still (Hz).
  final double minCutoff;

  /// Higher → less lag when moving fast.
  final double beta;
  final double derivativeCutoff;

  double? _x;
  double _dx = 0;
  Duration? _t;

  static double _alpha(double cutoff, double dt) {
    final tau = 1 / (2 * math.pi * cutoff);
    return 1 / (1 + tau / dt);
  }

  double filter(double value, Duration timestamp) {
    final last = _x;
    final lastT = _t;
    _t = timestamp;
    if (last == null || lastT == null) {
      _x = value;
      return value;
    }
    final dt = (timestamp - lastT).inMicroseconds / 1e6;
    if (dt <= 0) return last;
    final rawDx = (value - last) / dt;
    _dx = _dx + _alpha(derivativeCutoff, dt) * (rawDx - _dx);
    final cutoff = minCutoff + beta * _dx.abs();
    _x = last + _alpha(cutoff, dt) * (value - last);
    return _x!;
  }

  /// Velocity estimate in units per second (filtered derivative).
  double get velocity => _dx;

  void reset() {
    _x = null;
    _t = null;
    _dx = 0;
  }
}
