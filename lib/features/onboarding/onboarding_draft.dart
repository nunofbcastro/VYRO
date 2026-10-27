import '../../core/database/app_database.dart';
import '../nutrition/domain/nutrition_targets_rules.dart';
import 'domain/nutrition_targets.dart';

/// Editable state for the base-data wizard. Keeping it outside the widgets
/// makes validation and profile creation testable without a database.
///
/// The draft never keeps a copy of a value that the app reads elsewhere: it
/// is written to the same `VyroProfile` row, weight log and preferences that
/// the settings screens edit (see [saveSetup]).
class OnboardingDraft {
  OnboardingDraft({
    this.name = '',
    this.sex = 'unspecified',
    this.age = 30,
    this.heightCm = 175,
    this.weightKg = 75,
    this.goal = 'routine',
    this.activityLevel = 'moderate',
    this.dietaryChoice = 'none',
    this.workoutExperience = 'beginner',
    this.trainingDays = 3,
    this.targetMode = VyroProfile.modeAutomatic,
    this.manualKcal,
    this.manualProtein,
    this.manualCarbs,
    this.manualFat,
    this.coachVoice = false,
    this.llmPhrases = true,
    Set<String>? equipment,
  }) : equipment = equipment ?? {'bodyweight', 'dumbbells', 'cable'};

  factory OnboardingDraft.fromProfile(VyroProfile? profile) {
    if (profile == null) return OnboardingDraft();
    return OnboardingDraft(
      name: profile.name,
      sex: profile.sex,
      age: profile.age,
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
      goal: profile.goal,
      activityLevel: profile.activityLevel,
      dietaryChoice: profile.dietaryChoice,
      workoutExperience: profile.workoutExperience,
      trainingDays: profile.trainingDays,
      targetMode: profile.targetMode,
      manualKcal: profile.manualTargets ? profile.calorieGoal : null,
      manualProtein: profile.manualTargets ? profile.proteinGoal : null,
      manualCarbs: profile.manualTargets ? profile.carbsGoal : null,
      manualFat: profile.manualTargets ? profile.fatGoal : null,
      equipment: profile.availableEquipment.toSet(),
    );
  }

  String name;
  String sex;
  int age;
  double heightCm;
  double weightKg;
  String goal;
  String activityLevel;
  String dietaryChoice;
  String workoutExperience;
  int trainingDays;
  Set<String> equipment;

  /// `VyroProfile.modeAutomatic` (default) or `VyroProfile.modeManual`.
  String targetMode;
  double? manualKcal;
  double? manualProtein;
  double? manualCarbs;
  double? manualFat;

  /// Modo PT spoken coach. Off by default; stored under the same key the
  /// workout camera reads.
  bool coachVoice;

  /// "Frases geradas pela IA do telemóvel": only offered while [coachVoice]
  /// is on and the on-device model is available. Stored in the coach voice
  /// settings (`CoachVoiceSettings.llmPhrases`).
  bool llmPhrases;

  bool get manualTargets => targetMode == VyroProfile.modeManual;

  /// Automatic targets from the body data, the same formula the database
  /// uses when it recomputes targets from the latest weight.
  NutritionTargets get automaticTargets => NutritionTargets.calculate(
    sex: sex,
    age: age,
    heightCm: heightCm,
    weightKg: weightKg,
    activityLevel: activityLevel,
    goal: goal,
  );

  /// Targets the user will see in the review step and the app will use.
  NutritionTargets get targets {
    if (manualTargets &&
        manualKcal != null &&
        manualProtein != null &&
        manualCarbs != null &&
        manualFat != null) {
      return NutritionTargets(
        kcal: manualKcal!,
        protein: manualProtein!,
        carbs: manualCarbs!,
        fat: manualFat!,
      );
    }
    return automaticTargets;
  }

  /// Switches to manual targets, starting from the automatic values so the
  /// user only edits what they want to change.
  void startManualTargets() {
    final auto = automaticTargets;
    manualKcal ??= auto.kcal;
    manualProtein ??= auto.protein;
    manualCarbs ??= auto.carbs;
    manualFat ??= auto.fat;
    targetMode = VyroProfile.modeManual;
  }

  void useAutomaticTargets() => targetMode = VyroProfile.modeAutomatic;

  /// Energy implied by the manual macros (4/4/9 kcal per gram).
  double get manualMacroKcal => TargetsRules.macroKcal(
    protein: manualProtein ?? 0,
    carbs: manualCarbs ?? 0,
    fat: manualFat ?? 0,
  );

  /// True when the manual macros differ from the manual kcal by more than the
  /// tolerance of the targets editor. Only checked once kcal is in range.
  bool get manualMacrosMismatch {
    if (!manualTargets || TargetsRules.checkKcal(manualKcal) != null) {
      return false;
    }
    if (TargetsRules.checkGrams(manualProtein) != null ||
        TargetsRules.checkGrams(manualCarbs) != null ||
        TargetsRules.checkGrams(manualFat) != null) {
      return false;
    }
    return TargetsRules.macrosMismatch(
      kcal: manualKcal!,
      protein: manualProtein!,
      carbs: manualCarbs!,
      fat: manualFat!,
    );
  }

  /// Relative difference in whole percent, as the targets editor shows it.
  int get manualMismatchPercent {
    final kcal = manualKcal;
    if (kcal == null || kcal <= 0) return 0;
    return ((manualMacroKcal - kcal).abs() / kcal * 100).round();
  }

  /// Sets the manual kcal to the value the macros imply (rounded).
  void adjustManualKcalToMacros() =>
      manualKcal = manualMacroKcal.roundToDouble();

  /// Null when the manual values are usable, otherwise the first problem.
  /// Uses the same rules as the targets editor (`nutrition_targets_rules.dart`).
  TargetsIssue? manualTargetsIssue() {
    if (!manualTargets) return null;
    return TargetsRules.checkKcal(manualKcal) ??
        TargetsRules.checkGrams(manualProtein) ??
        TargetsRules.checkGrams(manualCarbs) ??
        TargetsRules.checkGrams(manualFat);
  }

  VyroProfile toProfile({
    required String locale,
    required String theme,
    NutritionTargets? targets,
  }) {
    final result = targets ?? this.targets;
    final manual = manualTargets;
    return VyroProfile(
      name: name.trim(),
      goal: goal,
      activityLevel: activityLevel,
      dietaryChoice: dietaryChoice,
      workoutExperience: workoutExperience,
      availableEquipment: equipment.isEmpty
          ? const ['bodyweight']
          : (equipment.toList()..sort()),
      trainingDays: trainingDays.clamp(1, 7),
      calorieGoal: result.kcal,
      proteinGoal: result.protein,
      carbsGoal: result.carbs,
      fatGoal: result.fat,
      targetMode: manual ? VyroProfile.modeManual : VyroProfile.modeAutomatic,
      targetsWeightKg: manual ? weightKg.clamp(30, 300).toDouble() : null,
      locale: locale == 'en' ? 'en' : 'pt',
      theme: const {'light', 'dark', 'system'}.contains(theme) ? theme : 'dark',
      sex: sex,
      age: age.clamp(14, 100),
      heightCm: heightCm.clamp(120, 230),
      weightKg: weightKg.clamp(30, 300),
      onboardingCompleted: true,
    );
  }
}
