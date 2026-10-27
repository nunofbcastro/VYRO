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
      // The location is English from the model: not shown in Portuguese.
      expect(find.textContaining('Posição na foto'), findsNothing);
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

  testWidgets('an unmatched English model name is never the card title', (
    tester,
  ) async {
    await pumpCard(
      tester,
      ReviewItem(
        const DetectedFood(
          label: 'blorf',
          grams: 100,
          source: VisionSource.systemAi,
          where: 'centre of plate',
        ),
      ),
    );
    expect(find.text('blorf'), findsNothing);
    expect(find.text('Que alimento?'), findsOneWidget);
    expect(find.text('Escolhe o alimento'), findsOneWidget);
  });

  testWidgets('a matched English answer shows the Portuguese food name', (
    tester,
  ) async {
    final egg = db.byKey('egg_fried')!;
    await pumpCard(
      tester,
      ReviewItem(
        DetectedFood(
          food: egg,
          label: 'fried egg',
          grams: 50,
          source: VisionSource.systemAi,
        ),
      ),
    );
    expect(find.text(egg.name(false)), findsOneWidget);
    expect(find.text('fried egg'), findsNothing);
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

  group('PhotoActionRow', () {
    const actions = [
      PhotoAction(icon: Icons.crop, label: 'Zona'),
      PhotoAction(icon: Icons.add_a_photo_outlined, label: '2.º ângulo'),
      PhotoAction(icon: Icons.restaurant_menu, label: 'Receita'),
      PhotoAction(icon: Icons.photo_library_outlined, label: 'Mais fotos'),
    ];

    Future<void> pumpRow(
      WidgetTester tester, {
      required double width,
      double textScale = 1,
      bool dark = true,
    }) async {
      tester.view.physicalSize = Size(width * 2.625, 900 * 2.625);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? VyroTheme.dark : VyroTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const Scaffold(
            body: const Padding(
              padding: const EdgeInsets.all(16),
              child: PhotoActionRow(actions: actions),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    List<Rect> tileRects(WidgetTester tester) => [
      for (final element
          in find
              .descendant(
                of: find.byType(PhotoActionRow),
                matching: find.byType(InkWell),
              )
              .evaluate())
        tester.getRect(find.byWidget(element.widget)),
    ];

    testWidgets('four tiles in one row keep 12 dp gaps at 412 dp', (
      tester,
    ) async {
      await pumpRow(tester, width: 412);
      final rects = tileRects(tester);
      expect(rects, hasLength(4));
      for (var i = 0; i < 3; i++) {
        expect(rects[i].top, rects[i + 1].top, reason: 'same row');
        expect(rects[i + 1].left - rects[i].right, closeTo(12, 0.01));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('four tiles stay in one row at 360 dp, text scale 1.0', (
      tester,
    ) async {
      await pumpRow(tester, width: 360);
      final rects = tileRects(tester);
      expect(rects.map((r) => r.top).toSet(), hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a 320 dp screen switches to a 2x2 grid with 12 dp gaps', (
      tester,
    ) async {
      await pumpRow(tester, width: 320);
      final rects = tileRects(tester);
      expect(rects, hasLength(4));
      // Row one: tiles 0 and 1. Row two: tiles 2 and 3.
      expect(rects[0].top, rects[1].top);
      expect(rects[2].top, rects[3].top);
      expect(rects[2].top - rects[0].bottom, closeTo(12, 0.01));
      expect(rects[1].left - rects[0].right, closeTo(12, 0.01));
      expect(rects[3].left - rects[2].right, closeTo(12, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('text scale 1.3 at 412 dp switches to a 2x2 grid', (
      tester,
    ) async {
      await pumpRow(tester, width: 412, textScale: 1.3);
      final rects = tileRects(tester);
      expect(rects[0].top, rects[1].top);
      expect(rects[2].top, greaterThan(rects[0].bottom));
      expect(rects[2].top - rects[0].bottom, closeTo(12, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('text scale 1.3 at 360 dp lays out without overflow', (
      tester,
    ) async {
      await pumpRow(tester, width: 360, textScale: 1.3, dark: false);
      expect(tileRects(tester), hasLength(4));
      expect(tester.takeException(), isNull);
    });
  });
}
