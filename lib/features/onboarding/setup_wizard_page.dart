import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../app/theme/appearance_sheet.dart';
import '../../app/theme/vyro_chrome.dart';
import '../../app/theme/vyro_theme.dart';
import '../../core/database/app_database.dart';
import '../motion_engine/feedback_engine/coach_llm_phrases.dart';
import '../motion_engine/feedback_engine/coach_voice_settings.dart';
import '../motion_engine/workout_camera/motion_coach_page.dart'
    show kVoiceCoachPreferenceKey;
import '../nutrition/domain/nutrition_targets_rules.dart';
import '../workouts/plan_wizard_page.dart';
import 'domain/setup_save.dart';
import 'onboarding_draft.dart';

class SetupWizardPage extends StatefulWidget {
  const SetupWizardPage({
    super.key,
    this.preview = false,
    this.onFinished,
    this.onBackToTutorial,
  });

  final bool preview;
  final ValueChanged<VyroProfile>? onFinished;
  final VoidCallback? onBackToTutorial;

  @override
  State<SetupWizardPage> createState() => _SetupWizardPageState();
}

class _SetupWizardPageState extends State<SetupWizardPage> {
  static const _stepCount = 8;

  late final OnboardingDraft draft = OnboardingDraft.fromProfile(
    SettingsScope.maybeOf(context)?.profile,
  );
  late final TextEditingController nameController = TextEditingController(
    text: draft.name,
  );
  late final TextEditingController ageController = TextEditingController(
    text: draft.age.toString(),
  );
  late final TextEditingController heightController = TextEditingController(
    text: _number(draft.heightCm),
  );
  late final TextEditingController weightController = TextEditingController(
    text: _number(draft.weightKg),
  );
  final ScrollController scrollController = ScrollController();

  // Manual target fields are controllers (not initialValue) so the
  // "Ajustar kcal às macros" action can update the kcal text in place.
  final TextEditingController manualKcalController = TextEditingController();
  final TextEditingController manualProteinController = TextEditingController();
  final TextEditingController manualCarbsController = TextEditingController();
  final TextEditingController manualFatController = TextEditingController();

  int step = 0;
  bool saving = false;
  String? error;

  /// Whether the on-device model can write coach phrases. Null while checking.
  bool? llmAvailable;

  static String _number(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);

  static String _manualText(double? value) =>
      value == null ? '' : value.round().toString();

  bool _controllersSynced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStored());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The draft reads SettingsScope, which is only allowed after initState.
    if (!_controllersSynced) {
      _controllersSynced = true;
      _syncManualControllers();
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    heightController.dispose();
    weightController.dispose();
    scrollController.dispose();
    manualKcalController.dispose();
    manualProteinController.dispose();
    manualCarbsController.dispose();
    manualFatController.dispose();
    super.dispose();
  }

  void _syncManualControllers() {
    manualKcalController.text = _manualText(draft.manualKcal);
    manualProteinController.text = _manualText(draft.manualProtein);
    manualCarbsController.text = _manualText(draft.manualCarbs);
    manualFatController.text = _manualText(draft.manualFat);
  }

  /// Reads the Modo PT switch and the phrase toggle from the same stores the
  /// coach settings use, and checks whether the on-device model is there.
  Future<void> _loadStored() async {
    if (!mounted) return;
    final services = AppServicesScope.of(context);
    final database = services.database;
    var voiceOn = draft.coachVoice;
    var phrases = draft.llmPhrases;
    var available = false;
    try {
      voiceOn = await database.getPreference(kVoiceCoachPreferenceKey) == 'on';
      final stored = await CoachVoicePreferences(
        read: database.getPreference,
        write: database.setPreference,
      ).load();
      phrases = stored.llmPhrases ?? true;
      available = await CoachLlmPhrases(services.llm).isAvailable();
    } catch (_) {
      // Unreadable stores keep the defaults; the phrase toggle stays disabled.
    }
    if (!mounted) return;
    setState(() {
      draft.coachVoice = voiceOn;
      draft.llmPhrases = phrases;
      llmAvailable = available;
    });
  }

  void _syncDraft() {
    draft.name = nameController.text.trim();
    draft.age = int.tryParse(ageController.text.trim()) ?? 0;
    draft.heightCm =
        double.tryParse(heightController.text.replaceAll(',', '.').trim()) ?? 0;
    draft.weightKg =
        double.tryParse(weightController.text.replaceAll(',', '.').trim()) ?? 0;
  }

  String? _validationFor(int index) {
    final t = stringsOf(context);
    switch (index) {
      case 0:
        return draft.name.length > 40 ? t.get('setupNameTooLong') : null;
      case 1:
        if (draft.age < 14 || draft.age > 100) return t.get('setupInvalidAge');
        if (draft.heightCm < 120 || draft.heightCm > 230) {
          return t.get('setupInvalidHeight');
        }
        if (draft.weightKg < 30 || draft.weightKg > 300) {
          return t.get('setupInvalidWeight');
        }
        return null;
      case 5:
        return draft.equipment.isEmpty ? t.get('setupEquipmentNeeded') : null;
      default:
        return null;
    }
  }

  void _scrollToTop() {
    if (!scrollController.hasClients) return;
    scrollController.jumpTo(0);
  }

  void _next({bool planAfter = false}) {
    _syncDraft();
    final validation = _validationFor(step);
    if (validation != null) {
      setState(() => error = validation);
      return;
    }
    setState(() => error = null);
    if (step < _stepCount - 1) {
      setState(() => step += 1);
      _scrollToTop();
    } else {
      _finish(openPlanWizard: planAfter);
    }
  }

  void _back() {
    if (step == 0) {
      if (widget.onBackToTutorial != null) {
        widget.onBackToTutorial!();
        return;
      }
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      return;
    }
    setState(() {
      step -= 1;
      error = null;
    });
    _scrollToTop();
  }

  Future<void> _finish({bool openPlanWizard = false}) async {
    _syncDraft();
    for (var index = 0; index < _stepCount; index++) {
      final validation = _validationFor(index);
      if (validation != null) {
        setState(() {
          step = index;
          error = validation;
        });
        _scrollToTop();
        return;
      }
    }
    if (draft.manualTargetsIssue() != null) {
      setState(() {
        step = _stepCount - 1;
        error = stringsOf(context).get('targetsErrorKcal');
      });
      _scrollToTop();
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final t = stringsOf(context);
    final settings = SettingsScope.of(context);
    final profile = draft.toProfile(
      locale: settings.locale.languageCode,
      theme: switch (settings.themeMode) {
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
        ThemeMode.dark => 'dark',
      },
    );

    final navigator = Navigator.of(context);
    try {
      if (widget.preview) {
        if (!mounted) return;
        setState(() => saving = false);
        if (widget.onFinished != null) {
          widget.onFinished!(profile);
        } else if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        return;
      }

      final services = AppServicesScope.of(context);
      await saveSetup(
        services.database,
        draft,
        locale: settings.locale.languageCode,
        theme: profile.theme,
      ).timeout(const Duration(seconds: 20));
      // No training plan is created here: the plan is optional. It is only
      // created when the user saves the plan wizard (opened below on request).
      await settings.refreshProfile().timeout(const Duration(seconds: 15));
      if (openPlanWizard) {
        // Setup is saved. The wizard opens on top of the app; the setup route
        // is popped first when it was pushed (not when it is the root gate).
        if (navigator.canPop()) navigator.pop();
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => const PlanWizardPage()),
        );
        return;
      }
      if (!mounted) return;
      setState(() => saving = false);
      if (navigator.canPop()) navigator.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = t.get('setupSaveError');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: VyroBackdrop(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                      child: Row(
                        children: [
                          VyroRoundButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: t.get('back'),
                            onPressed: _back,
                          ),
                          const Spacer(),
                          if (widget.preview)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Text(
                                t.get('tutorialPreviewNote'),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          VyroStepPill(index: step, count: _stepCount),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: VyroStepRail(index: step, count: _stepCount),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.02),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: LayoutBuilder(
                          key: ValueKey(step),
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                                controller: scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  28,
                                  20,
                                  24,
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: (constraints.maxHeight - 52)
                                        .clamp(0.0, double.infinity),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _stepHeader(t),
                                      const SizedBox(height: 26),
                                      Center(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 520,
                                          ),
                                          child: _stepBody(t),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                    VyroFooter(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      error!,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (step == _stepCount - 1) ...[
                            VyroPrimaryButton(
                              label: t.get('setupPlanNow'),
                              loading: saving,
                              icon: Icons.fitness_center_rounded,
                              onPressed: saving
                                  ? null
                                  : () => _next(planAfter: true),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: saving ? null : () => _next(),
                              child: Text(t.get('setupSkipPlan')),
                            ),
                          ] else
                            VyroPrimaryButton(
                              label: t.get('continue'),
                              loading: saving,
                              icon: Icons.arrow_forward_rounded,
                              onPressed: saving ? null : () => _next(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepHeader(VyroStrings t) {
    final (title, body) = switch (step) {
      0 => ('setupNameTitle', 'setupNameBody'),
      1 => ('setupBodyTitle', 'setupBodyBody'),
      2 => ('setupGoalTitle', 'setupGoalBody'),
      3 => ('setupActivityTitle', 'setupActivityBody'),
      4 => ('setupFoodTitle', 'setupFoodBody'),
      5 => ('setupScheduleTitle', 'setupScheduleBody'),
      6 => ('setupAppearanceTitle', 'setupAppearanceBody'),
      _ => ('setupReviewTitle', 'setupReviewBody'),
    };
    return VyroStepHeader(
      eyebrow: t.get('setupTitle'),
      title: t.get(title),
      body: t.get(body),
    );
  }

  Widget _stepBody(VyroStrings t) => switch (step) {
    0 => _nameStep(t),
    1 => _bodyStep(t),
    2 => _goalStep(t),
    3 => _activityStep(t),
    4 => _foodStep(t),
    5 => _scheduleStep(t),
    6 => _appearanceStep(t),
    _ => _reviewStep(t),
  };

  Widget _note(String text, {IconData icon = Icons.lock_outline_rounded}) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 15,
            color: Theme.of(context).textTheme.labelSmall?.color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      );

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );

  Widget _nameStep(VyroStrings t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: nameController,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: t.get('name'),
          hintText: t.get('setupNameHint'),
          prefixIcon: const Icon(Icons.person_outline_rounded),
        ),
      ),
      const SizedBox(height: 10),
      _note(t.get('onboardingDataNote')),
    ],
  );

  Widget _bodyStep(VyroStrings t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionLabel(t.get('setupSex')),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final value in const ['female', 'male', 'unspecified'])
            VyroPillChip(
              label: t.get(switch (value) {
                'female' => 'setupSexFemale',
                'male' => 'setupSexMale',
                _ => 'setupSexUnspecified',
              }),
              selected: draft.sex == value,
              onTap: () => setState(() => draft.sex = value),
            ),
        ],
      ),
      const SizedBox(height: 22),
      TextField(
        controller: ageController,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: t.get('setupAge'),
          suffixText: t.get('years'),
          prefixIcon: const Icon(Icons.cake_outlined),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: heightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: t.get('setupHeight'),
                suffixText: 'cm',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: t.get('setupWeight'),
                suffixText: 'kg',
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _note(t.get('setupReviewCaveat'), icon: Icons.info_outline_rounded),
    ],
  );

  Widget _goalStep(VyroStrings t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final value in const ['strength', 'nutrition', 'routine']) ...[
        VyroChoiceCard(
          icon: switch (value) {
            'strength' => Icons.fitness_center_rounded,
            'nutrition' => Icons.restaurant_rounded,
            _ => Icons.event_available_rounded,
          },
          title: t.get(switch (value) {
            'strength' => 'goalStrength',
            'nutrition' => 'goalNutrition',
            _ => 'goalRoutine',
          }),
          subtitle: t.get(switch (value) {
            'strength' => 'goalStrengthHint',
            'nutrition' => 'goalNutritionHint',
            _ => 'goalRoutineHint',
          }),
          selected: draft.goal == value,
          onTap: () => setState(() => draft.goal = value),
        ),
        const SizedBox(height: 10),
      ],
    ],
  );

  Widget _activityStep(VyroStrings t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final value in const ['low', 'moderate', 'high']) ...[
        VyroChoiceCard(
          icon: switch (value) {
            'low' => Icons.chair_outlined,
            'high' => Icons.directions_run_rounded,
            _ => Icons.directions_walk_rounded,
          },
          title: t.get('activity_$value'),
          subtitle: t.get(
            'activity${value[0].toUpperCase()}${value.substring(1)}Hint',
          ),
          selected: draft.activityLevel == value,
          onTap: () => setState(() => draft.activityLevel = value),
        ),
        const SizedBox(height: 10),
      ],
    ],
  );

  Widget _foodStep(VyroStrings t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionLabel(t.get('dietaryChoice')),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final value in const ['none', 'vegetarian', 'vegan'])
            VyroPillChip(
              label: t.get('diet_$value'),
              selected: draft.dietaryChoice == value,
              onTap: () => setState(() => draft.dietaryChoice = value),
            ),
        ],
      ),
      const SizedBox(height: 26),
      _sectionLabel(t.get('workoutExperience')),
      for (final value in const ['beginner', 'intermediate']) ...[
        VyroChoiceCard(
          icon: value == 'beginner'
              ? Icons.flag_outlined
              : Icons.trending_up_rounded,
          title: t.get('experience_$value'),
          subtitle: t.get(
            value == 'beginner'
                ? 'experienceBeginnerHint'
                : 'experienceIntermediateHint',
          ),
          selected: draft.workoutExperience == value,
          onTap: () => setState(() => draft.workoutExperience = value),
        ),
        const SizedBox(height: 10),
      ],
    ],
  );

  Widget _scheduleStep(VyroStrings t) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel(t.get('trainingDays')),
        VyroCard(
          padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${draft.trainingDays}',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.4,
                              height: 1,
                              color: scheme.onSurface,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          TextSpan(
                            text: '  ${t.get('setupDays')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              VyroRoundButton(
                icon: Icons.remove_rounded,
                size: 40,
                onPressed: draft.trainingDays > 1
                    ? () => setState(() => draft.trainingDays -= 1)
                    : null,
              ),
              const SizedBox(width: 8),
              VyroRoundButton(
                icon: Icons.add_rounded,
                size: 40,
                onPressed: draft.trainingDays < 7
                    ? () => setState(() => draft.trainingDays += 1)
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _sectionLabel(t.get('availableEquipment')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in const ['bodyweight', 'dumbbells', 'cable'])
              VyroPillChip(
                label: t.get('equipment_$value'),
                selected: draft.equipment.contains(value),
                onTap: () => setState(() {
                  if (draft.equipment.contains(value)) {
                    draft.equipment.remove(value);
                  } else {
                    draft.equipment.add(value);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t.get('setupPlan'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _appearanceStep(VyroStrings t) =>
      const AppearanceChoices(compact: false);

  Widget _targetsModeCard(VyroStrings t) {
    final scheme = Theme.of(context).colorScheme;
    final manual = draft.manualTargets;
    Widget option(String value, String label, IconData icon) {
      final selected = draft.targetMode == value;
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() {
          error = null;
          if (value == VyroProfile.modeManual) {
            draft.startManualTargets();
            _syncManualControllers();
          } else {
            draft.useAutomaticTargets();
          }
        }),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(child: Text(label)),
            ],
          ),
        ),
      );
    }

    return VyroCard(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          option(
            VyroProfile.modeAutomatic,
            t.get('setupTargetsAuto'),
            Icons.autorenew_rounded,
          ),
          option(
            VyroProfile.modeManual,
            t.get('setupTargetsManual'),
            Icons.edit_outlined,
          ),
          if (manual) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Text(
                t.get('setupTargetsManualBody'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            _manualField(
              label: t.get('targetsKcal'),
              controller: manualKcalController,
              suffix: t.get('kcalUnit'),
              onChanged: (value) => draft.manualKcal = value,
            ),
            _manualField(
              label: t.get('protein'),
              controller: manualProteinController,
              suffix: 'g',
              onChanged: (value) => draft.manualProtein = value,
            ),
            _manualField(
              label: t.get('carbs'),
              controller: manualCarbsController,
              suffix: 'g',
              onChanged: (value) => draft.manualCarbs = value,
            ),
            _manualField(
              label: t.get('fat'),
              controller: manualFatController,
              suffix: 'g',
              onChanged: (value) => draft.manualFat = value,
            ),
          ],
        ],
      ),
    );
  }

  Widget _manualField({
    required String label,
    required TextEditingController controller,
    required String suffix,
    required ValueChanged<double?> onChanged,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      onChanged: (text) => setState(() {
        error = null;
        onChanged(TargetsRules.parse(text));
      }),
    ),
  );

  Widget _mismatchCard(VyroStrings t) {
    final theme = Theme.of(context);
    return VyroCard(
      padding: const EdgeInsets.all(16),
      tint: theme.colorScheme.error.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t
                .get('targetsMacroKcal')
                .replaceAll('{kcal}', draft.manualMacroKcal.round().toString()),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            t
                .get('targetsMismatch')
                .replaceAll('{diff}', draft.manualMismatchPercent.toString()),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => setState(() {
              draft.adjustManualKcalToMacros();
              manualKcalController.text = _manualText(draft.manualKcal);
            }),
            style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
            child: Text(t.get('targetsAdjustKcal')),
          ),
        ],
      ),
    );
  }

  Widget _preferencesCard(VyroStrings t) => VyroCard(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t.get('setupVoiceTitle')),
          subtitle: Text(t.get('setupVoiceBody')),
          value: draft.coachVoice,
          onChanged: (value) => setState(() => draft.coachVoice = value),
        ),
        if (draft.coachVoice)
          SwitchListTile(
            key: const ValueKey('setupLlmPhrases'),
            contentPadding: EdgeInsets.zero,
            title: Text(t.get('coachVoiceLlmTitle')),
            subtitle: llmAvailable == null
                ? null
                : Text(
                    llmAvailable!
                        ? t.get('coachVoiceLlmSubtitle')
                        : t.get('coachVoiceLlmUnavailable'),
                  ),
            value: llmAvailable == true && draft.llmPhrases,
            onChanged: llmAvailable == true
                ? (value) => setState(() => draft.llmPhrases = value)
                : null,
          ),
        const SizedBox(height: 6),
        Text(
          t.get('setupPrivacyNote'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );

  Widget _reviewStep(VyroStrings t) {
    final targets = draft.targets;
    final scheme = Theme.of(context).colorScheme;
    final settings = SettingsScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VyroCard(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          tint: scheme.primary.withValues(alpha: dark ? 0.06 : 0.10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.get('reviewEstimated'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      t.get('setupTargets'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: VyroTheme.accentTextOf(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    targets.kcal.round().toString(),
                    style: TextStyle(
                      fontSize: 46,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                      color: scheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${t.get('kcalUnit')} · ${t.get('perDay')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  _Macro(
                    label: t.get('protein'),
                    value: targets.protein,
                    color: scheme.primary,
                  ),
                  _Macro(
                    label: t.get('carbs'),
                    value: targets.carbs,
                    color: scheme.tertiary,
                  ),
                  _Macro(
                    label: t.get('fat'),
                    value: targets.fat,
                    color: scheme.secondary,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _targetsModeCard(t),
        if (draft.manualMacrosMismatch) ...[
          const SizedBox(height: 14),
          _mismatchCard(t),
        ],
        const SizedBox(height: 14),
        VyroCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              _SummaryRow(
                label: t.get('reviewName'),
                value: draft.name.isEmpty ? t.get('notSpecified') : draft.name,
              ),
              _SummaryRow(
                label: t.get('reviewGoal'),
                value: t.get(switch (draft.goal) {
                  'strength' => 'goalStrength',
                  'nutrition' => 'goalNutrition',
                  _ => 'goalRoutine',
                }),
              ),
              _SummaryRow(
                label: t.get('reviewActivity'),
                value: t.get('activity_${draft.activityLevel}'),
              ),
              _SummaryRow(
                label: t.get('reviewTraining'),
                value:
                    '${draft.trainingDays} ${t.get('setupDays')} · ${t.get('experience_${draft.workoutExperience}')}',
              ),
              _SummaryRow(
                label: t.get('reviewEquipment'),
                value: draft.equipment.isEmpty
                    ? t.get('notSpecified')
                    : draft.equipment
                          .map((value) => t.get('equipment_$value'))
                          .join(', '),
              ),
              _SummaryRow(
                label: t.get('reviewAppearance'),
                value:
                    '${t.get(switch (settings.themeMode) {
                      ThemeMode.light => 'light',
                      ThemeMode.system => 'system',
                      ThemeMode.dark => 'dark',
                    })} · ${settings.locale.languageCode == 'en' ? 'EN' : 'PT'}',
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _preferencesCard(t),
        const SizedBox(height: 18),
        _note(t.get('setupReviewCaveat'), icon: Icons.info_outline_rounded),
        const SizedBox(height: 8),
        _note(t.get('reviewAdjustNote'), icon: Icons.tune_rounded),
      ],
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value.round().toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                TextSpan(
                  text: ' g',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: theme.colorScheme.outline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
