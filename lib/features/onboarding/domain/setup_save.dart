import '../../../core/database/app_database.dart';
import '../../motion_engine/feedback_engine/coach_voice_settings.dart';
import '../../motion_engine/workout_camera/motion_coach_page.dart'
    show kVoiceCoachPreferenceKey;
import '../onboarding_draft.dart';

/// Writes the setup answers to the same stores the settings screens read and
/// edit. Nothing is copied: the profile row, the weight log and the preference
/// keys are the single source of truth for the rest of the app.
///
/// Order matters: the profile first (its automatic targets are resolved from
/// the latest logged weight), then the body weight (one entry per calendar
/// day, so re-running setup replaces today's entry instead of adding one),
/// then manual targets when chosen.
Future<void> saveSetup(
  AppDatabase database,
  OnboardingDraft draft, {
  required String locale,
  required String theme,
  DateTime? now,
}) async {
  await database.saveUserProfile(draft.toProfile(locale: locale, theme: theme));
  await database.saveBodyWeight(
    measuredAt: now ?? DateTime.now(),
    weightKg: draft.weightKg.clamp(30, 300).toDouble(),
    replaceSameDay: true,
  );
  if (draft.manualTargets) {
    await database.saveManualTargets(
      kcal: draft.manualKcal!,
      protein: draft.manualProtein!,
      carbs: draft.manualCarbs!,
      fat: draft.manualFat!,
    );
  }
  await database.setPreference(
    kVoiceCoachPreferenceKey,
    draft.coachVoice ? 'on' : 'off',
  );
  if (draft.coachVoice) {
    // Only the phrase toggle is written here; the voice choice, speed and
    // pitch keep whatever the coach voice sheet stored before.
    final preferences = CoachVoicePreferences(
      read: database.getPreference,
      write: database.setPreference,
    );
    final current = await preferences.load();
    await preferences.save(current.copyWith(llmPhrases: draft.llmPhrases));
  }
}
