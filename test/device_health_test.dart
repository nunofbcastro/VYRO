import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/features/health/device_health.dart';
import 'package:vyro/features/health/device_health_store.dart';

void main() {
  final day = DateTime(2026, 11, 7);

  test('sums today and keeps the latest weight from another day', () {
    final reading = DeviceHealthDay.fromQuantities(
      day: day,
      readAt: DateTime(2026, 11, 7, 9),
      steps: 4200,
      quantities: [
        HealthQuantity(
          HealthQuantityKind.activeKcal,
          80,
          DateTime(2026, 11, 7, 8),
        ),
        HealthQuantity(
          HealthQuantityKind.activeKcal,
          20,
          DateTime(2026, 11, 6, 8),
        ),
        HealthQuantity(
          HealthQuantityKind.distanceM,
          1500,
          DateTime(2026, 11, 7, 8),
        ),
        HealthQuantity(HealthQuantityKind.weightKg, 70, DateTime(2026, 11, 1)),
        HealthQuantity(
          HealthQuantityKind.weightKg,
          71.5,
          DateTime(2026, 11, 6),
        ),
      ],
    );
    expect(reading.steps, 4200);
    expect(reading.activeKcal, 80);
    expect(reading.distanceMeters, 1500);
    expect(reading.weightKg, 71.5);
  });

  test('drops absurd values and unreadable text', () {
    final reading = DeviceHealthDay.fromQuantities(
      day: day,
      readAt: day,
      steps: 9000000,
      quantities: [HealthQuantity(HealthQuantityKind.weightKg, 2, day)],
    );
    expect(reading.steps, isNull);
    expect(reading.weightKg, isNull);
    expect(DeviceHealthDay.tryParse('not json'), isNull);
    expect(DeviceHealthDay.tryParse('{"day":"nope"}'), isNull);
  });

  test('the store hides yesterday and stays off until opted in', () async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
    final store = DeviceHealthStore(db);
    final today = DeviceHealthDay(
      day: day,
      readAt: DateTime(2026, 11, 7, 9),
      steps: 1000,
      activeKcal: 40,
    );
    await store.save(today);
    expect(await store.todayIfEnabled(day), isNull);
    await store.setEnabled(true);
    expect((await store.todayIfEnabled(day))?.steps, 1000);
    expect(await store.todayIfEnabled(DateTime(2026, 11, 8)), isNull);

    final again = DeviceHealthDay.tryParse(
      await db.getPreference(DeviceHealthStore.snapshotKey),
    );
    expect(again?.activeKcal, 40);
  });
}
