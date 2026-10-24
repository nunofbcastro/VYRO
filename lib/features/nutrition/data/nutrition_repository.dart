import '../../../core/database/app_database.dart';

abstract interface class NutritionRepository {
  Stream<List<FoodEntryRecord>> watchEntriesForDay(String day);
  Future<int> addEntry(FoodEntriesCompanion entry);
  Future<bool> updateEntry(FoodEntryRecord entry);
  Future<int> deleteEntry(int id);
}

class DriftNutritionRepository implements NutritionRepository {
  DriftNutritionRepository(this.database);
  final AppDatabase database;

  @override
  Stream<List<FoodEntryRecord>> watchEntriesForDay(String day) =>
      database.watchEntriesForDay(day);

  @override
  Future<int> addEntry(FoodEntriesCompanion entry) =>
      database.addFoodEntry(entry);

  @override
  Future<bool> updateEntry(FoodEntryRecord entry) =>
      database.updateFoodEntry(entry);

  @override
  Future<int> deleteEntry(int id) => database.removeFoodEntry(id);
}
