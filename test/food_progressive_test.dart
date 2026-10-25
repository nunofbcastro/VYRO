import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vyro/core/ai/on_device_llm.dart';
import 'package:vyro/features/nutrition/data/food_database.dart';
import 'package:vyro/features/nutrition/food_vision/food_vision.dart';
import 'package:vyro/features/nutrition/food_vision/system_food_vision.dart';

String _items(List<Map<String, Object>> rows) => jsonEncode({'items': rows});

Map<String, Object> _row(String name) => {
  'name': name,
  'where': 'centro do prato',
  'count': 1,
  'size': 'medium',
};

String _verdicts(List<bool> visible) => jsonEncode({
  'checks': [
    for (var i = 0; i < visible.length; i++) {'i': i, 'visible': visible[i]},
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/food_progressive');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final db = FoodDatabase.parse(
    File('assets/nutrition/foods.json').readAsStringSync(),
  );
  final photo = Uint8List.fromList(
    img.encodePng(img.Image(width: 64, height: 64)),
  );
  var replies = <String>[];

  setUp(() {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'describeImage');
      return replies.removeAt(0);
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  FoodVisionPipeline pipeline() => FoodVisionPipeline(
    llm: const _Llm(LlmStatus.available),
    system: SystemFoodVision(db, channel: channel),
    regions: const _Offline(),
  );

  test(
    'draft arrives first, then the final result with the same items',
    () async {
      replies = [
        _items([_row('Ovos'), _row('Pão torrado')]),
        _verdicts([true, true]),
      ];
      final events = await pipeline().analyseProgressive(photo).toList();
      expect(events, hasLength(2));
      final draft = events[0];
      final final_ = events[1];
      expect(draft.stage, VisionStage.draft);
      expect(final_.stage, VisionStage.final_);
      expect(draft.foods.every((f) => f.pending), isTrue);
      expect(final_.foods.any((f) => f.pending), isFalse);
      expect(
        [for (final f in final_.foods) f.label],
        [for (final f in draft.foods) f.label],
      );
      expect(final_.foods.first.food?.key, startsWith('egg_'));
    },
  );

  test(
    'a verification that removes an item shows it in the draft only',
    () async {
      replies = [
        _items([_row('Cerveja'), _row('Pão torrado')]),
        _verdicts([false, true]),
      ];
      final events = await pipeline().analyseProgressive(photo).toList();
      expect(events, hasLength(2));
      expect(events[0].foods, hasLength(2));
      expect(events[1].foods, hasLength(1));
      expect(events[1].foods.single.label, events[0].foods[1].label);
      expect(events[1].stage, VisionStage.final_);
    },
  );

  test(
    'analyse returns the same final result as the last stream event',
    () async {
      replies = [
        _items([_row('Cerveja')]),
        _verdicts([true]),
      ];
      final streamed = await pipeline().analyseProgressive(photo).toList();
      replies = [
        _items([_row('Cerveja')]),
        _verdicts([true]),
      ];
      final plain = await pipeline().analyse(photo);
      expect(plain.stage, VisionStage.final_);
      expect(
        [for (final f in plain.foods) f.label],
        [for (final f in streamed.last.foods) f.label],
      );
      expect(plain.timings.keys, containsAll(['first', 'verify']));
    },
  );

  test('detail carries a timing line with each stage', () async {
    replies = [
      _items([_row('Ovos')]),
      _verdicts([true]),
    ];
    final final_ = await pipeline().analyse(photo);
    final line = RegExp(r'timing: [^\n]+').firstMatch(final_.detail ?? '');
    expect(line, isNotNull);
    expect(line!.group(0), contains('first '));
    expect(line.group(0), contains('verify '));
    expect(line.group(0), contains('regions '));
    expect(line.group(0), matches(r'\d+\.\d s'));
  });

  test(
    'without the system model the stream emits only the final result',
    () async {
      final events = await FoodVisionPipeline(
        llm: const _Llm(LlmStatus.unavailable),
        system: SystemFoodVision(db, channel: channel),
        regions: const _Offline(),
      ).analyseProgressive(photo).toList();
      expect(events, hasLength(1));
      expect(events.single.stage, VisionStage.final_);
    },
  );

  test('steak gets sauce suggestions that are not in the totals', () async {
    replies = [
      _items([_row('Bife de vaca grelhado')]),
      _verdicts([true]),
    ];
    final final_ = await SystemFoodVision(db, channel: channel).analyse(photo);
    expect(final_.foods.single.food?.key, startsWith('beef_'));
    final suggested = [for (final s in final_.suggestions) s.food?.key];
    expect(suggested, containsAll(['brown_gravy', 'cooking_cream']));
    expect([
      for (final f in final_.foods) f.food?.key,
    ], isNot(containsAll(['brown_gravy', 'cooking_cream'])));
  });
}

class _Llm implements OnDeviceLlm {
  const _Llm(this._status);
  final LlmStatus _status;

  @override
  Future<LlmStatus> status() async => _status;

  @override
  Future<LlmStatus> download() async => _status;

  @override
  Future<String> generate(String prompt) async => '';
}

/// Offline classifier stand-in: one item, so the final result has regions
/// timing and a suggestion can be merged.
class _Offline implements FoodVisionService {
  const _Offline();

  @override
  Future<FoodVisionResult> analyse(Uint8List imageBytes) async =>
      const FoodVisionResult(foods: [], source: VisionSource.regionClassifier);
}
