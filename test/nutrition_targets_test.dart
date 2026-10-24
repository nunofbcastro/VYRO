import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/onboarding/domain/nutrition_targets.dart';

void main() {
  NutritionTargets targets({
    String sex = 'male',
    int age = 30,
    double height = 178,
    double weight = 78,
    String activity = 'moderate',
    String goal = 'routine',
  }) => NutritionTargets.calculate(
    sex: sex,
    age: age,
    heightCm: height,
    weightKg: weight,
    activityLevel: activity,
    goal: goal,
  );

  test('returns sane energy and macro values', () {
    final result = targets();
    expect(result.kcal, inInclusiveRange(1200, 4500));
    expect(result.protein, greaterThan(0));
    expect(result.carbs, greaterThan(0));
    expect(result.fat, greaterThan(0));
    expect((result.macroKcal - result.kcal).abs(), lessThan(20));
  });

  test('female estimate is lower than male for the same body data', () {
    expect(targets(sex: 'female').kcal, lessThan(targets(sex: 'male').kcal));
  });

  test('goal factors order energy targets', () {
    final cut = targets(goal: 'nutrition').kcal;
    final maintain = targets(goal: 'routine').kcal;
    final gain = targets(goal: 'strength').kcal;
    expect(cut, lessThan(maintain));
    expect(maintain, lessThan(gain));
  });

  test('higher activity increases the energy estimate', () {
    expect(
      targets(activity: 'low').kcal,
      lessThan(targets(activity: 'high').kcal),
    );
  });

  test('extreme inputs stay inside safe bounds', () {
    final result = NutritionTargets.calculate(
      sex: 'female',
      age: 200,
      heightCm: 20,
      weightKg: 500,
      activityLevel: 'high',
      goal: 'strength',
    );
    expect(result.kcal, inInclusiveRange(1200, 4500));
    expect(result.protein, inInclusiveRange(60, 260));
    expect(result.carbs, inInclusiveRange(50, 600));
    expect(result.fat, inInclusiveRange(35, 160));
  });
}
