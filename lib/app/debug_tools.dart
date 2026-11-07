import 'package:flutter/foundation.dart';

/// Developer-only screens (design system gallery, replaying the first-run
/// flow, demo placeholder screens) exist to build and review the app. They
/// are reachable only in debug builds; release and profile builds hide the
/// entry points and the router refuses the routes.
class DebugTools {
  DebugTools._();

  static bool _enabled = kDebugMode;

  static bool get enabled => _enabled;

  /// Lets tests check the release behaviour from a debug test run.
  @visibleForTesting
  static set enabled(bool value) => _enabled = value;

  /// Routes that only make sense while developing.
  static const Set<String> routes = {
    '/design-system',
    '/onboarding',
    '/profile-setup',
    '/splash',
  };
}
