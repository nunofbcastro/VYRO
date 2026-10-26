import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/features/onboarding/domain/nutrition_targets.dart';
import 'package:vyro/features/nutrition/domain/nutrition_targets_rules.dart';

/// Profile used by every test: a routine goal with moderate activity.
const _base = VyroProfile(
  name: 'Ana',
  sex: 'female',
  age: 32,
  heightCm: 168,
  weightKg: 70,
  goal: 'routine',
  activityLevel: 'moderate',
  onboardingCompleted: true,
);

/// The automatic kcal target the formula gives for [kg] with [_base].
double _kcalFor(double kg, {VyroProfile profile = _base}) =>
    NutritionTargets.calculate(
      sex: profile.sex,
      age: profile.age,
      heightCm: profile.heightCm,
      weightKg: kg,
      activityLevel: profile.activityLevel,
      goal: profile.goal,
    ).kcal;

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<VyroProfile> stored() async => (await database.getUserProfile())!;

  Future<void> weigh(DateTime day, double kg) => database.saveBodyWeight(
    measuredAt: DateTime(day.year, day.month, day.day, 12),
    weightKg: kg,
  );

  final oct1 = DateTime(2026, 10, 1);
  final oct20 = DateTime(2026, 10, 20);
  final oct25 = DateTime(2026, 10, 25);

  group('automatic targets follow the latest logged weight', () {
    test('the formula uses the latest entry by measurement time', () async {
      await database.saveUserProfile(_base);
      await weigh(oct20, 80);
      expect((await stored()).calorieGoal, _kcalFor(80));

      // A newer measurement day becomes the latest entry.
      await weigh(oct25, 74);
      final profile = await stored();
      expect(profile.calorieGoal, _kcalFor(74));
      expect(profile.targetsWeightKg, 74);
      expect(profile.targetMode, VyroProfile.modeAutomatic);
    });

    test('a backdated entry that is not the latest changes nothing', () async {
      await database.saveUserProfile(_base);
      await weigh(oct20, 80);
      final before = await stored();

      await weigh(oct1, 60);
      final after = await stored();
      expect(after.calorieGoal, before.calorieGoal);
      expect(after.calorieGoal, _kcalFor(80));
      expect(after.proteinGoal, before.proteinGoal);
      expect(after.targetsWeightKg, 80);
    });

    test('deleting the latest entry uses the previous one', () async {
      await database.saveUserProfile(_base);
      await weigh(oct1, 70);
      await weigh(oct20, 80);
      final latest = (await database.latestBodyWeight())!;
      expect(latest.weightKg, 80);

      await database.deleteBodyWeight(latest.id);
      expect((await stored()).calorieGoal, _kcalFor(70));
    });

    test('restoring the deleted latest entry brings its target back', () async {
      await database.saveUserProfile(_base);
      await weigh(oct1, 70);
      await weigh(oct20, 80);
      final latest = (await database.latestBodyWeight())!;

      await database.deleteBodyWeight(latest.id);
      expect((await stored()).calorieGoal, _kcalFor(70));

      expect(await database.restoreBodyWeight(latest), isTrue);
      expect((await stored()).calorieGoal, _kcalFor(80));
    });

    test('with no entries the profile weight is used', () async {
      await database.saveUserProfile(_base);
      expect((await stored()).calorieGoal, _kcalFor(70));

      await weigh(oct20, 80);
      await database.deleteBodyWeight((await database.latestBodyWeight())!.id);
      final profile = await stored();
      expect(profile.calorieGoal, _kcalFor(70));
      expect(profile.targetsWeightKg, 70);
    });

    test('changing goal or activity recalculates automatic targets', () async {
      await database.saveUserProfile(_base);
      await database.saveUserProfile(
        (await stored()).copyWith(goal: 'strength', activityLevel: 'high'),
      );
      final strength = _base.copyWith(goal: 'strength', activityLevel: 'high');
      final profile = await stored();
      expect(profile.calorieGoal, _kcalFor(70, profile: strength));
      expect(
        profile.proteinGoal,
        NutritionTargets.calculate(
          sex: strength.sex,
          age: strength.age,
          heightCm: strength.heightCm,
          weightKg: 70,
          activityLevel: 'high',
          goal: 'strength',
        ).protein,
      );
    });
  });

  group('manual targets', () {
    test('survive weight changes and are reported as changed', () async {
      await database.saveUserProfile(_base);
      await database.saveManualTargets(
        kcal: 2000,
        protein: 150,
        carbs: 200,
        fat: 60,
      );
      await weigh(oct20, 90);

      final profile = await stored();
      expect(profile.targetMode, VyroProfile.modeManual);
      expect(profile.calorieGoal, 2000);
      expect(profile.proteinGoal, 150);
      expect(profile.targetsWeightKg, 70);

      final state = await TargetsState.load(database);
      expect(state.manual, isTrue);
      expect(state.weightKg, 90);
      expect(state.weightChangedSinceManual, isTrue);
    });

    test('returning to automatic recomputes from the latest weight', () async {
      await database.saveUserProfile(_base);
      await weigh(oct20, 80);
      await database.saveManualTargets(
        kcal: 1800,
        protein: 120,
        carbs: 150,
        fat: 50,
      );

      await database.useAutomaticTargets();
      final profile = await stored();
      expect(profile.targetMode, VyroProfile.modeAutomatic);
      expect(profile.calorieGoal, _kcalFor(80));
      expect(profile.targetsWeightKg, 80);
    });

    test('keeping manual targets acknowledges the new weight', () async {
      await database.saveUserProfile(_base);
      await database.saveManualTargets(
        kcal: 2000,
        protein: 150,
        carbs: 200,
        fat: 60,
      );
      await weigh(oct20, 90);
      await database.keepManualTargets();

      final state = await TargetsState.load(database);
      expect(state.manual, isTrue);
      expect(state.profile.calorieGoal, 2000);
      expect(state.weightChangedSinceManual, isFalse);
    });

    test('a manual profile is not touched by profile saves', () async {
      await database.saveManualTargets(
        kcal: 2100,
        protein: 140,
        carbs: 230,
        fat: 70,
      );
      await database.saveUserProfile(
        (await stored()).copyWith(goal: 'nutrition'),
      );
      expect((await stored()).calorieGoal, 2100);
    });
  });

  group('export, import and deletion', () {
    test('a manual export round-trips mode and values', () async {
      await database.saveUserProfile(_base);
      await weigh(oct20, 80);
      await database.saveManualTargets(
        kcal: 1900,
        protein: 130,
        carbs: 190,
        fat: 55,
      );
      final exported = jsonDecode(jsonEncode(await database.exportAllData()));

      final copy = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(copy.close);
      await copy.importAllData(exported as Map<String, dynamic>);

      final profile = (await copy.getUserProfile())!;
      expect(profile.targetMode, VyroProfile.modeManual);
      expect(profile.calorieGoal, 1900);
      expect(profile.proteinGoal, 130);
      expect(profile.carbsGoal, 190);
      expect(profile.fatGoal, 55);
      expect(profile.targetsWeightKg, 80);
    });

    test(
      'an automatic export recalculates from the imported weights',
      () async {
        await database.saveUserProfile(_base);
        await weigh(oct20, 80);
        final exported = jsonDecode(jsonEncode(await database.exportAllData()));

        final copy = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(copy.close);
        await copy.importAllData(exported as Map<String, dynamic>);

        final profile = (await copy.getUserProfile())!;
        expect(profile.targetMode, VyroProfile.modeAutomatic);
        expect(profile.calorieGoal, _kcalFor(80));
      },
    );

    test('profiles saved before the mode existed are automatic', () {
      final legacy = VyroProfile.fromJson({
        'name': 'Ana',
        'calorieGoal': 2300,
        'proteinGoal': 150,
        'carbsGoal': 250,
        'fatGoal': 70,
      });
      expect(legacy.targetMode, VyroProfile.modeAutomatic);
      expect(legacy.targetsWeightKg, isNull);
      expect(legacy.manualTargets, isFalse);
    });

    test('clearing the data removes the profile and its mode', () async {
      await database.saveManualTargets(
        kcal: 2000,
        protein: 150,
        carbs: 200,
        fat: 60,
      );
      await database.clearUserData();
      expect(await database.getUserProfile(), isNull);

      final state = await TargetsState.load(database);
      expect(state.manual, isFalse);
    });
  });
}
