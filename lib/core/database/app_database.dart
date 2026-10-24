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

  Future<void> importAllData(Map<String, dynamic> data) async {
    if (data['format'] != 'vyro-local-export-v1') {
      throw const FormatException('Unsupported VYRO export format');
    }
    List<Map<String, dynamic>> rows(String key) {
      final raw = data[key];
      if (raw == null) throw FormatException('Missing rows in $key');
      if (raw is! List || raw.length > 100000) {
        throw FormatException('Invalid rows in $key');
      }
      return raw.map((row) {
        if (row is! Map<String, dynamic>)
          throw FormatException('Invalid row in $key');
        return row;
      }).toList();
    }

    final exerciseCatalogRows = rows('exerciseCatalog');
    final workoutPlanRows = rows('workoutPlans');
    final workoutDayRows = rows('workoutDays');
    final planExerciseRows = rows('planExercises');
    final workoutSessionRows = rows('workoutSessions');
    final exerciseSetRows = rows('exerciseSets');
    final bodyMeasurementRows = rows('bodyMeasurements');
    final foodEntryRows = rows('foodEntries');
    final cachedProductRows = rows('cachedProducts');
    final rawProfile = data['userProfile'];
    if (rawProfile != null && rawProfile is! Map<String, dynamic>) {
      throw const FormatException('Invalid user profile');
    }

    await transaction(() async {
      await delete(exerciseSets).go();
      await delete(workoutSessions).go();
      await delete(planExercises).go();
      await delete(workoutDays).go();
      await delete(workoutPlans).go();
      await delete(exerciseCatalog).go();
      await delete(bodyMeasurements).go();
      await delete(foodEntries).go();
      await delete(cachedProducts).go();
      await customStatement('DELETE FROM vyro_preferences');

      for (final row in exerciseCatalogRows) {
        await into(
          exerciseCatalog,
        ).insert(ExerciseCatalogData.fromJson(row).toCompanion(true));
      }
      for (final row in workoutPlanRows) {
        await into(
          workoutPlans,
        ).insert(WorkoutPlan.fromJson(row).toCompanion(true));
      }
      for (final row in workoutDayRows) {
        await into(
          workoutDays,
        ).insert(WorkoutDay.fromJson(row).toCompanion(true));
      }
      for (final row in planExerciseRows) {
        await into(
          planExercises,
        ).insert(PlanExercise.fromJson(row).toCompanion(true));
      }
      for (final row in workoutSessionRows) {
        await into(
          workoutSessions,
        ).insert(WorkoutSession.fromJson(row).toCompanion(true));
      }
      for (final row in exerciseSetRows) {
        await into(
          exerciseSets,
        ).insert(ExerciseSet.fromJson(row).toCompanion(true));
      }
      for (final row in bodyMeasurementRows) {
        await into(
          bodyMeasurements,
        ).insert(BodyMeasurement.fromJson(row).toCompanion(true));
      }
      for (final row in foodEntryRows) {
        await into(
          foodEntries,
        ).insert(FoodEntryRecord.fromJson(row).toCompanion(true));
      }
      for (final row in cachedProductRows) {
        await into(
          cachedProducts,
        ).insert(CachedProduct.fromJson(row).toCompanion(true));
      }
      if (rawProfile != null) {
        await saveUserProfile(VyroProfile.fromJson(rawProfile));
      }
    });
  }
}

class VyroProfile {
  const VyroProfile({
    this.name = '',
    this.goal = 'routine',
    this.activityLevel = 'moderate',
    this.dietaryChoice = 'none',
    this.workoutExperience = 'beginner',
    this.availableEquipment = const ['bodyweight', 'dumbbells', 'cable'],
    this.trainingDays = 3,
    this.calorieGoal = 2200,
    this.proteinGoal = 140,
    this.carbsGoal = 260,
    this.fatGoal = 75,
    this.locale = 'pt',
    this.theme = 'dark',
  });
  final String name, goal, locale, theme;
  final String activityLevel, dietaryChoice, workoutExperience;
  final List<String> availableEquipment;
  final int trainingDays;
  final double calorieGoal, proteinGoal, carbsGoal, fatGoal;
  factory VyroProfile.fromJson(Map<String, dynamic> json) {
    double positiveNumber(String key, double fallback) {
      final value = (json[key] as num?)?.toDouble();
      return value != null && value.isFinite && value > 0 && value <= 100000
          ? value
          : fallback;
    }

    final rawEquipment = json['availableEquipment'];
    final equipment = rawEquipment is List
        ? rawEquipment
              .whereType<String>()
              .where(
                (value) =>
                    const {'bodyweight', 'dumbbells', 'cable'}.contains(value),
              )
              .toSet()
              .toList()
        : const ['bodyweight', 'dumbbells', 'cable'];
    final goal = json['goal'] as String? ?? 'routine';
    final activity = json['activityLevel'] as String? ?? 'moderate';
    final diet = json['dietaryChoice'] as String? ?? 'none';
    final experience = json['workoutExperience'] as String? ?? 'beginner';
    return VyroProfile(
      name: json['name'] as String? ?? '',
      goal: const {'strength', 'nutrition', 'routine'}.contains(goal)
          ? goal
          : 'routine',
      activityLevel: const {'low', 'moderate', 'high'}.contains(activity)
          ? activity
          : 'moderate',
      dietaryChoice: const {'none', 'vegetarian', 'vegan'}.contains(diet)
          ? diet
          : 'none',
      workoutExperience: const {'beginner', 'intermediate'}.contains(experience)
          ? experience
          : 'beginner',
      availableEquipment: equipment.isEmpty ? const ['bodyweight'] : equipment,
      trainingDays: ((json['trainingDays'] as num?)?.toInt() ?? 3).clamp(1, 7),
      calorieGoal: positiveNumber('calorieGoal', 2200),
      proteinGoal: positiveNumber('proteinGoal', 140),
      carbsGoal: positiveNumber('carbsGoal', 260),
      fatGoal: positiveNumber('fatGoal', 75),
      locale: json['locale'] == 'en' ? 'en' : 'pt',
      theme: const {'light', 'dark', 'system'}.contains(json['theme'])
          ? json['theme'] as String
          : 'dark',
    );
  }
  Map<String, Object?> toJson() => {
    'name': name,
    'goal': goal,
    'activityLevel': activityLevel,
    'dietaryChoice': dietaryChoice,
    'workoutExperience': workoutExperience,
    'availableEquipment': availableEquipment,
    'trainingDays': trainingDays,
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
    String? activityLevel,
    String? dietaryChoice,
    String? workoutExperience,
    List<String>? availableEquipment,
    int? trainingDays,
    double? calorieGoal,
    double? proteinGoal,
    double? carbsGoal,
    double? fatGoal,
    String? locale,
    String? theme,
  }) => VyroProfile(
    name: name ?? this.name,
    goal: goal ?? this.goal,
    activityLevel: activityLevel ?? this.activityLevel,
    dietaryChoice: dietaryChoice ?? this.dietaryChoice,
    workoutExperience: workoutExperience ?? this.workoutExperience,
    availableEquipment: availableEquipment ?? this.availableEquipment,
    trainingDays: trainingDays ?? this.trainingDays,
    calorieGoal: calorieGoal ?? this.calorieGoal,
    proteinGoal: proteinGoal ?? this.proteinGoal,
    carbsGoal: carbsGoal ?? this.carbsGoal,
    fatGoal: fatGoal ?? this.fatGoal,
    locale: locale ?? this.locale,
    theme: theme ?? this.theme,
  );
}
