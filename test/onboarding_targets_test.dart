import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/features/motion_engine/feedback_engine/coach_voice_settings.dart';
import 'package:vyro/features/motion_engine/workout_camera/motion_coach_page.dart'
    show kVoiceCoachPreferenceKey;
import 'package:vyro/features/onboarding/domain/setup_save.dart';
import 'package:vyro/features/onboarding/onboarding_draft.dart';

OnboardingDraft _manual({
  required double kcal,
  required double protein,
  required double carbs,
  required double fat,
}) {
  final draft = OnboardingDraft()
    ..targetMode = VyroProfile.modeManual
    ..manualKcal = kcal
    ..manualProtein = protein
    ..manualCarbs = carbs
    ..manualFat = fat;
  return draft;
}

void main() {
  group('manual macros versus kcal (review step)', () {
    test('warns when the macros differ by more than 5%', () {
      // 100 g protein, 200 g carbs, 60 g fat = 1740 kcal against 2000 kcal.
      final draft = _manual(kcal: 2000, protein: 100, carbs: 200, fat: 60);

      expect(draft.manualMacroKcal, 1740);
      expect(draft.manualMacrosMismatch, isTrue);
      expect(draft.manualMismatchPercent, 13);
    });

    test('does not warn inside the 5% tolerance', () {
      final draft = _manual(kcal: 1740, protein: 100, carbs: 200, fat: 60);

      expect(draft.manualMacrosMismatch, isFalse);
      expect(draft.manualMismatchPercent, 0);
    });

    test('does not warn in automatic mode or with an out-of-range kcal', () {
      final automatic = _manual(kcal: 2000, protein: 100, carbs: 200, fat: 60)
        ..targetMode = VyroProfile.modeAutomatic;
      expect(automatic.manualMacrosMismatch, isFalse);

      // Out of range is reported by the field validation, not the warning.
      final low = _manual(kcal: 500, protein: 100, carbs: 200, fat: 60);
      expect(low.manualMacrosMismatch, isFalse);
      expect(low.manualTargetsIssue(), isNotNull);
    });

    test('adjusting kcal to the macros removes the warning', () {
      final draft = _manual(kcal: 2000, protein: 100, carbs: 200, fat: 60);

      draft.adjustManualKcalToMacros();

      expect(draft.manualKcal, 1740);
      expect(draft.manualMacrosMismatch, isFalse);
      expect(draft.manualTargetsIssue(), isNull);
    });
  });

  group('saveSetup coach phrase toggle', () {
    late AppDatabase database;

    setUp(() => database = AppDatabase(executor: NativeDatabase.memory()));
    tearDown(() => database.close());

    test('stores the phrase toggle when Modo PT is on', () async {
      await saveSetup(
        database,
        OnboardingDraft(coachVoice: true, llmPhrases: false),
        locale: 'pt',
        theme: 'dark',
        now: DateTime(2026, 10, 26),
      );

      final stored = await CoachVoicePreferences(
        read: database.getPreference,
        write: database.setPreference,
      ).load();
      expect(stored.llmPhrases, isFalse);
      expect(await database.getPreference(kVoiceCoachPreferenceKey), 'on');
    });

    test('leaves the stored phrase toggle alone when Modo PT is off', () async {
      final preferences = CoachVoicePreferences(
        read: database.getPreference,
        write: database.setPreference,
      );
      await preferences.save(const CoachVoiceSettings(llmPhrases: true));

      await saveSetup(
        database,
        OnboardingDraft(coachVoice: false, llmPhrases: false),
        locale: 'pt',
        theme: 'dark',
        now: DateTime(2026, 10, 26),
      );

      expect((await preferences.load()).llmPhrases, isTrue);
      expect(await database.getPreference(kVoiceCoachPreferenceKey), 'off');
    });
  });
}
