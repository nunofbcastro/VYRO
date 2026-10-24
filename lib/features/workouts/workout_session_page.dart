import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/l10n/strings.dart';
import '../../core/database/app_database.dart';
import '../../core/widgets/vyro_widgets.dart';
import 'data/workout_repository.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: StreamBuilder<List<ExerciseSet>>(
        stream: widget.repository.watchSets(widget.sessionId),
        builder: (context, snapshot) {
          final sets = snapshot.data ?? const <ExerciseSet>[];
          final groups = <String, List<ExerciseSet>>{};
          for (final set in sets) {
            groups.putIfAbsent(set.exerciseKey, () => []).add(set);
          }
          final complete =
              sets.isNotEmpty && sets.every((set) => set.completed);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _secondsLeft > 0
                              ? '${t.get('restTimer')} · ${_formatTime(_secondsLeft)}'
                              : t.get('savedLocally'),
                        ),
                      ),
                      if (_secondsLeft > 0)
                        TextButton(
                          onPressed: _stopRest,
                          child: Text(t.get('skip')),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final group in groups.entries)
                FutureBuilder<ExerciseInfo?>(
                  future: widget.repository.exerciseInfo(group.key),
                  builder: (context, exerciseSnapshot) {
                    final info = exerciseSnapshot.data;
                    final name = info == null
                        ? group.key
                        : t.isEnglish
                        ? info.nameEn
                        : info.namePt;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionTitle(name),
                          for (final set in group.value)
                            Card(
                              child: ListTile(
                                leading: Checkbox(
                                  value: set.completed,
                                  onChanged: (value) =>
                                      _toggleSet(set, value ?? false),
                                ),
                                title: Text('${t.get('set')} ${set.setNumber}'),
                                subtitle: Text(
                                  '${set.reps ?? '—'} ${t.get('reps').toLowerCase()} · '
                                  '${set.weightKg == null ? '—' : set.weightKg!.toStringAsFixed(1)} kg',
                                ),
                                onTap: () => _editSet(set),
                                trailing: IconButton(
                                  tooltip: t.get('edit'),
                                  onPressed: () => _editSet(set),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              if (groups.isEmpty && !snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(t.get('empty')),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: complete && !_saving ? _finish : null,
                icon: const Icon(Icons.check),
                label: Text(t.get('finishWorkout')),
              ),
              if (!complete && sets.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  t.get('completeSetsHint'),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          );
        },
      ),
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

String _formatTime(int value) =>
    '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
