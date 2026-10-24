import 'dart:convert';

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
    beforeOpen: (_) async {
      await customStatement(
        'CREATE TABLE IF NOT EXISTS vyro_preferences (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
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
      await customStatement('DELETE FROM vyro_preferences');
      return removedEntries;
    });
  }

  Future<VyroProfile?> getUserProfile() async {
    final row = await customSelect(
      'SELECT value FROM vyro_preferences WHERE key = ?',
      variables: [Variable.withString('profile')],
    ).getSingleOrNull();
    if (row == null) return null;
    return VyroProfile.fromJson(
      jsonDecode(row.read<String>('value')) as Map<String, dynamic>,
    );
  }

  Future<void> saveUserProfile(VyroProfile profile) async {
    await customStatement(
      'INSERT OR REPLACE INTO vyro_preferences (key, value) VALUES (?, ?)',
      [
        Variable.withString('profile'),
        Variable.withString(jsonEncode(profile.toJson())),
      ],
    );
  }

  Future<void> updateProfileLocale(String value) async {
    final profile = await getUserProfile() ?? const VyroProfile();
    await saveUserProfile(profile.copyWith(locale: value));
  }

  Future<void> updateProfileTheme(String value) async {
    final profile = await getUserProfile() ?? const VyroProfile();
    await saveUserProfile(profile.copyWith(theme: value));
  }

  Future<Map<String, Object?>> exportAllData() async {
    final entries = await select(foodEntries).get();
    final products = await select(cachedProducts).get();
    final plans = await select(workoutPlans).get();
    final days = await select(workoutDays).get();
    final exercises = await select(exerciseCatalog).get();
    final planExercisesRows = await select(planExercises).get();
    final sessions = await select(workoutSessions).get();
    final sets = await select(exerciseSets).get();
    final measurements = await select(bodyMeasurements).get();
    final profile = await getUserProfile();
    return {
      'format': 'vyro-local-export-v1',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'foodEntries': entries.map((row) => row.toJson()).toList(),
      'cachedProducts': products.map((row) => row.toJson()).toList(),
      'workoutPlans': plans.map((row) => row.toJson()).toList(),
      'workoutDays': days.map((row) => row.toJson()).toList(),
      'exerciseCatalog': exercises.map((row) => row.toJson()).toList(),
      'planExercises': planExercisesRows.map((row) => row.toJson()).toList(),
      'workoutSessions': sessions.map((row) => row.toJson()).toList(),
      'exerciseSets': sets.map((row) => row.toJson()).toList(),
      'bodyMeasurements': measurements.map((row) => row.toJson()).toList(),
      if (profile != null) 'userProfile': profile.toJson(),
    };
  }
}

class VyroProfile {
  const VyroProfile({
    this.name = '',
    this.goal = 'routine',
    this.calorieGoal = 2200,
    this.proteinGoal = 140,
    this.carbsGoal = 260,
    this.fatGoal = 75,
    this.locale = 'pt',
    this.theme = 'dark',
  });
  final String name, goal, locale, theme;
  final double calorieGoal, proteinGoal, carbsGoal, fatGoal;
  factory VyroProfile.fromJson(Map<String, dynamic> json) => VyroProfile(
    name: json['name'] as String? ?? '',
    goal: json['goal'] as String? ?? 'routine',
    calorieGoal: (json['calorieGoal'] as num?)?.toDouble() ?? 2200,
    proteinGoal: (json['proteinGoal'] as num?)?.toDouble() ?? 140,
    carbsGoal: (json['carbsGoal'] as num?)?.toDouble() ?? 260,
    fatGoal: (json['fatGoal'] as num?)?.toDouble() ?? 75,
    locale: json['locale'] as String? ?? 'pt',
    theme: json['theme'] as String? ?? 'dark',
  );
  Map<String, Object?> toJson() => {
    'name': name,
    'goal': goal,
    'calorieGoal': calorieGoal,
    'proteinGoal': proteinGoal,
    'carbsGoal': carbsGoal,
    'fatGoal': fatGoal,
    'locale': locale,
    'theme': theme,
  };
  VyroProfile copyWith({
    String? name,
    String? goal,
    double? calorieGoal,
    double? proteinGoal,
    double? carbsGoal,
    double? fatGoal,
    String? locale,
    String? theme,
  }) => VyroProfile(
    name: name ?? this.name,
    goal: goal ?? this.goal,
    calorieGoal: calorieGoal ?? this.calorieGoal,
    proteinGoal: proteinGoal ?? this.proteinGoal,
    carbsGoal: carbsGoal ?? this.carbsGoal,
    fatGoal: fatGoal ?? this.fatGoal,
    locale: locale ?? this.locale,
    theme: theme ?? this.theme,
  );
}
