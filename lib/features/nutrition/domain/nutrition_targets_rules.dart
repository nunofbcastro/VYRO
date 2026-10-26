import '../../../core/database/app_database.dart';

/// Problems the targets editor reports for one field.
enum TargetsIssue { invalid, kcalRange, gramsRange }

/// Pure rules for the daily targets: parsing pt-PT numbers, ranges, the
/// kcal-versus-macros check and what a weight change means for the user.
class TargetsRules {
  const TargetsRules._();

  static const minKcal = 1000.0;
  static const maxKcal = 6000.0;
  static const maxGrams = 1000.0;

  /// Relative gap between the kcal target and the energy implied by the
  /// macros above which the editor warns.
  static const mismatchTolerance = 0.05;

  /// Atwater factors: 4 kcal per gram of protein and carbohydrate, 9 per gram
  /// of fat.
  static double macroKcal({
    required double protein,
    required double carbs,
    required double fat,
  }) => protein * 4 + carbs * 4 + fat * 9;

  static bool macrosMismatch({
    required double kcal,
    required double protein,
    required double carbs,
    required double fat,
  }) {
    if (kcal <= 0) return false;
    final implied = macroKcal(protein: protein, carbs: carbs, fat: fat);
    return (implied - kcal).abs() > kcal * mismatchTolerance;
  }

  /// Reads a number typed with a decimal comma ("72,5") or a point. Returns
  /// null for empty or non-numeric text.
  static double? parse(String text) {
    final normalised = text.trim().replaceAll(',', '.');
    if (normalised.isEmpty) return null;
    final value = double.tryParse(normalised);
    return value != null && value.isFinite ? value : null;
  }

  static TargetsIssue? checkKcal(double? value) {
    if (value == null) return TargetsIssue.invalid;
    if (value < minKcal || value > maxKcal) return TargetsIssue.kcalRange;
    return null;
  }

  static TargetsIssue? checkGrams(double? value) {
    if (value == null) return TargetsIssue.invalid;
    if (value < 0 || value > maxGrams) return TargetsIssue.gramsRange;
    return null;
  }
}

/// What the app knows about targets right now: the stored profile plus the
/// weight the formula would use (the latest logged entry, else the profile).
class TargetsState {
  const TargetsState({required this.profile, this.latestWeight});

  final VyroProfile profile;

  /// The latest weight entry by measurement time, or null when none exists.
  final BodyMeasurement? latestWeight;

  /// Weight the automatic formula uses.
  double get weightKg => latestWeight?.weightKg ?? profile.weightKg;

  bool get manual => profile.manualTargets;

  /// True in manual mode when the weight moved since the targets were set or
  /// last acknowledged. Profiles without a recorded basis never trigger it.
  bool get weightChangedSinceManual {
    final basis = profile.targetsWeightKg;
    if (!manual || basis == null) return false;
    return (weightKg - basis).abs() >= 0.05;
  }

  static Future<TargetsState> load(AppDatabase database) async {
    final profile = await database.getUserProfile() ?? const VyroProfile();
    final latest = await database.latestBodyWeight();
    return TargetsState(profile: profile, latestWeight: latest);
  }
}

/// What a weight change did to the targets, for the feedback message.
enum WeightTargetsOutcome {
  /// Nothing the user needs to hear about.
  none,

  /// Automatic targets were recalculated to new values.
  updated,

  /// Manual targets stay, but the weight moved: offer a recalculation.
  hint,
}

/// Compares the targets before and after a weight change.
WeightTargetsOutcome weightTargetsOutcome({
  required TargetsState before,
  required TargetsState after,
}) {
  if (!after.manual) {
    final b = before.profile;
    final a = after.profile;
    final changed =
        b.calorieGoal.round() != a.calorieGoal.round() ||
        b.proteinGoal.round() != a.proteinGoal.round() ||
        b.carbsGoal.round() != a.carbsGoal.round() ||
        b.fatGoal.round() != a.fatGoal.round();
    return changed ? WeightTargetsOutcome.updated : WeightTargetsOutcome.none;
  }
  final weightMoved = after.weightKg != before.weightKg;
  return weightMoved && after.weightChangedSinceManual
      ? WeightTargetsOutcome.hint
      : WeightTargetsOutcome.none;
}
