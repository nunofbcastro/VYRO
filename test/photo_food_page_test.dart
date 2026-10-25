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
import 'package:vyro/core/ai/on_device_llm.dart';
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

  Future<void> open(WidgetTester tester, {FoodVisionService? service}) async {
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
                      vision: service ?? vision,
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

  /// Picks from the gallery: the Hero button on the first use, then the
  /// "Mais fotos" action under the photo.
  Future<void> choose(WidgetTester tester, {bool first = false}) async {
    final button = first
        ? find.text('Escolher da galeria')
        : find.text('Mais fotos');
    await tester.ensureVisible(button);
    await tester.runAsync(() async {
      await tester.tap(button);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
  }

  /// Taps a widget and lets the real-time file reads finish.
  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.runAsync(() async {
      await tester.tap(find.text(text));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
  }

  /// Lets queued real-time work (file reads, stream events) run.
  Future<void> flush(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }

  Future<List<String>> savedNames() async {
    final entries = await database.watchEntriesForDay('2026-10-25').first;
    return [for (final e in entries) e.name];
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
    expect(await tester.runAsync(savedNames), [
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
      final names = await tester.runAsync(savedNames);
      expect(names, hasLength(4));
      expect(
        names!.where((n) => n == db.byKey('chicken_breast_roasted')!.namePt),
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

  testWidgets('a generic name asks which food it is, with no database match', (
    tester,
  ) async {
    vision.result = Future.value(
      const FoodVisionResult(
        source: VisionSource.systemAi,
        foods: [
          DetectedFood(
            label: 'Bebida',
            grams: 100,
            source: VisionSource.systemAi,
            where: 'cup top-left',
            needsChoice: true,
          ),
        ],
      ),
    );
    await open(tester);
    await choose(tester, first: true);
    await tester.pumpAndSettle();
    expect(find.text('Que bebida?'), findsOneWidget);
    expect(find.text('Escolhe o alimento'), findsOneWidget);
    expect(find.text('Escolher'), findsOneWidget);
    expect(find.text('parcial'), findsOneWidget);
    // The English position text stays inside the collapsed details.
    expect(find.textContaining('cup top-left'), findsNothing);
    expect(find.textContaining('Sem correspondência'), findsNothing);
    expect(find.text('Adicionar 0 ao diário'), findsOneWidget);
    expect(find.text('1 por escolher'), findsOneWidget);
  });

  testWidgets('a busy phone AI explains itself and retries the same photo', (
    tester,
  ) async {
    final pending = Completer<FoodVisionResult>();
    vision.result = pending.future;
    await open(tester);
    await choose(tester, first: true);
    pending.completeError(
      const LlmException('generation_failed: quota exceeded'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('A IA do telemóvel está ocupada. Tenta de novo daqui a pouco.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Adicionar alimento'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Adicionar alimento'), findsOneWidget);

    vision.result = Future.value(meal(['espresso']));
    await tester.ensureVisible(find.text('Tentar de novo'));
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(vision.calls, 2);
    expect(find.text('Adicionar 1 ao diário'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsNothing);
  });

  // Changed in v0.6.5 (real device: a steak in a pan showed a plain notice
  // with no retry). A confirmed empty photo now shows the retry card with
  // its own explanation, and the offline hypotheses as "Outras hipóteses".
  testWidgets('a confirmed empty photo shows the retry card and suggestions', (
    tester,
  ) async {
    vision.result = Future.value(
      FoodVisionResult(
        source: VisionSource.systemAi,
        foods: const [],
        confirmedEmpty: true,
        suggestions: [
          DetectedFood(
            food: db.byKey('espresso'),
            label: 'Café expresso',
            grams: 30,
            source: VisionSource.regionClassifier,
          ),
        ],
      ),
    );
    await open(tester);
    await choose(tester, first: true);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'A IA do telemóvel não encontrou comida nesta foto. Tenta outra vez, analisa uma zona ou adiciona manualmente.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tentar de novo'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Outras hipóteses'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Outras hipóteses'), findsOneWidget);
    expect(find.text(db.byKey('espresso')!.namePt), findsOneWidget);
    expect(find.textContaining('Não identificámos'), findsNothing);
    expect(find.text('Adicionar 0 ao diário'), findsOneWidget);

    vision.result = Future.value(meal(['espresso']));
    await tester.scrollUntilVisible(
      find.text('Adicionar alimento'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Tentar de novo'));
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(vision.calls, 2);
    expect(find.text('Adicionar 1 ao diário'), findsOneWidget);
  });

  testWidgets(
    'draft lines show a pending indicator, then the final replaces them',
    (tester) async {
      final chicken = db.byKey('chicken_breast_roasted')!;
      final bread = db.byKey('bread_white_toasted')!;
      final staged = _Staged(
        draft: FoodVisionResult(
          source: VisionSource.systemAi,
          stage: VisionStage.draft,
          foods: [
            DetectedFood(
              food: chicken,
              label: chicken.namePt,
              grams: chicken.portionG,
              source: VisionSource.systemAi,
              pending: true,
            ),
            DetectedFood(
              food: bread,
              label: bread.namePt,
              grams: bread.portionG,
              source: VisionSource.systemAi,
              pending: true,
            ),
          ],
        ),
      );
      await open(tester, service: staged);
      await choose(tester, first: true);
      await tester.pump();
      expect(find.text('A identificar alimentos…'), findsOneWidget);
      expect(find.text('Adicionar 0 ao diário'), findsOneWidget);

      staged.draftGate.complete();
      await flush(tester);
      expect(find.text('A confirmar…'), findsOneWidget);
      expect(find.text('a confirmar…'), findsWidgets);
      expect(find.text(chicken.namePt), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(bread.namePt),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(bread.namePt), findsOneWidget);

      staged.finalGate.complete(
        FoodVisionResult(
          source: VisionSource.systemAi,
          foods: [
            DetectedFood(
              food: chicken,
              label: chicken.namePt,
              grams: chicken.portionG,
              source: VisionSource.systemAi,
            ),
          ],
        ),
      );
      await flush(tester);
      await tester.pumpAndSettle();
      expect(find.text('a confirmar…'), findsNothing);
      expect(find.text(bread.namePt), findsNothing);
      expect(find.text(chicken.namePt), findsOneWidget);
      expect(find.text('Adicionar 1 ao diário'), findsOneWidget);
    },
  );

  testWidgets('the card subtitle is grams and kcal only, never English where', (
    tester,
  ) async {
    final chicken = db.byKey('chicken_breast_roasted')!;
    vision.result = Future.value(
      FoodVisionResult(
        source: VisionSource.systemAi,
        foods: [
          DetectedFood(
            food: chicken,
            label: chicken.namePt,
            grams: 150,
            where: 'centre of plate',
            source: VisionSource.systemAi,
          ),
        ],
      ),
    );
    await open(tester);
    await choose(tester, first: true);
    await tester.pumpAndSettle();
    final kcal = (chicken.kcal * 150 / 100).round();
    expect(find.text('150 g · $kcal kcal'), findsOneWidget);
    expect(find.textContaining('centre of plate'), findsNothing);
    expect(find.textContaining('kcal/100 g'), findsNothing);
    expect(find.text('Esclarecer alimento ou porção'), findsNothing);
    expect(find.text('a confirmar'), findsOneWidget);
  });

  testWidgets('meal chips stay on one row', (tester) async {
    vision.result = Future.value(meal(['espresso']));
    await open(tester);
    await choose(tester, first: true);
    await tester.pumpAndSettle();
    final centres = [
      for (final label in ['Pequeno-almoço', 'Almoço', 'Lanche', 'Jantar'])
        tester.getCenter(find.text(label)).dy,
    ];
    expect(
      centres.reduce((a, b) => a > b ? a : b) -
          centres.reduce((a, b) => a < b ? a : b),
      lessThan(1),
    );
  });

  testWidgets('the CTA counts savable foods and never skips unresolved ones', (
    tester,
  ) async {
    final chicken = db.byKey('chicken_breast_roasted')!;
    final espresso = db.byKey('espresso')!;
    vision.result = Future.value(
      FoodVisionResult(
        source: VisionSource.systemAi,
        foods: [
          DetectedFood(
            food: chicken,
            label: chicken.namePt,
            grams: chicken.portionG,
            source: VisionSource.systemAi,
          ),
          DetectedFood(
            food: espresso,
            label: espresso.namePt,
            grams: espresso.portionG,
            source: VisionSource.systemAi,
          ),
          const DetectedFood(
            label: 'Peixe grelhado',
            grams: 120,
            source: VisionSource.systemAi,
          ),
        ],
      ),
    );
    await open(tester);
    await choose(tester, first: true);
    await tester.pumpAndSettle();
    expect(find.text('Adicionar 2 ao diário'), findsOneWidget);
    expect(find.text('1 por escolher'), findsOneWidget);
    expect(find.text('parcial'), findsOneWidget);

    // Tapping the CTA points at the unresolved line and saves nothing.
    await tester.tap(find.text('Adicionar 2 ao diário'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Escolhe o alimento por escolher antes de guardar, ou guarda só os restantes.',
      ),
      findsOneWidget,
    );
    expect(await tester.runAsync(savedNames), isEmpty);

    // The guidance snackbar covers the footer for a few seconds.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Guardar só 2'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(await tester.runAsync(savedNames), [
      chicken.namePt,
      espresso.namePt,
    ]);
  });

  testWidgets(
    'several photos as separate meals: queue header, Seguinte and background analysis',
    (tester) async {
      picker.files = [
        XFile.fromData(bytes, name: 'a.png'),
        XFile.fromData(bytes, name: 'b.png'),
        XFile.fromData(bytes, name: 'c.png'),
      ];
      vision.queue = [
        Future.value(
          const FoodVisionResult(source: VisionSource.systemAi, foods: []),
        ),
        Future.value(meal(['espresso'])),
        Future.value(meal(['bread_white_toasted'])),
      ];
      await open(tester);
      await choose(tester, first: true);
      expect(find.text('São da mesma refeição?'), findsOneWidget);
      await tapText(tester, 'Refeições diferentes');
      await flush(tester);
      await tester.pumpAndSettle();

      expect(find.text('Foto 1 de 3'), findsOneWidget);
      expect(find.text('Seguinte'), findsOneWidget);
      // The second photo starts in the background while the first is reviewed.
      expect(vision.calls, 2);

      await tester.tap(find.text('Seguinte'));
      await tester.pumpAndSettle();
      expect(find.text('Foto 2 de 3'), findsOneWidget);
      expect(find.text('Adicionar 1 ao diário'), findsOneWidget);

      await tapText(tester, 'Adicionar 1 ao diário');
      await flush(tester);
      await tester.pumpAndSettle();
      expect(find.text('Foto 3 de 3'), findsOneWidget);
      expect(vision.calls, 3);
      expect(await tester.runAsync(savedNames), [db.byKey('espresso')!.namePt]);
    },
  );

  testWidgets('same meal merges two photos as two views', (tester) async {
    picker.files = [
      XFile.fromData(bytes, name: 'a.png'),
      XFile.fromData(bytes, name: 'b.png'),
    ];
    vision.viewResult = Future.value(meal(['espresso', 'bread_white_toasted']));
    await open(tester);
    await choose(tester, first: true);
    await tapText(tester, 'Mesma refeição');
    await flush(tester);
    await tester.pumpAndSettle();

    expect(vision.viewCalls, 1);
    expect(vision.calls, 0);
    expect(find.text('Foto 1 de 2'), findsNothing);
    expect(find.text('Adicionar 2 ao diário'), findsOneWidget);
  });
}

class _Picker extends ImagePicker {
  _Picker(this.bytes);
  final Uint8List bytes;
  bool cancel = false;

  /// Files returned by [pickMultiImage]; one photo by default.
  List<XFile>? files;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => cancel ? null : XFile.fromData(bytes, name: 'test.png');

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    if (cancel) return const [];
    return files ?? [XFile.fromData(bytes, name: 'test.png')];
  }
}

class _Vision implements MultiPhotoFoodVisionService {
  late Future<FoodVisionResult> result;

  /// Answers for the first, second, third... analysis when set.
  List<Future<FoodVisionResult>>? queue;
  late Future<FoodVisionResult> viewResult;
  int calls = 0;
  int viewCalls = 0;

  @override
  Future<FoodVisionResult> analyse(Uint8List imageBytes) {
    calls++;
    final list = queue;
    return list != null ? list[calls - 1] : result;
  }

  @override
  Future<FoodVisionResult> analyseViews(
    Uint8List primary,
    Uint8List secondary,
  ) {
    viewCalls++;
    return viewResult;
  }
}

/// Emits a draft once [draftGate] completes, then waits for [finalGate].
class _Staged implements StagedFoodVisionService {
  _Staged({required this.draft});

  final FoodVisionResult draft;
  final draftGate = Completer<void>();
  final finalGate = Completer<FoodVisionResult>();

  @override
  Future<FoodVisionResult> analyse(Uint8List imageBytes) =>
      analyseStaged(imageBytes);

  @override
  Future<FoodVisionResult> analyseStaged(
    Uint8List imageBytes, {
    Uint8List? secondaryImage,
    void Function(FoodVisionResult draft)? onDraft,
  }) async {
    await draftGate.future;
    onDraft?.call(draft);
    return finalGate.future;
  }
}
