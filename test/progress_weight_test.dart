import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/app/app.dart';
import 'package:vyro/app/app_services.dart';
import 'package:vyro/app/l10n/strings.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/features/progress/domain/body_weight.dart';
import 'package:vyro/features/progress/line_chart.dart';
import 'package:vyro/features/progress/progress_page.dart';

/// Lets drift and the sheet animations finish.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// History rows sit below the chart, often under the fold, so they are
/// scrolled into view before a tap or swipe.
Future<void> tapEntry(WidgetTester tester, int id) async {
  final row = find.byKey(ValueKey('weight-$id'));
  await tester.ensureVisible(row);
  await tester.pump();
  await tester.tap(row);
}

Future<void> swipeEntry(WidgetTester tester, int id) async {
  final row = find.byKey(ValueKey('weight-$id'));
  await tester.ensureVisible(row);
  await tester.pump();
  await tester.drag(row, const Offset(-500, 0));
}

/// Widget flows of the weight log on the progress page (pt-PT).
///
/// Drift runs its SQLite work on real async completions, so database calls
/// go through [tester.runAsync]; see [_db].
/// Unmounts the page and drains drift's zero-length timers, so the test
/// ends with no pending timers.
void _flowTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(seconds: 1));
    }
  });
}

void main() {
  late AppDatabase database;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(today.year, today.month, today.day - 1);

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpProgress(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final services = AppServices(database: database);
    final settings = AppSettings(services);
    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('pt', 'PT'),
          supportedLocales: VyroStrings.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SettingsScope(settings: settings, child: const ProgressPage()),
        ),
      ),
    );
    await settle(tester);
  }

  Future<T> _db<T>(WidgetTester tester, Future<T> Function() action) async =>
      (await tester.runAsync(action))!;

  Future<int> seed(WidgetTester tester, DateTime day, double kg) => _db(
    tester,
    () => database.saveBodyWeight(
      measuredAt: DateTime(day.year, day.month, day.day, 12),
      weightKg: kg,
    ),
  );

  Future<List<BodyMeasurement>> rows(WidgetTester tester) =>
      _db(tester, () => database.watchBodyWeights().first);

  Finder button(String label) => find.widgetWithText(FilledButton, label);

  Future<void> openAddSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Registar peso'));
    await settle(tester);
  }

  _flowTest('adds yesterday with a comma decimal', (tester) async {
    await pumpProgress(tester);
    await openAddSheet(tester);

    await tester.enterText(find.byType(TextField), '74,5');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ontem'));
    await settle(tester);
    await tester.tap(button('Guardar'));
    await settle(tester);

    final stored = await rows(tester);
    expect(stored, hasLength(1));
    expect(stored.single.weightKg, 74.5);
    expect(bodyDay(stored.single.measuredAt), yesterday);
    expect(find.text(formatBodyDate(yesterday)), findsWidgets);
    expect(find.text('74,5 kg'), findsWidgets);
  });

  _flowTest('rejects a value outside the allowed range', (tester) async {
    await pumpProgress(tester);
    await openAddSheet(tester);

    await tester.enterText(find.byType(TextField), '19,9');
    await tester.tap(button('Guardar'));
    await settle(tester);

    expect(
      find.text('Indica um peso entre 20 e 400 kg, com até uma casa decimal.'),
      findsOneWidget,
    );
    expect(await rows(tester), isEmpty);
  });

  _flowTest('editing an entry pre-fills it and saves the change', (
    tester,
  ) async {
    final id = await seed(tester, yesterday, 74.5);
    await pumpProgress(tester);

    await tapEntry(tester, id);
    await settle(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '74,5');

    await tester.enterText(find.byType(TextField), '74,2');
    await tester.tap(button('Guardar'));
    await settle(tester);

    final stored = await rows(tester);
    expect(stored, hasLength(1));
    expect(stored.single.id, id);
    expect(stored.single.weightKg, 74.2);
  });

  _flowTest('moving an entry to today keeps a single entry', (tester) async {
    final id = await seed(tester, yesterday, 74.5);
    await pumpProgress(tester);

    await tapEntry(tester, id);
    await settle(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Hoje'));
    await settle(tester);
    await tester.tap(button('Guardar'));
    await settle(tester);

    final stored = await rows(tester);
    expect(stored.single.id, id);
    expect(bodyDay(stored.single.measuredAt), today);
  });

  _flowTest('a second entry for the same day asks before replacing', (
    tester,
  ) async {
    await seed(tester, today, 70);
    await pumpProgress(tester);

    await openAddSheet(tester);
    await tester.enterText(find.byType(TextField), '71');
    await tester.tap(button('Guardar'));
    await settle(tester);
    expect(find.text('Já existe um registo neste dia'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await settle(tester);
    var stored = await rows(tester);
    expect(stored, hasLength(1));
    expect(stored.single.weightKg, 70);

    await openAddSheet(tester);
    await tester.enterText(find.byType(TextField), '71');
    await tester.tap(button('Guardar'));
    await settle(tester);
    await tester.tap(button('Substituir'));
    await settle(tester);

    stored = await rows(tester);
    expect(stored, hasLength(1));
    expect(stored.single.weightKg, 71);
  });

  _flowTest('swipe deletes with an Anular snackbar that restores the entry', (
    tester,
  ) async {
    final id = await seed(tester, yesterday, 74.5);
    await pumpProgress(tester);

    await swipeEntry(tester, id);
    await settle(tester);
    await settle(tester);

    expect(await rows(tester), isEmpty);
    expect(find.text('Registo apagado.'), findsOneWidget);

    await tester.tap(find.text('Anular'));
    await settle(tester);

    final stored = await rows(tester);
    expect(stored, hasLength(1));
    expect(stored.single.id, id);
    expect(stored.single.weightKg, 74.5);
  });

  _flowTest('deleting from the edit sheet asks for confirmation first', (
    tester,
  ) async {
    final id = await seed(tester, yesterday, 74.5);
    await pumpProgress(tester);

    await tapEntry(tester, id);
    await settle(tester);
    await tester.tap(find.text('Apagar registo'));
    await settle(tester);
    expect(find.text('Apagar este registo?'), findsOneWidget);
    expect(await rows(tester), hasLength(1));

    await tester.tap(button('Apagar'));
    await settle(tester);

    expect(await rows(tester), isEmpty);
    expect(find.text('Registo apagado.'), findsOneWidget);
  });

  _flowTest('tapping the chart point opens that entry', (tester) async {
    await seed(tester, yesterday, 74.5);
    await seed(tester, today, 75);
    await pumpProgress(tester);

    final chart = find.byType(LineChart);
    final topRight = tester.getTopRight(chart);
    await tester.tapAt(topRight + const Offset(-2, 20));
    await settle(tester);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '75,0');
  });
}
