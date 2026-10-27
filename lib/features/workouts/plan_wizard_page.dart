import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../core/ai/on_device_llm.dart';
import '../../core/ui/vyro_ui.dart';
import 'data/workout_repository.dart';
import 'domain/ai_plan.dart';
import 'domain/plan_generator.dart';
import 'domain/plan_preferences.dart';

/// Questions before generating a plan. Steps adapt to earlier answers (equipment
/// by place, dumbbell weight only with dumbbells, cardio type only with cardio,
/// detraining only after some experience). Optional steps can be skipped.
///
/// The plan itself always comes from the deterministic generator. The
/// on-device model, when available, may only add one summary sentence built
/// from the generator's facts.
///
/// Drafts: answers in progress live only in this session. The saved
/// preferences change only when the plan is saved; leaving the wizard (X,
/// cancel, back on the first step, system back) discards unsaved answers and
/// never touches the existing plan. Leaving with unsaved answers or an
/// unsaved preview asks for confirmation first.
class PlanWizardPage extends StatefulWidget {
  const PlanWizardPage({super.key});

  @override
  State<PlanWizardPage> createState() => _PlanWizardPageState();
}

enum _Step {
  goal,
  experience,
  days,
  duration,
  location,
  equipment,
  limits,
  focus,
  exercises,
  cardio,
  style,
  context,
  block,
  review,
}

/// Steps that can be skipped; skipping resets their answers to the defaults.
const _skippable = {_Step.limits, _Step.focus, _Step.exercises, _Step.context};

/// Equipment offered for each place. "mixed" offers everything.
const _equipmentByLocation = <String, List<String>>{
  'home': [
    'bodyweight',
    'dumbbells',
    'bands',
    'kettlebell',
    'bench',
    'step',
    'pullup_bar',
    'trx',
  ],
  'gym': [
    'bodyweight',
    'dumbbells',
    'barbell',
    'rack',
    'bench',
    'machines',
    'cable',
    'pullup_bar',
    'kettlebell',
    'step',
  ],
  'outdoor': ['bodyweight', 'pullup_bar', 'bands', 'step', 'trx'],
};

const _goalKeys = <String, String>{
  'fat_loss': 'w2GoalFatLoss',
  'muscle': 'w2GoalMuscle',
  'strength': 'goalStrength',
  'endurance': 'w2GoalEndurance',
  'health': 'w2GoalHealth',
  'mobility': 'w2GoalMobility',
};

class _PlanWizardPageState extends State<PlanWizardPage> {
  _Step _step = _Step.goal;
  PlanPreferences? _prefs;

  /// Preferences as loaded when the wizard opened; used to detect changes.
  PlanPreferences? _initial;
  final _limitations = TextEditingController();
  final _search = TextEditingController();
  final _dumbbellKg = TextEditingController();
  LlmStatus _llm = LlmStatus.unavailable;
  List<ExerciseInfo> _catalog = const [];
  GeneratedPlan? _preview;
  String? _summary;
  bool _busy = false;
  bool _saving = false;
  bool _failed = false;
  bool _started = false;
  bool _leaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final services = AppServicesScope.of(context);
    services.workoutRepository.loadPreferences().then((prefs) {
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _initial = prefs;
        _limitations.text = prefs.limitations;
        _dumbbellKg.text = prefs.dumbbellMaxKg?.toString() ?? '';
      });
    });
    services.llm.status().then((s) {
      if (mounted) setState(() => _llm = s);
    });
    services.workoutRepository.exerciseCatalog().then((catalog) {
      if (mounted) setState(() => _catalog = catalog);
    });
  }

  @override
  void dispose() {
    _limitations.dispose();
    _search.dispose();
    _dumbbellKg.dispose();
    super.dispose();
  }

  /// Any change to an answer invalidates the preview and its summary.
  void _update(PlanPreferences prefs) => setState(() {
    _prefs = prefs;
    _preview = null;
    _summary = null;
    _failed = false;
  });

  bool _canContinue(PlanPreferences prefs) => switch (_step) {
    _Step.days => prefs.weekdays.isNotEmpty,
    _Step.equipment => prefs.equipment.isNotEmpty,
    _Step.context => !prefs.isBlocked,
    _ => true,
  };

  void _next() => setState(() {
    final index = _step.index;
    if (index < _Step.values.length - 1) {
      _step = _Step.values[index + 1];
    }
  });

  void _back() => setState(() {
    final index = _step.index;
    if (index > 0) _step = _Step.values[index - 1];
  });

  /// True when an answer differs from the saved preferences or a generated
  /// preview has not been saved yet.
  bool get _hasUnsaved {
    if (_preview != null) return true;
    final prefs = _prefs;
    final initial = _initial;
    if (prefs == null || initial == null) return false;
    return prefs.encode() != initial.encode();
  }

  /// Leaves the whole wizard, returning to the page it was opened from. Asks
  /// first when unsaved answers or a preview would be lost.
  Future<void> _leave() async {
    if (_leaving || _saving) return;
    _leaving = true;
    try {
      if (_hasUnsaved) {
        final t = stringsOf(context);
        final leave = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            content: Text(t.get('wizExitMsg')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(t.get('wizExitStay')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(t.get('wizExitLeave')),
              ),
            ],
          ),
        );
        if (leave != true || !mounted) return;
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      _leaving = false;
    }
  }

  /// System back and the header back arrow: previous step, or leave on step 1.
  void _backOrLeave() {
    if (_step == _Step.goal) {
      _leave();
    } else {
      _back();
    }
  }

  /// Skipping an optional step keeps its defaults.
  void _skipAndNext(PlanPreferences prefs) {
    final cleared = switch (_step) {
      _Step.limits => prefs.copyWith(limitAreas: {}, limitations: ''),
      _Step.focus => prefs.copyWith(priorities: {}),
      _Step.exercises => prefs.copyWith(
        avoidedExercises: {},
        favouriteExercises: {},
      ),
      _Step.context => prefs.copyWith(
        clearAgeRange: true,
        clearActivityLevel: true,
      ),
      _ => prefs,
    };
    _limitations.text = cleared.limitations;
    _update(cleared);
    _next();
  }

  Future<void> _generate() async {
    final prefs = _prefs;
    if (prefs == null || prefs.isBlocked) return;
    final repository = AppServicesScope.of(context).workoutRepository;
    setState(() {
      _busy = true;
      _failed = false;
      _summary = null;
    });
    try {
      final plan = await repository.rulePlan(prefs);
      if (!mounted) return;
      setState(() {
        _preview = plan;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  Future<void> _summarise() async {
    final plan = _preview;
    if (plan == null) return;
    final services = AppServicesScope.of(context);
    final english = stringsOf(context).isEnglish;
    final facts = [for (final note in plan.notes) note.text(english)];
    setState(() => _busy = true);
    String? text;
    try {
      final raw = await services.llm.generate(
        buildRationalePrompt(facts, english: english),
      );
      text = parseRationale(raw, facts);
    } catch (_) {
      text = null;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _summary = text ?? '';
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
    final summary = _summary;
    await repository.savePlan(
      plan,
      prefs.goal,
      summary: summary == null || summary.isEmpty ? null : summary,
    );
    messenger?.showSnackBar(SnackBar(content: Text(t.get('planGenerated'))));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final prefs = _prefs;
    return PopScope(
      // Never pops by itself: _backOrLeave decides, so each exit pops once.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backOrLeave();
      },
      child: VyroSubpageScaffold(
        title: t.get('wizTitle'),
        actions: [
          VyroRoundButton(
            icon: Icons.close_rounded,
            tooltip: t.get('wizCancel'),
            size: 48,
            onPressed: () => _leave(),
          ),
        ],
        footer: prefs == null ? null : _footer(t, prefs),
        body: prefs == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: VyroStepRail(
                      index: _step.index,
                      count: _Step.values.length,
                    ),
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
                          children: _content(t, prefs),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _footer(VyroStrings t, PlanPreferences prefs) {
    if (_step == _Step.review) {
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
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: _busy ? null : _generate,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(t.get('wizRegenerate')),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: _saving ? null : () => _leave(),
                    child: Text(t.get('wizCancel')),
                  ),
                ),
              ],
            ),
          ],
        );
      }
      return VyroPrimaryButton(
        label: t.get('w2Generate'),
        icon: Icons.bolt_rounded,
        loading: _busy,
        onPressed: _canContinue(prefs) && !prefs.isBlocked && !_busy
            ? _generate
            : null,
      );
    }
    final skippable = _skippable.contains(_step);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VyroPrimaryButton(
          label: t.get('wizNext'),
          onPressed: _canContinue(prefs) ? _next : null,
        ),
        if (skippable)
          TextButton(
            onPressed: () => _skipAndNext(prefs),
            child: Text(t.get('w2Skip')),
          ),
      ],
    );
  }

  Widget _question(VyroStrings t, String title, [String? body]) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: VyroStepHeader(eyebrow: t.get('wizStep'), title: title, body: body),
  );

  Widget _card({
    required String title,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
    String? subtitle,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: VyroChoiceCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      selected: selected,
      onTap: onTap,
    ),
  );

  Widget _pills(List<Widget> children) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );

  Widget _errorText(String text) =>
      Text(text, style: TextStyle(color: Theme.of(context).colorScheme.error));

  List<Widget> _content(VyroStrings t, PlanPreferences prefs) {
    final english = t.isEnglish;
    switch (_step) {
      case _Step.goal:
        return [
          _question(t, t.get('w2GoalQ')),
          _card(
            icon: Icons.local_fire_department_outlined,
            title: t.get('w2GoalFatLoss'),
            subtitle: t.get('w2GoalFatLossHint'),
            selected: prefs.goal == 'fat_loss',
            onTap: () => _update(prefs.copyWith(goal: 'fat_loss')),
          ),
          _card(
            icon: Icons.fitness_center_rounded,
            title: t.get('w2GoalMuscle'),
            subtitle: t.get('w2GoalMuscleHint'),
            selected: prefs.goal == 'muscle',
            onTap: () => _update(prefs.copyWith(goal: 'muscle')),
          ),
          _card(
            icon: Icons.bolt_rounded,
            title: t.get('goalStrength'),
            subtitle: t.get('goalStrengthHint'),
            selected: prefs.goal == 'strength',
            onTap: () => _update(prefs.copyWith(goal: 'strength')),
          ),
          _card(
            icon: Icons.directions_run_rounded,
            title: t.get('w2GoalEndurance'),
            subtitle: t.get('w2GoalEnduranceHint'),
            selected: prefs.goal == 'endurance',
            onTap: () => _update(prefs.copyWith(goal: 'endurance')),
          ),
          _card(
            icon: Icons.self_improvement_rounded,
            title: t.get('w2GoalHealth'),
            subtitle: t.get('w2GoalHealthHint'),
            selected: prefs.goal == 'health',
            onTap: () => _update(prefs.copyWith(goal: 'health')),
          ),
          _card(
            icon: Icons.accessibility_new_rounded,
            title: t.get('w2GoalMobility'),
            subtitle: t.get('w2GoalMobilityHint'),
            selected: prefs.goal == 'mobility',
            onTap: () => _update(prefs.copyWith(goal: 'mobility')),
          ),
          const SizedBox(height: 12),
          _label('${t.get('w2SecondaryQ')} · ${t.get('w2Optional')}'),
          _pills([
            VyroPillChip(
              label: t.get('w2NoSecondary'),
              selected: prefs.secondaryGoal == null,
              onTap: () => _update(prefs.copyWith(clearSecondaryGoal: true)),
            ),
            for (final value in PlanPreferences.goals)
              if (value != prefs.goal)
                VyroPillChip(
                  label: t.get(_goalKeys[value]!),
                  selected: prefs.secondaryGoal == value,
                  onTap: () => _update(prefs.copyWith(secondaryGoal: value)),
                ),
          ]),
        ];
      case _Step.experience:
        return [
          _question(t, t.get('w2ExpQ')),
          for (final (value, label, hint) in [
            ('never', 'w2ExpNever', 'w2ExpNeverHint'),
            ('under6m', 'w2ExpUnder6', 'w2ExpUnder6Hint'),
            ('six24m', 'w2Exp6to24', 'w2Exp6to24Hint'),
            ('over2y', 'w2ExpOver2', 'w2ExpOver2Hint'),
          ])
            _card(
              title: t.get(label),
              subtitle: t.get(hint),
              selected: prefs.experience == value,
              onTap: () => _update(prefs.copyWith(experience: value)),
            ),
          if (prefs.experience != 'never') ...[
            const SizedBox(height: 12),
            _label(t.get('w2DetrainQ')),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                t.get('w2DetrainHint'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            _pills([
              for (final (value, label) in [
                ('none', 'w2DetrainNone'),
                ('lt1m', 'w2DetrainLt1'),
                ('1to6m', 'w2Detrain1to6'),
                ('gt6m', 'w2DetrainGt6'),
              ])
                VyroPillChip(
                  label: t.get(label),
                  selected: prefs.detraining == value,
                  onTap: () => _update(prefs.copyWith(detraining: value)),
                ),
            ]),
          ],
        ];
      case _Step.days:
        return [
          _question(t, t.get('wizDaysQ'), t.get('wizDaysHint')),
          _pills([
            for (var d = 1; d <= 7; d++)
              VyroPillChip(
                label: weekdayLong(d, english: english),
                selected: prefs.weekdays.contains(d),
                onTap: () {
                  final days = {...prefs.weekdays};
                  days.contains(d) ? days.remove(d) : days.add(d);
                  _update(prefs.copyWith(weekdays: days.toList()));
                },
              ),
          ]),
          const SizedBox(height: 16),
          Text(
            prefs.weekdays.isEmpty
                ? t.get('wizPickOneDay')
                : '${prefs.daysPerWeek} ${t.get('wizSummaryDays')} · '
                      '${prefs.weekdays.map((d) => weekdayShort(d, english: english)).join(' · ')}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ];
      case _Step.duration:
        return [
          _question(t, t.get('wizDurationQ'), t.get('wizDurationHint')),
          for (final minutes in PlanPreferences.sessionLengths)
            _card(
              icon: Icons.timer_outlined,
              title: '$minutes ${t.get('wizMinutes')}',
              subtitle:
                  '${exercisesForMinutes(minutes)} ${t.get('wizExercises')}',
              selected: prefs.sessionMinutes == minutes,
              onTap: () => _update(prefs.copyWith(sessionMinutes: minutes)),
            ),
        ];
      case _Step.location:
        return [
          _question(t, t.get('w2LocQ')),
          for (final (value, label, hint, icon) in [
            ('home', 'w2LocHome', 'w2LocHomeHint', Icons.home_outlined),
            ('gym', 'w2LocGym', 'w2LocGymHint', Icons.fitness_center_rounded),
            (
              'outdoor',
              'w2LocOutdoor',
              'w2LocOutdoorHint',
              Icons.park_outlined,
            ),
            ('mixed', 'w2LocMixed', 'w2LocMixedHint', Icons.layers_outlined),
          ])
            _card(
              icon: icon,
              title: t.get(label),
              subtitle: t.get(hint),
              selected: prefs.location == value,
              onTap: () => _setLocation(prefs, value),
            ),
        ];
      case _Step.equipment:
        final options =
            _equipmentByLocation[prefs.location] ??
            PlanPreferences.equipmentIds;
        return [
          _question(t, t.get('wizEquipmentQ'), t.get('w2EquipHintLoc')),
          _pills([
            for (final id in options)
              VyroPillChip(
                label: t.get('w2Eq_$id'),
                selected: prefs.equipment.contains(id),
                onTap: () {
                  final set = {...prefs.equipment};
                  set.contains(id) ? set.remove(id) : set.add(id);
                  _update(prefs.copyWith(equipment: set));
                },
              ),
          ]),
          if (prefs.equipment.isEmpty) ...[
            const SizedBox(height: 12),
            _errorText(t.get('setupEquipmentNeeded')),
          ],
          if (prefs.equipment.contains('dumbbells')) ...[
            const SizedBox(height: 24),
            _label(t.get('w2DumbbellKgQ')),
            TextField(
              controller: _dumbbellKg,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: t.get('w2DumbbellKgHint'),
                suffixText: t.get('w2Kg'),
                prefixIcon: const Icon(Icons.scale_outlined),
              ),
              onChanged: (value) {
                final kg = int.tryParse(value.trim());
                _update(
                  prefs.copyWith(
                    dumbbellMaxKg: kg,
                    clearDumbbellMaxKg: kg == null,
                  ),
                );
              },
            ),
          ],
        ];
      case _Step.limits:
        return [
          _question(t, t.get('w2LimQ'), t.get('w2LimHint')),
          for (final area in PlanPreferences.limitAreaIds) ...[
            _label(t.get('w2Area_$area')),
            _pills([
              for (final level in PlanPreferences.limitLevels)
                VyroPillChip(
                  label: t.get('w2Lvl_$level'),
                  selected: prefs.limitAreas[area] == level,
                  onTap: () {
                    final map = {...prefs.limitAreas};
                    if (map[area] == level) {
                      map.remove(area);
                    } else {
                      map[area] = level;
                    }
                    _update(prefs.copyWith(limitAreas: map));
                  },
                ),
            ]),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _limitations,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: t.get('wizLimitations'),
              hintText: t.get('wizLimitationsHint'),
              prefixIcon: const Icon(Icons.healing_outlined),
            ),
            onChanged: (value) => _prefs = prefs.copyWith(limitations: value),
          ),
          const SizedBox(height: 12),
          VyroCard(
            padding: const EdgeInsets.all(14),
            child: Text(
              t.get('w2Medical'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ];
      case _Step.focus:
        return [
          _question(t, t.get('wizFocusQ'), t.get('wizFocusHint')),
          _pills([
            VyroPillChip(
              label: t.get('wizFocusBalanced'),
              selected: prefs.priorities.isEmpty,
              onTap: () => _update(prefs.copyWith(priorities: {})),
            ),
            for (final area in PlanPreferences.allPriorities)
              VyroPillChip(
                label: t.get('area_$area'),
                selected: prefs.priorities.contains(area),
                onTap: () {
                  final set = {...prefs.priorities};
                  set.contains(area) ? set.remove(area) : set.add(area);
                  _update(prefs.copyWith(priorities: set));
                },
              ),
          ]),
        ];
      case _Step.exercises:
        final query = _search.text.trim().toLowerCase();
        final matches = [
          for (final e in _catalog)
            if (query.isEmpty ||
                e.namePt.toLowerCase().contains(query) ||
                e.nameEn.toLowerCase().contains(query))
              e,
        ];
        return [
          _question(t, t.get('w2ExQ'), t.get('w2ExHint')),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: t.get('w2ExSearch'),
              prefixIcon: const Icon(Icons.search_rounded),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          for (final e in matches.take(60))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    english ? e.nameEn : e.namePt,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  _pills([
                    VyroPillChip(
                      label: t.get('w2ExAvoid'),
                      selected: prefs.avoidedExercises.contains(e.key),
                      onTap: () {
                        final set = {...prefs.avoidedExercises};
                        set.contains(e.key)
                            ? set.remove(e.key)
                            : set.add(e.key);
                        _update(prefs.copyWith(avoidedExercises: set));
                      },
                    ),
                    VyroPillChip(
                      label: t.get('w2ExFav'),
                      selected: prefs.favouriteExercises.contains(e.key),
                      onTap: () {
                        final set = {...prefs.favouriteExercises};
                        set.contains(e.key)
                            ? set.remove(e.key)
                            : set.add(e.key);
                        _update(prefs.copyWith(favouriteExercises: set));
                      },
                    ),
                  ]),
                ],
              ),
            ),
        ];
      case _Step.cardio:
        return [
          _question(t, t.get('w2CardioQ')),
          for (final (value, label, hint, icon) in [
            (
              'none',
              'w2CardioNone',
              'w2CardioNoneHint',
              Icons.self_improvement_rounded,
            ),
            (
              'finisher',
              'w2CardioFinisher',
              'w2CardioFinisherHint',
              Icons.timer_outlined,
            ),
            (
              'dedicated',
              'w2CardioDedicated',
              'w2CardioDedicatedHint',
              Icons.directions_run_rounded,
            ),
          ])
            _card(
              icon: icon,
              title: t.get(label),
              subtitle: t.get(hint),
              selected: prefs.cardio == value,
              onTap: () => _update(prefs.copyWith(cardio: value)),
            ),
          if (prefs.cardio != 'none') ...[
            const SizedBox(height: 12),
            _label(t.get('w2CardioTypeQ')),
            _pills([
              for (final (value, label) in [
                ('walk', 'w2CT_walk'),
                ('run', 'w2CT_run'),
                ('bike', 'w2CT_bike'),
                ('row', 'w2CT_row'),
                ('hiit', 'w2CT_hiit'),
              ])
                VyroPillChip(
                  label: t.get(label),
                  selected: prefs.cardioType == value,
                  onTap: () => _update(prefs.copyWith(cardioType: value)),
                ),
            ]),
          ],
          const SizedBox(height: 16),
          _label(t.get('w2ImpactQ')),
          _pills([
            VyroPillChip(
              label: t.get('w2ImpactYes'),
              selected: prefs.impactAllowed,
              onTap: () => _update(prefs.copyWith(impactAllowed: true)),
            ),
            VyroPillChip(
              label: t.get('w2ImpactNo'),
              selected: !prefs.impactAllowed,
              onTap: () => _update(prefs.copyWith(impactAllowed: false)),
            ),
          ]),
        ];
      case _Step.style:
        return [
          _question(t, t.get('w2StyleQ')),
          _card(
            icon: Icons.format_list_numbered_rounded,
            title: t.get('w2StyleTrad'),
            subtitle: t.get('w2StyleTradHint'),
            selected: prefs.style == 'traditional',
            onTap: () => _update(prefs.copyWith(style: 'traditional')),
          ),
          _card(
            icon: Icons.loop_rounded,
            title: t.get('w2StyleCircuits'),
            subtitle: t.get('w2StyleCircuitsHint'),
            selected: prefs.style == 'circuits',
            onTap: () => _update(prefs.copyWith(style: 'circuits')),
          ),
          const SizedBox(height: 12),
          _label(t.get('w2RestQ')),
          _pills([
            for (final (value, label) in [
              ('short', 'w2RestShort'),
              ('normal', 'w2RestNormal'),
              ('long', 'w2RestLong'),
            ])
              VyroPillChip(
                label: t.get(label),
                selected: prefs.rest == value,
                onTap: () => _update(prefs.copyWith(rest: value)),
              ),
          ]),
        ];
      case _Step.context:
        return [
          _question(t, t.get('w2CtxQ'), t.get('w2CtxHint')),
          _label(t.get('w2AgeQ')),
          _pills([
            for (final (value, label) in [
              ('under18', 'w2AgeUnder18'),
              ('18to39', 'w2Age18'),
              ('40to59', 'w2Age40'),
              ('60plus', 'w2Age60'),
            ])
              VyroPillChip(
                label: t.get(label),
                selected: prefs.ageRange == value,
                onTap: () => _update(
                  prefs.ageRange == value
                      ? prefs.copyWith(clearAgeRange: true)
                      : prefs.copyWith(ageRange: value),
                ),
              ),
            VyroPillChip(
              label: t.get('w2AgeNone'),
              selected: prefs.ageRange == null,
              onTap: () => _update(prefs.copyWith(clearAgeRange: true)),
            ),
          ]),
          if (prefs.isBlocked) ...[
            const SizedBox(height: 14),
            VyroCard(
              padding: const EdgeInsets.all(14),
              child: _errorText(t.get('w2AgeUnder18Msg')),
            ),
          ],
          const SizedBox(height: 24),
          _label(t.get('w2ActQ')),
          _pills([
            for (final (value, label) in [
              ('sedentary', 'w2ActSedentary'),
              ('light', 'w2ActLight'),
              ('active', 'w2ActActive'),
            ])
              VyroPillChip(
                label: t.get(label),
                selected: prefs.activityLevel == value,
                onTap: () => _update(
                  prefs.activityLevel == value
                      ? prefs.copyWith(clearActivityLevel: true)
                      : prefs.copyWith(activityLevel: value),
                ),
              ),
          ]),
        ];
      case _Step.block:
        return [
          _question(t, t.get('w2BlockQ'), t.get('w2BlockHint')),
          for (final weeks in PlanPreferences.blockOptions)
            _card(
              icon: Icons.date_range_rounded,
              title: '$weeks ${t.get('w2Weeks')}',
              selected: prefs.blockWeeks == weeks,
              onTap: () => _update(prefs.copyWith(blockWeeks: weeks)),
            ),
        ];
      case _Step.review:
        return _reviewContent(t, prefs);
    }
  }

  void _setLocation(PlanPreferences prefs, String value) {
    final allowed =
        (_equipmentByLocation[value] ?? PlanPreferences.equipmentIds).toSet();
    var equipment = prefs.equipment.where(allowed.contains).toSet();
    if (equipment.isEmpty) equipment = {allowed.first};
    _update(prefs.copyWith(location: value, equipment: equipment));
  }

  List<Widget> _reviewContent(VyroStrings t, PlanPreferences prefs) {
    final theme = Theme.of(context);
    final english = t.isEnglish;
    final preview = _preview;
    String goalLabel(String goal) => t.get(_goalKeys[goal] ?? 'w2GoalHealth');
    String experienceLabel(String value) => switch (value) {
      'never' => t.get('w2ExpNever'),
      'six24m' => t.get('w2Exp6to24'),
      'over2y' => t.get('w2ExpOver2'),
      _ => t.get('w2ExpUnder6'),
    };
    String cardioLabel(String value) => switch (value) {
      'finisher' => t.get('w2CardioFinisher'),
      'dedicated' => t.get('w2CardioDedicated'),
      _ => t.get('w2CardioNone'),
    };
    final limitText = prefs.limitAreas.entries
        .map(
          (e) => '${t.get('w2Area_${e.key}')} (${t.get('w2Lvl_${e.value}')})',
        )
        .join(', ');
    final focusText = prefs.priorities.isEmpty
        ? t.get('wizFocusBalanced')
        : prefs.priorities.map((p) => t.get('area_$p')).join(', ');
    final equipmentText = prefs.equipment
        .map((e) => t.get('w2Eq_$e'))
        .join(', ');
    final exerciseText =
        '${t.get('w2ExAvoid')}: ${prefs.avoidedExercises.length} · '
        '${t.get('w2ExFav')}: ${prefs.favouriteExercises.length}';

    return [
      _question(t, t.get('w2ReviewQ'), t.get('w2ReviewHint')),
      if (prefs.isBlocked) ...[
        VyroCard(
          padding: const EdgeInsets.all(14),
          child: _errorText(t.get('w2AgeUnder18Msg')),
        ),
        const SizedBox(height: 14),
      ],
      VyroGroupedSection(
        children: [
          VyroListRow(
            icon: Icons.flag_outlined,
            title: goalLabel(prefs.goal),
            subtitle: prefs.secondaryGoal == null
                ? null
                : '+ ${goalLabel(prefs.secondaryGoal!)}',
            onTap: () => setState(() => _step = _Step.goal),
          ),
          VyroListRow(
            icon: Icons.trending_up_rounded,
            title: experienceLabel(prefs.experience),
            subtitle: prefs.experience == 'never'
                ? null
                : t.get(switch (prefs.detraining) {
                    'lt1m' => 'w2DetrainLt1',
                    '1to6m' => 'w2Detrain1to6',
                    'gt6m' => 'w2DetrainGt6',
                    _ => 'w2DetrainNone',
                  }),
            onTap: () => setState(() => _step = _Step.experience),
          ),
          VyroListRow(
            icon: Icons.calendar_month_outlined,
            title: prefs.weekdays
                .map((d) => weekdayShort(d, english: english))
                .join(' · '),
            onTap: () => setState(() => _step = _Step.days),
          ),
          VyroListRow(
            icon: Icons.timer_outlined,
            title: '${prefs.sessionMinutes} ${t.get('wizMinutes')}',
            onTap: () => setState(() => _step = _Step.duration),
          ),
          VyroListRow(
            icon: Icons.place_outlined,
            title: t.get(switch (prefs.location) {
              'home' => 'w2LocHome',
              'gym' => 'w2LocGym',
              'outdoor' => 'w2LocOutdoor',
              _ => 'w2LocMixed',
            }),
            onTap: () => setState(() => _step = _Step.location),
          ),
          VyroListRow(
            icon: Icons.fitness_center_rounded,
            title: equipmentText,
            onTap: () => setState(() => _step = _Step.equipment),
          ),
          VyroListRow(
            icon: Icons.healing_outlined,
            title: limitText.isEmpty ? t.get('w2NoSecondary') : limitText,
            onTap: () => setState(() => _step = _Step.limits),
          ),
          VyroListRow(
            icon: Icons.tune_rounded,
            title: focusText,
            onTap: () => setState(() => _step = _Step.focus),
          ),
          VyroListRow(
            icon: Icons.block_rounded,
            title: exerciseText,
            onTap: () => setState(() => _step = _Step.exercises),
          ),
          VyroListRow(
            icon: Icons.directions_run_rounded,
            title: cardioLabel(prefs.cardio),
            subtitle: prefs.impactAllowed ? null : t.get('w2ImpactNo'),
            onTap: () => setState(() => _step = _Step.cardio),
          ),
          VyroListRow(
            icon: Icons.loop_rounded,
            title: t.get(
              prefs.style == 'circuits' ? 'w2StyleCircuits' : 'w2StyleTrad',
            ),
            subtitle: t.get(switch (prefs.rest) {
              'short' => 'w2RestShort',
              'long' => 'w2RestLong',
              _ => 'w2RestNormal',
            }),
            onTap: () => setState(() => _step = _Step.style),
          ),
          VyroListRow(
            icon: Icons.person_outline_rounded,
            title: prefs.ageRange == null
                ? t.get('w2AgeNone')
                : t.get(switch (prefs.ageRange) {
                    'under18' => 'w2AgeUnder18',
                    '18to39' => 'w2Age18',
                    '40to59' => 'w2Age40',
                    _ => 'w2Age60',
                  }),
            subtitle: prefs.activityLevel == null
                ? null
                : t.get(switch (prefs.activityLevel) {
                    'sedentary' => 'w2ActSedentary',
                    'light' => 'w2ActLight',
                    _ => 'w2ActActive',
                  }),
            onTap: () => setState(() => _step = _Step.context),
          ),
          VyroListRow(
            icon: Icons.date_range_rounded,
            title: '${prefs.blockWeeks} ${t.get('w2Weeks')}',
            onTap: () => setState(() => _step = _Step.block),
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
                _llm == LlmStatus.available ? 'wizAiNote' : 'wizAiUnavailable',
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
      if (_failed) ...[
        const SizedBox(height: 12),
        _errorText(t.get('w2Required')),
      ],
      if (_busy) ...[
        const SizedBox(height: 28),
        const Center(child: CircularProgressIndicator()),
      ],
      if (preview != null) ..._previewContent(t, preview),
    ];
  }

  List<Widget> _previewContent(VyroStrings t, GeneratedPlan plan) {
    final theme = Theme.of(context);
    final english = t.isEnglish;
    final muted = theme.textTheme.bodySmall;
    return [
      const SizedBox(height: 28),
      Text(t.get('wizPreview'), style: theme.textTheme.headlineSmall),
      const SizedBox(height: 6),
      Text(
        english ? plan.titleEn : plan.titlePt,
        style: theme.textTheme.titleSmall?.copyWith(
          color: VyroTheme.accentTextOf(context),
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      Text(t.get('wizRulesSource'), style: muted),
      const SizedBox(height: 16),
      Text(t.get('w2Why'), style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      for (final note in plan.notes)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            '• ${note.text(english)}',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      for (final warning in plan.warnings) ...[
        VyroCard(
          padding: const EdgeInsets.all(14),
          child: _errorText(warning.text(english)),
        ),
        const SizedBox(height: 8),
      ],
      if (_summary != null) ...[
        const SizedBox(height: 8),
        VyroCard(
          padding: const EdgeInsets.all(14),
          child: Text(
            _summary!.isEmpty
                ? t.get('wizAiFailed')
                : '${t.get('w2SummarizedAi')}: ${_summary!}',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
      if (_llm == LlmStatus.available)
        TextButton.icon(
          onPressed: _busy ? null : _summarise,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: Text(t.get('w2SummarizeAi')),
        ),
      const SizedBox(height: 16),
      Text(t.get('w2Block'), style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      for (final phase in blockPhases(plan.weeks))
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(phase.text(english), style: theme.textTheme.bodyMedium),
        ),
      const SizedBox(height: 16),
      for (final day in plan.days) ...[
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
                        '${weekdayShort(day.weekday, english: english)} · '
                        '${english ? day.nameEn : day.namePt}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      t
                          .get('aboutMinutes')
                          .replaceAll('{n}', '${day.estimatedMinutes}'),
                      style: muted,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(english ? day.warmupEn : day.warmupPt, style: muted),
                const SizedBox(height: 10),
                for (final slot in day.exercises)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _nameOf(slot.exerciseKey, english),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (slot.supersetGroup != null) ...[
                              Text(
                                t.get('w2Superset'),
                                style: muted?.copyWith(
                                  color: VyroTheme.accentTextOf(context),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              slot.timed
                                  ? '${slot.sets} × ${slot.reps} ${t.get('w2Seconds')}'
                                  : '${slot.sets} × ${slot.reps}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          progressionRule(slot, english: english),
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                if (day.cardioMinutes > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${t.get('w2Cardio')}: ${day.cardioMinutes} min',
                      style: muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
      Text(t.get('w2Medical'), style: muted),
      const SizedBox(height: 4),
      Text(t.get('notMedicalPlan'), style: muted),
    ];
  }

  String _nameOf(String key, bool english) {
    for (final e in _catalog) {
      if (e.key == key) return english ? e.nameEn : e.namePt;
    }
    return key;
  }
}
