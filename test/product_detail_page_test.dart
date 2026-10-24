import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/app/app_services.dart';
import 'package:vyro/app/l10n/strings.dart';
import 'package:vyro/app/theme/vyro_theme.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/features/barcode/product_detail_page.dart';
import 'package:vyro/features/nutrition/domain/food_product.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(executor: NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<void> pumpPage(WidgetTester tester, FoodProduct product) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppServicesScope(
        services: AppServices(database: database),
        child: MaterialApp(
          theme: VyroTheme.dark,
          locale: const Locale('pt', 'PT'),
          supportedLocales: VyroStrings.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<bool>(
                      builder: (_) => ProductDetailPage(
                        product: product,
                        day: DateTime(2026, 10, 24),
                        initialMeal: 'snack',
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('logs two bars as units converted to grams', (tester) async {
    await pumpPage(
      tester,
      const FoodProduct(
        barcode: '5601234567890',
        name: 'Barra de aveia',
        quantity: '6 x 25 g',
        kcalPer100g: 400,
        proteinPer100g: 10,
        carbsPer100g: 60,
        fatPer100g: 12,
      ),
    );

    // No serving declared: the unit (25 g) is the default.
    expect(find.text('Unidade'), findsOneWidget);
    expect(find.text('1 unidade = 25 g'), findsOneWidget);
    expect(find.textContaining('100 kcal'), findsWidgets);

    await tester.tap(find.text('2'));
    await tester.pump();
    expect(find.text('unidades'), findsOneWidget);
    expect(find.textContaining('200 kcal'), findsWidgets);

    await tester.runAsync(() async {
      await tester.tap(find.textContaining('Adicionar ao diário'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    final entries = await tester.runAsync(
      () => database.watchEntriesForDay('2026-10-24').first,
    );
    expect(entries, hasLength(1));
    final entry = entries!.single;
    expect(entry.quantityGrams, 50);
    expect(entry.portionUnit, 'unit');
    expect(entry.portionCount, 2);
    expect(entry.mealType, 'snack');
    expect(entry.source, 'open_food_facts');
  });

  testWidgets('a unit without declared weight asks for it first', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const FoodProduct(
        barcode: '5601234567890',
        name: 'Iogurte',
        quantity: '500 g',
        kcalPer100g: 60,
      ),
    );

    await tester.tap(find.text('Unidade'));
    await tester.pump();
    expect(
      find.text('Indica o peso de uma unidade para calcular.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Peso de uma unidade'),
      '125',
    );
    await tester.pump();
    expect(find.textContaining('75 kcal'), findsWidgets);
  });
}
