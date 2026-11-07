import 'dart:convert';

/// One quantity read from Health Connect or Apple Health.
enum HealthQuantityKind { activeKcal, distanceM, weightKg }

class HealthQuantity {
  const HealthQuantity(this.kind, this.value, this.at);

  final HealthQuantityKind kind;
  final double value;
  final DateTime at;
}

/// One local reading for a calendar day. Numbers come from the phone's
/// health store. They are not a VYRO measurement and they do not change
/// the food calorie target.
class DeviceHealthDay {
  const DeviceHealthDay({
    required this.day,
    required this.readAt,
    this.steps,
    this.activeKcal,
    this.distanceMeters,
    this.weightKg,
  });

  /// Local calendar day, at midnight.
  final DateTime day;
  final DateTime readAt;
  final int? steps;
  final double? activeKcal;
  final double? distanceMeters;
  final double? weightKg;

  bool get isEmpty =>
      steps == null &&
      activeKcal == null &&
      distanceMeters == null &&
      weightKg == null;

  bool sameDay(DateTime other) =>
      day.year == other.year &&
      day.month == other.month &&
      day.day == other.day;

  Map<String, Object?> toJson() => {
    'day': _ymd(day),
    'readAt': readAt.toIso8601String(),
    if (steps != null) 'steps': steps,
    if (activeKcal != null) 'activeKcal': activeKcal,
    if (distanceMeters != null) 'distanceM': distanceMeters,
    if (weightKg != null) 'weightKg': weightKg,
  };

  /// Null when the stored text is missing or not a reading we wrote.
  static DeviceHealthDay? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final day = _parseYmd(json['day']);
      final readAt = DateTime.tryParse('${json['readAt']}');
      if (day == null || readAt == null) return null;
      return DeviceHealthDay(
        day: day,
        readAt: readAt,
        steps: _int(json['steps'], 0, 200000),
        activeKcal: _double(json['activeKcal'], 0, 20000),
        distanceMeters: _double(json['distanceM'], 0, 250000),
        weightKg: _double(json['weightKg'], 20, 400),
      );
    } catch (_) {
      return null;
    }
  }

  /// Steps are the store's own total for the day. Active calories and
  /// distance are summed for [day] only. Weight is the latest sample in
  /// the list, even from an earlier day.
  static DeviceHealthDay fromQuantities({
    required DateTime day,
    required DateTime readAt,
    int? steps,
    required List<HealthQuantity> quantities,
  }) {
    double? sum(HealthQuantityKind kind) {
      var total = 0.0;
      var any = false;
      for (final sample in quantities) {
        if (sample.kind != kind || !_sameDay(sample.at, day)) continue;
        if (sample.value.isNaN || sample.value < 0) continue;
        total += sample.value;
        any = true;
      }
      return any ? total : null;
    }

    HealthQuantity? latestWeight;
    for (final sample in quantities) {
      if (sample.kind != HealthQuantityKind.weightKg) continue;
      if (sample.value.isNaN || sample.value < 20 || sample.value > 400) {
        continue;
      }
      if (latestWeight == null || sample.at.isAfter(latestWeight.at)) {
        latestWeight = sample;
      }
    }

    final safeSteps = steps == null || steps < 0 || steps > 200000
        ? null
        : steps;
    return DeviceHealthDay(
      day: DateTime(day.year, day.month, day.day),
      readAt: readAt,
      steps: safeSteps,
      activeKcal: _cap(sum(HealthQuantityKind.activeKcal), 20000),
      distanceMeters: _cap(sum(HealthQuantityKind.distanceM), 250000),
      weightKg: latestWeight?.value,
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

double? _cap(double? value, double max) {
  if (value == null || value > max) return null;
  return value;
}

int? _int(Object? raw, int min, int max) {
  final value = raw is num ? raw.toInt() : int.tryParse('$raw');
  if (value == null || value < min || value > max) return null;
  return value;
}

double? _double(Object? raw, double min, double max) {
  final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
  if (value == null || value.isNaN || value < min || value > max) return null;
  return value;
}

String _ymd(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

DateTime? _parseYmd(Object? raw) {
  final text = raw?.toString() ?? '';
  final parts = text.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}
