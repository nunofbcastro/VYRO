import 'package:flutter/material.dart';

import '../../app/l10n/strings.dart';
import 'data/workout_repository.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(t.get('workoutDay'))),
      body: FutureBuilder<WorkoutDayData?>(
        future: _dayFuture,
        builder: (context, snapshot) {
          final day = snapshot.data;
          if (snapshot.hasError) return Center(child: Text(t.get('error')));
          if (day == null)
            return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.isEnglish ? day.day.nameEn : day.day.namePt,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _addExercise(day),
                    icon: const Icon(Icons.add),
                    label: Text(t.get('addExercise')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (day.exercises.isEmpty)
                Card(
                  child: ListTile(
                    title: Text(t.get('empty')),
                    trailing: TextButton(
                      onPressed: () => _addExercise(day),
                      child: Text(t.get('addExercise')),
                    ),
                  ),
                ),
              for (final exercise in day.exercises)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.isEnglish
                                    ? exercise.info.nameEn
                                    : exercise.info.namePt,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) => value == 'edit'
                                  ? _editExercise(exercise)
                                  : _removeExercise(exercise),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(t.get('edit')),
                                ),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Text(t.get('delete')),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t.isEnglish
                              ? exercise.info.instructionsEn
                              : exercise.info.instructionsPt,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _Tag(
                              '${exercise.planExercise.sets} ${t.get('sets').toLowerCase()}',
                            ),
                            _Tag(
                              '${exercise.planExercise.repTarget} ${t.get('reps').toLowerCase()}',
                            ),
                            _Tag(
                              '${exercise.planExercise.restSeconds} ${t.get('rest').toLowerCase()}',
                            ),
                            _Tag(_equipmentLabel(exercise.info.equipment, t)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                t.get('notMedicalPlan'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
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

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) =>
      Chip(label: Text(label), visualDensity: VisualDensity.compact);
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
