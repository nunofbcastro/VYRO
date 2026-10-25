import 'package:flutter/material.dart';

import '../../app/l10n/strings.dart';
import '../../core/ui/vyro_ui.dart';
import 'data/workout_repository.dart';
import '../motion_engine/exercise_registry/exercise_analysis_registry.dart';
import '../motion_engine/workout_camera/motion_coach_page.dart';
import 'domain/exercise_guides.dart';
import 'domain/plan_generator.dart';
import 'workout_session_page.dart';

class WorkoutDayPage extends StatefulWidget {
  const WorkoutDayPage({
    super.key,
    required this.dayId,
    required this.repository,
  });
  final int dayId;
  final WorkoutRepository repository;

  @override
  State<WorkoutDayPage> createState() => _WorkoutDayPageState();
}

class _WorkoutDayPageState extends State<WorkoutDayPage> {
  Future<WorkoutDayData?>? _dayFuture;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    _dayFuture ??= widget.repository.loadDay(widget.dayId);
    return FutureBuilder<WorkoutDayData?>(
      future: _dayFuture,
      builder: (context, snapshot) {
        final day = snapshot.data;
        return VyroSubpageScaffold(
          title: day == null
              ? t.get('workoutDay')
              : (t.isEnglish ? day.day.nameEn : day.day.namePt),
          actions: [
            if (day != null)
              VyroRoundButton(
                icon: Icons.add_rounded,
                tooltip: t.get('addExercise'),
                onPressed: () => _addExercise(day),
              ),
          ],
          footer: day == null || day.exercises.isEmpty
              ? null
              : VyroPrimaryButton(
                  label: t.get('workoutStart'),
                  icon: Icons.play_arrow_rounded,
                  loading: _starting,
                  onPressed: () => _start(day),
                ),
          body: snapshot.hasError
              ? Center(child: Text(t.get('error')))
              : day == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    _DaySummary(day: day),
                    const SizedBox(height: 22),
                    VyroSectionTitle(
                      label:
                          '${day.exercises.length} ${t.get('exerciseCount')}',
                      action: t.get('addExercise'),
                      onAction: () => _addExercise(day),
                    ),
                    if (day.exercises.isEmpty)
                      VyroCard(
                        child: Text(
                          t.get('empty'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    for (var i = 0; i < day.exercises.length; i++) ...[
                      VyroFadeSlideIn(
                        delay: Duration(milliseconds: 40 * i.clamp(0, 8)),
                        child: _ExerciseCard(
                          index: i + 1,
                          exercise: day.exercises[i],
                          onEdit: () => _editExercise(day.exercises[i]),
                          onRemove: () => _removeExercise(day.exercises[i]),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      t.get('notMedicalPlan'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
        );
      },
    );
  }

  bool _starting = false;

  Future<void> _start(WorkoutDayData day) async {
    final t = stringsOf(context);
    setState(() => _starting = true);
    try {
      final active = await widget.repository.activeSession();
      final title =
          active?.workoutName ??
          (t.isEnglish ? day.day.nameEn : day.day.namePt);
      final id =
          active?.id ??
          await widget.repository.startSession(
            dayId: day.day.id,
            workoutName: title,
          );
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutSessionPage(
            sessionId: id,
            repository: widget.repository,
            title: title,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _dayFuture = widget.repository.loadDay(widget.dayId));
    await _dayFuture;
  }

  Future<void> _editExercise(PlannedExercise exercise) async {
    final result = await showDialog<_ExerciseSettings>(
      context: context,
      builder: (_) => _ExerciseSettingsDialog(exercise: exercise),
    );
    if (result == null) return;
    await widget.repository.updatePlanExercise(
      id: exercise.planExercise.id,
      sets: result.sets,
      reps: result.reps,
      restSeconds: result.restSeconds,
    );
    await _refresh();
  }

  Future<void> _removeExercise(PlannedExercise exercise) async {
    final t = stringsOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.get('delete')),
        content: Text(t.get('deleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.get('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.get('delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repository.removePlanExercise(exercise.planExercise.id);
      await _refresh();
    }
  }

  Future<void> _addExercise(WorkoutDayData day) async {
    final t = stringsOf(context);
    final catalog = await widget.repository.exerciseCatalog();
    if (!mounted) return;
    final selected = await showModalBottomSheet<ExerciseInfo>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                t.get('chooseExercise'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final exercise in catalog)
              ListTile(
                title: Text(t.isEnglish ? exercise.nameEn : exercise.namePt),
                subtitle: Text(
                  t.isEnglish
                      ? exercise.instructionsEn
                      : exercise.instructionsPt,
                ),
                onTap: () => Navigator.pop(context, exercise),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await widget.repository.addExercise(
      dayId: day.day.id,
      exerciseKey: selected.key,
    );
    await _refresh();
  }
}

class _ExerciseSettings {
  const _ExerciseSettings(this.sets, this.reps, this.restSeconds);
  final int sets;
  final int reps;
  final int restSeconds;
}

class _ExerciseSettingsDialog extends StatefulWidget {
  const _ExerciseSettingsDialog({required this.exercise});
  final PlannedExercise exercise;

  @override
  State<_ExerciseSettingsDialog> createState() =>
      _ExerciseSettingsDialogState();
}

class _ExerciseSettingsDialogState extends State<_ExerciseSettingsDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _sets;
  late final TextEditingController _reps;
  late final TextEditingController _rest;

  @override
  void initState() {
    super.initState();
    _sets = TextEditingController(
      text: widget.exercise.planExercise.sets.toString(),
    );
    _reps = TextEditingController(
      text: widget.exercise.planExercise.repTarget.toString(),
    );
    _rest = TextEditingController(
      text: widget.exercise.planExercise.restSeconds.toString(),
    );
  }

  @override
  void dispose() {
    _sets.dispose();
    _reps.dispose();
    _rest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    return AlertDialog(
      title: Text(t.get('editExercise')),
      content: Form(
        key: _key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _number(_sets, t.get('sets')),
            _number(_reps, t.get('reps')),
            _number(_rest, t.get('rest')),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.get('cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (!_key.currentState!.validate()) return;
            Navigator.pop(
              context,
              _ExerciseSettings(
                int.parse(_sets.text),
                int.parse(_reps.text),
                int.parse(_rest.text),
              ),
            );
          },
          child: Text(t.get('save')),
        ),
      ],
    );
  }

  Widget _number(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final number = int.tryParse(value ?? '');
          return number == null || number < 1
              ? stringsOf(context).get('error')
              : null;
        },
      );
}

String _equipmentLabel(String value, VyroStrings t) => switch (value) {
  'halteres' => t.get('dumbbells'),
  'cabo' => t.get('cableMachine'),
  'peso corporal' => t.get('bodyweight'),
  'peso corporal ou halteres' => t.get('bodyweightOrDumbbells'),
  _ => value,
};

/// Header: weekday, estimated duration, totals and muscles worked.
class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.day});
  final WorkoutDayData day;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final slots = [
      for (final e in day.exercises)
        PlannedSlot(
          exerciseKey: e.planExercise.exerciseKey,
          sets: e.planExercise.sets,
          reps: e.planExercise.repTarget,
          restSeconds: e.planExercise.restSeconds,
        ),
    ];
    final minutes = estimateMinutes(slots);
    final sets = slots.fold<int>(0, (sum, s) => sum + s.sets);
    final muscles = <String>{
      for (final e in day.exercises)
        muscleLabel(e.info.muscleGroup, english: t.isEnglish),
    };
    final weekday = day.day.weekday;
    Widget stat(IconData icon, String value, String label) => Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: VyroTheme.accentTextOf(context)),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
    return VyroCard(
      tint: scheme.primary.withValues(alpha: dark ? 0.07 : 0.09),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (weekday != null)
            Text(
              weekdayLong(weekday, english: t.isEnglish).toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: VyroTheme.accentTextOf(context),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            t.isEnglish ? day.day.nameEn : day.day.namePt,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              stat(Icons.timer_outlined, '≈$minutes', t.get('wizMinutes')),
              stat(
                Icons.format_list_numbered_rounded,
                '${day.exercises.length}',
                t.get('wizExercises'),
              ),
              stat(Icons.repeat_rounded, '$sets', t.get('sets').toLowerCase()),
            ],
          ),
          if (muscles.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in muscles)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      m,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One exercise: number, name, prescription and an expandable how-to.
class _ExerciseCard extends StatefulWidget {
  const _ExerciseCard({
    required this.index,
    required this.exercise,
    required this.onEdit,
    required this.onRemove,
  });

  final int index;
  final PlannedExercise exercise;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  static final _registry = ExerciseAnalysisRegistry();
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final e = widget.exercise;
    final plan = e.planExercise;
    final guide = guideFor(e.info.key);
    final english = t.isEnglish;
    final isHold = e.info.key.contains('plank');
    Widget metric(String value, String label) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
    return VyroCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '${widget.index}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: VyroTheme.accentTextOf(context),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      english ? e.info.nameEn : e.info.namePt,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${muscleLabel(e.info.muscleGroup, english: english)} · '
                      '${_equipmentLabel(e.info.equipment, t)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: t.get('settings'),
                onSelected: (v) =>
                    v == 'edit' ? widget.onEdit() : widget.onRemove(),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'edit', child: Text(t.get('edit'))),
                  PopupMenuItem(value: 'remove', child: Text(t.get('delete'))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                metric('${plan.sets}', t.get('sets').toLowerCase()),
                const SizedBox(width: 8),
                metric(
                  isHold ? '${plan.repTarget}s' : '${plan.repTarget}',
                  isHold ? t.get('holdLabel') : t.get('reps').toLowerCase(),
                ),
                const SizedBox(width: 8),
                metric('${plan.restSeconds}s', t.get('restLabel')),
              ],
            ),
          ),
          if (_registry.canAnalyse(e.info.key)) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MotionCoachPage(
                      exerciseKey: e.info.key,
                      exerciseName: english ? e.info.nameEn : e.info.namePt,
                    ),
                  ),
                ),
                icon: const Icon(Icons.videocam_outlined, size: 18),
                label: Text(t.get('maOpen')),
              ),
            ),
          ],
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 18,
                    color: VyroTheme.accentTextOf(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.get('howTo'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: VyroTheme.accentTextOf(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: VyroMotion.normal,
                    child: const Icon(Icons.expand_more_rounded),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: VyroMotion.normal,
            curve: VyroMotion.curve,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(2, 4, 12, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (guide == null)
                          Text(
                            english
                                ? e.info.instructionsEn
                                : e.info.instructionsPt,
                            style: theme.textTheme.bodyMedium,
                          )
                        else ...[
                          for (var i = 0; i < guide.steps(english).length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 22,
                                    child: Text(
                                      '${i + 1}.',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      guide.steps(english)[i],
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: scheme.onSurface),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 4),
                          _Note(
                            icon: Icons.tips_and_updates_outlined,
                            color: VyroTheme.accentTextOf(context),
                            label: t.get('tipLabel'),
                            text: guide.tip(english),
                          ),
                          const SizedBox(height: 8),
                          _Note(
                            icon: Icons.warning_amber_rounded,
                            color: scheme.tertiary,
                            label: t.get('mistakeLabel'),
                            text: guide.mistake(english),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.color,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label  ',
                    style: TextStyle(fontWeight: FontWeight.w800, color: color),
                  ),
                  TextSpan(text: text),
                ],
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
