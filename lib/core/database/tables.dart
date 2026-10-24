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
  DateTimeColumn get lastFetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {barcode};
}
