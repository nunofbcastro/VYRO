import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    FoodEntries,
    CachedProducts,
    WorkoutPlans,
    WorkoutDays,
    ExerciseCatalog,
    PlanExercises,
    WorkoutSessions,
    ExerciseSets,
    BodyMeasurements,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor})
    : super(
        executor ??
            driftDatabase(
              name: 'vyro',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) => migrator.createAll(),
    onUpgrade: (Migrator migrator, int from, int to) async {
      if (from < 2) {
        await migrator.createTable(workoutPlans);
        await migrator.createTable(workoutDays);
        await migrator.createTable(exerciseCatalog);
        await migrator.createTable(planExercises);
        await migrator.createTable(workoutSessions);
        await migrator.createTable(exerciseSets);
        await migrator.createTable(bodyMeasurements);
      }
    },
  );

  Stream<List<FoodEntryRecord>> watchEntriesForDay(String day) =>
      (select(foodEntries)
            ..where((entry) => entry.day.equals(day))
            ..orderBy([(entry) => OrderingTerm.asc(entry.createdAt)]))
          .watch();

  Stream<List<FoodEntryRecord>> watchEntriesSince(String day) =>
      (select(foodEntries)
            ..where((entry) => entry.day.isBiggerOrEqualValue(day))
            ..orderBy([(entry) => OrderingTerm.asc(entry.day)]))
          .watch();

  Future<int> addFoodEntry(FoodEntriesCompanion entry) =>
      into(foodEntries).insert(entry);

  Future<bool> updateFoodEntry(FoodEntryRecord entry) =>
      update(foodEntries).replace(entry);

  Future<int> removeFoodEntry(int id) =>
      (delete(foodEntries)..where((entry) => entry.id.equals(id))).go();

  Future<CachedProduct?> cachedProduct(String barcode) => (select(
    cachedProducts,
  )..where((product) => product.barcode.equals(barcode))).getSingleOrNull();

  Future<void> cacheProduct(CachedProductsCompanion product) async {
    await into(cachedProducts).insertOnConflictUpdate(product);
  }

  Future<WorkoutPlan?> getActiveWorkoutPlan() => (select(
    workoutPlans,
  )..where((plan) => plan.active.equals(true))).getSingleOrNull();

  Stream<WorkoutSession?> watchActiveWorkoutSession() =>
      (select(workoutSessions)
            ..where((session) => session.status.equals('active'))
            ..limit(1))
          .watchSingleOrNull();

  Future<int> addWorkoutPlan(WorkoutPlansCompanion plan) =>
      into(workoutPlans).insert(plan);

  Future<int> addWorkoutDay(WorkoutDaysCompanion day) =>
      into(workoutDays).insert(day);

  Future<int> addPlanExercise(PlanExercisesCompanion exercise) =>
      into(planExercises).insert(exercise);

  Stream<List<WorkoutSession>> watchWorkoutSessions() => (select(
    workoutSessions,
  )..orderBy([(session) => OrderingTerm.desc(session.startedAt)])).watch();

  Stream<List<ExerciseSet>> watchExerciseSets(int sessionId) =>
      (select(exerciseSets)
            ..where((set) => set.sessionId.equals(sessionId))
            ..orderBy([
              (set) => OrderingTerm.asc(set.exerciseKey),
              (set) => OrderingTerm.asc(set.setNumber),
            ]))
          .watch();

  Future<int> clearUserData() async {
    return transaction(() async {
      final removedEntries = await delete(foodEntries).go();
      await delete(cachedProducts).go();
      await delete(exerciseSets).go();
      await delete(workoutSessions).go();
      await delete(planExercises).go();
      await delete(workoutDays).go();
      await delete(workoutPlans).go();
      await delete(exerciseCatalog).go();
      await delete(bodyMeasurements).go();
      return removedEntries;
    });
  }
}
