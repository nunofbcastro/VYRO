import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/app/l10n/strings.dart';
import 'package:vyro/app/theme/vyro_theme.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';
import 'package:vyro/features/nutrition/food_vision/food_vision.dart';
import 'package:vyro/features/nutrition/photo/review_model.dart';
import 'package:vyro/features/nutrition/widgets/photo_review_widgets.dart';

void main() {
  final db = FoodDatabase.parse(
    File('assets/nutrition/foods.json').readAsStringSync(),
  );

  Future<void> pumpCard(WidgetTester tester, ReviewItem item) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: VyroTheme.dark,
        locale: const Locale('pt', 'PT'),
        supportedLocales: VyroStrings.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: ListView(
            children: [
              FoodReviewCard(
                item: item,
                onChange: () {},
                onGrams: (_) {},
                onRemove: () {},
                onClarify: () {},
              ),
            ],
          ),
        ),
      ),
    );
    // A pending spinner animates forever, so do not wait for it to settle.
    await tester.pump();
  }

  testWidgets(
    'an unmatched generic item asks for the food; details hold the English position',
    (tester) async {
      await pumpCard(
        tester,
        ReviewItem(
          const DetectedFood(
            label: 'Bebida',
            grams: 100,
            source: VisionSource.systemAi,
            where: 'cup top-left',
            needsChoice: true,
          ),
        ),
      );
      expect(find.text('Que bebida?'), findsOneWidget);
      expect(find.text('Escolhe o alimento'), findsOneWidget);
      expect(find.text('Escolher'), findsOneWidget);
      expect(find.textContaining('cup top-left'), findsNothing);

      await tester.tap(find.text('Detalhes'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nome demasiado geral'), findsOneWidget);
      expect(find.text('Posição na foto: cup top-left'), findsOneWidget);
      expect(find.text('Esclarecer alimento ou porção'), findsOneWidget);
    },
  );

  testWidgets(
    'a matched item shows grams and kcal, and a confirm pill when unverified',
    (tester) async {
      final rice = db.byKey('rice_white_cooked')!;
      await pumpCard(
        tester,
        ReviewItem(
          DetectedFood(
            food: rice,
            label: rice.namePt,
            grams: 150,
            source: VisionSource.systemAi,
            where: 'centre of plate',
          ),
        ),
      );
      expect(find.text(rice.name(false)), findsOneWidget);
      final kcal = (rice.kcal * 150 / 100).round();
      expect(find.text('150 g · $kcal kcal'), findsOneWidget);
      expect(find.text('a confirmar'), findsOneWidget);
      expect(find.textContaining('kcal/100 g'), findsNothing);
      expect(find.textContaining('centre of plate'), findsNothing);
    },
  );

  testWidgets('a draft line shows only the pending indicator', (tester) async {
    final rice = db.byKey('rice_white_cooked')!;
    await pumpCard(
      tester,
      ReviewItem(
        DetectedFood(
          food: rice,
          label: rice.namePt,
          grams: 150,
          source: VisionSource.systemAi,
          pending: true,
        ),
      ),
    );
    expect(find.text('a confirmar…'), findsOneWidget);
    expect(find.text('a confirmar'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('the summary says parcial while some lines have no values', (
    tester,
  ) async {
    final rice = db.byKey('rice_white_cooked')!;
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: VyroTheme.dark,
        locale: const Locale('pt', 'PT'),
        supportedLocales: VyroStrings.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: ReviewSummary(
            items: [
              ReviewItem(
                DetectedFood(
                  food: rice,
                  label: rice.namePt,
                  grams: 100,
                  source: VisionSource.systemAi,
                ),
              ),
              ReviewItem(
                const DetectedFood(
                  label: 'Peixe grelhado',
                  grams: 120,
                  source: VisionSource.systemAi,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('parcial'), findsOneWidget);
    expect(find.text('Totais sem 1 por escolher.'), findsOneWidget);
  });
}
