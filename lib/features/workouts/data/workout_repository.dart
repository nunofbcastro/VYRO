import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../nutrition/domain/food_product.dart' show dayKey;
import '../domain/plan_details.dart';
import '../domain/plan_generator.dart';
import '../domain/plan_preferences.dart';
import '../domain/week_schedule.dart';

class ExerciseInfo {
  const ExerciseInfo({
    required this.key,
    required this.namePt,
    required this.nameEn,
    required this.muscleGroup,
    required this.instructionsPt,
    required this.instructionsEn,
    required this.equipment,
    required this.difficulty,
  });

  final String key;
  final String namePt;
  final String nameEn;
  final String muscleGroup;
  final String instructionsPt;
  final String instructionsEn;
  final String equipment;
  final String difficulty;
}

class PlannedExercise {
  const PlannedExercise({required this.planExercise, required this.info});
  final PlanExercise planExercise;
  final ExerciseInfo info;
}

class WorkoutDayData {
  const WorkoutDayData({
    required this.day,
    required this.exercises,
    this.details,
  });
  final WorkoutDay day;
  final List<PlannedExercise> exercises;

  /// The plan's details (block, warm-ups), shared by every day of the plan.
  final PlanDetails? details;
}

class WorkoutPlanData {
  const WorkoutPlanData({required this.plan, required this.days, this.details});
  final WorkoutPlan plan;
  final List<WorkoutDayData> days;

  /// Block, warm-ups, rationale and warnings. Null for plans saved before
  /// schema v6 (their details were never stored).
  final PlanDetails? details;
}

class WorkoutRepository {
  WorkoutRepository(this.database);
  final AppDatabase database;

  Future<WorkoutPlanData> loadOrCreatePlan() async {
    await _seedCatalog();
    var plan = await database.getActiveWorkoutPlan();
    if (plan == null) {
      plan = await _createStarterPlan();
    }
    return _loadPlan(plan);
  }

  Future<WorkoutPlanData> reloadPlan() async {
    final plan = await database.getActiveWorkoutPlan();
    if (plan == null) return loadOrCreatePlan();
    return _loadPlan(plan);
  }

  Future<WorkoutPlanData> createPlanFromProfile() async {
    await _seedCatalog();
    return database.transaction(() async {
      final current = await database.getActiveWorkoutPlan();
      if (current != null) {
        await (database.update(database.workoutPlans)
              ..where((plan) => plan.id.equals(current.id)))
            .write(const WorkoutPlansCompanion(active: Value(false)));
      }
      final profile = await database.getUserProfile() ?? const VyroProfile();
      final plan = await _createPlan(profile);
      return _loadPlan(plan);
    });
  }

  static const _prefsKey = 'plan_preferences';

  /// True once the user answered the plan wizard at least once.
  Future<bool> hasPreferences() async =>
      (await database.getPreference(_prefsKey)) != null;

  /// Last wizard answers, or defaults derived from the profile.
  Future<PlanPreferences> loadPreferences() async {
    final profile = await database.getUserProfile() ?? const VyroProfile();
    final fallback = PlanPreferences(
      goal: _goalFromProfile(profile.goal),
      experience: profile.workoutExperience == 'intermediate'
          ? 'six24m'
          : 'under6m',
      weekdays: defaultWeekdays(profile.trainingDays),
      equipment: profile.availableEquipment.toSet(),
    );
    return PlanPreferences.decode(
      await database.getPreference(_prefsKey),
      fallback: fallback,
    );
  }

  static String _goalFromProfile(String goal) => switch (goal) {
    'nutrition' => 'fat_loss',
    'strength' => 'strength',
    _ => 'health',
  };

  /// Saves the answers and mirrors goal, days, experience and equipment into
  /// the profile so the rest of the app stays consistent.
  Future<void> savePreferences(PlanPreferences prefs) async {
    await database.setPreference(_prefsKey, prefs.encode());
    final profile = await database.getUserProfile() ?? const VyroProfile();
    await database.saveUserProfile(
      profile.copyWith(
        goal: switch (prefs.goal) {
          'fat_loss' => 'nutrition',
          'strength' || 'muscle' => 'strength',
          _ => 'routine',
        },
        trainingDays: prefs.daysPerWeek,
        workoutExperience:
            prefs.experience == 'never' || prefs.experience == 'under6m'
            ? 'beginner'
            : 'intermediate',
        availableEquipment: prefs.equipment.toList(),
      ),
    );
  }

  /// Rule-based plan for the wizard answers. Throws [StateError] for users
  /// the generator does not support (under 18).
  Future<GeneratedPlan> rulePlan(PlanPreferences prefs) async {
    await _seedCatalog();
    final rows = await database.select(database.exerciseCatalog).get();
    return buildPlan(
      prefs,
      {for (final row in rows) row.exerciseKey: row.equipment},
      namesOf: {
        for (final row in rows) row.exerciseKey: (row.namePt, row.nameEn),
      },
    );
  }

  /// Replaces the active plan with [plan]. History is kept. [summary] is the
  /// on-device sentence the user saw, when there was one; the block starts
  /// today.
  Future<WorkoutPlanData> savePlan(
    GeneratedPlan plan,
    String goal, {
    String? summary,
  }) async {
    await _seedCatalog();
    return database.transaction(() async {
      final current = await database.getActiveWorkoutPlan();
      if (current != null) {
        await (database.update(database.workoutPlans)
              ..where((row) => row.id.equals(current.id)))
            .write(const WorkoutPlansCompanion(active: Value(false)));
      }
      return _loadPlan(await _insertPlan(plan, goal, summary: summary));
    });
  }

  Future<WorkoutDayData?> loadDay(int dayId) async {
    final plan = await reloadPlan();
    for (final day in plan.days) {
      if (day.day.id == dayId) return day;
    }
    return null;
  }

  Future<List<ExerciseInfo>> exerciseCatalog() async {
    await _seedCatalog();
    final rows = await (database.select(
      database.exerciseCatalog,
    )..orderBy([(exercise) => OrderingTerm.asc(exercise.namePt)])).get();
    return rows.map(_toInfo).toList();
  }

  Future<ExerciseInfo?> exerciseInfo(String key) async {
    final row = await (database.select(
      database.exerciseCatalog,
    )..where((exercise) => exercise.exerciseKey.equals(key))).getSingleOrNull();
    return row == null ? null : _toInfo(row);
  }

  Future<void> updatePlanExercise({
    required int id,
    required int sets,
    required int reps,
    required int restSeconds,
  }) async {
    await (database.update(
      database.planExercises,
    )..where((exercise) => exercise.id.equals(id))).write(
      PlanExercisesCompanion(
        sets: Value(sets),
        repTarget: Value(reps),
        restSeconds: Value(restSeconds),
      ),
    );
  }

  Future<void> addExercise({
    required int dayId,
    required String exerciseKey,
  }) async {
    final count = await (database.select(
      database.planExercises,
    )..where((exercise) => exercise.dayId.equals(dayId))).get();
    await database.addPlanExercise(
      PlanExercisesCompanion.insert(
        dayId: dayId,
        exerciseKey: exerciseKey,
        sortOrder: count.length,
      ),
    );
  }

  Future<void> removePlanExercise(int id) async {
    await (database.delete(
      database.planExercises,
    )..where((exercise) => exercise.id.equals(id))).go();
  }

  Future<void> renamePlan(int id, String title) async {
    await (database.update(database.workoutPlans)
          ..where((plan) => plan.id.equals(id)))
        .write(WorkoutPlansCompanion(title: Value(title)));
  }

  Future<int> startSession({
    required int dayId,
    required String workoutName,
  }) async {
    final existing =
        await (database.select(database.workoutSessions)
              ..where((session) => session.status.equals('active'))
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return existing.id;

    final plan = await database.getActiveWorkoutPlan();
    if (plan == null) throw StateError('No active workout plan');
    final planned =
        await (database.select(database.planExercises)
              ..where((exercise) => exercise.dayId.equals(dayId))
              ..orderBy([(exercise) => OrderingTerm.asc(exercise.sortOrder)]))
            .get();

    return database.transaction(() async {
      final sessionId = await database
          .into(database.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              day: dayKey(DateTime.now()),
              planName: plan.title,
              workoutName: workoutName,
            ),
          );
      for (final exercise in planned) {
        for (var index = 1; index <= exercise.sets; index++) {
          await database
              .into(database.exerciseSets)
              .insert(
                ExerciseSetsCompanion.insert(
                  sessionId: sessionId,
                  exerciseKey: exercise.exerciseKey,
                  setNumber: index,
                  targetReps: exercise.repTarget,
                  reps: Value(exercise.repTarget),
                ),
              );
        }
      }
      return sessionId;
    });
  }

  Future<WorkoutSession?> activeSession() =>
      (database.select(database.workoutSessions)
            ..where((session) => session.status.equals('active'))
            ..limit(1))
          .getSingleOrNull();

  Future<void> updateSet({
    required int id,
    required int? reps,
    required double? weightKg,
    required bool completed,
  }) async {
    await (database.update(
      database.exerciseSets,
    )..where((set) => set.id.equals(id))).write(
      ExerciseSetsCompanion(
        reps: Value(reps),
        weightKg: Value(weightKg),
        completed: Value(completed),
        completedAt: Value(completed ? DateTime.now() : null),
      ),
    );
  }

  Future<void> finishSession(int id) async {
    await (database.update(
      database.workoutSessions,
    )..where((session) => session.id.equals(id))).write(
      WorkoutSessionsCompanion(
        status: const Value('completed'),
        finishedAt: Value(DateTime.now()),
      ),
    );
  }

  Stream<WorkoutSession?> watchActiveSession() =>
      (database.select(database.workoutSessions)
            ..where((session) => session.status.equals('active'))
            ..limit(1))
          .watchSingleOrNull();

  Stream<List<WorkoutSession>> watchSessions() =>
      database.watchWorkoutSessions();

  Stream<List<ExerciseSet>> watchSets(int sessionId) =>
      database.watchExerciseSets(sessionId);

  Future<int> addBodyWeight(double weightKg) => database
      .into(database.bodyMeasurements)
      .insert(BodyMeasurementsCompanion.insert(weightKg: weightKg));

  Stream<List<BodyMeasurement>> watchBodyMeasurements() =>
      (database.select(database.bodyMeasurements)..orderBy([
            (measurement) => OrderingTerm.asc(measurement.measuredAt),
          ]))
          .watch();

  Stream<double> watchTrainingVolume() => database
      .customSelect(
        'SELECT COALESCE(SUM(COALESCE(s.reps, 0) * COALESCE(s.weight_kg, 0.0)), 0.0) AS volume '
        'FROM exercise_sets s JOIN workout_sessions w ON w.id = s.session_id '
        'WHERE w.status = ? AND s.completed = 1',
        variables: [const Variable<String>('completed')],
        readsFrom: {database.exerciseSets, database.workoutSessions},
      )
      .watchSingle()
      .map((row) => row.read<double>('volume'));

  Future<WorkoutPlan> _createStarterPlan() async {
    final profile = await database.getUserProfile() ?? const VyroProfile();
    return _createPlan(profile);
  }

  Future<WorkoutPlan> _createPlan(VyroProfile profile) async {
    final catalog = await database.select(database.exerciseCatalog).get();
    final generated = generatePlan(
      daysPerWeek: profile.trainingDays,
      goal: _goalFromProfile(profile.goal),
      experience: profile.workoutExperience,
      available: profile.availableEquipment.toSet(),
      equipmentOf: {for (final row in catalog) row.exerciseKey: row.equipment},
    );
    return _insertPlan(generated, profile.goal);
  }

  Future<WorkoutPlan> _insertPlan(
    GeneratedPlan generated,
    String goal, {
    String? summary,
  }) {
    final details = PlanDetails.fromPlan(
      generated,
      startedOn: DateTime.now(),
      summary: summary,
    );
    return database.transaction(() async {
      final planId = await database.addWorkoutPlan(
        WorkoutPlansCompanion.insert(
          title: generated.titlePt,
          goal: goal,
          details: Value(details.encode()),
        ),
      );
      for (var index = 0; index < generated.days.length; index++) {
        final day = generated.days[index];
        final dayId = await database.addWorkoutDay(
          WorkoutDaysCompanion.insert(
            planId: planId,
            dayNumber: index + 1,
            namePt: day.namePt,
            nameEn: day.nameEn,
            weekday: Value(day.weekday),
          ),
        );
        for (var position = 0; position < day.exercises.length; position++) {
          final slot = day.exercises[position];
          await database.addPlanExercise(
            PlanExercisesCompanion.insert(
              dayId: dayId,
              exerciseKey: slot.exerciseKey,
              sortOrder: position,
              sets: Value(slot.sets),
              repTarget: Value(slot.reps),
              restSeconds: Value(slot.restSeconds),
            ),
          );
        }
      }
      return (await (database.select(
        database.workoutPlans,
      )..where((row) => row.id.equals(planId))).getSingle());
    });
  }

  /// Plans created before weekdays existed get the default spread.
  Future<void> _ensureWeekdays(List<WorkoutDay> days) async {
    if (days.every((day) => day.weekday != null)) return;
    final defaults = defaultWeekdays(days.length);
    for (var i = 0; i < days.length; i++) {
      if (days[i].weekday != null) continue;
      await (database.update(
        database.workoutDays,
      )..where((row) => row.id.equals(days[i].id))).write(
        WorkoutDaysCompanion(weekday: Value(defaults[i % defaults.length])),
      );
    }
  }

  /// Moves a workout to another weekday; a workout already there swaps
  /// places, so the week never has two workouts on one day.
  Future<void> setWeekday({required int dayId, required int weekday}) async {
    await database.transaction(() async {
      final plan = await database.getActiveWorkoutPlan();
      if (plan == null) return;
      final days = await (database.select(
        database.workoutDays,
      )..where((day) => day.planId.equals(plan.id))).get();
      final moving = days.firstWhere((day) => day.id == dayId);
      for (final other in days) {
        if (other.id != dayId && other.weekday == weekday) {
          await (database.update(database.workoutDays)
                ..where((row) => row.id.equals(other.id)))
              .write(WorkoutDaysCompanion(weekday: Value(moving.weekday)));
        }
      }
      await (database.update(database.workoutDays)
            ..where((row) => row.id.equals(dayId)))
          .write(WorkoutDaysCompanion(weekday: Value(weekday)));
    });
  }

  /// Schedule slots of a loaded plan, for [buildWeek].
  static List<ScheduleSlot> slotsOf(WorkoutPlanData plan) => [
    for (final day in plan.days)
      if (day.day.weekday != null)
        ScheduleSlot(
          dayId: day.day.id,
          weekday: day.day.weekday!,
          namePt: day.day.namePt,
          nameEn: day.day.nameEn,
        ),
  ];

  /// Date key → workout name of sessions completed on that date.
  Stream<Map<String, String>> watchDoneDays() => watchSessions().map(
    (sessions) => {
      for (final session in sessions.reversed)
        if (session.status == 'completed') session.day: session.workoutName,
    },
  );

  Stream<Set<String>> watchSkippedDays() => database
      .select(database.scheduleSkips)
      .watch()
      .map((rows) => {for (final row in rows) row.date});

  Future<void> skipDates(Iterable<String> keys) async {
    await database.batch((batch) {
      batch.insertAllOnConflictUpdate(database.scheduleSkips, [
        for (final key in keys) ScheduleSkipsCompanion.insert(date: key),
      ]);
    });
  }

  Future<void> unskipDates(Iterable<String> keys) async {
    await (database.delete(
      database.scheduleSkips,
    )..where((row) => row.date.isIn(keys.toList()))).go();
  }

  /// Records a workout as done without logging sets ("já fiz").
  Future<void> markDone({
    required DateTime date,
    required String workoutName,
  }) async {
    final plan = await database.getActiveWorkoutPlan();
    final key = dayKey(date);
    await unskipDates([key]);
    await database
        .into(database.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            day: key,
            planName: plan?.title ?? '',
            workoutName: workoutName,
            status: const Value('completed'),
            finishedAt: Value(DateTime.now()),
          ),
        );
  }

  /// Removes completed sessions on [date] (undo of "marcar como feito").
  Future<void> clearDone(DateTime date) async {
    final key = dayKey(date);
    final sessions =
        await (database.select(database.workoutSessions)..where(
              (row) => row.day.equals(key) & row.status.equals('completed'),
            ))
            .get();
    for (final session in sessions) {
      await (database.delete(
        database.exerciseSets,
      )..where((row) => row.sessionId.equals(session.id))).go();
      await (database.delete(
        database.workoutSessions,
      )..where((row) => row.id.equals(session.id))).go();
    }
  }

  Future<WorkoutPlanData> _loadPlan(WorkoutPlan plan) async {
    await _ensureWeekdays(
      await (database.select(
        database.workoutDays,
      )..where((day) => day.planId.equals(plan.id))).get(),
    );
    final days =
        await (database.select(database.workoutDays)
              ..where((day) => day.planId.equals(plan.id))
              ..orderBy([(day) => OrderingTerm.asc(day.dayNumber)]))
            .get();
    final details = PlanDetails.decode(plan.details);
    final result = <WorkoutDayData>[];
    for (final day in days) {
      final planExercises =
          await (database.select(database.planExercises)
                ..where((exercise) => exercise.dayId.equals(day.id))
                ..orderBy([(exercise) => OrderingTerm.asc(exercise.sortOrder)]))
              .get();
      final exercises = <PlannedExercise>[];
      for (final planExercise in planExercises) {
        final catalogEntry =
            await (database.select(database.exerciseCatalog)..where(
                  (exercise) =>
                      exercise.exerciseKey.equals(planExercise.exerciseKey),
                ))
                .getSingleOrNull();
        if (catalogEntry != null) {
          exercises.add(
            PlannedExercise(
              planExercise: planExercise,
              info: _toInfo(catalogEntry),
            ),
          );
        }
      }
      result.add(
        WorkoutDayData(day: day, exercises: exercises, details: details),
      );
    }
    return WorkoutPlanData(plan: plan, days: result, details: details);
  }

  Future<void> _seedCatalog() async {
    await database.batch((batch) {
      batch.insertAllOnConflictUpdate(
        database.exerciseCatalog,
        _starterExercises.map((exercise) => exercise.toCompanion()).toList(),
      );
    });
  }

  ExerciseInfo _toInfo(ExerciseCatalogData row) => ExerciseInfo(
    key: row.exerciseKey,
    namePt: row.namePt,
    nameEn: row.nameEn,
    muscleGroup: row.muscleGroup,
    instructionsPt: row.instructionsPt,
    instructionsEn: row.instructionsEn,
    equipment: row.equipment,
    difficulty: row.difficulty,
  );
}

extension on ExerciseInfo {
  ExerciseCatalogCompanion toCompanion() => ExerciseCatalogCompanion.insert(
    exerciseKey: key,
    namePt: namePt,
    nameEn: nameEn,
    muscleGroup: muscleGroup,
    instructionsPt: instructionsPt,
    instructionsEn: instructionsEn,
    equipment: equipment,
    difficulty: difficulty,
  );
}

const _starterExercises = <ExerciseInfo>[
  ExerciseInfo(
    key: 'goblet_squat',
    namePt: 'Agachamento goblet',
    nameEn: 'Goblet squat',
    muscleGroup: 'legs',
    instructionsPt:
        'Segura um peso junto ao peito e agacha até uma amplitude confortável.',
    instructionsEn:
        'Hold a weight at your chest and squat to a comfortable depth.',
    equipment: 'halteres',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'dumbbell_press',
    namePt: 'Supino com halteres',
    nameEn: 'Dumbbell chest press',
    muscleGroup: 'chest',
    instructionsPt:
        'Deita num banco ou no chão e empurra os halteres acima do peito.',
    instructionsEn:
        'Lie on a bench or floor and press the dumbbells above your chest.',
    equipment: 'halteres',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'seated_row',
    namePt: 'Remada sentada',
    nameEn: 'Seated row',
    muscleGroup: 'back',
    instructionsPt:
        'Puxa as pegas em direção ao tronco, mantendo o movimento controlado.',
    instructionsEn:
        'Pull the handles toward your torso with a controlled movement.',
    equipment: 'cabo',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'glute_bridge',
    namePt: 'Ponte de glúteos',
    nameEn: 'Glute bridge',
    muscleGroup: 'glutes',
    instructionsPt: 'Eleva a bacia sem arquear excessivamente a zona lombar.',
    instructionsEn: 'Raise your hips without over-arching your lower back.',
    equipment: 'peso corporal',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'plank',
    namePt: 'Prancha',
    nameEn: 'Plank',
    muscleGroup: 'core',
    instructionsPt: 'Mantém o corpo alinhado e respira normalmente.',
    instructionsEn: 'Keep your body aligned and breathe normally.',
    equipment: 'peso corporal',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'split_squat',
    namePt: 'Agachamento dividido',
    nameEn: 'Split squat',
    muscleGroup: 'legs',
    instructionsPt:
        'Desce com controlo numa posição escalonada; ajusta a amplitude ao conforto.',
    instructionsEn:
        'Lower with control in a split stance; adjust range to comfort.',
    equipment: 'peso corporal ou halteres',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'shoulder_press',
    namePt: 'Press de ombros',
    nameEn: 'Shoulder press',
    muscleGroup: 'shoulders',
    instructionsPt:
        'Empurra os halteres acima da cabeça sem forçar a amplitude.',
    instructionsEn:
        'Press dumbbells overhead without forcing your range of motion.',
    equipment: 'halteres',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'lat_pulldown',
    namePt: 'Puxada frontal',
    nameEn: 'Lat pulldown',
    muscleGroup: 'back',
    instructionsPt: 'Puxa a barra à frente do peito com o tronco estável.',
    instructionsEn: 'Pull the bar in front of your chest with a steady torso.',
    equipment: 'cabo',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'hip_hinge',
    namePt: 'Peso morto romeno',
    nameEn: 'Romanian deadlift',
    muscleGroup: 'hamstrings',
    instructionsPt: 'Leva a bacia atrás e mantém a carga perto das pernas.',
    instructionsEn: 'Hinge at the hips and keep the load close to your legs.',
    equipment: 'halteres',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'dead_bug',
    namePt: 'Dead bug',
    nameEn: 'Dead bug',
    muscleGroup: 'core',
    instructionsPt:
        'Move um braço e a perna oposta sem perder o controlo do tronco.',
    instructionsEn:
        'Move the opposite arm and leg while keeping your trunk controlled.',
    equipment: 'peso corporal',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'push_up',
    namePt: 'Flexão',
    nameEn: 'Push-up',
    muscleGroup: 'chest',
    instructionsPt:
        'Mantém o corpo alinhado; usa uma superfície elevada se necessário.',
    instructionsEn:
        'Keep your body aligned; use an elevated surface if needed.',
    equipment: 'peso corporal',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'side_plank',
    namePt: 'Prancha lateral',
    nameEn: 'Side plank',
    muscleGroup: 'core',
    instructionsPt:
        'Mantém a bacia elevada e reduz o tempo se perderes o alinhamento.',
    instructionsEn:
        'Keep your hips lifted and shorten the hold if alignment changes.',
    equipment: 'peso corporal',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'reverse_lunge',
    namePt: 'Afundo à retaguarda',
    nameEn: 'Reverse lunge',
    muscleGroup: 'legs',
    instructionsPt:
        'Dá um passo atrás e baixa com controlo; o joelho da frente acompanha o pé.',
    instructionsEn:
        'Step back and lower with control; front knee tracks over the foot.',
    equipment: 'peso corporal ou halteres',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'dumbbell_row',
    namePt: 'Remada com halter',
    nameEn: 'Dumbbell row',
    muscleGroup: 'back',
    instructionsPt:
        'Apoia uma mão, mantém as costas neutras e puxa o halter em direção à anca.',
    instructionsEn:
        'Support one hand, keep a neutral back and pull the dumbbell toward the hip.',
    equipment: 'halteres',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'lateral_raise',
    namePt: 'Elevação lateral',
    nameEn: 'Lateral raise',
    muscleGroup: 'shoulders',
    instructionsPt:
        'Eleva os halteres de lado até à altura dos ombros, sem balanço.',
    instructionsEn: 'Raise the dumbbells to shoulder height without swinging.',
    equipment: 'halteres',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'biceps_curl',
    namePt: 'Curl de bíceps',
    nameEn: 'Biceps curl',
    muscleGroup: 'arms',
    instructionsPt: 'Cotovelos junto ao tronco; sobe e desce com controlo.',
    instructionsEn: 'Elbows by your sides; lift and lower with control.',
    equipment: 'halteres',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'triceps_pushdown',
    namePt: 'Extensão de tríceps no cabo',
    nameEn: 'Cable triceps pushdown',
    muscleGroup: 'arms',
    instructionsPt:
        'Cotovelos fixos; estende os braços até ao fim e regressa devagar.',
    instructionsEn: 'Keep elbows fixed; extend fully and return slowly.',
    equipment: 'cabo',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'face_pull',
    namePt: 'Face pull',
    nameEn: 'Face pull',
    muscleGroup: 'shoulders',
    instructionsPt:
        'Puxa a corda em direção ao rosto, afastando as mãos no final.',
    instructionsEn:
        'Pull the rope toward your face, spreading the hands at the end.',
    equipment: 'cabo',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'pike_push_up',
    namePt: 'Flexão em pique',
    nameEn: 'Pike push-up',
    muscleGroup: 'shoulders',
    instructionsPt:
        'Anca alta, baixa a cabeça entre as mãos e empurra de volta.',
    instructionsEn:
        'Hips high, lower your head between the hands and push back up.',
    equipment: 'peso corporal',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'superman',
    namePt: 'Super-homem',
    nameEn: 'Superman',
    muscleGroup: 'back',
    instructionsPt:
        'Deitado de barriga para baixo, eleva braços e pernas sem forçar o pescoço.',
    instructionsEn:
        'Lying face down, lift arms and legs without straining the neck.',
    equipment: 'peso corporal',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'calf_raise',
    namePt: 'Elevação de gémeos',
    nameEn: 'Calf raise',
    muscleGroup: 'legs',
    instructionsPt: 'Sobe na ponta dos pés, pausa e desce devagar.',
    instructionsEn: 'Rise onto your toes, pause and lower slowly.',
    equipment: 'peso corporal',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'bird_dog',
    namePt: 'Bird dog',
    nameEn: 'Bird dog',
    muscleGroup: 'core',
    instructionsPt:
        'De quatro, estende braço e perna opostos mantendo a anca estável.',
    instructionsEn:
        'On all fours, extend opposite arm and leg keeping the hips steady.',
    equipment: 'peso corporal',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'kettlebell_squat',
    namePt: 'Agachamento com kettlebell',
    nameEn: 'Kettlebell squat',
    muscleGroup: 'legs',
    instructionsPt:
        'Segura o kettlebell junto ao peito e agacha com a coluna neutra.',
    instructionsEn:
        'Hold the kettlebell at your chest and squat with a neutral spine.',
    equipment: 'kettlebell',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'barbell_squat',
    namePt: 'Agachamento com barra',
    nameEn: 'Barbell back squat',
    muscleGroup: 'legs',
    instructionsPt:
        'Barra apoiada nas costas, pés firmes e agachamento até uma amplitude confortável.',
    instructionsEn:
        'Bar on your upper back, feet planted, squat to a comfortable depth.',
    equipment: 'barra olímpica + rack',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'box_squat',
    namePt: 'Agachamento no banco',
    nameEn: 'Box squat',
    muscleGroup: 'legs',
    instructionsPt: 'Senta num banco controlado e levanta sem balançar.',
    instructionsEn:
        'Sit back to a box with control and stand up without rocking.',
    equipment: 'banco',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'leg_press',
    namePt: 'Prensa de pernas',
    nameEn: 'Leg press',
    muscleGroup: 'legs',
    instructionsPt:
        'Empurra a plataforma com o pé inteiro sem bloquear os joelhos.',
    instructionsEn:
        'Press the platform with the whole foot without locking the knees.',
    equipment: 'máquinas',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'hip_thrust',
    namePt: 'Elevação de anca',
    nameEn: 'Hip thrust',
    muscleGroup: 'glutes',
    instructionsPt:
        'Costas apoiadas no banco, sobe a anca e aperta os glúteos no topo.',
    instructionsEn:
        'Upper back on a bench, lift the hips and squeeze the glutes at the top.',
    equipment: 'banco',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'step_up',
    namePt: 'Subida ao step',
    nameEn: 'Step-up',
    muscleGroup: 'legs',
    instructionsPt:
        'Sobe para o step com um pé, empurra com a perna da frente e desce devagar.',
    instructionsEn:
        'Step up with one foot, push through that leg and lower slowly.',
    equipment: 'step ou banco',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'bench_press',
    namePt: 'Supino com barra',
    nameEn: 'Barbell bench press',
    muscleGroup: 'chest',
    instructionsPt:
        'Barra à largura dos ombros, desce até ao peito e empurra de volta.',
    instructionsEn:
        'Bar at shoulder width, lower to the chest and press back up.',
    equipment: 'barra olímpica + banco',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'landmine_press',
    namePt: 'Press na barra landmine',
    nameEn: 'Landmine press',
    muscleGroup: 'shoulders',
    instructionsPt:
        'Empurra a ponta da barra para cima e para a frente, com o tronco estável.',
    instructionsEn:
        'Press the end of the bar up and forward with a steady torso.',
    equipment: 'barra olímpica',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'band_pull_apart',
    namePt: 'Abertura com elástico',
    nameEn: 'Band pull-apart',
    muscleGroup: 'back',
    instructionsPt:
        'Com os braços estendidos, abre o elástico até ao peito sem encolher os ombros.',
    instructionsEn:
        'With straight arms, pull the band apart to chest height without shrugging.',
    equipment: 'elásticos',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'trx_row',
    namePt: 'Remada no TRX',
    nameEn: 'TRX row',
    muscleGroup: 'back',
    instructionsPt:
        'Corpo inclinado com os calcanhares no chão; puxa o peito até às alças.',
    instructionsEn:
        'Body angled with heels down; pull your chest toward the handles.',
    equipment: 'trx',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'pull_up',
    namePt: 'Elevação na barra',
    nameEn: 'Pull-up',
    muscleGroup: 'back',
    instructionsPt:
        'Pega à largura dos ombros; puxa o queixo acima da barra e desce com controlo.',
    instructionsEn:
        'Shoulder-width grip; pull your chin over the bar and lower with control.',
    equipment: 'barra de elevações',
    difficulty: 'iniciante',
  ),
  ExerciseInfo(
    key: 'single_leg_balance',
    namePt: 'Equilíbrio num pé',
    nameEn: 'Single-leg balance',
    muscleGroup: 'core',
    instructionsPt:
        'Em pé num pé, mantém o joelho ligeiramente fletido e o olhar à frente.',
    instructionsEn:
        'Stand on one foot with a slight knee bend and eyes forward.',
    equipment: 'peso corporal',
    difficulty: 'iniciante',
  ),
];
