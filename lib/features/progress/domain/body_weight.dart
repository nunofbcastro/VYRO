/// Rules for body weight entries on the progress page. Pure Dart so they can
/// be tested without widgets or a database.
library;

const double bodyWeightMinKg = 20;
const double bodyWeightMaxKg = 400;

/// How far back the date picker goes.
const int bodyWeightMaxAgeYears = 5;

/// Accepts "75", "75.5" and pt-PT "75,5". Returns null for anything that is
/// not a single number inside [bodyWeightMinKg]..[bodyWeightMaxKg] with at
/// most one decimal place.
double? parseBodyWeight(String raw) {
  final text = raw.trim().replaceAll(' ', '');
  if (!RegExp(r'^\d{1,3}([.,]\d)?$').hasMatch(text)) return null;
  final value = double.tryParse(text.replaceAll(',', '.'));
  if (value == null) return null;
  if (value < bodyWeightMinKg || value > bodyWeightMaxKg) return null;
  return value;
}

/// Text shown in the input: decimal comma for pt-PT, dot for English.
String formatBodyWeightInput(double kg, {required bool english}) {
  final text = kg.toStringAsFixed(1);
  return english ? text : text.replaceAll('.', ',');
}

/// Value with one decimal and the unit, e.g. "75,5 kg" in pt-PT.
String formatBodyWeight(double kg, {required bool english}) =>
    '${formatBodyWeightInput(kg, english: english)} kg';

/// Calendar date only, e.g. "25/10/2026".
String formatBodyDate(DateTime day) =>
    '${day.day.toString().padLeft(2, '0')}/'
    '${day.month.toString().padLeft(2, '0')}/'
    '${day.year}';

/// Midnight of the local calendar day of [value].
DateTime bodyDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool isSameBodyDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Earliest day the date picker allows, relative to [today].
DateTime bodyWeightFirstDay(DateTime today) =>
    DateTime(today.year - bodyWeightMaxAgeYears, today.month, today.day);

/// Time stored for an entry on [day]. Today uses the current time; other
/// days use noon so they never fall on a day boundary. An unchanged day keeps
/// the original time of [original].
DateTime bodyMeasuredAt({
  required DateTime day,
  required DateTime now,
  DateTime? original,
}) {
  if (original != null && isSameBodyDay(original, day)) return original;
  if (isSameBodyDay(day, now)) return now;
  return DateTime(day.year, day.month, day.day, 12);
}
