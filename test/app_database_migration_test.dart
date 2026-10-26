import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/features/workouts/domain/plan_details.dart';

import 'generated_migrations/schema.dart';

/// Migration tests use the schema dumps in `drift_schemas/` (see
/// `test/generated_migrations/`). Regenerate them with
/// `dart run drift_dev schema dump` and `dart run drift_dev schema generate`
/// whenever a table changes, and add a test for each new version step.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test(
    'v5 to v6 keeps existing plans and adds an empty details column',
    () async {
      final schema = await verifier.schemaAt(5);
      schema.rawDatabase.execute(
        "INSERT INTO workout_plans (title, goal, active, created_at) "
        "VALUES ('Plano antigo', 'health', 1, 1700000000)",
      );

      final db = AppDatabase(executor: schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 6);

      final plan = await db.getActiveWorkoutPlan();
      expect(plan, isNotNull);
      expect(plan!.title, 'Plano antigo');
      expect(plan.details, isNull);
      expect(PlanDetails.decode(plan.details), isNull);
    },
  );

  test('a fresh v6 database has the details column', () async {
    final schema = await verifier.schemaAt(6);
    final db = AppDatabase(executor: schema.newConnection());
    addTearDown(db.close);
    await db.validateDatabaseSchema();
  });
}
