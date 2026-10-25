import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vyro/core/ai/on_device_llm.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';
import 'package:vyro/features/nutrition/food_vision/food_vision.dart';
import 'package:vyro/features/nutrition/food_vision/system_food_vision.dart';

/// Simulated model answer: one item row, as the photo prompt asks for.
Map<String, Object> row(
  String name, {
  int count = 1,
  String where = 'centre of plate',
}) => {'name': name, 'where': where, 'count': count, 'size': 'medium'};

/// A drink the model placed in a container, as the photo prompt asks.
Map<String, Object> drink(String name, {int count = 1}) =>
    row(name, count: count, where: 'cup top-left');

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
        drink('Café expresso'),
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

  // (a) Regression (v0.6.4): verification used to empty a draft when it
  // rejected every item, and the review then showed a plain "nothing found"
  // notice. Now every item stays as uncertain and the foods are kept.
  test(
    'verification that rejects every item keeps them all as uncertain',
    () async {
      replies = [
        items([
          row('Bife de vaca frito', where: 'pan centre'),
          row('Ovo estrelado', where: 'pan'),
        ]),
        verdicts([false, false]),
      ];
      final result = await SystemFoodVision(
        db,
        channel: channel,
      ).analyse(photo);
      expect(result.foods.map((f) => f.food?.key), [
        'beef_steak_fried',
        'egg_fried',
      ]);
      expect(result.confirmedEmpty, isFalse);
      expect(
        result.detail,
        allOf(
          contains('→ kept (verify rejected all — kept as uncertain'),
          isNot(contains('→ dropped')),
        ),
      );
    },
  );

  // (b) One false among several: only that item is removed.
  test('one false among several drops only that item', () async {
    replies = [
      items([
        row('Bife de vaca frito'),
        row('Ovo estrelado'),
        row('Pão torrado'),
      ]),
      verdicts([true, false, true]),
    ];
    final result = await SystemFoodVision(db, channel: channel).analyse(photo);
    expect(result.foods.map((f) => f.food?.key), [
      'beef_steak_fried',
      'bread_white_toasted',
    ]);
    expect(result.detail, contains('→ dropped (verify=false)'));
    expect(result.detail, isNot(contains('verify rejected all')));
  });

  // (c) Empty first answer, second chance finds the steak and the egg.
  test(
    'an empty first answer gets a second chance that names the foods',
    () async {
      replies = [
        '{"items":[]}',
        items([row('Bife de vaca frito'), row('Ovo estrelado')]),
        verdicts([true, true]),
      ];
      final result = await SystemFoodVision(
        db,
        channel: channel,
      ).analyse(photo);
      expect(calls, hasLength(3));
      expect(calls[1]['prompt'], buildFoodSecondChancePrompt());
      expect(calls[1]['prompt'], contains('pan, pot, tray, box'));
      expect(result.foods.map((f) => f.food?.key), [
        'beef_steak_fried',
        'egg_fried',
      ]);
      expect(result.confirmedEmpty, isFalse);
      expect(result.detail, contains('first: empty → second chance: {"items"'));
    },
  );

  // (d) Both answers empty: only now is the photo a confirmed empty review.
  test('an empty first answer and an empty second chance confirm it', () async {
    replies = ['{"items":[]}', '{"items":[]}'];
    final result = await SystemFoodVision(db, channel: channel).analyse(photo);
    expect(result.foods, isEmpty);
    expect(result.confirmedEmpty, isTrue);
    expect(calls, hasLength(2));
    expect(
      result.detail,
      contains('first: empty → second chance: {"items":[]}'),
    );
  });

  test(
    'a second chance that is not valid JSON is not a confirmed empty',
    () async {
      replies = ['{"items":[]}', 'não sei'];
      await expectLater(
        SystemFoodVision(db, channel: channel).analyse(photo),
        throwsA(isA<LlmException>()),
      );
    },
  );

  test(
    'second chance prompt keeps the format and the regression lines out',
    () {
      final prompt = buildFoodSecondChancePrompt();
      expect(prompt, contains('"items"'));
      expect(prompt, contains('pan, pot, tray'));
      expect(prompt, contains('Do not output grams'));
      expect(prompt, isNot(contains('Fewer items')));
      expect(prompt, isNot(contains('1 to 4')));
    },
  );

  // (e) The non-food filter reads the item name, not the where text: a steak
  // "na frigideira" (in the pan) is food and reaches verification.
  test(
    'a steak whose where is in the pan is not dropped as non-food',
    () async {
      replies = [
        items([row('Bife de vaca frito', where: 'na frigideira, centro')]),
        verdicts([true]),
      ];
      final result = await SystemFoodVision(
        db,
        channel: channel,
      ).analyse(photo);
      expect(result.foods.single.food?.key, 'beef_steak_fried');
      expect(result.detail, isNot(contains('dropped non-food')));
      expect(calls[1]['prompt'], contains('0: Bife de vaca frito'));
    },
  );

  test('a non-empty first answer never triggers the second chance', () async {
    replies = [
      items([row('Bife')]),
      verdicts([true]),
    ];
    await SystemFoodVision(db, channel: channel).analyse(photo);
    expect(calls, hasLength(2));
    expect(calls[1]['prompt'], isNot(buildFoodSecondChancePrompt()));
  });

  test('unparseable verification keeps the first list and says so', () async {
    replies = [
      items([drink('Café')]),
      'not JSON',
    ];
    final result = await SystemFoodVision(db, channel: channel).analyse(photo);
    expect(result.foods.single.food?.key, 'espresso');
    expect(result.foods.single.grams, 30);
    expect(result.detail, contains('verify: unparsed'));
  });

  // Regression: an omitted or non-boolean verdict used to send the item to
  // suggestions (v0.6.3), which removed true positives. Now it stays in the
  // main list, marked uncertain ("Hipótese a confirmar" in the review).
  test('a verdict missing for one item keeps that item as uncertain', () async {
    replies = [
      items([row('Pão torrado'), row('Manteiga')]),
      // Index 1 has no boolean verdict: kept, uncertain, counted.
      '{"checks":[{"i":0,"visible":true},{"i":1,"visible":"yes"}]}',
    ];
    final result = await SystemFoodVision(db, channel: channel).analyse(photo);
    expect(result.foods.map((f) => f.food?.key), [
      'bread_white_toasted',
      'butter_salted',
    ]);
    expect(result.suggestions, isEmpty);
    expect(result.detail, contains('verify: incomplete'));
    expect(
      result.detail,
      contains('Manteiga → kept (verify omitted, uncertain'),
    );
  });

  test('an explicit visible:false still drops the item', () async {
    replies = [
      items([row('Pão torrado'), row('Queijo da serra')]),
      verdicts([true, false]),
    ];
    final result = await SystemFoodVision(db, channel: channel).analyse(photo);
    expect(result.foods.map((f) => f.food?.key), ['bread_white_toasted']);
    expect(result.detail, contains('→ dropped (verify=false)'));
  });

  test(
    'a burger and a beer with no where fields both stay in the list',
    () async {
      replies = [
        '{"items":['
            '{"name":"Hambúrguer","count":1,"size":"medium"},'
            '{"name":"Cerveja","count":1,"size":"medium"}'
            ']}',
        verdicts([true, true]),
      ];
      final result = await SystemFoodVision(
        db,
        channel: channel,
      ).analyse(photo);
      expect(result.foods, hasLength(2));
      expect(result.suggestions, isEmpty);
      expect(result.foods.map((f) => f.food?.key), contains('beer'));
      expect(result.detail, contains('Cerveja → kept (verify=true, no where'));
    },
  );

  test(
    'a beer whose where is prose ("on the table, right") stays in the list',
    () async {
      replies = [
        items([row('Cerveja', where: 'on the table, right')]),
        verdicts([true]),
      ];
      final result = await SystemFoodVision(
        db,
        channel: channel,
      ).analyse(photo);
      expect(result.foods.single.food?.key, 'beer');
      expect(result.suggestions, isEmpty);
    },
  );

  test('a beer with an empty verdict list is kept as uncertain', () async {
    replies = [
      items([row('Cerveja', where: 'on the table, right')]),
      '{"checks":[]}',
    ];
    final result = await SystemFoodVision(db, channel: channel).analyse(photo);
    expect(result.foods.single.food?.key, 'beer');
    expect(result.detail, contains('verify: incomplete'));
  });

  test('failed verification keeps the first usable result', () async {
    replies = [
      items([drink('Café')]),
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
      items([drink('Café')]),
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
      items([drink('Café')]),
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
          drink('Café expresso'),
          drink('Café com leite', count: 1),
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
      items([drink('Café expresso'), drink('Café com leite')]),
      verdicts([true, true]),
      items([drink('Café com leite'), drink('Café expresso')]),
      verdicts([true, true]),
    ];
    final vision = SystemFoodVision(db, channel: channel);
    final espressoFirst = await vision.analyse(photo);
    final milkFirst = await vision.analyse(photo);
    expect(espressoFirst.foods.map((f) => f.food?.key), ['espresso']);
    expect(milkFirst.foods.map((f) => f.food?.key), ['coffee_with_milk']);
    // The other coffee is a suggestion (outside totals), never silently lost.
    expect(espressoFirst.suggestions.map((f) => f.food?.key), [
      'coffee_with_milk',
    ]);
    expect(espressoFirst.detail, contains('→ suggestion (duplicate coffee)'));
  });

  test('photo prompt has no category checklist and asks for a location', () {
    final prompt = buildFoodPhotoPrompt();
    expect(prompt, isNot(contains('Check protein')));
    expect(prompt, isNot(contains('visible spreads')));
    expect(prompt, isNot(contains('starches')));
    expect(prompt, contains('"where"'));
    expect(prompt, contains('ONE drink'));
    expect(prompt, contains('every drink in a glass, cup, bottle or can'));
    expect(prompt, contains('Never list the same coffee twice'));
    expect(prompt, contains('pan, pot, tray, box, packaging or hand'));
    expect(prompt, contains('still list the food, not the container'));
    // Regression: these lines made the small model drop true positives.
    expect(prompt, isNot(contains('Fewer items')));
    expect(prompt, isNot(contains('1 to 4')));
    expect(
      prompt,
      isNot(contains('"where": short location in the photo, required')),
    );
  });

  test('verify prompt treats partly visible items as visible', () {
    final prompt = buildFoodVerifyPrompt(
      parseFoodPhotoAnswer(items([row('Cerveja')]), db),
    );
    expect(prompt, contains('even partly, small or at the edge'));
    expect(prompt, contains('only if you are confident it is NOT'));
    expect(prompt, isNot(contains('when you cannot clearly see it')));
  });

  test('verify prompt never asks to add foods and omits the photo prompt', () {
    final draft = parseFoodPhotoAnswer(items([row('Pão torrado')]), db);
    final prompt = buildFoodVerifyPrompt(draft);
    expect(prompt.toLowerCase(), isNot(contains('add')));
    expect(prompt, isNot(contains('Analyse ONLY')));
    expect(prompt, contains('0: Pão torrado'));
    expect(prompt, contains('"checks"'));
  });

  test('verdicts are per index; omitted or non-boolean ones are null', () {
    expect(parseFoodVerifyAnswer(verdicts([true, false]), 2), [true, false]);
    expect(parseFoodVerifyAnswer(verdicts([true]), 2), [true, null]);
    expect(parseFoodVerifyAnswer('{"items":[]}', 1), isNull);
    expect(parseFoodVerifyAnswer('not JSON', 1), isNull);
    expect(parseFoodVerifyAnswer('{"checks":[{"i":0,"visible":1}]}', 1), [
      null,
    ]);
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

  // ------------------------------------------------------------ trust rules

  test(
    'croissant case: towel and napkin dropped, generic names flagged',
    () async {
      replies = [
        items([
          row('Sanduíche', where: 'centre of plate'),
          drink('Bebida'),
          row('Toalha', where: 'under the plate'),
          row('Guardanapo', where: 'left edge'),
        ]),
        verdicts([true, true]),
      ];
      final result = await SystemFoodVision(
        db,
        channel: channel,
      ).analyse(photo);
      expect(result.foods.map((f) => f.label), ['Sanduíche', 'Bebida']);
      expect(result.foods.every((f) => f.needsChoice), isTrue);
      expect(result.foods.every((f) => f.food == null), isTrue);
      expect(result.suggestions, isEmpty);
      expect(result.confirmedEmpty, isFalse);
      expect(result.detail, contains('dropped non-food: Toalha, Guardanapo'));
      expect(result.detail, contains('generic: Sanduíche, Bebida'));
      // Non-food items never reach the verification prompt.
      expect(calls[1]['prompt'], isNot(contains('Toalha')));
      expect(calls[1]['prompt'], contains('0: Sanduíche'));
    },
  );

  // Regression (v0.6.3): a beer whose "where" did not name a container, or
  // was missing, went to suggestions. Drinks are now treated like food.
  test('pasta case: a beer in the top right stays in the main list', () async {
    replies = [
      items([
        row('Massa cozida', where: 'centre of plate'),
        row('Cerveja', where: 'top right'),
        drink('Café expresso'),
        row('Fiambre', where: 'beside the pasta'),
      ]),
      verdicts([true, true, true, true]),
    ];
    final result = await SystemFoodVision(db, channel: channel).analyse(photo);
    expect(result.foods.map((f) => f.label), contains('Cerveja'));
    expect(result.suggestions, isEmpty);
    expect(result.foods.map((f) => f.food?.key), contains('espresso'));
    expect(
      result.detail,
      contains(
        'Cerveja → kept (verify=true, where "top right", drink, no container in where)',
      ),
    );
  });

  test('a drink without container words stays in the main list', () async {
    replies = [
      items([row('Sumo de laranja', where: 'on the table')]),
      verdicts([true]),
    ];
    final result = await SystemFoodVision(db, channel: channel).analyse(photo);
    expect(result.foods.single.label, contains('Sumo'));
    expect(result.suggestions, isEmpty);
    expect(result.confirmedEmpty, isFalse);
  });

  test(
    'an item without a where stays in the main list, not suggestions',
    () async {
      replies = [
        items([
          row('Pão torrado', where: ''),
          row('Manteiga', where: 'on the bread'),
        ]),
        verdicts([true, true]),
      ];
      final result = await SystemFoodVision(
        db,
        channel: channel,
      ).analyse(photo);
      expect(result.foods.map((f) => f.food?.key), [
        'bread_white_toasted',
        'butter_salted',
      ]);
      expect(result.suggestions, isEmpty);
      expect(
        result.detail,
        contains('Pão torrado → kept (verify=true, no where'),
      );
    },
  );

  test('unparsed verification keeps every item, drinks included', () async {
    replies = [
      items([
        row('Pão torrado'),
        drink('Café expresso', count: 1)..['where'] = 'counter',
      ]),
      'not JSON',
    ];
    final result = await SystemFoodVision(db, channel: channel).analyse(photo);
    expect(result.detail, contains('verify: unparsed'));
    expect(result.foods.map((f) => f.food?.key), [
      'bread_white_toasted',
      'espresso',
    ]);
    expect(result.suggestions, isEmpty);
    expect(
      result.detail,
      contains('Café expresso (bica) → kept (verify unparsed'),
    );
  });

  test('only non-food items is not a confirmed empty meal', () async {
    replies = [
      items([row('Toalha'), row('Mesa', where: 'bottom')]),
    ];
    final result = await SystemFoodVision(db, channel: channel).analyse(photo);
    expect(result.foods, isEmpty);
    expect(result.confirmedEmpty, isFalse);
    expect(calls, hasLength(1));
    expect(result.detail, contains('dropped non-food: Toalha, Mesa'));
  });
}
