import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/features/nutrition/domain/nutrition_targets_rules.dart';

void main() {
  group('parsing and ranges', () {
    test('reads decimal commas and points, rejects junk', () {
      expect(TargetsRules.parse('72,5'), 72.5);
      expect(TargetsRules.parse(' 2100 '), 2100);
      expect(TargetsRules.parse('150.5'), 150.5);
      expect(TargetsRules.parse(''), isNull);
      expect(TargetsRules.parse('abc'), isNull);
      expect(TargetsRules.parse('NaN'), isNull);
    });

    test('kcal must be between 1000 and 6000', () {
      expect(TargetsRules.checkKcal(null), TargetsIssue.invalid);
      expect(TargetsRules.checkKcal(999), TargetsIssue.kcalRange);
      expect(TargetsRules.checkKcal(1000), isNull);
      expect(TargetsRules.checkKcal(6000), isNull);
      expect(TargetsRules.checkKcal(6001), TargetsIssue.kcalRange);
    });

    test('macro grams must be between 0 and 1000', () {
      expect(TargetsRules.checkGrams(null), TargetsIssue.invalid);
      expect(TargetsRules.checkGrams(-1), TargetsIssue.gramsRange);
      expect(TargetsRules.checkGrams(0), isNull);
      expect(TargetsRules.checkGrams(1000), isNull);
      expect(TargetsRules.checkGrams(1001), TargetsIssue.gramsRange);
    });
  });

  group('kcal and macros', () {
    test('uses 4, 4 and 9 kcal per gram', () {
      expect(TargetsRules.macroKcal(protein: 150, carbs: 200, fat: 70), 2030);
    });

    test('warns only beyond 5 percent of the kcal target', () {
      // 2100 implied against 2000: exactly 5 percent is still accepted.
      expect(
        TargetsRules.macrosMismatch(
          kcal: 2000,
          protein: 190,
          carbs: 200,
          fat: 60,
        ),
        isFalse,
      );
      // 2118 implied against 2000: beyond 5 percent.
      expect(
        TargetsRules.macrosMismatch(
          kcal: 2000,
          protein: 190,
          carbs: 200,
          fat: 62,
        ),
        isTrue,
      );
    });
  });

  group('weight change outcome', () {
    VyroProfile profile({
      double kcal = 2000,
      String mode = VyroProfile.modeAutomatic,
      double? basis,
    }) => VyroProfile(
      sex: 'female',
      age: 32,
      heightCm: 168,
      weightKg: 70,
      calorieGoal: kcal,
      targetMode: mode,
      targetsWeightKg: basis,
    );

    BodyMeasurement weight(double kg) => BodyMeasurement(
      id: 1,
      measuredAt: DateTime(2026, 10, 25, 12),
      weightKg: kg,
      note: null,
    );

    test('automatic targets that changed are reported as updated', () {
      final outcome = weightTargetsOutcome(
        before: TargetsState(profile: profile(kcal: 2150)),
        after: TargetsState(
          profile: profile(kcal: 2100),
          latestWeight: weight(72.5),
        ),
      );
      expect(outcome, WeightTargetsOutcome.updated);
    });

    test('unchanged automatic targets stay silent', () {
      final outcome = weightTargetsOutcome(
        before: TargetsState(profile: profile(kcal: 2100)),
        after: TargetsState(
          profile: profile(kcal: 2100),
          latestWeight: weight(72.5),
        ),
      );
      expect(outcome, WeightTargetsOutcome.none);
    });

    test('manual targets with a moved weight offer a recalculation', () {
      final outcome = weightTargetsOutcome(
        before: TargetsState(
          profile: profile(mode: VyroProfile.modeManual, basis: 70),
        ),
        after: TargetsState(
          profile: profile(mode: VyroProfile.modeManual, basis: 70),
          latestWeight: weight(72.5),
        ),
      );
      expect(outcome, WeightTargetsOutcome.hint);
    });

    test('manual targets stay silent when the latest weight did not move', () {
      final outcome = weightTargetsOutcome(
        before: TargetsState(
          profile: profile(mode: VyroProfile.modeManual, basis: 70),
          latestWeight: weight(70),
        ),
        after: TargetsState(
          profile: profile(mode: VyroProfile.modeManual, basis: 70),
          latestWeight: weight(70),
        ),
      );
      expect(outcome, WeightTargetsOutcome.none);
    });
  });
}
