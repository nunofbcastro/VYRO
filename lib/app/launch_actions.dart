import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:quick_actions/quick_actions.dart';

import 'l10n/strings.dart';

/// Shortcuts that open a screen directly: app-icon quick actions (long press)
/// and the buttons on the home-screen widgets (`vyro://action/<id>`).
enum LaunchAction {
  scan('scan', '/barcode', 'scan', 'ic_shortcut_scan'),
  photo('photo', '/photo-camera', 'photo', 'ic_shortcut_photo'),
  manual('manual', '/nutrition', 'manual', 'ic_shortcut_manual'),
  training('training', '/training', 'trainingToday', 'ic_shortcut_training'),
  assistant('assistant', '/assistant', 'assistant', 'ic_shortcut_assistant');

  const LaunchAction(this.id, this.route, this.labelKey, this.androidIcon);
  final String id;
  final String route;
  final String labelKey;

  /// Android drawable used by the app-icon shortcut.
  final String androidIcon;

  static LaunchAction? fromId(String? id) {
    for (final action in values) {
      if (action.id == id) return action;
    }
    return null;
  }

  /// `vyro://action/scan` → [scan].
  static LaunchAction? fromUri(Uri? uri) {
    if (uri == null || uri.scheme != 'vyro') return null;
    final segments = uri.pathSegments;
    return fromId(segments.isEmpty ? uri.host : segments.last);
  }
}

/// Routes [LaunchAction]s once the app shell is ready. Actions that arrive
/// during splash or onboarding wait until [markReady].
class LaunchActions {
  LaunchActions._();

  static final navigatorKey = GlobalKey<NavigatorState>();
  static LaunchAction? _pending;
  static bool _ready = false;
  static StreamSubscription<Uri?>? _widgetClicks;
  static String? _shortcutLocale;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Starts listening to widget taps and app-icon shortcuts.
  static Future<void> init() async {
    if (!_supported) return;
    try {
      const QuickActions().initialize(
        (type) => handle(LaunchAction.fromId(type)),
      );
      _widgetClicks ??= HomeWidget.widgetClicked.listen(
        (uri) => handle(LaunchAction.fromUri(uri)),
      );
      handle(
        LaunchAction.fromUri(
          await HomeWidget.initiallyLaunchedFromHomeWidget(),
        ),
      );
    } catch (_) {
      // Plugins missing (tests) — shortcuts are optional.
    }
  }

  /// (Re)publishes the app-icon shortcuts in the current language.
  static Future<void> updateShortcuts(Locale locale) async {
    if (!_supported || _shortcutLocale == locale.toLanguageTag()) return;
    _shortcutLocale = locale.toLanguageTag();
    final t = VyroStrings(locale);
    try {
      await const QuickActions().setShortcutItems([
        for (final action in const [
          LaunchAction.scan,
          LaunchAction.photo,
          LaunchAction.training,
          LaunchAction.assistant,
        ])
          ShortcutItem(
            type: action.id,
            localizedTitle: t.get(action.labelKey),
            icon: action.androidIcon,
          ),
      ]);
    } catch (_) {}
  }

  static void handle(LaunchAction? action) {
    if (action == null) return;
    if (!_ready) {
      _pending = action;
      return;
    }
    _open(action);
  }

  /// Called by the tab shell once the user is past onboarding.
  static void markReady() {
    _ready = true;
    final pending = _pending;
    _pending = null;
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _open(pending));
    }
  }

  static void markNotReady() => _ready = false;

  static void _open(LaunchAction action) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.popUntil((route) => route.isFirst);
    navigator.pushNamed(action.route);
  }
}
