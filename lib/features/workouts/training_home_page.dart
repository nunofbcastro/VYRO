import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../core/widgets/vyro_widgets.dart';
import '../../core/database/app_database.dart';
import 'data/workout_repository.dart';
import 'workout_day_page.dart';
import 'workout_session_page.dart';

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key});

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  Future<WorkoutPlanData>? _planFuture;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final repository = AppServicesScope.of(context).workoutRepository;
    _planFuture ??= repository.loadOrCreatePlan();
    return Scaffold(
      appBar: AppBar(title: Text(t.get('training'))),
      body: FutureBuilder<WorkoutPlanData>(
        future: _planFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.get('error')),
                  TextButton(
                    onPressed: () => setState(
                      () => _planFuture = repository.loadOrCreatePlan(),
                    ),
                    child: Text(t.get('retry')),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _planFuture = repository.reloadPlan());
              await _planFuture;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                SectionTitle(
                  t.get('plans'),
                  action: t.get('editPlan'),
                  onAction: () => _renamePlan(data, repository),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.plan.title == 'Plano base · 3 dias'
                              ? t.get('starterPlan')
                              : data.plan.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(t.get('workoutIntro')),
                        const SizedBox(height: 10),
                        Text(
                          t.get('notMedicalPlan'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                StreamBuilder<WorkoutSession?>(
                  stream: repository.watchActiveSession(),
                  builder: (context, activeSnapshot) {
                    final session = activeSnapshot.data;
                    if (session == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: ActionCard(
                        icon: Icons.play_circle_outline,
                        title: t.get('resumeWorkout'),
                        subtitle: session.workoutName,
                        onTap: () => _openSession(session),
                      ),
                    );
                  },
                ),
                SectionTitle(t.get('week')),
                for (final day in data.days)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _openDay(day, repository),
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
                                          ? day.day.nameEn
                                          : day.day.namePt,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: t.get('workoutStart'),
                                    onPressed: () =>
                                        _startDay(day, repository, t),
                                    icon: const Icon(Icons.play_arrow_rounded),
                                  ),
                                ],
                              ),
                              Text(
                                '${day.exercises.length} ${t.get('exerciseCount')} · '
                                '${day.exercises.fold<int>(0, (sum, item) => sum + item.planExercise.sets)} ${t.get('sets').toLowerCase()}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              for (final exercise in day.exercises.take(4))
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '· ${_exerciseName(exercise.info, t)}  '
                                    '${exercise.planExercise.sets} × ${exercise.planExercise.repTarget}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                SectionTitle(t.get('sessions')),
                StreamBuilder<List<WorkoutSession>>(
                  stream: repository.watchSessions(),
                  builder: (context, sessionsSnapshot) {
                    final sessions =
                        (sessionsSnapshot.data ?? const <WorkoutSession>[])
                            .where((session) => session.status == 'completed')
                            .take(5)
                            .toList();
                    if (sessions.isEmpty) return Text(t.get('noHistory'));
                    return Column(
                      children: [
                        for (final session in sessions)
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.check_circle_outline),
                              title: Text(session.workoutName),
                              subtitle: Text(session.day),
                              trailing: Text(t.get('completed')),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openDay(
    WorkoutDayData day,
    WorkoutRepository repository,
  ) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WorkoutDayPage(dayId: day.day.id, repository: repository),
      ),
    );
    if (mounted) setState(() => _planFuture = repository.reloadPlan());
  }

  Future<void> _startDay(
    WorkoutDayData day,
    WorkoutRepository repository,
    VyroStrings t,
  ) async {
    final active = await repository.activeSession();
    final title =
        active?.workoutName ?? (t.isEnglish ? day.day.nameEn : day.day.namePt);
    final id =
        active?.id ??
        await repository.startSession(dayId: day.day.id, workoutName: title);
    if (mounted) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutSessionPage(
            sessionId: id,
            repository: repository,
            title: title,
          ),
        ),
      );
    }
  }

  Future<void> _openSession(WorkoutSession session) async {
    final services = AppServicesScope.of(context);
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSessionPage(
          sessionId: session.id,
          repository: services.workoutRepository,
          title: session.workoutName,
        ),
      ),
    );
  }

  Future<void> _renamePlan(
    WorkoutPlanData data,
    WorkoutRepository repository,
  ) async {
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
    await repository.renamePlan(data.plan.id, value);
    if (mounted) setState(() => _planFuture = repository.reloadPlan());
  }
}

String _exerciseName(ExerciseInfo info, VyroStrings t) =>
    t.isEnglish ? info.nameEn : info.namePt;
