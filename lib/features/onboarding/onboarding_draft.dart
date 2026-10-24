import '../../core/database/app_database.dart';
import 'domain/nutrition_targets.dart';

/// Editable state for the base-data wizard. Keeping it outside the widgets
/// makes validation and profile creation testable without a database.
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

  NutritionTargets get targets => NutritionTargets.calculate(
    sex: sex,
    age: age,
    heightCm: heightCm,
    weightKg: weightKg,
    activityLevel: activityLevel,
    goal: goal,
  );

  VyroProfile toProfile({
    required String locale,
    required String theme,
    NutritionTargets? targets,
  }) {
    final result = targets ?? this.targets;
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
