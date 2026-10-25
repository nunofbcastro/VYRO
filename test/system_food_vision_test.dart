import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vyro/features/nutrition/data/food_database.dart';
import 'package:vyro/features/nutrition/food_vision/system_food_vision.dart';

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
    'independent photos replace the meal and review corrects one coffee',
    () async {
      const chicken =
          '{"items":[{"name":"Peito de frango grelhado","count":2,"grams":240}]}';
      const wrongBreakfast =
          '{"items":[{"name":"Peito de frango grelhado","grams":240},'
          '{"name":"Pão torrado","grams":60},{"name":"Manteiga","grams":10},'
          '{"name":"Café expresso","count":2,"grams":60}]}';
      const breakfast =
          '{"items":[{"name":"Pão torrado","grams":60},'
          '{"name":"Manteiga","grams":10},{"name":"Café expresso","count":1,"grams":30}]}';
      replies = [chicken, chicken, wrongBreakfast, breakfast];
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
      final draft = (calls[3]['prompt'] as String).split('untrusted').last;
      expect(draft, contains('Café'));
    },
  );

  test('verification may remove every hallucinated food', () async {
    replies = ['{"items":[{"name":"Café","grams":30}]}', '{"items":[]}'];
    final result = await SystemFoodVision(db, channel: channel).analyse(photo);
    expect(result.foods, isEmpty);
  });

  test(
    'an explicit no-food answer is valid and needs no second pass',
    () async {
      replies = ['{"items":[]}'];
      final result = await SystemFoodVision(
        db,
        channel: channel,
      ).analyse(photo);
      expect(result.foods, isEmpty);
      expect(calls, hasLength(1));
    },
  );

  test('malformed verification preserves the first usable result', () async {
    replies = ['{"items":[{"name":"Café","grams":30}]}', 'not JSON'];
    final result = await SystemFoodVision(db, channel: channel).analyse(photo);
    expect(result.foods.single.food?.key, 'espresso');
    expect(result.foods.single.grams, 30);
  });

  test('failed verification preserves the first usable result', () async {
    replies = [
      '{"items":[{"name":"Café","grams":30}]}',
      PlatformException(code: 'bad_args'),
    ];
    final result = await SystemFoodVision(db, channel: channel).analyse(photo);
    expect(result.foods.single.food?.key, 'espresso');
  });

  test('review carries only candidates from the current photo', () async {
    const chicken =
        '{"items":[{"name":"Peito de frango grelhado","grams":120}]}';
    const coffee = '{"items":[{"name":"Café","grams":30}]}';
    replies = [chicken, chicken, coffee, coffee];
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
      '{"items":[{"name":"Café","count":1}]}',
      '{"items":[{"name":"Café","count":1}]}',
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
}
