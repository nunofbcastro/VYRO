import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/features/onboarding/onboarding_draft.dart';

void main() {
  test('draft creates a completed profile with computed targets', () {
    final draft = OnboardingDraft(
      name: '  Alex  ',
      sex: 'female',
      age: 32,
      heightCm: 168,
      weightKg: 64,
      goal: 'nutrition',
      activityLevel: 'moderate',
      trainingDays: 4,
      equipment: {'dumbbells', 'bodyweight'},
    );
    final profile = draft.toProfile(locale: 'en', theme: 'light');

    expect(profile.name, 'Alex');
    expect(profile.onboardingCompleted, isTrue);
    expect(profile.locale, 'en');
    expect(profile.theme, 'light');
    expect(profile.sex, 'female');
    expect(profile.age, 32);
    expect(profile.heightCm, 168);
    expect(profile.weightKg, 64);
    expect(profile.trainingDays, 4);
    expect(profile.availableEquipment, ['bodyweight', 'dumbbells']);
    expect(profile.calorieGoal, draft.targets.kcal);
    expect(profile.proteinGoal, draft.targets.protein);
  });

  test('draft round-trips through the profile JSON format', () {
    final profile = OnboardingDraft(
      name: 'Sam',
      sex: 'unspecified',
      age: 41,
      heightCm: 181,
      weightKg: 88,
      goal: 'strength',
      activityLevel: 'high',
      trainingDays: 5,
      equipment: {'cable'},
    ).toProfile(locale: 'pt', theme: 'system');

    final restored = VyroProfile.fromJson(profile.toJson());
    expect(restored.name, profile.name);
    expect(restored.sex, profile.sex);
    expect(restored.age, profile.age);
    expect(restored.heightCm, profile.heightCm);
    expect(restored.weightKg, profile.weightKg);
    expect(restored.onboardingCompleted, isTrue);
    expect(restored.theme, 'system');
    expect(restored.availableEquipment, ['cable']);
  });

  test('legacy profiles without onboarding data stay incomplete', () {
    final restored = VyroProfile.fromJson(const {
      'name': 'Legacy',
      'goal': 'routine',
      'activityLevel': 'moderate',
      'dietaryChoice': 'none',
      'workoutExperience': 'beginner',
      'trainingDays': 3,
      'calorieGoal': 2200,
      'proteinGoal': 140,
      'carbsGoal': 260,
      'fatGoal': 75,
      'locale': 'pt',
      'theme': 'dark',
    });
    expect(restored.onboardingCompleted, isFalse);
    expect(restored.sex, 'unspecified');
    expect(restored.age, 30);
    expect(restored.heightCm, 175);
    expect(restored.weightKg, 75);
  });

  test('invalid values are clamped when read back', () {
    final restored = VyroProfile.fromJson(const {
      'sex': 'invalid',
      'age': 5,
      'heightCm': 10,
      'weightKg': 900,
      'onboardingCompleted': true,
    });
    expect(restored.sex, 'unspecified');
    expect(restored.age, 14);
    expect(restored.heightCm, 120);
    expect(restored.weightKg, 300);
  });
}
