// Opt-in visual check: renders key screens at phone size to PNG files.
//
// Run with:
//   VYRO_RENDER_SCREENS=1 flutter test tool/screens/render_screens_test.dart
// Optional environment:
//   VYRO_RENDER_OUT     output folder (default: the session scratchpad)
//   VYRO_RENDER_PREFIX  file name prefix, e.g. "before" or "after"
//   FLUTTER_MATERIAL_FONTS  folder with Roboto and MaterialIcons fonts
//
// The screens use fake data and an in-memory database. Nothing is written to
// the app's real storage.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:vyro/app/app.dart';
import 'package:vyro/app/app_services.dart';
import 'package:vyro/app/l10n/strings.dart';
import 'package:vyro/app/theme/vyro_theme.dart';
import 'package:vyro/core/database/app_database.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';
import 'package:vyro/features/nutrition/food_vision/food_vision.dart';
import 'package:vyro/features/nutrition/photo_food_page.dart';
import 'package:vyro/core/ai/on_device_llm.dart';
import 'package:vyro/features/assistant/assistant_page.dart';
import 'package:vyro/features/assistant/local_intelligence_page.dart';
import 'package:vyro/features/dashboard/live_home_page.dart';
import 'package:vyro/features/nutrition/domain/food_product.dart';
import 'package:vyro/features/nutrition/nutrition_diary_page.dart';
import 'package:vyro/features/progress/body_weight_sheet.dart';
import 'package:vyro/features/progress/progress_page.dart';
import 'package:vyro/features/profile/profile_settings_page.dart';
import 'package:vyro/features/workouts/data/workout_repository.dart';
import 'package:vyro/features/workouts/domain/plan_details.dart';
import 'package:vyro/features/workouts/domain/plan_preferences.dart';
import 'package:vyro/features/workouts/plan_wizard_page.dart';
import 'package:vyro/features/workouts/training_page.dart';
import 'package:vyro/features/workouts/workout_day_page.dart';
import 'package:vyro/features/workouts/workout_session_page.dart';

/// Wizard step names in order (14 steps, review last).
const _wizardSteps = [
  'goal',
  'experience',
  'days',
  'duration',
  'location',
  'equipment',
  'limits',
  'focus',
  'exercises',
  'cardio',
  'style',
  'context',
  'block',
  'review',
];

/// Answers for the training captures: full body, three days, home kit.
const _renderPrefs = PlanPreferences(
  goal: 'muscle',
  experience: 'six24m',
  weekdays: [1, 3, 5],
  sessionMinutes: 45,
  location: 'home',
  equipment: {'bodyweight', 'dumbbells', 'bands'},
);

/// Answers that leave days with two exercises, so the preview shows warnings.
const _warningPrefs = PlanPreferences(
  goal: 'muscle',
  experience: 'six24m',
  weekdays: [1, 3, 5, 6],
  sessionMinutes: 20,
  equipment: {'bodyweight', 'bands'},
  limitAreas: {
    'wrist_elbow': 'avoid_completely',
    'knee': 'avoid_completely',
    'lower_back': 'avoid_completely',
    'shoulder': 'avoid_completely',
  },
);

/// Saves a plan for [answers] and moves the block start to [startedOn], so a
/// capture can show any week of the block.
Future<void> _seedPlan(
  AppDatabase db,
  WorkoutRepository repo, {
  required DateTime startedOn,
  PlanPreferences answers = _renderPrefs,
}) async {
  final plan = await repo.rulePlan(answers);
  await repo.savePreferences(answers);
  await repo.savePlan(
    plan,
    answers.goal,
    summary: 'Um plano de três dias, com foco em ganhar massa muscular.',
  );
  final active = await db.getActiveWorkoutPlan();
  final details = PlanDetails.decode(active!.details)!;
  final moved = PlanDetails(
    startedOn: startedOn,
    blockWeeks: details.blockWeeks,
    notes: details.notes,
    warnings: details.warnings,
    warmups: details.warmups,
    summary: details.summary,
  );
  await (db.update(db.workoutPlans)..where((row) => row.id.equals(active.id)))
      .write(WorkoutPlansCompanion(details: Value(moved.encode())));
}

final _enabled = Platform.environment['VYRO_RENDER_SCREENS'] == '1';
final _outDir =
    Platform.environment['VYRO_RENDER_OUT'] ??
    'C:/Users/Nuno/AppData/Local/Temp/claude/C--Users-Nuno-Downloads-VYRO/'
        '855c3774-28c0-465d-ad13-90f24e0faae6/scratchpad/screens';
final _prefix = Platform.environment['VYRO_RENDER_PREFIX'] ?? 'shot';
final _fontDir =
    Platform.environment['FLUTTER_MATERIAL_FONTS'] ??
    'C:/flutter/flutter/bin/cache/artifacts/material_fonts';

/// Phone size used for every capture: 412 x 915 dp at 2.625 px per dp.
const _dpr = 2.625;

/// Fake food photo: a plate on a table, generated in memory.
Uint8List _fakePhoto() {
  final image = img.Image(width: 640, height: 480);
  img.fill(image, color: img.ColorRgb8(74, 56, 40));
  img.fillCircle(
    image,
    x: 210,
    y: 250,
    radius: 150,
    color: img.ColorRgb8(236, 226, 204),
  );
  img.fillCircle(
    image,
    x: 210,
    y: 250,
    radius: 105,
    color: img.ColorRgb8(206, 150, 86),
  );
  img.fillCircle(
    image,
    x: 150,
    y: 220,
    radius: 40,
    color: img.ColorRgb8(120, 170, 78),
  );
  img.fillCircle(
    image,
    x: 260,
    y: 290,
    radius: 34,
    color: img.ColorRgb8(200, 70, 60),
  );
  img.fillRect(
    image,
    x1: 400,
    y1: 60,
    x2: 600,
    y2: 200,
    color: img.ColorRgb8(90, 110, 130),
  );
  return Uint8List.fromList(img.encodePng(image));
}

class _Picker extends ImagePicker {
  _Picker(this.bytes);
  final Uint8List bytes;
  List<XFile>? files;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => XFile.fromData(bytes, name: 'render.png');

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async => files ?? [XFile.fromData(bytes, name: 'render.png')];
}

/// Fake on-device model: always ready, answers with a fixed sentence.
class _FakeLlm implements OnDeviceLlm {
  @override
  Future<LlmStatus> status() async => LlmStatus.available;

  @override
  Future<LlmStatus> download() async => LlmStatus.available;

  @override
  Future<String> generate(String prompt) async =>
      'Hoje ainda tens margem para jantar leve.';
}

class _Vision implements MultiPhotoFoodVisionService {
  late Future<FoodVisionResult> result;

  @override
  Future<FoodVisionResult> analyse(Uint8List imageBytes) => result;

  @override
  Future<FoodVisionResult> analyseViews(
    Uint8List primary,
    Uint8List secondary,
  ) => result;
}

/// Loads the real Roboto and Material icon fonts so text is not Ahem boxes.
Future<void> _loadFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    Future<ByteData> read(String name) async {
      final bytes = await File('$_fontDir/$name').readAsBytes();
      return ByteData.view(Uint8List.fromList(bytes).buffer);
    }

    // Roboto is also registered as 'Ahem': a text style with no font family
    // (a per-widget TextStyle inside a button) falls back to Ahem in tests.
    for (final family in ['Roboto', 'Ahem']) {
      final roboto = FontLoader(family)
        ..addFont(read('roboto-light.ttf'))
        ..addFont(read('roboto-regular.ttf'))
        ..addFont(read('roboto-medium.ttf'))
        ..addFont(read('roboto-bold.ttf'));
      await roboto.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(read('materialicons-regular.otf'));
    await icons.load();
  });
}

/// Adds the Roboto family to a text style that has none.
TextStyle? _withRoboto(TextStyle? style) =>
    (style ?? const TextStyle()).copyWith(fontFamily: 'Roboto');

/// App button themes set text styles without a font family. Material then
/// replaces the ambient text style, so those labels fall back to the engine
/// default (Ahem blocks in tests). The harness gives them Roboto explicitly.
ButtonStyle? _buttonRoboto(ButtonStyle? style) => style?.copyWith(
  textStyle: WidgetStateProperty.resolveWith(
    (states) => _withRoboto(style.textStyle?.resolve(states)),
  ),
);

/// Theme with Roboto as the text family (the Android default), so captured
/// text has real glyph widths.
ThemeData _roboto(ThemeData theme) => theme.copyWith(
  textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
  primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Roboto'),
  filledButtonTheme: FilledButtonThemeData(
    style: _buttonRoboto(theme.filledButtonTheme.style),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: _buttonRoboto(theme.outlinedButtonTheme.style),
  ),
  textButtonTheme: TextButtonThemeData(
    style: _buttonRoboto(theme.textButtonTheme.style),
  ),
  chipTheme: theme.chipTheme.copyWith(
    labelStyle: _withRoboto(theme.chipTheme.labelStyle),
  ),
  navigationBarTheme: theme.navigationBarTheme.copyWith(
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) =>
          _withRoboto(theme.navigationBarTheme.labelTextStyle?.resolve(states)),
    ),
  ),
);

/// Lets real-time work finish (image decoding, file reads) and animations
/// run for a moment. Never uses pumpAndSettle: spinners animate forever.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// [raw] keeps [name] as the whole file name (used by the wizard_ captures).
Future<void> _capture(
  WidgetTester tester,
  GlobalKey key,
  String name, {
  bool unmount = true,
  bool raw = false,
}) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: _dpr);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_outDir).createSync(recursive: true);
    File(
      raw ? '$_outDir/$name.png' : '$_outDir/${_prefix}_$name.png',
    ).writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
  if (!unmount) return;
  // Unmount and drain pending timers, so the test ends cleanly.
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

/// Fake weight log: one entry every third day over the last month.
Future<void> seedWeights(AppDatabase db) async {
  const values = [78.2, 77.9, 77.6, 77.8, 77.1, 76.9, 76.5, 76.8, 76.2, 76.0];
  final today = DateTime.now();
  for (var i = 0; i < values.length; i++) {
    final day = DateTime(
      today.year,
      today.month,
      today.day - (values.length - 1 - i) * 3,
    );
    await db.saveBodyWeight(
      measuredAt: DateTime(day.year, day.month, day.day, 12),
      weightKg: values[i],
    );
  }
}

void main() {
  late AppDatabase database;
  late FoodDatabase foods;
  late Uint8List photo;
  late _Picker picker;
  late _Vision vision;

  setUpAll(() {
    if (!_enabled) return;
    foods = FoodDatabase.parse(
      File('assets/nutrition/foods.json').readAsStringSync(),
    );
    photo = _fakePhoto();
  });

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    picker = _Picker(photo);
    vision = _Vision();
  });
  tearDown(() => database.close());

  /// Pumps [page] in a phone-sized frame with the given theme, wrapped in a
  /// RepaintBoundary so the frame can be captured.
  Future<GlobalKey> pumpPhone(
    WidgetTester tester,
    Widget page, {
    required bool dark,
    double width = 412,
    double height = 915,
  }) async {
    tester.view.physicalSize = Size(width * _dpr, height * _dpr);
    tester.view.devicePixelRatio = _dpr;
    addTearDown(tester.view.reset);
    await _loadFonts(tester);
    final key = GlobalKey();
    final theme = dark ? VyroTheme.dark : VyroTheme.light;
    final services = AppServices(database: database, llm: _FakeLlm());
    final settings = AppSettings(services);
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: AppServicesScope(
          services: services,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _roboto(theme),
            locale: const Locale('pt', 'PT'),
            supportedLocales: VyroStrings.supportedLocales,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: SettingsScope(settings: settings, child: page),
          ),
        ),
      ),
    );
    return key;
  }

  FoodVisionResult review() {
    FoodRef ref(String key) => foods.byKey(key)!;
    return FoodVisionResult(
      source: VisionSource.systemAi,
      foods: [
        DetectedFood(
          food: ref('rice_white_cooked'),
          label: ref('rice_white_cooked').namePt,
          grams: 150,
          source: VisionSource.systemAi,
        ),
        DetectedFood(
          food: ref('chicken_breast_roasted'),
          label: ref('chicken_breast_roasted').namePt,
          grams: 120,
          source: VisionSource.systemAi,
          corroborated: true,
        ),
        const DetectedFood(
          label: 'Bebida',
          grams: 200,
          source: VisionSource.systemAi,
          needsChoice: true,
        ),
      ],
      suggestions: [
        DetectedFood(
          food: foods.byKey('tomato_raw'),
          label: 'tomato',
          grams: 60,
          source: VisionSource.systemAi,
        ),
        DetectedFood(
          food: foods.byKey('olive_oil'),
          label: 'olive oil',
          grams: 10,
          source: VisionSource.systemAi,
        ),
      ],
      timings: const {'total': Duration(milliseconds: 1200)},
    );
  }

  PhotoFoodPage photoPage() => PhotoFoodPage(
    day: DateTime(2026, 10, 25),
    imagePicker: picker,
    vision: vision,
  );

  for (final dark in [true, false]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('photo hero ($mode)', skip: !_enabled, (tester) async {
      final key = await pumpPhone(tester, photoPage(), dark: dark);
      await _settle(tester);
      await _capture(tester, key, 'photo_hero_$mode');
    });

    testWidgets(
      'photo review with unmatched food and suggestions ($mode)',
      skip: !_enabled,
      (tester) async {
        vision.result = Future.value(review());
        final key = await pumpPhone(tester, photoPage(), dark: dark);
        await _settle(tester);
        await tester.tap(find.text('Escolher da galeria'));
        await _settle(tester);
        await _settle(tester);
        await _capture(tester, key, 'photo_review_$mode');
      },
    );

    testWidgets('photo analysing ($mode)', skip: !_enabled, (tester) async {
      vision.result = Completer<FoodVisionResult>().future;
      final key = await pumpPhone(tester, photoPage(), dark: dark);
      await _settle(tester);
      await tester.tap(find.text('Escolher da galeria'));
      await _settle(tester);
      await _capture(tester, key, 'photo_analysing_$mode');
    });

    testWidgets('photo queue of two with review ($mode)', skip: !_enabled, (
      tester,
    ) async {
      vision.result = Future.value(review());
      picker.files = [
        XFile.fromData(photo, name: 'a.png'),
        XFile.fromData(photo, name: 'b.png'),
      ];
      final key = await pumpPhone(tester, photoPage(), dark: dark);
      await _settle(tester);
      await tester.tap(find.text('Escolher da galeria'));
      await _settle(tester);
      await _settle(tester);
      await _capture(tester, key, 'photo_queue_$mode');
    });
  }

  // ---- Other screens (fake data in an in-memory database) ----

  Future<void> seedToday(AppDatabase db) async {
    final today = dayKey(DateTime.now());
    final entries = [
      ('breakfast', 'Aveia com leite', 60.0, 370.0),
      ('lunch', 'Frango grelhado', 150.0, 165.0),
      ('lunch', 'Arroz branco cozido', 180.0, 130.0),
      ('snack', 'Iogurte natural', 125.0, 61.0),
    ];
    for (final (meal, name, grams, kcal) in entries) {
      await db.addFoodEntry(
        FoodEntriesCompanion.insert(
          day: today,
          mealType: meal,
          name: name,
          quantityGrams: grams,
          kcalPer100g: Value(kcal / grams * 100),
        ),
      );
    }
  }

  for (final dark in [true, false]) {
    final mode = dark ? 'dark' : 'light';

    for (final size in const [(412.0, 915.0), (360.0, 800.0)]) {
      final suffix = size.$1 == 360 ? '_w360' : '';

      testWidgets(
        'photo review 360 ($mode)',
        skip: !_enabled || size.$1 != 360,
        (tester) async {
          vision.result = Future.value(review());
          final key = await pumpPhone(
            tester,
            photoPage(),
            dark: dark,
            width: size.$1,
            height: size.$2,
          );
          await _settle(tester);
          await tester.tap(find.text('Escolher da galeria'));
          await _settle(tester);
          await _settle(tester);
          await _capture(tester, key, 'photo_review_${mode}$suffix');
        },
      );

      testWidgets(
        'nutrition diary ($mode, ${size.$1.toInt()})',
        skip: !_enabled,
        (tester) async {
          await tester.runAsync(() => seedToday(database));
          final key = await pumpPhone(
            tester,
            const NutritionDiaryPage(),
            dark: dark,
            width: size.$1,
            height: size.$2,
          );
          await _settle(tester);
          await _capture(tester, key, 'diary_$mode$suffix');
        },
      );

      testWidgets(
        'dashboard home ($mode, ${size.$1.toInt()})',
        skip: !_enabled,
        (tester) async {
          await tester.runAsync(() => seedToday(database));
          final key = await pumpPhone(
            tester,
            const LiveHomePage(),
            dark: dark,
            width: size.$1,
            height: size.$2,
          );
          await _settle(tester);
          await _capture(tester, key, 'home_$mode$suffix');
        },
      );

      // Collapsed header: full wordmark at the top, V mark once the title
      // sits beside it. Run with VYRO_RENDER_PREFIX=header.
      testWidgets(
        'header at top and scrolled ($mode, ${size.$1.toInt()})',
        skip: !_enabled,
        (tester) async {
          await tester.runAsync(() => seedToday(database));
          final key = await pumpPhone(
            tester,
            const LiveHomePage(),
            dark: dark,
            width: size.$1,
            height: size.$2,
          );
          await _settle(tester);
          await _capture(tester, key, 'home_top_$mode$suffix', unmount: false);
          await tester.drag(find.byType(ListView).first, const Offset(0, -500));
          await _settle(tester);
          await _capture(tester, key, 'home_scrolled_$mode$suffix');
        },
      );

      testWidgets('workout day ($mode, ${size.$1.toInt()})', skip: !_enabled, (
        tester,
      ) async {
        final repo = WorkoutRepository(database);
        final dayId = await tester.runAsync(() async {
          final plan = await repo.loadOrCreatePlan();
          return plan.days.first.day.id;
        });
        final key = await pumpPhone(
          tester,
          WorkoutDayPage(dayId: dayId!, repository: repo),
          dark: dark,
          width: size.$1,
          height: size.$2,
        );
        await _settle(tester);
        await _capture(tester, key, 'workout_day_$mode$suffix');
      });

      testWidgets(
        'workout session ($mode, ${size.$1.toInt()})',
        skip: !_enabled,
        (tester) async {
          final repo = WorkoutRepository(database);
          final (sessionId, title) = (await tester.runAsync(() async {
            final plan = await repo.loadOrCreatePlan();
            final day = plan.days.first.day;
            final id = await repo.startSession(
              dayId: day.id,
              workoutName: day.namePt,
            );
            return (id, day.namePt);
          }))!;
          final key = await pumpPhone(
            tester,
            WorkoutSessionPage(
              sessionId: sessionId,
              repository: repo,
              title: title,
            ),
            dark: dark,
            width: size.$1,
            height: size.$2,
          );
          await _settle(tester);
          await _capture(tester, key, 'workout_session_$mode$suffix');
        },
      );

      testWidgets(
        'profile settings ($mode, ${size.$1.toInt()})',
        skip: !_enabled,
        (tester) async {
          final key = await pumpPhone(
            tester,
            const ProfileSettingsPage(),
            dark: dark,
            width: size.$1,
            height: size.$2,
          );
          await _settle(tester);
          await _capture(tester, key, 'profile_settings_$mode$suffix');
        },
      );

      testWidgets(
        'local intelligence ($mode, ${size.$1.toInt()})',
        skip: !_enabled,
        (tester) async {
          final key = await pumpPhone(
            tester,
            LocalIntelligencePage(day: DateTime(2026, 10, 25)),
            dark: dark,
            width: size.$1,
            height: size.$2,
          );
          await _settle(tester);
          await _settle(tester);
          await _capture(tester, key, 'local_intelligence_$mode$suffix');
        },
      );
    }

    for (final size in const [(412.0, 915.0), (360.0, 800.0)]) {
      final suffix = size.$1 == 360 ? '_w360' : '';

      testWidgets(
        'progress weight ($mode, ${size.$1.toInt()})',
        skip: !_enabled,
        (tester) async {
          await tester.runAsync(() => seedWeights(database));
          final key = await pumpPhone(
            tester,
            const ProgressPage(),
            dark: dark,
            width: size.$1,
            height: size.$2,
          );
          await _settle(tester);
          await _capture(
            tester,
            key,
            'weight_progress_$mode$suffix',
            unmount: false,
          );
          await tester.ensureVisible(find.text('Histórico'));
          await _settle(tester);
          await _capture(tester, key, 'weight_history_$mode$suffix');
        },
      );

      testWidgets(
        'weight sheet add ($mode, ${size.$1.toInt()})',
        skip: !_enabled,
        (tester) async {
          final key = await pumpPhone(
            tester,
            const Scaffold(body: SafeArea(child: BodyWeightSheet())),
            dark: dark,
            width: size.$1,
            height: size.$2,
          );
          await _settle(tester);
          await tester.enterText(find.byType(TextField), '75,5');
          await _settle(tester);
          await _capture(tester, key, 'weight_sheet_add_$mode$suffix');
        },
      );

      testWidgets(
        'weight sheet edit ($mode, ${size.$1.toInt()})',
        skip: !_enabled,
        (tester) async {
          final key = await pumpPhone(
            tester,
            Scaffold(
              body: SafeArea(
                child: BodyWeightSheet(
                  entry: BodyMeasurement(
                    id: 1,
                    measuredAt: DateTime.now().subtract(
                      const Duration(days: 1),
                    ),
                    weightKg: 76.5,
                    note: null,
                  ),
                ),
              ),
            ),
            dark: dark,
            width: size.$1,
            height: size.$2,
          );
          await _settle(tester);
          await _capture(tester, key, 'weight_sheet_edit_$mode$suffix');
        },
      );
    }

    testWidgets('assistant chat with meal card ($mode)', skip: !_enabled, (
      tester,
    ) async {
      await tester.runAsync(() => seedToday(database));
      final key = await pumpPhone(tester, const AssistantPage(), dark: dark);
      await _settle(tester);
      await tester.enterText(find.byType(TextField).first, 'O que comi hoje?');
      await _settle(tester);
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      for (var i = 0; i < 6; i++) {
        await _settle(tester);
      }
      await _capture(tester, key, 'assistant_$mode');
    });
  }

  // Plan wizard, preview, training home and workout day, with the plan
  // details (block, warm-up, progression, rationale, warnings). Files start
  // with wizard_ and are written at 412 and 360 dp, dark and light.
  Future<void> goToReview(WidgetTester tester) async {
    for (var i = 0; i < _wizardSteps.length - 1; i++) {
      await tester.tap(find.text('Continuar'));
      await _settle(tester);
    }
  }

  for (final dark in [true, false]) {
    final mode = dark ? 'dark' : 'light';
    for (final size in const [(412.0, 915.0), (360.0, 800.0)]) {
      final dims = '${mode}_w${size.$1.toInt()}';

      testWidgets('wizard steps ($dims)', skip: !_enabled, (tester) async {
        final key = await pumpPhone(
          tester,
          const PlanWizardPage(),
          dark: dark,
          width: size.$1,
          height: size.$2,
        );
        await _settle(tester);
        for (var i = 0; i < _wizardSteps.length; i++) {
          await _settle(tester);
          final number = (i + 1).toString().padLeft(2, '0');
          await _capture(
            tester,
            key,
            'wizard_${number}_${_wizardSteps[i]}_$dims',
            unmount: false,
            raw: true,
          );
          if (i < _wizardSteps.length - 1) {
            await tester.tap(find.text('Continuar'));
            await _settle(tester);
          }
        }
      });

      testWidgets('wizard preview ($dims)', skip: !_enabled, (tester) async {
        final key = await pumpPhone(
          tester,
          const PlanWizardPage(),
          dark: dark,
          width: size.$1,
          height: size.$2,
        );
        await _settle(tester);
        await goToReview(tester);
        await tester.tap(find.text('Gerar plano'));
        await _settle(tester);
        await _capture(
          tester,
          key,
          'wizard_preview_top_$dims',
          unmount: false,
          raw: true,
        );
        await tester.drag(find.byType(ListView).first, const Offset(0, -900));
        await _settle(tester);
        await _capture(tester, key, 'wizard_preview_days_$dims', raw: true);
      });

      testWidgets('wizard preview with warnings ($dims)', skip: !_enabled, (
        tester,
      ) async {
        await tester.runAsync(
          () => WorkoutRepository(database).savePreferences(_warningPrefs),
        );
        final key = await pumpPhone(
          tester,
          const PlanWizardPage(),
          dark: dark,
          width: size.$1,
          height: size.$2,
        );
        await _settle(tester);
        await goToReview(tester);
        await tester.tap(find.text('Gerar plano'));
        await _settle(tester);
        await _capture(tester, key, 'wizard_preview_warnings_$dims', raw: true);
      });

      testWidgets('wizard training home ($dims)', skip: !_enabled, (
        tester,
      ) async {
        final repo = WorkoutRepository(database);
        await tester.runAsync(
          () => _seedPlan(database, repo, startedOn: DateTime.now()),
        );
        final key = await pumpPhone(
          tester,
          const TrainingPage(),
          dark: dark,
          width: size.$1,
          height: size.$2,
        );
        await _settle(tester);
        await _capture(
          tester,
          key,
          'wizard_training_home_$dims',
          unmount: false,
          raw: true,
        );
        await tester.ensureVisible(find.text('Sobre este plano'));
        await _settle(tester);
        await _capture(tester, key, 'wizard_training_about_$dims', raw: true);
      });

      testWidgets('wizard training home deload ($dims)', skip: !_enabled, (
        tester,
      ) async {
        final repo = WorkoutRepository(database);
        // Three weeks in: the last week of a four-week block.
        await tester.runAsync(
          () => _seedPlan(
            database,
            repo,
            startedOn: DateTime.now().subtract(const Duration(days: 21)),
          ),
        );
        final key = await pumpPhone(
          tester,
          const TrainingPage(),
          dark: dark,
          width: size.$1,
          height: size.$2,
        );
        await _settle(tester);
        await tester.ensureVisible(find.text('Sobre este plano'));
        await _settle(tester);
        await _capture(tester, key, 'wizard_training_deload_$dims', raw: true);
      });

      testWidgets('wizard workout day ($dims)', skip: !_enabled, (
        tester,
      ) async {
        final repo = WorkoutRepository(database);
        final dayId = await tester.runAsync(() async {
          await _seedPlan(database, repo, startedOn: DateTime.now());
          final plan = await repo.reloadPlan();
          return plan.days.first.day.id;
        });
        final key = await pumpPhone(
          tester,
          WorkoutDayPage(dayId: dayId!, repository: repo),
          dark: dark,
          width: size.$1,
          height: size.$2,
        );
        await _settle(tester);
        await _capture(
          tester,
          key,
          'wizard_workout_day_$dims',
          unmount: false,
          raw: true,
        );
        await tester.drag(find.byType(ListView).first, const Offset(0, -520));
        await _settle(tester);
        await _capture(
          tester,
          key,
          'wizard_workout_day_progression_$dims',
          raw: true,
        );
      });

      testWidgets('wizard workout day deload ($dims)', skip: !_enabled, (
        tester,
      ) async {
        final repo = WorkoutRepository(database);
        final dayId = await tester.runAsync(() async {
          await _seedPlan(
            database,
            repo,
            startedOn: DateTime.now().subtract(const Duration(days: 21)),
          );
          final plan = await repo.reloadPlan();
          return plan.days.first.day.id;
        });
        final key = await pumpPhone(
          tester,
          WorkoutDayPage(dayId: dayId!, repository: repo),
          dark: dark,
          width: size.$1,
          height: size.$2,
        );
        await _settle(tester);
        await _capture(
          tester,
          key,
          'wizard_workout_day_deload_$dims',
          raw: true,
        );
      });
    }
  }
}
