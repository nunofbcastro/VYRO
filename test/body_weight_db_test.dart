import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<List<BodyMeasurement>> allWeights() =>
      database.watchBodyWeights().first;

  test('adds an entry on a past day', () async {
    final id = await database.saveBodyWeight(
      measuredAt: DateTime(2026, 10, 25, 12),
      weightKg: 74.5,
    );

    final rows = await allWeights();
    expect(rows, hasLength(1));
    expect(rows.single.id, id);
    expect(rows.single.weightKg, 74.5);
    expect(rows.single.measuredAt, DateTime(2026, 10, 25, 12));

    final onDay = await database.bodyWeightOnDay(DateTime(2026, 10, 25, 23));
    expect(onDay?.id, id);
    expect(await database.bodyWeightOnDay(DateTime(2026, 10, 24)), isNull);
  });

  test('updates the value and the day of an existing entry', () async {
    final id = await database.saveBodyWeight(
      measuredAt: DateTime(2026, 10, 25, 12),
      weightKg: 74.5,
    );

    await database.saveBodyWeight(
      id: id,
      measuredAt: DateTime(2026, 10, 25, 12),
      weightKg: 74.2,
    );
    var rows = await allWeights();
    expect(rows, hasLength(1));
    expect(rows.single.weightKg, 74.2);

    await database.saveBodyWeight(
      id: id,
      measuredAt: DateTime(2026, 10, 22, 12),
      weightKg: 74.2,
    );
    rows = await allWeights();
    expect(rows.single.measuredAt, DateTime(2026, 10, 22, 12));
    expect(await database.bodyWeightOnDay(DateTime(2026, 10, 25)), isNull);
  });

  test('a second entry on the same day is a conflict by default', () async {
    await database.saveBodyWeight(
      measuredAt: DateTime(2026, 10, 25, 8),
      weightKg: 74.5,
    );

    await expectLater(
      database.saveBodyWeight(
        measuredAt: DateTime(2026, 10, 25, 20),
        weightKg: 75,
      ),
      throwsA(isA<BodyWeightDayConflict>()),
    );
    expect(await allWeights(), hasLength(1));
  });

  test('replaceSameDay keeps one entry per day', () async {
    await database.saveBodyWeight(
      measuredAt: DateTime(2026, 10, 25, 8),
      weightKg: 74.5,
    );

    await database.saveBodyWeight(
      measuredAt: DateTime(2026, 10, 25, 20),
      weightKg: 75,
      replaceSameDay: true,
    );

    final rows = await allWeights();
    expect(rows, hasLength(1));
    expect(rows.single.weightKg, 75);
  });

  test('moving an entry onto a taken day needs replaceSameDay', () async {
    await database.saveBodyWeight(
      measuredAt: DateTime(2026, 10, 25, 12),
      weightKg: 74.5,
    );
    final today = await database.saveBodyWeight(
      measuredAt: DateTime(2026, 10, 26, 12),
      weightKg: 73,
    );

    await expectLater(
      database.saveBodyWeight(
        id: today,
        measuredAt: DateTime(2026, 10, 25, 12),
        weightKg: 73,
      ),
      throwsA(isA<BodyWeightDayConflict>()),
    );

    await database.saveBodyWeight(
      id: today,
      measuredAt: DateTime(2026, 10, 25, 12),
      weightKg: 73,
      replaceSameDay: true,
    );
    final rows = await allWeights();
    expect(rows, hasLength(1));
    expect(rows.single.id, today);
    expect(rows.single.weightKg, 73);
  });

  test('deletes an entry and the stream reflects it', () async {
    final id = await database.saveBodyWeight(
      measuredAt: DateTime(2026, 10, 25, 12),
      weightKg: 74.5,
    );

    expect(await database.deleteBodyWeight(id), 1);
    expect(await allWeights(), isEmpty);
  });

  test('restores a deleted entry with its id and value', () async {
    final id = await database.saveBodyWeight(
      measuredAt: DateTime(2026, 10, 25, 12),
      weightKg: 74.5,
    );
    final removed = (await allWeights()).single;
    await database.deleteBodyWeight(id);

    expect(await database.restoreBodyWeight(removed), isTrue);
    final rows = await allWeights();
    expect(rows.single.id, id);
    expect(rows.single.weightKg, 74.5);
  });

  test('restore is refused when another entry now holds that day', () async {
    final id = await database.saveBodyWeight(
      measuredAt: DateTime(2026, 10, 25, 12),
      weightKg: 74.5,
    );
    final removed = (await allWeights()).single;
    await database.deleteBodyWeight(id);
    await database.saveBodyWeight(
      measuredAt: DateTime(2026, 10, 25, 9),
      weightKg: 75,
    );

    expect(await database.restoreBodyWeight(removed), isFalse);
    final rows = await allWeights();
    expect(rows, hasLength(1));
    expect(rows.single.weightKg, 75);
  });

  test('edits and deletions survive export and import', () async {
    final id = await database.saveBodyWeight(
      measuredAt: DateTime(2026, 10, 24, 12),
      weightKg: 75,
    );
    await database.saveBodyWeight(
      id: id,
      measuredAt: DateTime(2026, 10, 24, 12),
      weightKg: 74.8,
    );
    await database.saveBodyWeight(
      measuredAt: DateTime(2026, 10, 25, 12),
      weightKg: 74.5,
    );
    await database.deleteBodyWeight(
      (await database.bodyWeightOnDay(DateTime(2026, 10, 25)))!.id,
    );

    final exported =
        jsonDecode(jsonEncode(await database.exportAllData()))
            as Map<String, dynamic>;

    final restored = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(restored.close);
    await restored.importAllData(exported);
    final rows = await restored.watchBodyWeights().first;
    expect(rows, hasLength(1));
    expect(rows.single.weightKg, 74.8);
    expect(rows.single.measuredAt, DateTime(2026, 10, 24, 12));
  });
}
