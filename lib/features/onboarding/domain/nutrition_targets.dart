/// Deterministic starting targets for the onboarding summary.
///
/// These are estimates, not medical or nutritional advice. The formula is
/// intentionally simple and documented so the result can be explained:
/// Mifflin-St Jeor BMR × activity factor × goal factor, then a macro split
/// based on body weight.
class NutritionTargets {
  const NutritionTargets({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  /// Estimated energy from the macro split. Useful for tests and for showing
  /// that the displayed macros are consistent with the calorie target.
  double get macroKcal => protein * 4 + carbs * 4 + fat * 9;

  static NutritionTargets calculate({
    required String sex,
    required int age,
    required double heightCm,
    required double weightKg,
    required String activityLevel,
    required String goal,
  }) {
    final safeAge = age.clamp(14, 100);
    final safeHeight = heightCm.clamp(120, 230);
    final safeWeight = weightKg.clamp(30, 300);

    // Mifflin-St Jeor. "unspecified" uses the midpoint of the male/female
    // constants so the estimate stays neutral without inventing data.
    final sexConstant = switch (sex) {
      'male' => 5.0,
      'female' => -161.0,
      _ => -78.0,
    };
    final bmr = 10 * safeWeight + 6.25 * safeHeight - 5 * safeAge + sexConstant;

    final activityFactor = switch (activityLevel) {
      'low' => 1.25,
      'high' => 1.65,
      _ => 1.45,
    };
    final goalFactor = switch (goal) {
      'strength' => 1.08,
      'nutrition' => 0.88,
      _ => 1.0,
    };

    final kcal = (bmr * activityFactor * goalFactor).clamp(1200, 4500);
    final roundedKcal = (kcal / 10).round() * 10.0;

    final proteinPerKg = goal == 'strength' ? 2.0 : 1.8;
    final protein = (safeWeight * proteinPerKg).clamp(60, 260);
    final fat = (safeWeight * 0.9).clamp(35, 160);
    final carbs = ((roundedKcal - protein * 4 - fat * 9) / 4).clamp(50, 600);

    return NutritionTargets(
      kcal: roundedKcal,
      protein: protein.roundToDouble(),
      carbs: carbs.roundToDouble(),
      fat: fat.roundToDouble(),
    );
  }
}
