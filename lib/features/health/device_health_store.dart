import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/database/app_database.dart';
import 'device_health.dart';

/// Opt-in flag and the last reading, both in `vyro_preferences`.
/// Export, import and "delete all data" already cover that table.
class DeviceHealthStore {
  DeviceHealthStore(this.database);

  final AppDatabase database;

  static const enabledKey = 'device_health_enabled_v1';
  static const snapshotKey = 'device_health_day_v1';

  /// Bumped after a write so the home card reloads.
  static final changes = ValueNotifier<int>(0);

  Future<bool> isEnabled() async =>
      (await database.getPreference(enabledKey)) == '1';

  Future<void> setEnabled(bool enabled) async {
    await database.setPreference(enabledKey, enabled ? '1' : '0');
    changes.value++;
  }

  Future<void> save(DeviceHealthDay day) async {
    await database.setPreference(snapshotKey, jsonEncode(day.toJson()));
    changes.value++;
  }

  Future<DeviceHealthDay?> read() async =>
      DeviceHealthDay.tryParse(await database.getPreference(snapshotKey));

  /// The reading for [now]'s calendar day, and only when the user opted in.
  Future<DeviceHealthDay?> todayIfEnabled(DateTime now) async {
    if (!await isEnabled()) return null;
    final day = await read();
    if (day == null || !day.sameDay(now) || day.isEmpty) return null;
    return day;
  }
}
