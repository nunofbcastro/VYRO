import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [FoodEntries, CachedProducts])
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
  int get schemaVersion => 1;

  Stream<List<FoodEntryRecord>> watchEntriesForDay(String day) =>
      (select(foodEntries)
            ..where((entry) => entry.day.equals(day))
            ..orderBy([(entry) => OrderingTerm.asc(entry.createdAt)]))
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

  Future<int> clearUserData() async {
    return transaction(() async {
      final removedEntries = await delete(foodEntries).go();
      await delete(cachedProducts).go();
      return removedEntries;
    });
  }
}
