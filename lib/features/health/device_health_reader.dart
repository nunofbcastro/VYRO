import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';

import 'device_health.dart';

enum DeviceHealthAvailability { unsupported, needsInstall, ready }

/// Reads Health Connect (Android) or Apple Health (iOS). Never writes.
/// Fitbit, Garmin, Polar and Samsung are not signed into: if those apps
/// already record into Health Connect or Apple Health, their numbers show up.
class DeviceHealthReader {
  DeviceHealthReader({Health? health}) : _health = health ?? Health();

  final Health _health;

  static const readTypes = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.WEIGHT,
  ];

  static bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<DeviceHealthAvailability> availability() async {
    if (!supported) return DeviceHealthAvailability.unsupported;
    await _health.configure();
    if (!Platform.isAndroid) return DeviceHealthAvailability.ready;
    final status = await _health.getHealthConnectSdkStatus();
    if (status == HealthConnectSdkStatus.sdkAvailable) {
      return DeviceHealthAvailability.ready;
    }
    return DeviceHealthAvailability.needsInstall;
  }

  Future<void> installHealthConnect() => _health.installHealthConnect();

  /// Asks for read access only. False when the person refuses.
  Future<bool> requestAccess() async {
    await _health.configure();
    return _health.requestAuthorization(
      readTypes,
      permissions: [for (final _ in readTypes) HealthDataAccess.READ],
    );
  }

  /// Today's steps, active calories and distance, plus the latest weight
  /// in the last 30 days. Throws [PlatformException] when the store fails.
  Future<DeviceHealthDay> readToday(DateTime now) async {
    await _health.configure();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final steps = await _health.getTotalStepsInInterval(start, end);
    final today = await _health.getHealthDataFromTypes(
      types: const [
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.DISTANCE_DELTA,
      ],
      startTime: start,
      endTime: end,
    );
    final weights = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.WEIGHT],
      startTime: start.subtract(const Duration(days: 30)),
      endTime: end,
    );
    final quantities = <HealthQuantity>[];
    for (final point in [...today, ...weights]) {
      final sample = _quantity(point);
      if (sample != null) quantities.add(sample);
    }
    return DeviceHealthDay.fromQuantities(
      day: start,
      readAt: now,
      steps: steps,
      quantities: quantities,
    );
  }
}

HealthQuantity? _quantity(HealthDataPoint point) {
  final value = point.value;
  if (value is! NumericHealthValue) return null;
  final number = value.numericValue.toDouble();
  final kind = switch (point.type) {
    HealthDataType.ACTIVE_ENERGY_BURNED => HealthQuantityKind.activeKcal,
    HealthDataType.DISTANCE_DELTA => HealthQuantityKind.distanceM,
    HealthDataType.WEIGHT => HealthQuantityKind.weightKg,
    _ => null,
  };
  if (kind == null) return null;
  return HealthQuantity(kind, number, point.dateFrom.toLocal());
}
