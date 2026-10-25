import 'package:drift/drift.dart';

@DataClassName('FoodEntryRecord')
class FoodEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get day => text()();
  TextColumn get mealType => text()();
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  RealColumn get quantityGrams => real()();
  RealColumn get kcalPer100g => real().nullable()();
  RealColumn get proteinPer100g => real().nullable()();
  RealColumn get carbsPer100g => real().nullable()();
  RealColumn get fatPer100g => real().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();

  /// How the amount was entered: grams, serving, unit or package.
  TextColumn get portionUnit => text().nullable()();

  /// Number of portions; `quantityGrams` stays the source of truth.
  RealColumn get portionCount => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class CachedProducts extends Table {
  TextColumn get barcode => text()();
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get quantity => text().nullable()();
  RealColumn get kcalPer100g => real().nullable()();
  RealColumn get proteinPer100g => real().nullable()();
  RealColumn get carbsPer100g => real().nullable()();
  RealColumn get fatPer100g => real().nullable()();
  TextColumn get nutriScore => text().nullable()();
  TextColumn get servingSize => text().nullable()();
  RealColumn get servingGrams => real().nullable()();
  RealColumn get packageGrams => real().nullable()();
  BoolColumn get liquid => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastFetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {barcode};
}

class WorkoutPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get goal => text()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class WorkoutDays extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer()();
  IntColumn get dayNumber => integer()();
  TextColumn get namePt => text()();
  TextColumn get nameEn => text()();

  /// ISO weekday this workout is scheduled on (1 = Monday … 7 = Sunday).
  IntColumn get weekday => integer().nullable()();
}

class ExerciseCatalog extends Table {
  TextColumn get exerciseKey => text()();
  TextColumn get namePt => text()();
  TextColumn get nameEn => text()();
  TextColumn get muscleGroup => text()();
  TextColumn get instructionsPt => text()();
  TextColumn get instructionsEn => text()();
  TextColumn get equipment => text()();
  TextColumn get difficulty => text()();

  @override
  Set<Column<Object>> get primaryKey => {exerciseKey};
}

class PlanExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get dayId => integer()();
  TextColumn get exerciseKey => text()();
  IntColumn get sortOrder => integer()();
  IntColumn get sets => integer().withDefault(const Constant(3))();
  IntColumn get repTarget => integer().withDefault(const Constant(10))();
  IntColumn get restSeconds => integer().withDefault(const Constant(90))();
}

class WorkoutSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get day => text()();
  TextColumn get planName => text()();
  TextColumn get workoutName => text()();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
}

class ExerciseSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer()();
  TextColumn get exerciseKey => text()();
  IntColumn get setNumber => integer()();
  IntColumn get targetReps => integer()();
  IntColumn get reps => integer().nullable()();
  RealColumn get weightKg => real().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

/// Dates the user marked as "não posso treinar" in the weekly plan.
class ScheduleSkips extends Table {
  TextColumn get date => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {date};
}

class BodyMeasurements extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get measuredAt => dateTime().withDefault(currentDateAndTime)();
  RealColumn get weightKg => real()();
  TextColumn get note => text().nullable()();
}
