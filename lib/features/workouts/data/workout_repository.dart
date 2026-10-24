import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../nutrition/domain/food_product.dart' show dayKey;

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
  const WorkoutDayData({required this.day, required this.exercises});
  final WorkoutDay day;
  final List<PlannedExercise> exercises;
}

class WorkoutPlanData {
  const WorkoutPlanData({required this.plan, required this.days});
  final WorkoutPlan plan;
  final List<WorkoutDayData> days;
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
    return database.transaction(() async {
      final planId = await database.addWorkoutPlan(
        WorkoutPlansCompanion.insert(
          title: 'Plano base · 3 dias',
          goal: 'forca_e_condicao',
        ),
      );
      final dayDefinitions = <(String, String, List<String>)>[
        (
          'Dia A · Corpo inteiro',
          'Day A · Full body',
          [
            'goblet_squat',
            'dumbbell_press',
            'seated_row',
            'glute_bridge',
            'plank',
          ],
        ),
        (
          'Dia B · Corpo inteiro',
          'Day B · Full body',
          [
            'split_squat',
            'shoulder_press',
            'lat_pulldown',
            'hip_hinge',
            'dead_bug',
          ],
        ),
        (
          'Dia C · Corpo inteiro',
          'Day C · Full body',
          ['goblet_squat', 'push_up', 'seated_row', 'hip_hinge', 'side_plank'],
        ),
      ];
      for (var index = 0; index < dayDefinitions.length; index++) {
        final definition = dayDefinitions[index];
        final dayId = await database.addWorkoutDay(
          WorkoutDaysCompanion.insert(
            planId: planId,
            dayNumber: index + 1,
            namePt: definition.$1,
            nameEn: definition.$2,
          ),
        );
        for (var position = 0; position < definition.$3.length; position++) {
          await database.addPlanExercise(
            PlanExercisesCompanion.insert(
              dayId: dayId,
              exerciseKey: definition.$3[position],
              sortOrder: position,
            ),
          );
        }
      }
      return (await database.getActiveWorkoutPlan())!;
    });
  }

  Future<WorkoutPlanData> _loadPlan(WorkoutPlan plan) async {
    final days =
        await (database.select(database.workoutDays)
              ..where((day) => day.planId.equals(plan.id))
              ..orderBy([(day) => OrderingTerm.asc(day.dayNumber)]))
            .get();
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
      result.add(WorkoutDayData(day: day, exercises: exercises));
    }
    return WorkoutPlanData(plan: plan, days: result);
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
];
