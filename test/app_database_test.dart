import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/core/database/app_database.dart';

/// Guards the persistence contract used by onboarding, settings and import.
///
/// Regression: `saveUserProfile` passed `Variable` objects to
/// `customStatement`, which fails with "Unknown db value" on the web executor
/// and left the returned future hanging forever.
void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('profile round-trips through local storage', () async {
    const profile = VyroProfile(
      name: 'Nuno',
      locale: 'en',
      theme: 'light',
      onboardingCompleted: true,
      calorieGoal: 2340,
    );

    await database.saveUserProfile(profile);
    final stored = await database.getUserProfile();

    expect(stored, isNotNull);
    expect(stored!.name, 'Nuno');
    expect(stored.locale, 'en');
    expect(stored.theme, 'light');
    expect(stored.onboardingCompleted, isTrue);
    expect(stored.calorieGoal, 2340);
  });

  test('saving twice keeps a single profile row', () async {
    await database.saveUserProfile(
      const VyroProfile(name: 'First', onboardingCompleted: true),
    );
    await database.saveUserProfile(
      const VyroProfile(name: 'Second', onboardingCompleted: true),
    );

    final stored = await database.getUserProfile();
    expect(stored?.name, 'Second');
  });

  test('locale and theme updates keep the rest of the profile', () async {
    await database.saveUserProfile(
      const VyroProfile(name: 'Nuno', onboardingCompleted: true),
    );

    await database.updateProfileLocale('en');
    await database.updateProfileTheme('light');

    final stored = await database.getUserProfile();
    expect(stored?.name, 'Nuno');
    expect(stored?.locale, 'en');
    expect(stored?.theme, 'light');
  });
}
