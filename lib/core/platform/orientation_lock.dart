import 'dart:async';

import 'package:flutter/services.dart';

/// Screen orientation policy.
///
/// The whole app is portrait-only, except the live exercise camera screen
/// (`MotionCoachPage`), which needs landscape for its side panel. That screen
/// acquires landscape with [allowAllOrientations] and gives it back with
/// [releaseAllOrientations]. Several camera screens may be open at once (for
/// example a page pushed twice), so landscape is only released when the last
/// holder lets go.
class OrientationLock {
  OrientationLock._();

  static const portraitOnly = [DeviceOrientation.portraitUp];

  static const allOrientations = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  static int _landscapeHolders = 0;

  /// Number of screens currently holding landscape. Exposed for tests.
  static int get landscapeHolders => _landscapeHolders;

  /// Locks the app to portrait. Called once at startup, before `runApp`.
  static Future<void> lockPortrait() =>
      SystemChrome.setPreferredOrientations(portraitOnly);

  /// Lets the device rotate. Each call must be paired with one
  /// [releaseAllOrientations].
  static Future<void> allowAllOrientations() {
    _landscapeHolders++;
    return SystemChrome.setPreferredOrientations(allOrientations);
  }

  /// Gives back one hold. Restores portrait only when no holder is left.
  static Future<void> releaseAllOrientations() {
    if (_landscapeHolders > 0) _landscapeHolders--;
    if (_landscapeHolders > 0) return Future.value();
    return SystemChrome.setPreferredOrientations(portraitOnly);
  }
}
