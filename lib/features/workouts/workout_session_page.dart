import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/l10n/strings.dart';
import '../../core/ui/vyro_ui.dart';
import '../../core/database/app_database.dart';
import 'data/workout_repository.dart';
import '../motion_engine/exercise_registry/exercise_analysis_registry.dart';
import '../motion_engine/workout_camera/motion_coach_page.dart';
import 'domain/exercise_guides.dart';

class WorkoutSessionPage extends StatefulWidget {
  const WorkoutSessionPage({
    super.key,
    required this.sessionId,
    required this.repository,
    required this.title,
  });
  final int sessionId;
  final WorkoutRepository repository;
  final String title;

  @override
  State<WorkoutSessionPage> createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage> {
  Timer? _restTimer;
  int _secondsLeft = 0;
  bool _saving = false;

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    return StreamBuilder<List<ExerciseSet>>(
      stream: widget.repository.watchSets(widget.sessionId),
      builder: (context, snapshot) {
        final sets = snapshot.data ?? const <ExerciseSet>[];
        final groups = <String, List<ExerciseSet>>{};
        for (final set in sets) {
          groups.putIfAbsent(set.exerciseKey, () => []).add(set);
        }
        final done = sets.where((s) => s.completed).length;
        final complete = sets.isNotEmpty && done == sets.length;
        return VyroSubpageScaffold(
          title: widget.title,
          footer: sets.isEmpty
              ? null
              : VyroPrimaryButton(
                  label: complete
                      ? t.get('finishWorkout')
                      : '${t.get('finishWorkout')} · $done/${sets.length}',
                  icon: Icons.check_rounded,
                  loading: _saving,
                  onPressed: complete ? _finish : null,
                ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _SessionHeader(
                done: done,
                total: sets.length,
                secondsLeft: _secondsLeft,
                onSkipRest: _stopRest,
              ),
              const SizedBox(height: 18),
              for (final group in groups.entries) ...[
                FutureBuilder<ExerciseInfo?>(
                  future: widget.repository.exerciseInfo(group.key),
                  builder: (context, info) => _SessionExerciseCard(
                    info: info.data,
                    exerciseKey: group.key,
                    sets: group.value,
                    onToggle: _toggleSet,
                    onEdit: _editSet,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (groups.isEmpty && !snapshot.hasError)
                VyroCard(child: Text(t.get('empty'))),
              if (!complete && sets.isNotEmpty)
                Text(
                  t.get('completeSetsHint'),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleSet(ExerciseSet set, bool completed) async {
    await widget.repository.updateSet(
      id: set.id,
      reps: set.reps,
      weightKg: set.weightKg,
      completed: completed,
    );
    if (completed) _startRest();
  }

  Future<void> _editSet(ExerciseSet set) async {
    final result = await showDialog<(int, double?)>(
      context: context,
      builder: (_) => _SetEditDialog(set: set),
    );
    if (result == null) return;
    await widget.repository.updateSet(
      id: set.id,
      reps: result.$1,
      weightKg: result.$2,
      completed: set.completed,
    );
  }

  void _startRest() {
    _restTimer?.cancel();
    setState(() => _secondsLeft = 90);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsLeft = 0);
      } else if (mounted) {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _stopRest() {
    _restTimer?.cancel();
    setState(() => _secondsLeft = 0);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    await widget.repository.finishSession(widget.sessionId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(stringsOf(context).get('sessionDone'))),
      );
      Navigator.pop(context);
    }
  }
}

class _SetEditDialog extends StatefulWidget {
  const _SetEditDialog({required this.set});
  final ExerciseSet set;

  @override
  State<_SetEditDialog> createState() => _SetEditDialogState();
}

class _SetEditDialogState extends State<_SetEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _reps;
  late final TextEditingController _weight;

  @override
  void initState() {
    super.initState();
    _reps = TextEditingController(
      text: widget.set.reps?.toString() ?? widget.set.targetReps.toString(),
    );
    _weight = TextEditingController(
      text: widget.set.weightKg?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    return AlertDialog(
      title: Text('${t.get('set')} ${widget.set.setNumber}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _reps,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: t.get('reps')),
              validator: (value) =>
                  int.tryParse(value ?? '') == null ? t.get('error') : null,
            ),
            TextFormField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: '${t.get('weight')} (kg)'),
              validator: (value) =>
                  value != null &&
                      value.isNotEmpty &&
                      double.tryParse(value.replaceAll(',', '.')) == null
                  ? t.get('error')
                  : null,
            ),
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
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, (
              int.parse(_reps.text),
              _weight.text.trim().isEmpty
                  ? null
                  : double.parse(_weight.text.replaceAll(',', '.')),
            ));
          },
          child: Text(t.get('save')),
        ),
      ],
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.done,
    required this.total,
    required this.secondsLeft,
    required this.onSkipRest,
  });

  final int done;
  final int total;
  final int secondsLeft;
  final VoidCallback onSkipRest;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final resting = secondsLeft > 0;
    return VyroCard(
      tint: scheme.primary.withValues(alpha: dark ? 0.07 : 0.09),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          VyroRing(
            value: total == 0 ? 0 : done / total,
            size: 76,
            stroke: 7,
            child: Text(
              '$done/$total',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resting ? t.get('restTimer') : t.get('sets'),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  resting ? _clock(secondsLeft) : t.get('savedLocally'),
                  style: resting
                      ? theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: VyroTheme.accentTextOf(context),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )
                      : theme.textTheme.titleSmall,
                ),
                if (resting)
                  TextButton(
                    onPressed: onSkipRest,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 32),
                    ),
                    child: Text(t.get('skip')),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _SessionExerciseCard extends StatelessWidget {
  static final _registry = ExerciseAnalysisRegistry();

  const _SessionExerciseCard({
    required this.info,
    required this.exerciseKey,
    required this.sets,
    required this.onToggle,
    required this.onEdit,
  });

  final ExerciseInfo? info;
  final String exerciseKey;
  final List<ExerciseSet> sets;
  final Future<void> Function(ExerciseSet, bool) onToggle;
  final Future<void> Function(ExerciseSet) onEdit;

  /// Planned reps of the next set (the first not yet completed, else the
  /// first). Holds are timed and have no rep target, so they return null.
  int? get _plannedReps {
    if (exerciseKey.contains('plank') || sets.isEmpty) return null;
    final next = sets.firstWhere((s) => !s.completed, orElse: () => sets.first);
    return next.targetReps;
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final english = t.isEnglish;
    final name = info == null
        ? exerciseKey
        : (english ? info!.nameEn : info!.namePt);
    final guide = guideFor(exerciseKey);
    final allDone = sets.every((s) => s.completed);
    return VyroCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                allDone
                    ? Icons.check_circle_rounded
                    : Icons.fitness_center_rounded,
                size: 20,
                color: allDone
                    ? VyroTheme.accentTextOf(context)
                    : theme.textTheme.bodySmall?.color,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(name, style: theme.textTheme.titleMedium)),
              if (_registry.canAnalyse(exerciseKey))
                IconButton(
                  tooltip: t.get('maOpen'),
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MotionCoachPage(
                        exerciseKey: exerciseKey,
                        exerciseName: name,
                        targetReps: _plannedReps,
                      ),
                    ),
                  ),
                  icon: Icon(
                    Icons.videocam_outlined,
                    color: VyroTheme.accentTextOf(context),
                  ),
                ),
              if (guide != null)
                TextButton.icon(
                  onPressed: () => _showGuide(context, name, guide),
                  icon: const Icon(Icons.menu_book_outlined, size: 16),
                  label: Text(t.get('howTo')),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (final set in sets)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onEdit(set),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    InkResponse(
                      onTap: () => onToggle(set, !set.completed),
                      radius: 24,
                      child: AnimatedContainer(
                        duration: VyroMotion.fast,
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: set.completed
                              ? scheme.primary
                              : Colors.transparent,
                          border: Border.all(
                            color: set.completed
                                ? scheme.primary
                                : scheme.outline,
                            width: 1.6,
                          ),
                        ),
                        child: set.completed
                            ? Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: scheme.onPrimary,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 70,
                      child: Text(
                        '${t.get('set')} ${set.setNumber}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${set.reps ?? set.targetReps} ${t.get('reps').toLowerCase()}'
                        '${set.weightKg == null ? '' : ' · ${set.weightKg!.toStringAsFixed(1)} kg'}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          decoration: set.completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showGuide(BuildContext context, String name, ExerciseGuide guide) {
    final english = stringsOf(context).isEnglish;
    final t = stringsOf(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(name, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 14),
              for (var i = 0; i < guide.steps(english).length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '${i + 1}. ${guide.steps(english)[i]}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                '${t.get('tipLabel')}: ${guide.tip(english)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: VyroTheme.accentTextOf(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${t.get('mistakeLabel')}: ${guide.mistake(english)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
