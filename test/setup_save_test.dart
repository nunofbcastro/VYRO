import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/features/nutrition/domain/nutrition_targets_rules.dart';
import 'package:vyro/features/onboarding/domain/setup_save.dart';
import 'package:vyro/features/onboarding/onboarding_draft.dart';
import 'package:vyro/features/workouts/data/workout_repository.dart';
import 'package:vyro/features/motion_engine/workout_camera/motion_coach_page.dart'
    show kVoiceCoachPreferenceKey;

OnboardingDraft _draft({double weight = 80}) => OnboardingDraft(
  name: 'Alex',
  sex: 'male',
  age: 35,
  heightCm: 180,
  weightKg: weight,
  goal: 'routine',
  activityLevel: 'moderate',
  trainingDays: 4,
  equipment: {'bodyweight', 'dumbbells'},
);

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'setup creates the first dated weight entry from the body step',
    () async {
      final now = DateTime(2026, 10, 26, 9);
      await saveSetup(
        database,
        _draft(weight: 82.5),
        locale: 'pt',
        theme: 'dark',
        now: now,
      );

      final latest = await database.latestBodyWeight();
      expect(latest, isNotNull);
      expect(latest!.weightKg, 82.5);
      expect(latest.measuredAt, now);
    },
  );

  test(
    'automatic targets are the default and follow the logged weight',
    () async {
      final draft = _draft(weight: 80);
      await saveSetup(database, draft, locale: 'pt', theme: 'dark');

      final profile = (await database.getUserProfile())!;
      expect(profile.targetMode, VyroProfile.modeAutomatic);
      expect(profile.calorieGoal, draft.automaticTargets.kcal);
      expect(profile.proteinGoal, draft.automaticTargets.protein);
      expect(profile.carbsGoal, draft.automaticTargets.carbs);
      expect(profile.fatGoal, draft.automaticTargets.fat);
    },
  );

  test(
    'manual inline edit saves manual targets and validates ranges',
    () async {
      final draft = _draft();
      draft.startManualTargets();
      expect(draft.manualTargetsIssue(), isNull);

      draft.manualKcal = 2200;
      draft.manualProtein = 160;
      draft.manualCarbs = 210;
      draft.manualFat = 70;
      await saveSetup(database, draft, locale: 'pt', theme: 'dark');

      final profile = (await database.getUserProfile())!;
      expect(profile.manualTargets, isTrue);
      expect(profile.calorieGoal, 2200);
      expect(profile.proteinGoal, 160);
      expect(profile.carbsGoal, 210);
      expect(profile.fatGoal, 70);
    },
  );

  test('out-of-range manual kcal is reported, not saved', () {
    final draft = _draft()..startManualTargets();
    draft.manualKcal = 500;
    expect(draft.manualTargetsIssue(), TargetsIssue.kcalRange);
    draft.manualKcal = 2000;
    draft.manualFat = 2000;
    expect(draft.manualTargetsIssue(), TargetsIssue.gramsRange);
  });

  test('re-running setup on the same day replaces the entry', () async {
    final day = DateTime(2026, 10, 26, 8);
    await saveSetup(
      database,
      _draft(weight: 80),
      locale: 'pt',
      theme: 'dark',
      now: day,
    );
    await saveSetup(
      database,
      _draft(weight: 79),
      locale: 'pt',
      theme: 'dark',
      now: DateTime(2026, 10, 26, 18),
    );

    final entries = await database.watchBodyWeights().first;
    expect(entries, hasLength(1));
    expect(entries.single.weightKg, 79);
  });

  test('voice coach is off by default and optional', () async {
    await saveSetup(database, _draft(), locale: 'pt', theme: 'dark');
    expect(await database.getPreference(kVoiceCoachPreferenceKey), 'off');

    final draft = _draft()..coachVoice = true;
    await saveSetup(database, draft, locale: 'pt', theme: 'dark');
    expect(await database.getPreference(kVoiceCoachPreferenceKey), 'on');
  });

  test('planner defaults come from the setup answers', () async {
    await saveSetup(database, _draft(), locale: 'pt', theme: 'dark');
    final prefs = await WorkoutRepository(database).loadPreferences();
    expect(prefs.daysPerWeek, 4);
    expect(prefs.equipment, {'bodyweight', 'dumbbells'});
    expect(prefs.goal, 'health');
  });
}
