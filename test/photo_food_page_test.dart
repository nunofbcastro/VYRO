import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:vyro/app/app_services.dart';
import 'package:vyro/app/l10n/strings.dart';
import 'package:vyro/app/theme/vyro_chrome.dart';
import 'package:vyro/app/theme/vyro_theme.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';
import 'package:vyro/features/nutrition/food_vision/food_vision.dart';
import 'package:vyro/features/nutrition/photo_food_page.dart';

void main() {
  final db = FoodDatabase.parse(
    File('assets/nutrition/foods.json').readAsStringSync(),
  );
  final bytes = Uint8List.fromList(
    img.encodePng(img.Image(width: 8, height: 8)),
  );
  late AppDatabase database;
  late _Picker picker;
  late _Vision vision;

  FoodVisionResult meal(List<String> keys) => FoodVisionResult(
    source: VisionSource.systemAi,
    foods: [
      for (final key in keys)
        DetectedFood(
          food: db.byKey(key)!,
          label: db.byKey(key)!.namePt,
          grams: db.byKey(key)!.portionG,
          source: VisionSource.systemAi,
        ),
    ],
  );

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    picker = _Picker(bytes);
    vision = _Vision();
  });
  tearDown(() => database.close());

  Future<void> open(WidgetTester tester) async {
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
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PhotoFoodPage(
                      day: DateTime(2026, 10, 25),
                      imagePicker: picker,
                      vision: vision,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, {bool first = false}) async {
    final button = first
        ? find.text('Escolher da galeria')
        : find.byTooltip('Escolher da galeria');
    await tester.ensureVisible(button);
    await tester.runAsync(() async {
      await tester.tap(button);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  testWidgets('new photo clears old meal while analysis is pending', (
    tester,
  ) async {
    vision.result = Future.value(meal(['chicken_breast_roasted']));
    await open(tester);
    await choose(tester, first: true);
    await tester.pumpAndSettle();
    expect(find.text('Adicionar 1 ao diário'), findsOneWidget);
    final pending = Completer<FoodVisionResult>();
    vision.result = pending.future;
    await choose(tester);
    expect(find.text('Adicionar 1 ao diário'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    pending.complete(
      meal(['bread_white_toasted', 'butter_salted', 'espresso']),
    );
    await tester.pumpAndSettle();
    expect(find.text('Adicionar 3 ao diário'), findsOneWidget);
    // Saving the second photo writes only the three new foods.
    await tester.runAsync(() async {
      await tester.tap(find.text('Adicionar 3 ao diário'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    final entries = await tester.runAsync(
      () => database.watchEntriesForDay('2026-10-25').first,
    );
    expect(entries!.map((e) => e.name), [
      db.byKey('bread_white_toasted')!.namePt,
      db.byKey('butter_salted')!.namePt,
      db.byKey('espresso')!.namePt,
    ]);
  });

  testWidgets(
    'saving then opening another photo does not repeat the saved meal',
    (tester) async {
      vision.result = Future.value(meal(['chicken_breast_roasted']));
      await open(tester);
      await choose(tester, first: true);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Adicionar 1 ao diário'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      // Let the first save confirmation leave the shared messenger before
      // opening another page (otherwise it covers the second save button).
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      vision.result = Future.value(
        meal(['bread_white_toasted', 'butter_salted', 'espresso']),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await choose(tester, first: true);
      await tester.pumpAndSettle();
      expect(find.text('Adicionar 3 ao diário'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Adicionar 3 ao diário'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      final entries = await tester.runAsync(
        () => database.watchEntriesForDay('2026-10-25').first,
      );
      expect(entries, hasLength(4));
      expect(
        entries!.where(
          (e) => e.name == db.byKey('chicken_breast_roasted')!.namePt,
        ),
        hasLength(1),
      );
      expect(vision.calls, 2);
    },
  );

  testWidgets('cancelled picker preserves the unsaved current review', (
    tester,
  ) async {
    vision.result = Future.value(meal(['espresso']));
    await open(tester);
    await choose(tester, first: true);
    await tester.pumpAndSettle();
    picker.cancel = true;
    await choose(tester);
    await tester.pumpAndSettle();
    expect(vision.calls, 1);
    expect(find.text('Adicionar 1 ao diário'), findsOneWidget);
    expect(
      tester
          .widget<VyroPrimaryButton>(find.byType(VyroPrimaryButton))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('late analysis after leaving the page is ignored', (
    tester,
  ) async {
    final pending = Completer<FoodVisionResult>();
    vision.result = pending.future;
    await open(tester);
    await choose(tester, first: true);
    Navigator.of(tester.element(find.byType(PhotoFoodPage))).pop();
    await tester.pumpAndSettle();
    pending.complete(meal(['espresso']));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Picker extends ImagePicker {
  _Picker(this.bytes);
  final Uint8List bytes;
  bool cancel = false;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => cancel ? null : XFile.fromData(bytes, name: 'test.png');
}

class _Vision implements FoodVisionService {
  late Future<FoodVisionResult> result;
  int calls = 0;

  @override
  Future<FoodVisionResult> analyse(Uint8List imageBytes) {
    calls++;
    return result;
  }
}
