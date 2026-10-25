import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Snapshot shown by the home-screen widgets ("Hoje" and "Calorias").
///
/// Labels are passed already translated so the native widgets need no
/// strings of their own. Values come from local data only; nothing leaves the
/// device.
@immutable
class HomeWidgetSnapshot {
  const HomeWidgetSnapshot({
    required this.kcalEaten,
    required this.kcalGoal,
    required this.proteinEaten,
    required this.proteinGoal,
    required this.nextWorkout,
    required this.nextWhen,
    required this.weekDone,
    required this.weekTotal,
    required this.labels,
  });

  final int kcalEaten;
  final int kcalGoal;
  final int proteinEaten;
  final int proteinGoal;

  /// Next workout name, or a status text when nothing is pending.
  final String nextWorkout;

  /// "Hoje", "Quarta-feira"… or empty.
  final String nextWhen;
  final int weekDone;
  final int weekTotal;

  /// Translated labels: kcal, left, over, next, week, protein, title.
  final Map<String, String> labels;

  int get kcalLeft => kcalGoal - kcalEaten;

  /// 0–100 for native progress bars.
  int get kcalPercent =>
      kcalGoal <= 0 ? 0 : (kcalEaten * 100 / kcalGoal).round().clamp(0, 100);

  Map<String, Object> toData() => {
    'kcal_eaten': kcalEaten,
    'kcal_goal': kcalGoal,
    'kcal_left': kcalLeft,
    'kcal_percent': kcalPercent,
    'protein_eaten': proteinEaten,
    'protein_goal': proteinGoal,
    'next_workout': nextWorkout,
    'next_when': nextWhen,
    'week_done': weekDone,
    'week_total': weekTotal,
    for (final entry in labels.entries) 'lbl_${entry.key}': entry.value,
  };

  @override
  bool operator ==(Object other) =>
      other is HomeWidgetSnapshot && mapEquals(other.toData(), toData());

  @override
  int get hashCode => Object.hashAll(toData().values);
}

/// Pushes [HomeWidgetSnapshot]s to the native widgets.
///
/// Android: `VyroTodayWidgetProvider` and `VyroCaloriesWidgetProvider`
/// (android/app/src/main/kotlin/…/widgets). iOS: the `VyroWidget` WidgetKit
/// extension in `ios/VyroWidget` (see docs/WIDGETS.md for the Xcode setup).
class VyroHomeWidgets {
  VyroHomeWidgets._();

  /// App Group shared with the iOS widget extension.
  static const appGroupId = 'group.com.example.vyro';
  static const _androidProviders = [
    'com.example.vyro.widgets.VyroTodayWidgetProvider',
    'com.example.vyro.widgets.VyroCaloriesWidgetProvider',
  ];
  static const _iosKind = 'VyroWidget';

  static HomeWidgetSnapshot? _last;
  static bool _groupSet = false;

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Saves the snapshot and refreshes the widgets. Identical snapshots are
  /// skipped, and failures are ignored: widgets are a convenience and must
  /// never break the app.
  static Future<void> publish(HomeWidgetSnapshot snapshot) async {
    if (!supported || snapshot == _last) return;
    _last = snapshot;
    try {
      if (!_groupSet) {
        await HomeWidget.setAppGroupId(appGroupId);
        _groupSet = true;
      }
      for (final entry in snapshot.toData().entries) {
        await HomeWidget.saveWidgetData<Object>(entry.key, entry.value);
      }
      for (final provider in _androidProviders) {
        await HomeWidget.updateWidget(
          qualifiedAndroidName: provider,
          iOSName: _iosKind,
        );
      }
    } catch (_) {
      // Missing plugin (tests), no widget installed, or iOS without the
      // extension: nothing to update.
    }
  }
}
