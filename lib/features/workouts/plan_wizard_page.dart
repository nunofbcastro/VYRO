import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../core/ai/on_device_llm.dart';
import '../../core/ui/vyro_ui.dart';
import 'domain/ai_plan.dart';
import 'domain/plan_generator.dart';
import 'domain/plan_preferences.dart';

/// Step-by-step questions before generating a plan: goal, experience,
/// weekdays, session length, equipment, priority and limitations.
///
/// Generation uses the on-device model when available, always validated by
/// [parseAiPlan]; otherwise (or if the answer is invalid) the rule-based
/// [generatePlan]. The user previews the plan before saving it.
class PlanWizardPage extends StatefulWidget {
  const PlanWizardPage({super.key});

  @override
  State<PlanWizardPage> createState() => _PlanWizardPageState();
}

enum _Source { ai, rules, aiFallback }

class _PlanWizardPageState extends State<PlanWizardPage> {
  static const _steps = 7;
  int _step = 0;
  PlanPreferences? _prefs;
  final _limitations = TextEditingController();
  LlmStatus _llm = LlmStatus.unavailable;
  bool _generating = false;
  bool _saving = false;
  GeneratedPlan? _preview;
  _Source? _source;
  String? _notes;
  Map<String, String> _names = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefs != null) return;
    final services = AppServicesScope.of(context);
    services.workoutRepository.loadPreferences().then((prefs) {
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _limitations.text = prefs.limitations;
      });
    });
    services.llm.status().then((s) {
      if (mounted) setState(() => _llm = s);
    });
    services.workoutRepository.exerciseCatalog().then((catalog) {
      if (!mounted) return;
      final english = stringsOf(context).isEnglish;
      setState(
        () => _names = {
          for (final e in catalog) e.key: english ? e.nameEn : e.namePt,
        },
      );
    });
  }

  @override
  void dispose() {
    _limitations.dispose();
    super.dispose();
  }

  void _update(PlanPreferences prefs) => setState(() => _prefs = prefs);

  bool get _canContinue {
    final prefs = _prefs;
    if (prefs == null) return false;
    return switch (_step) {
      2 => prefs.weekdays.isNotEmpty,
      4 => prefs.equipment.isNotEmpty,
      _ => true,
    };
  }

  Future<void> _generate({required bool useAi}) async {
    final prefs = _prefs!.copyWith(limitations: _limitations.text.trim());
    final services = AppServicesScope.of(context);
    final repository = services.workoutRepository;
    final english = stringsOf(context).isEnglish;
    setState(() {
      _prefs = prefs;
      _generating = true;
      _preview = null;
    });
    final rules = await repository.rulePlan(prefs);
    GeneratedPlan plan = rules;
    var source = _Source.rules;
    String? notes;
    if (useAi) {
      try {
        final choices = await repository.catalogChoices(
          prefs,
          english: english,
        );
        final raw = await services.llm.generate(
          buildPlanPrompt(prefs, choices, english: english),
        );
        final parsed = parseAiPlan(
          raw,
          prefs: prefs,
          allowedKeys: {for (final c in choices) c.key},
          fallbackTitles: rules,
        );
        if (parsed != null) {
          plan = parsed.plan;
          notes = parsed.notes;
          source = _Source.ai;
        } else {
          source = _Source.aiFallback;
        }
      } catch (_) {
        source = _Source.aiFallback;
      }
    }
    if (!mounted) return;
    setState(() {
      _generating = false;
      _preview = plan;
      _source = source;
      _notes = notes;
    });
  }

  Future<void> _save() async {
    final plan = _preview;
    final prefs = _prefs;
    if (plan == null || prefs == null) return;
    setState(() => _saving = true);
    final repository = AppServicesScope.of(context).workoutRepository;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final t = stringsOf(context);
    await repository.savePreferences(prefs);
    await repository.savePlan(plan, prefs.goal);
    messenger?.showSnackBar(SnackBar(content: Text(t.get('planGenerated'))));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final prefs = _prefs;
    final last = _step == _steps - 1;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step--);
      },
      child: VyroSubpageScaffold(
        title: t.get('wizTitle'),
        footer: prefs == null
            ? null
            : last
            ? _reviewFooter(t)
            : VyroPrimaryButton(
                label: t.get('wizNext'),
                onPressed: _canContinue ? () => setState(() => _step++) : null,
              ),
        body: prefs == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: VyroStepRail(index: _step, count: _steps),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: VyroMotion.normal,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0.04, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                          children: _stepContent(t, prefs),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _reviewFooter(VyroStrings t) {
    if (_preview != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VyroPrimaryButton(
            label: t.get('wizSave'),
            icon: Icons.check_rounded,
            loading: _saving,
            onPressed: _save,
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _generating
                ? null
                : () => _generate(useAi: _llm == LlmStatus.available),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(t.get('wizRegenerate')),
          ),
        ],
      );
    }
    final ai = _llm == LlmStatus.available;
    return VyroPrimaryButton(
      label: t.get(ai ? 'wizUseAi' : 'wizUseRules'),
      icon: ai ? Icons.auto_awesome_rounded : Icons.bolt_rounded,
      loading: _generating,
      onPressed: () => _generate(useAi: ai),
    );
  }

  Widget _question(String title, [String? body]) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: VyroStepHeader(
      eyebrow: stringsOf(context).get('wizStep'),
      title: title,
      body: body,
    ),
  );

  List<Widget> _stepContent(VyroStrings t, PlanPreferences prefs) {
    switch (_step) {
      case 0:
        return [
          _question(t.get('wizGoalQ')),
          for (final (value, label, hint, icon) in [
            (
              'strength',
              'goalStrength',
              'goalStrengthHint',
              Icons.fitness_center_rounded,
            ),
            (
              'nutrition',
              'wizGoalNutritionPlan',
              'wizGoalNutritionPlanHint',
              Icons.local_fire_department_outlined,
            ),
            (
              'routine',
              'goalRoutine',
              'goalRoutineHint',
              Icons.self_improvement_rounded,
            ),
          ]) ...[
            VyroChoiceCard(
              icon: icon,
              title: t.get(label),
              subtitle: t.get(hint),
              selected: prefs.goal == value,
              onTap: () => _update(prefs.copyWith(goal: value)),
            ),
            const SizedBox(height: 10),
          ],
        ];
      case 1:
        return [
          _question(t.get('wizExperienceQ')),
          for (final (value, label, hint) in [
            ('beginner', 'wizExpBeginner', 'experienceBeginnerHint'),
            (
              'intermediate',
              'wizExpIntermediate',
              'experienceIntermediateHint',
            ),
            ('advanced', 'wizExpAdvanced', 'wizExpAdvancedHint'),
          ]) ...[
            VyroChoiceCard(
              title: t.get(label),
              subtitle: t.get(hint),
              selected: prefs.experience == value,
              onTap: () => _update(prefs.copyWith(experience: value)),
            ),
            const SizedBox(height: 10),
          ],
        ];
      case 2:
        return [
          _question(t.get('wizDaysQ'), t.get('wizDaysHint')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var d = 1; d <= 7; d++)
                VyroPillChip(
                  label: weekdayLong(d, english: t.isEnglish),
                  selected: prefs.weekdays.contains(d),
                  onTap: () {
                    final days = {...prefs.weekdays};
                    days.contains(d) ? days.remove(d) : days.add(d);
                    _update(prefs.copyWith(weekdays: days.toList()));
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            prefs.weekdays.isEmpty
                ? t.get('wizPickOneDay')
                : '${prefs.daysPerWeek} ${t.get('wizSummaryDays')} · '
                      '${prefs.weekdays.map((d) => weekdayShort(d, english: t.isEnglish)).join(' · ')}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ];
      case 3:
        return [
          _question(t.get('wizDurationQ'), t.get('wizDurationHint')),
          for (final minutes in const [30, 45, 60, 75]) ...[
            VyroChoiceCard(
              icon: Icons.timer_outlined,
              title: '$minutes ${t.get('wizMinutes')}',
              subtitle:
                  '${exercisesForMinutes(minutes)} ${t.get('wizExercises')}',
              selected: prefs.sessionMinutes == minutes,
              onTap: () => _update(prefs.copyWith(sessionMinutes: minutes)),
            ),
            const SizedBox(height: 10),
          ],
        ];
      case 4:
        return [
          _question(t.get('wizEquipmentQ')),
          for (final (value, icon) in [
            ('bodyweight', Icons.accessibility_new_rounded),
            ('dumbbells', Icons.fitness_center_rounded),
            ('cable', Icons.cable_rounded),
          ]) ...[
            VyroChoiceCard(
              icon: icon,
              title: t.get('equipment_$value'),
              selected: prefs.equipment.contains(value),
              onTap: () {
                final set = {...prefs.equipment};
                set.contains(value) ? set.remove(value) : set.add(value);
                _update(prefs.copyWith(equipment: set));
              },
            ),
            const SizedBox(height: 10),
          ],
          if (prefs.equipment.isEmpty)
            Text(
              t.get('setupEquipmentNeeded'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ];
      case 5:
        return [
          _question(t.get('wizFocusQ')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final (value, label) in [
                ('balanced', 'wizFocusBalanced'),
                ('legs', 'wizFocusLegs'),
                ('upper', 'wizFocusUpper'),
                ('core', 'wizFocusCore'),
              ])
                VyroPillChip(
                  label: t.get(label),
                  selected: prefs.emphasis == value,
                  onTap: () => _update(prefs.copyWith(emphasis: value)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _limitations,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: t.get('wizLimitations'),
              hintText: t.get('wizLimitationsHint'),
              prefixIcon: const Icon(Icons.healing_outlined),
            ),
          ),
          Text(
            t.get('wizLimitationsNote'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ];
      default:
        return _reviewContent(t, prefs);
    }
  }

  List<Widget> _reviewContent(VyroStrings t, PlanPreferences prefs) {
    final theme = Theme.of(context);
    final preview = _preview;
    final goalLabel = t.get(switch (prefs.goal) {
      'strength' => 'goalStrength',
      'nutrition' => 'wizGoalNutritionPlan',
      _ => 'goalRoutine',
    });
    if (preview == null) {
      return [
        _question(t.get('wizReviewQ')),
        VyroGroupedSection(
          children: [
            VyroListRow(
              icon: Icons.flag_outlined,
              title: goalLabel,
              onTap: () => setState(() => _step = 0),
            ),
            VyroListRow(
              icon: Icons.calendar_month_outlined,
              title: prefs.weekdays
                  .map((d) => weekdayShort(d, english: t.isEnglish))
                  .join(' · '),
              onTap: () => setState(() => _step = 2),
            ),
            VyroListRow(
              icon: Icons.timer_outlined,
              title: '${prefs.sessionMinutes} ${t.get('wizMinutes')}',
              onTap: () => setState(() => _step = 3),
            ),
            VyroListRow(
              icon: Icons.fitness_center_rounded,
              title: prefs.equipment
                  .map((e) => t.get('equipment_$e'))
                  .join(', '),
              onTap: () => setState(() => _step = 4),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _llm == LlmStatus.available
                  ? Icons.auto_awesome_outlined
                  : Icons.info_outline_rounded,
              size: 18,
              color: VyroTheme.accentTextOf(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t.get(
                  _llm == LlmStatus.available
                      ? 'wizAiNote'
                      : 'wizAiUnavailable',
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        if (_generating) ...[
          const SizedBox(height: 28),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 12),
          Text(
            t.get('wizGenerating'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ];
    }
    return [
      Text(t.get('wizPreview'), style: theme.textTheme.headlineSmall),
      const SizedBox(height: 6),
      Text(
        t.get(switch (_source) {
          _Source.ai => 'wizAiSource',
          _Source.aiFallback => 'wizAiFailed',
          _ => 'wizRulesSource',
        }),
        style: theme.textTheme.bodySmall?.copyWith(
          color: VyroTheme.accentTextOf(context),
          fontWeight: FontWeight.w700,
        ),
      ),
      if (_notes != null) ...[
        const SizedBox(height: 8),
        Text(_notes!, style: theme.textTheme.bodyMedium),
      ],
      const SizedBox(height: 16),
      for (final day in preview.days) ...[
        VyroFadeSlideIn(
          child: VyroCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${weekdayShort(day.weekday, english: t.isEnglish)} · '
                        '${t.isEnglish ? day.nameEn : day.namePt}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      t
                          .get('aboutMinutes')
                          .replaceAll(
                            '{n}',
                            '${estimateMinutes(day.exercises)}',
                          ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final slot in day.exercises)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _names[slot.exerciseKey] ?? slot.exerciseKey,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          '${slot.sets} × ${slot.reps}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
      Text(t.get('notMedicalPlan'), style: theme.textTheme.bodySmall),
    ];
  }
}
