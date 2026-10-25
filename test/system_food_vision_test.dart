import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vyro/features/nutrition/data/food_database.dart';
import 'package:vyro/features/nutrition/food_vision/food_vision.dart';
import 'package:vyro/features/nutrition/food_vision/system_food_vision.dart';

/// Simulated model answer: one item row, as the photo prompt asks for.
Map<String, Object> row(String name, {int count = 1}) => {
  'name': name,
  'where': 'plate',
  'count': count,
  'size': 'medium',
};

String items(List<Map<String, Object>> rows) => jsonEncode({'items': rows});

/// Simulated verification answer, one verdict per draft index.
String verdicts(List<bool> visible) => jsonEncode({
  'checks': [
    for (var i = 0; i < visible.length; i++) {'i': i, 'visible': visible[i]},
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/food_vision');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final db = FoodDatabase.parse(
    File('assets/nutrition/foods.json').readAsStringSync(),
  );
  final photo = Uint8List.fromList(
    img.encodePng(img.Image(width: 8, height: 8)),
  );
  final calls = <Map<Object?, Object?>>[];
  var replies = <Object>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'describeImage');
      calls.add(call.arguments as Map<Object?, Object?>);
      final reply = replies.removeAt(0);
      if (reply is Exception) throw reply;
      return reply;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'independent photos replace the meal; verification drops a hallucination',
    () async {
      final chicken = items([row('Peito de frango grelhado', count: 2)]);
      final breakfastWithChicken = items([
        row('Peito de frango grelhado'),
        row('Pão torrado'),
        row('Manteiga'),
        row('Café expresso'),
      ]);
      replies = [
        chicken,
        verdicts([true]),
        breakfastWithChicken,
        verdicts([false, true, true, true]),
      ];
      final vision = SystemFoodVision(db, channel: channel);
      final first = await vision.analyse(photo);
      final nextPhoto = Uint8List.fromList(
        img.encodePng(
          img.Image(width: 9, height: 9)..clear(img.ColorRgb8(255, 255, 255)),
        ),
      );
      final second = await vision.analyse(nextPhoto);
      expect(first.foods.single.food?.key, 'chicken_breast_roasted');
      expect(second.foods.map((f) => f.food?.key), [
        'bread_white_toasted',
        'butter_salted',
        'espresso',
      ]);
      expect(second.foods.last.count, 1);
      expect(second.foods.last.grams, 30);
      expect(calls[2]['prompt'], calls[0]['prompt']);
      expect(calls[2]['prompt'], isNot(contains('Peito de frango')));
      expect(
        calls[2]['image'],
        isNot(orderedEquals(calls[0]['image'] as Uint8List)),
      );
      expect(calls[3]['prompt'], contains('Café expresso'));
    },
  );

  test(
    'verification that rejects every item gives a confirmed empty meal',
    () async {
      replies = [
        items([row('Café')]),
        verdicts([false]),
      ];
      final result = await SystemFoodVision(
        db,
        channel: channel,
      ).analyse(photo);
      expect(result.foods, isEmpty);
      expect(result.confirmedEmpty, isTrue);
    },
  );

  test(
    'an explicit no-food answer is valid and needs no second pass',
    () async {
      replies = ['{"items":[]}'];
      final result = await SystemFoodVision(
        db,
        channel: channel,
      ).analyse(photo);
      expect(result.foods, isEmpty);
      expect(result.confirmedEmpty, isTrue);
      expect(calls, hasLength(1));
    },
  );

  test('unparseable verification keeps the first list and says so', () async {
    replies = [
      items([row('Café')]),
      'not JSON',
    ];
    final result = await SystemFoodVision(db, channel: channel).analyse(photo);
    expect(result.foods.single.food?.key, 'espresso');
    expect(result.foods.single.grams, 30);
    expect(result.detail, contains('verify: unparsed'));
  });

  test(
    'a verdict missing for one item is unparseable, not a rejection',
    () async {
      replies = [
        items([row('Pão torrado'), row('Manteiga')]),
        // Index 1 has no verdict and a string is not a boolean: keep both.
        '{"checks":[{"i":0,"visible":true},{"i":1,"visible":"yes"}]}',
      ];
      final result = await SystemFoodVision(
        db,
        channel: channel,
      ).analyse(photo);
      expect(result.foods, hasLength(2));
      expect(result.detail, contains('verify: unparsed'));
    },
  );

  test('failed verification keeps the first usable result', () async {
    replies = [
      items([row('Café')]),
      PlatformException(code: 'bad_args'),
    ];
    final result = await SystemFoodVision(db, channel: channel).analyse(photo);
    expect(result.foods.single.food?.key, 'espresso');
    expect(result.detail, contains('verify: failed'));
  });

  test('verification carries only candidates from the current photo', () async {
    final chicken = items([row('Peito de frango grelhado')]);
    replies = [
      chicken,
      verdicts([true]),
      items([row('Café')]),
      verdicts([true]),
    ];
    final vision = SystemFoodVision(db, channel: channel);
    await vision.analyse(photo);
    await vision.analyse(photo);
    expect(calls[3]['prompt'], isNot(contains('frango')));
    expect(calls[3]['prompt'], contains('Café'));
  });

  test('invalid image never calls the model', () async {
    replies = [];
    await expectLater(
      SystemFoodVision(
        db,
        channel: channel,
      ).analyse(Uint8List.fromList(utf8.encode('bad'))),
      throwsFormatException,
    );
    expect(calls, isEmpty);
  });

  test('two angles belong to the same meal and never double counts', () async {
    replies = [
      items([row('Café')]),
      verdicts([true]),
    ];
    final result = await SystemFoodVision(
      db,
      channel: channel,
    ).analyseViews(photo, photo);
    expect(result.foods.single.count, 1);
    expect(calls.first['secondImage'], isA<Uint8List>());
    expect(calls.first['prompt'], contains('SAME meal'));
    expect(result.foods.single.grams, 30);
  });

  test(
    'a seven-food draft of two toast slices and one espresso keeps two foods',
    () async {
      replies = [
        items([
          row('Pão torrado', count: 2),
          row('Manteiga'),
          row('Café expresso'),
          row('Café com leite', count: 1),
          row('Feijão encarnado', count: 2),
          row('Alface', count: 3),
          row('Tomate', count: 3),
        ]),
        verdicts([true, false, true, false, false, false, false]),
      ];
      final result = await SystemFoodVision(
        db,
        channel: channel,
      ).analyse(photo);
      expect(result.foods.map((f) => f.food?.key), [
        'bread_white_toasted',
        'espresso',
      ]);
      expect(result.foods.first.count, 2);
      expect(result.foods.first.grams, 60);
      expect(result.foods.last.grams, 30);
      expect(result.confirmedEmpty, isFalse);
      expect(calls[1]['prompt'], contains('Feijão encarnado'));
    },
  );

  test('espresso and café com leite together keep one coffee', () async {
    replies = [
      items([row('Café expresso'), row('Café com leite')]),
      verdicts([true, true]),
      items([row('Café com leite'), row('Café expresso')]),
      verdicts([true, true]),
    ];
    final vision = SystemFoodVision(db, channel: channel);
    final espressoFirst = await vision.analyse(photo);
    final milkFirst = await vision.analyse(photo);
    expect(espressoFirst.foods.map((f) => f.food?.key), ['espresso']);
    expect(milkFirst.foods.map((f) => f.food?.key), ['coffee_with_milk']);
  });

  test('photo prompt has no category checklist and asks for a location', () {
    final prompt = buildFoodPhotoPrompt();
    expect(prompt, isNot(contains('Check protein')));
    expect(prompt, isNot(contains('visible spreads')));
    expect(prompt, isNot(contains('starches')));
    expect(prompt, contains('"where"'));
    expect(prompt, contains('ONE drink'));
    expect(prompt, contains('Fewer items is better than guessing'));
  });

  test('verify prompt never asks to add foods and omits the photo prompt', () {
    final draft = parseFoodPhotoAnswer(items([row('Pão torrado')]), db);
    final prompt = buildFoodVerifyPrompt(draft);
    expect(prompt.toLowerCase(), isNot(contains('add')));
    expect(prompt, isNot(contains('Analyse ONLY')));
    expect(prompt, contains('0: Pão torrado'));
    expect(prompt, contains('"checks"'));
  });

  test('verdicts must cover every index and be booleans', () {
    expect(parseFoodVerifyAnswer(verdicts([true, false]), 2), [true, false]);
    expect(parseFoodVerifyAnswer(verdicts([true]), 2), isNull);
    expect(parseFoodVerifyAnswer('{"items":[]}', 1), isNull);
    expect(
      parseFoodVerifyAnswer('{"checks":[{"i":0,"visible":1}]}', 1),
      isNull,
    );
  });

  test('non-unit foods ignore the model count; unit foods keep it', () {
    final foods = parseFoodPhotoAnswer(
      items([
        row('Feijão encarnado', count: 2),
        row('Alface', count: 3),
        row('Tomate', count: 3),
      ]),
      db,
    );
    final beans = foods[0];
    final lettuce = foods[1];
    final tomato = foods[2];
    expect(beans.count, 1);
    expect(beans.grams, db.byKey('beans_red_cooked')!.portionG);
    expect(lettuce.count, 1);
    expect(lettuce.grams, db.byKey('lettuce_raw')!.portionG);
    expect(tomato.count, 3);
    expect(tomato.grams, db.byKey('tomato_raw')!.portionG * 3);
  });

  test('coffee category comes from the key, else from the name', () {
    expect(
      coffeeKindOf(
        const DetectedFood(
          label: 'Galão',
          grams: 200,
          source: VisionSource.systemAi,
        ),
      ),
      CoffeeKind.withMilk,
    );
    expect(
      coffeeKindOf(
        const DetectedFood(
          label: 'Café',
          grams: 30,
          source: VisionSource.systemAi,
        ),
      ),
      CoffeeKind.espresso,
    );
    expect(
      coffeeKindOf(
        const DetectedFood(
          label: 'Sumo de laranja',
          grams: 200,
          source: VisionSource.systemAi,
        ),
      ),
      isNull,
    );
  });
}
