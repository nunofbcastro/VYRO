import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../core/database/app_database.dart';
import '../../core/ui/vyro_ui.dart';
import 'data/workout_repository.dart';
import 'domain/plan_generator.dart';
import 'domain/week_schedule.dart';
import 'plan_details_view.dart';
import 'plan_wizard_page.dart';
import 'workout_day_page.dart';
import 'workout_session_page.dart';

/// Training tab: this week's schedule (Mon → Sun) with done / can't / missed
/// states, the next workout, and the plan's workouts with their weekdays.
class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key});

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  Future<WorkoutPlanData?>? _planFuture;
  Future<bool>? _personalised;

  WorkoutRepository get _repository =>
      AppServicesScope.of(context).workoutRepository;

  void _reload() => setState(() {
    _planFuture = _repository.reloadPlan();
    _personalised = _repository.hasPreferences();
  });

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final repository = _repository;
    _planFuture ??= repository.reloadPlan();
    _personalised ??= repository.hasPreferences();
    return FutureBuilder<WorkoutPlanData?>(
      future: _planFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return VyroPageScaffold(
          title: t.get('training'),
          eyebrow: data == null ? t.get('plans') : _planTitle(data, t),
          actions: [
            VyroRoundButton(
              icon: Icons.auto_awesome_outlined,
              tooltip: t.get('generateFromGoals'),
              onPressed: _generate,
            ),
          ],
          body: snapshot.hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t.get('error')),
                      TextButton(
                        onPressed: () => setState(
                          () => _planFuture = repository.reloadPlan(),
                        ),
                        child: Text(t.get('retry')),
                      ),
                    ],
                  ),
                )
              : snapshot.connectionState != ConnectionState.done
              ? const Center(child: CircularProgressIndicator())
              : data == null
              ? _NoPlanView(onCreate: _generate)
              : StreamBuilder<Map<String, String>>(
                  stream: repository.watchDoneDays(),
                  builder: (context, doneSnapshot) =>
                      StreamBuilder<Set<String>>(
                        stream: repository.watchSkippedDays(),
                        builder: (context, skipSnapshot) {
                          final week = buildWeek(
                            today: DateTime.now(),
                            slots: WorkoutRepository.slotsOf(data),
                            done: doneSnapshot.data ?? const {},
                            skipped: skipSnapshot.data ?? const {},
                          );
                          return _body(context, data, week);
                        },
                      ),
                ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    WorkoutPlanData data,
    List<ScheduledDay> week,
  ) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final next = nextWorkout(week);
    final progress = weekProgress(week);
    final remaining = remainingTrainingKeys(week);
    final pausedKeys = [
      for (final day in week)
        if (day.status == DayStatus.skipped &&
            !day.date.isBefore(_today()) &&
            day.isTraining)
          day.key,
    ];
    return VyroPageBody(
      children: [
        FutureBuilder<bool>(
          future: _personalised,
          builder: (context, snapshot) {
            if (snapshot.data != false) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: VyroCard(
                tint: theme.colorScheme.primary.withValues(alpha: 0.08),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          color: VyroTheme.accentTextOf(context),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t.get('personaliseTitle'),
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.get('personaliseBody'),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    VyroPrimaryButton(
                      label: t.get('personaliseCta'),
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _generate,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        StreamBuilder<WorkoutSession?>(
          stream: _repository.watchActiveSession(),
          builder: (context, active) {
            final session = active.data;
            if (session == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ActionCard(
                icon: Icons.play_circle_outline,
                title: t.get('resumeWorkout'),
                subtitle: session.workoutName,
                onTap: () => _openSession(session.id, session.workoutName),
              ),
            );
          },
        ),
        VyroCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.get('week'),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    '${progress.done}/${progress.scheduled} ${t.get('workoutsDone')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress.scheduled == 0
                      ? 0
                      : progress.done / progress.scheduled,
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 14),
              _WeekStrip(week: week, onTap: (day) => _dayActions(day, data)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (next != null)
          _NextWorkoutCard(
            day: next,
            plan: data,
            onStart: () => _start(next, data),
            onDone: () => _markDone(next),
            onSkip: () => _repository.skipDates([next.key]),
          )
        else
          VyroCard(
            child: Row(
              children: [
                Icon(switch (weekOutcome(week, DateTime.now())) {
                  WeekOutcome.allDone => Icons.emoji_events_outlined,
                  WeekOutcome.paused => Icons.beach_access_outlined,
                  _ => Icons.event_repeat_rounded,
                }, color: VyroTheme.accentTextOf(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _outcomeText(data, week, t),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        if (remaining.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => _skipWeek(remaining),
            icon: const Icon(Icons.event_busy_outlined),
            label: Text(t.get('skipWeek')),
          )
        else if (pausedKeys.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => _repository.unskipDates(pausedKeys),
            icon: const Icon(Icons.event_available_outlined),
            label: Text(t.get('resumeWeek')),
          ),
        const SizedBox(height: 24),
        VyroGroupedSection(
          header: t.get('week'),
          children: [
            for (final day in week)
              _DayRow(day: day, onTap: () => _dayActions(day, data)),
          ],
        ),
        const SizedBox(height: 24),
        VyroSectionTitle(
          label: t.get('planWorkouts'),
          action: t.get('editPlan'),
          onAction: () => _renamePlan(data),
        ),
        for (final day in data.days) ...[
          _PlanDayCard(
            day: day,
            onOpen: () => _openDay(day),
            onWeekday: () => _chooseWeekday(day),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 18),
        VyroSectionTitle(label: t.get('aboutPlanTitle')),
        if (data.details != null)
          PlanAboutCard(details: data.details!)
        else
          VyroCard(
            child: Text(
              t.get('aboutPlanLegacy'),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        const SizedBox(height: 6),
        VyroPrimaryButton(
          label: t.get('generateFromGoals'),
          icon: Icons.auto_awesome_outlined,
          onPressed: _generate,
        ),
        const SizedBox(height: 10),
        Text(t.get('planRules'), style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(t.get('notMedicalPlan'), style: theme.textTheme.bodySmall),
      ],
    );
  }

  String _outcomeText(
    WorkoutPlanData data,
    List<ScheduledDay> week,
    VyroStrings t,
  ) {
    switch (weekOutcome(week, DateTime.now())) {
      case WeekOutcome.allDone:
        return t.get('weekAllDone');
      case WeekOutcome.paused:
        return t.get('weekPaused');
      case WeekOutcome.over:
      case null:
        final first = firstSlotNextWeek(WorkoutRepository.slotsOf(data));
        if (first == null) return t.get('weekOver');
        return '${t.get('weekOver')} ${t.get('nextUp')}: '
            '${weekdayLong(first.weekday, t)} · '
            '${t.isEnglish ? first.nameEn : first.namePt}';
    }
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _planTitle(WorkoutPlanData data, VyroStrings t) =>
      data.plan.title == 'Plano base · 3 dias'
      ? t.get('starterPlan')
      : data.plan.title;

  WorkoutDayData? _planDay(WorkoutPlanData plan, ScheduledDay day) {
    for (final d in plan.days) {
      if (d.day.id == day.slot?.dayId) return d;
    }
    return null;
  }

  String _slotName(ScheduleSlot slot, VyroStrings t) =>
      t.isEnglish ? slot.nameEn : slot.namePt;

  Future<void> _dayActions(ScheduledDay day, WorkoutPlanData plan) async {
    final t = stringsOf(context);
    final slot = day.slot;
    final planDay = _planDay(plan, day);
    final future = !day.date.isBefore(_today());
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(
                  '${weekdayLong(day.date.weekday, t)} · '
                  '${slot == null ? t.get('statusRest') : _slotName(slot, t)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              VyroGroupedSection(
                children: [
                  if (slot != null && future && day.status != DayStatus.done)
                    VyroListRow(
                      icon: Icons.play_arrow_rounded,
                      title: t.get('startNow'),
                      onTap: () => Navigator.pop(context, 'start'),
                    ),
                  if (day.status != DayStatus.done && (slot != null || !future))
                    VyroListRow(
                      icon: Icons.check_rounded,
                      title: t.get('markDone'),
                      onTap: () => Navigator.pop(context, 'done'),
                    ),
                  if (day.status == DayStatus.done)
                    VyroListRow(
                      icon: Icons.undo_rounded,
                      title: t.get('undo'),
                      subtitle: t.get('statusDone'),
                      onTap: () => Navigator.pop(context, 'undoDone'),
                    ),
                  if (slot != null &&
                      (day.status == DayStatus.planned ||
                          day.status == DayStatus.today ||
                          day.status == DayStatus.missed))
                    VyroListRow(
                      icon: Icons.event_busy_outlined,
                      title: t.get('cantTrain'),
                      onTap: () => Navigator.pop(context, 'skip'),
                    ),
                  if (day.status == DayStatus.skipped)
                    VyroListRow(
                      icon: Icons.undo_rounded,
                      title: t.get('undo'),
                      subtitle: t.get('statusSkipped'),
                      onTap: () => Navigator.pop(context, 'unskip'),
                    ),
                  if (planDay != null) ...[
                    VyroListRow(
                      icon: Icons.swap_horiz_rounded,
                      title: t.get('moveDay'),
                      onTap: () => Navigator.pop(context, 'move'),
                    ),
                    VyroListRow(
                      icon: Icons.list_alt_rounded,
                      title: t.get('workoutDay'),
                      onTap: () => Navigator.pop(context, 'open'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'start':
        await _start(day, plan);
      case 'done':
        await _markDone(day);
      case 'undoDone':
        await _repository.clearDone(day.date);
      case 'skip':
        await _repository.skipDates([day.key]);
      case 'unskip':
        await _repository.unskipDates([day.key]);
      case 'move':
        if (planDay != null) await _chooseWeekday(planDay);
      case 'open':
        if (planDay != null) await _openDay(planDay);
    }
  }

  Future<void> _markDone(ScheduledDay day) async {
    final t = stringsOf(context);
    await _repository.markDone(
      date: day.date,
      workoutName: day.slot == null
          ? t.get('extraWorkout')
          : _slotName(day.slot!, t),
    );
  }

  Future<void> _start(ScheduledDay day, WorkoutPlanData plan) async {
    final planDay = _planDay(plan, day);
    if (planDay == null) return;
    final t = stringsOf(context);
    final active = await _repository.activeSession();
    final title =
        active?.workoutName ??
        (t.isEnglish ? planDay.day.nameEn : planDay.day.namePt);
    final id =
        active?.id ??
        await _repository.startSession(
          dayId: planDay.day.id,
          workoutName: title,
        );
    if (mounted) await _openSession(id, title);
  }

  Future<void> _openSession(int id, String title) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSessionPage(
          sessionId: id,
          repository: _repository,
          title: title,
        ),
      ),
    );
  }

  Future<void> _openDay(WorkoutDayData day) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WorkoutDayPage(dayId: day.day.id, repository: _repository),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _chooseWeekday(WorkoutDayData day) async {
    final t = stringsOf(context);
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(
                  '${t.get('chooseWeekday')} · '
                  '${t.isEnglish ? day.day.nameEn : day.day.namePt}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var weekday = 1; weekday <= 7; weekday++)
                    VyroPillChip(
                      label: weekdayLong(weekday, t),
                      selected: day.day.weekday == weekday,
                      onTap: () => Navigator.pop(context, weekday),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    await _repository.setWeekday(dayId: day.day.id, weekday: picked);
    if (mounted) _reload();
  }

  Future<void> _skipWeek(List<String> keys) async {
    final t = stringsOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.get('skipWeek')),
        content: Text(t.get('skipWeekConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.get('confirm')),
          ),
        ],
      ),
    );
    if (ok == true) await _repository.skipDates(keys);
  }

  /// Opens the plan wizard (questions → AI or rules → preview → save).
  Future<void> _generate() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PlanWizardPage()),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _renamePlan(WorkoutPlanData data) async {
    final t = stringsOf(context);
    final controller = TextEditingController(text: data.plan.title);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.get('editPlan')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: t.get('planTitle')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(t.get('save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    await _repository.renamePlan(data.plan.id, value);
    if (mounted) _reload();
  }
}

/// Visual style for each status, shared by the strip and the rows.
({IconData icon, Color color, String label}) _statusStyle(
  BuildContext context,
  DayStatus status,
) {
  final t = stringsOf(context);
  final scheme = Theme.of(context).colorScheme;
  final muted = Theme.of(context).textTheme.bodySmall?.color ?? scheme.outline;
  return switch (status) {
    DayStatus.done => (
      icon: Icons.check_rounded,
      color: VyroTheme.accentTextOf(context),
      label: t.get('statusDone'),
    ),
    DayStatus.skipped => (
      icon: Icons.remove_rounded,
      color: muted,
      label: t.get('statusSkipped'),
    ),
    DayStatus.missed => (
      icon: Icons.priority_high_rounded,
      color: scheme.error,
      label: t.get('statusMissed'),
    ),
    DayStatus.today => (
      icon: Icons.fitness_center_rounded,
      color: VyroTheme.accentTextOf(context),
      label: t.get('statusToday'),
    ),
    DayStatus.planned => (
      icon: Icons.fitness_center_rounded,
      color: scheme.onSurface,
      label: t.get('statusPlanned'),
    ),
    DayStatus.rest => (
      icon: Icons.bedtime_outlined,
      color: muted,
      label: t.get('statusRest'),
    ),
  };
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.week, required this.onTap});
  final List<ScheduledDay> week;
  final ValueChanged<ScheduledDay> onTap;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        for (final day in week)
          Expanded(
            child: Builder(
              builder: (context) {
                final style = _statusStyle(context, day.status);
                final isToday = day.status == DayStatus.today;
                final filled = day.status == DayStatus.done;
                return Semantics(
                  button: true,
                  label: '${weekdayLong(day.date.weekday, t)}, ${style.label}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onTap(day),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: ExcludeSemantics(
                        child: Column(
                          children: [
                            Text(
                              weekdayShort(day.date.weekday, t).substring(0, 1),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isToday
                                    ? VyroTheme.accentTextOf(context)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: filled
                                    ? scheme.primary
                                    : day.isTraining
                                    ? (dark
                                          ? const Color(0xFF1A1D23)
                                          : const Color(0xFFF0F4EA))
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isToday
                                      ? scheme.primary
                                      : day.status == DayStatus.missed
                                      ? scheme.error.withValues(alpha: 0.6)
                                      : Colors.transparent,
                                  width: 1.6,
                                ),
                              ),
                              child: Center(
                                child: day.isTraining || filled
                                    ? Icon(
                                        style.icon,
                                        size: 16,
                                        color: filled
                                            ? scheme.onPrimary
                                            : style.color,
                                      )
                                    : Text(
                                        '${day.date.day}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Shown on the training tab when the user has no active plan. Nothing is
/// created until the user finishes the plan wizard.
class _NoPlanView extends StatelessWidget {
  const _NoPlanView({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    return VyroPageBody(
      children: [
        VyroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.fitness_center_rounded,
                size: 32,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                t.get('noPlanTitle'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(t.get('noPlanBody'), style: theme.textTheme.bodyMedium),
              const SizedBox(height: 18),
              VyroPrimaryButton(
                label: t.get('createTrainingPlan'),
                icon: Icons.add_rounded,
                onPressed: onCreate,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NextWorkoutCard extends StatelessWidget {
  const _NextWorkoutCard({
    required this.day,
    required this.plan,
    required this.onStart,
    required this.onDone,
    required this.onSkip,
  });

  final ScheduledDay day;
  final WorkoutPlanData plan;
  final VoidCallback onStart;
  final VoidCallback onDone;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final slot = day.slot!;
    WorkoutDayData? planDay;
    for (final d in plan.days) {
      if (d.day.id == slot.dayId) planDay = d;
    }
    final exercises = planDay?.exercises ?? const <PlannedExercise>[];
    final when = day.status == DayStatus.today
        ? t.get('todayShort')
        : weekdayLong(day.date.weekday, t);
    return VyroCard(
      tint: scheme.primary.withValues(alpha: dark ? 0.07 : 0.09),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${t.get('nextUp').toUpperCase()} · ${when.toUpperCase()}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: VyroTheme.accentTextOf(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t.isEnglish ? slot.nameEn : slot.namePt,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '${exercises.length} ${t.get('exerciseCount')} · '
            '${exercises.fold<int>(0, (sum, e) => sum + e.planExercise.sets)} '
            '${t.get('sets').toLowerCase()}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final exercise in exercises.take(5))
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    t.isEnglish ? exercise.info.nameEn : exercise.info.namePt,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          VyroPrimaryButton(
            label: t.get('startNow'),
            icon: Icons.play_arrow_rounded,
            onPressed: onStart,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onDone,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(t.get('markDone')),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.textTheme.bodyMedium?.color,
                  ),
                  icon: const Icon(Icons.event_busy_outlined, size: 18),
                  label: Text(t.get('statusSkipped')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.onTap});
  final ScheduledDay day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final style = _statusStyle(context, day.status);
    final slot = day.slot;
    final title = slot != null
        ? (t.isEnglish ? slot.nameEn : slot.namePt)
        : day.doneWorkout ?? t.get('statusRest');
    return VyroListRow(
      icon: style.icon,
      iconColor: style.color,
      title: '${weekdayShort(day.date.weekday, t)} ${day.date.day} · $title',
      subtitle: slot == null && day.status == DayStatus.done
          ? t.get('extraWorkout')
          : style.label,
      onTap: onTap,
    );
  }
}

class _PlanDayCard extends StatelessWidget {
  const _PlanDayCard({
    required this.day,
    required this.onOpen,
    required this.onWeekday,
  });

  final WorkoutDayData day;
  final VoidCallback onOpen;
  final VoidCallback onWeekday;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final weekday = day.day.weekday;
    return VyroCard(
      padding: EdgeInsets.zero,
      radius: 20,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.isEnglish ? day.day.nameEn : day.day.namePt,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          for (final exercise in day.exercises.take(4))
                            '${t.isEnglish ? exercise.info.nameEn : exercise.info.namePt} '
                                '${exercise.planExercise.sets}×${exercise.planExercise.repTarget}',
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ActionChip(
                  avatar: const Icon(Icons.event_rounded, size: 16),
                  label: Text(weekday == null ? '—' : weekdayShort(weekday, t)),
                  tooltip: t.get('moveDay'),
                  onPressed: onWeekday,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
