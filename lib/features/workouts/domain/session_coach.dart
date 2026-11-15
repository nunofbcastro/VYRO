/// Deterministic "what to try today" hints for a workout session, built from
/// the last time each exercise was logged. Same double-progression rule the
/// plan shows (`progressionRule` in plan_generator.dart): top of the rep
/// target in every set → raise the load a little; otherwise keep the load and
/// aim for one more rep.
///
/// A hint is a suggestion the user can ignore or edit. It is not a
/// prescription and says nothing about technique or safety.
library;

/// One logged set from an earlier session.
class PastSet {
  const PastSet({required this.reps, this.weightKg});

  /// Repetitions done, or seconds held for a timed exercise.
  final int reps;
  final double? weightKg;
}

enum LoadAdvice {
  /// Every set reached the target: add load (or make it harder).
  raise,

  /// Some set fell short: same load, aim for one more rep per set.
  keep,
}

class SessionHint {
  const SessionHint({
    required this.advice,
    required this.lastReps,
    required this.target,
    required this.timed,
    this.lastKg,
    this.suggestedKg,
  });

  final LoadAdvice advice;

  /// Reps (or seconds) of each completed set last time, in set order.
  final List<int> lastReps;

  /// Heaviest load used last time; null when no load was logged.
  final double? lastKg;

  /// Load to try today: [lastKg] raised by [nextLoad] when the advice is
  /// [LoadAdvice.raise], [lastKg] itself otherwise. Null without a load.
  final double? suggestedKg;

  /// Today's rep (or seconds) target.
  final int target;
  final bool timed;
}

/// About 5% more, rounded to the nearest 0.5 kg, at least +0.5 kg and at most
/// +2.5 kg (the plan's "2–5% or ~2 kg" rule, in plates and dumbbells that
/// exist).
double nextLoad(double kg) {
  final raised = (kg * 1.05 * 2).round() / 2;
  final step = (raised - kg).clamp(0.5, 2.5);
  return ((kg + step) * 2).round() / 2;
}

/// The hint for one exercise, or null when it was never logged before.
/// [last] holds the completed sets of the most recent session with it.
SessionHint? sessionHint({
  required List<PastSet> last,
  required int target,
  required bool timed,
}) {
  if (last.isEmpty || target <= 0) return null;
  final reachedAll = last.every((s) => s.reps >= target);
  double? lastKg;
  for (final set in last) {
    final kg = set.weightKg;
    if (kg != null && kg > 0 && (lastKg == null || kg > lastKg)) lastKg = kg;
  }
  final advice = reachedAll ? LoadAdvice.raise : LoadAdvice.keep;
  return SessionHint(
    advice: advice,
    lastReps: [for (final s in last) s.reps],
    lastKg: lastKg,
    suggestedKg: lastKg == null || timed
        ? lastKg
        : advice == LoadAdvice.raise
        ? nextLoad(lastKg)
        : lastKg,
    target: target,
    timed: timed,
  );
}

/// "20 kg", "22.5 kg": no trailing ".0". [comma] writes the decimal the
/// Portuguese way ("22,5 kg").
String formatKg(double kg, {bool comma = false}) {
  final text = kg == kg.roundToDouble()
      ? '${kg.round()}'
      : kg.toStringAsFixed(1);
  return '${comma ? text.replaceAll('.', ',') : text} kg';
}
