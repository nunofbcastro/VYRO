import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../../core/ai/on_device_llm.dart';
import '../data/food_database.dart';
import 'food_vision.dart';
import 'photo_quality.dart';
import 'portion_estimate.dart';

/// Multi-food recognition with the phone's own multimodal model (Gemini
/// Nano through ML Kit GenAI / AICore). On-device; the photo is not sent
/// anywhere. Counts pieces; grams come from the offline typical portion.
class SystemFoodVision implements MultiPhotoFoodVisionService {
  SystemFoodVision(this.database, {MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('vyro/on_device_llm');

  final FoodDatabase database;
  final MethodChannel _channel;

  /// Longest image side sent to the model (keeps memory and latency low).
  static const maxSide = 768;

  @override
  Future<FoodVisionResult> analyse(Uint8List imageBytes) =>
      _analyse(imageBytes, null);

  @override
  Future<FoodVisionResult> analyseViews(
    Uint8List primary,
    Uint8List secondary,
  ) => _analyse(primary, secondary);

  Future<FoodVisionResult> _analyse(
    Uint8List imageBytes,
    Uint8List? secondBytes,
  ) async {
    final jpeg = await compute(_downscale, imageBytes);
    final secondPhoto = secondBytes == null
        ? null
        : await compute(_downscale, secondBytes);
    final first = await _ask(
      jpeg,
      buildFoodPhotoPrompt(),
      secondPhoto: secondPhoto,
    );
    final draft = parseFoodPhotoAnswer(first, database);
    if (draft.isEmpty) {
      if (_photoItems(first)?.isEmpty != true) {
        throw LlmException('invalid_foods: ${_clip(first)}');
      }
      return FoodVisionResult(
        foods: const [],
        source: VisionSource.systemAi,
        detail: first,
        confirmedEmpty: true,
      );
    }
    // Verification only removes draft items; it never adds foods. If its
    // answer is missing or incomplete, the draft is kept unchanged.
    var foods = draft;
    var detail = first;
    try {
      final verify = await _ask(
        jpeg,
        buildFoodVerifyPrompt(draft),
        secondPhoto: secondPhoto,
      );
      final verdicts = parseFoodVerifyAnswer(verify, draft.length);
      if (verdicts == null) {
        detail = '$first\n---\nverify: unparsed\n$verify';
      } else {
        foods = [
          for (var i = 0; i < draft.length; i++)
            if (verdicts[i]) draft[i],
        ];
        detail = '$first\n---\n$verify';
      }
    } catch (error) {
      detail = '$first\n---\nverify: failed ($error)';
    }
    final sane = applyDrinkSanity(foods);
    if (sane.length != foods.length) {
      detail = '$detail\nsanity: one coffee kept';
    }
    foods = sane;
    return FoodVisionResult(
      foods: foods,
      source: VisionSource.systemAi,
      detail: detail,
      confirmedEmpty: foods.isEmpty,
    );
  }

  /// One multimodal request, retried once (AICore can be briefly busy).
  Future<String> _ask(
    Uint8List jpeg,
    String prompt, {
    Uint8List? secondPhoto,
  }) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final raw = await _channel.invokeMethod<String>('describeImage', {
          'image': jpeg,
          'prompt': secondPhoto == null
              ? prompt
              : '$prompt\nBoth images show the SAME meal from two angles. Reconcile identities; never sum counts from the two views. Do not claim measured weight.',
          if (secondPhoto != null) 'secondImage': secondPhoto,
        });
        if (raw == null || raw.trim().isEmpty) {
          throw const LlmException('empty');
        }
        return raw;
      } on PlatformException catch (e) {
        if (attempt >= 1 || e.code == 'bad_args') {
          throw LlmException('${e.code}: ${e.message ?? ''}');
        }
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
    }
  }

  static String _clip(String text) =>
      text.length <= 200 ? text : '${text.substring(0, 200)}…';
}

Uint8List _downscale(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('invalid_image');
  var image = img.bakeOrientation(decoded);
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > SystemFoodVision.maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: SystemFoodVision.maxSide)
        : img.copyResize(image, height: SystemFoodVision.maxSide);
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 85));
}

const _jsonFormat =
    '{"items":[{"name":"...","where":"...","count":1,"size":"medium"}]}';

/// First look: what is visible, where it is, and relative size. Grams are
/// applied later from the offline database so the small model is not asked
/// to weigh food. No category checklist: it made the model fill every slot.
String buildFoodPhotoPrompt() => '''
Analyse ONLY the image attached to THIS request. It is a new, independent meal. Never reuse foods from earlier images, messages or meals.
List only the foods and drinks you can point to in this photo. Fewer items is better than guessing. A typical photo has 1 to 4 items. Never add side dishes, salads, vegetables, legumes, spreads or garnishes that are not clearly visible. Do not infer hidden ingredients, oil, sugar or milk.
One row per food type, with its TOTAL count. A single cup or glass is ONE drink, even with a saucer, handle or shadow. Never list the same coffee twice.
For each item give:
- "name": short food name in European Portuguese.
- "where": short location in the photo, required, e.g. "centre of plate" or "cup top-left".
- "count": number of clearly separate pieces or containers, else 1.
- "size": small, medium or large compared with a typical single serving. Do not output grams.
If no food or drink is visible reply {"items":[]}.
Reply with JSON only, no markdown: $_jsonFormat''';

/// Verification: yes/no per draft item. It must not add or rename foods.
String buildFoodVerifyPrompt(List<DetectedFood> draft) {
  final items = [
    for (var i = 0; i < draft.length; i++) '$i: ${draft[i].label}',
  ].join('\n');
  return '''
Look ONLY at the attached photo (any attached view of it). Check each numbered item below and answer whether that food or drink is clearly visible in THIS photo.
Use "visible": false when you cannot clearly see it, when it is only a guess, or when it is not in the photo. Use "visible": true only for what you can clearly see. Do not name any other food and do not rename items.
$items
Reply with JSON only, no markdown, one entry per item: {"checks":[{"i":0,"visible":true}]}''';
}

Map<String, dynamic>? _jsonObject(String raw) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    final json = jsonDecode(raw.substring(start, end + 1));
    return json is Map<String, dynamic> ? json : null;
  } catch (_) {
    return null;
  }
}

List<dynamic>? _photoItems(String raw) {
  final items = _jsonObject(raw)?['items'];
  return items is List ? items : null;
}

/// One verdict per draft index, or null unless every index has a boolean
/// verdict. A partial answer is treated as unparseable, so the draft stays.
List<bool>? parseFoodVerifyAnswer(String raw, int draftCount) {
  final checks = _jsonObject(raw)?['checks'];
  if (checks is! List) return null;
  final verdicts = List<bool?>.filled(draftCount, null);
  for (final check in checks) {
    if (check is! Map) continue;
    final i = check['i'];
    final visible = check['visible'];
    if (i is! int || visible is! bool) continue;
    if (i < 0 || i >= draftCount) continue;
    verdicts[i] = visible;
  }
  if (verdicts.any((v) => v == null)) return null;
  return [for (final v in verdicts) v!];
}

enum CoffeeKind { espresso, withMilk }

const _milkCoffeeWords = [
  'com leite',
  'galão',
  'galao',
  'meia de leite',
  'meia-de-leite',
  'cappuccino',
  'latte',
];
const _espressoWords = ['café', 'cafe', 'expresso', 'espresso', 'bica'];

/// Coffee category from the database key when matched, else from the name.
/// Milk words are checked first because "Café com leite" also says café.
CoffeeKind? coffeeKindOf(DetectedFood food) {
  final key = food.food?.key;
  if (key != null) {
    return switch (key) {
      'espresso' => CoffeeKind.espresso,
      'coffee_with_milk' => CoffeeKind.withMilk,
      _ => null,
    };
  }
  final text = food.label.toLowerCase();
  if (_milkCoffeeWords.any(text.contains)) return CoffeeKind.withMilk;
  if (_espressoWords.any(text.contains)) return CoffeeKind.espresso;
  return null;
}

/// One cup, one drink: when an espresso-type and a milk-type coffee are both
/// listed, only the first coffee listed by the model is kept. Pure function.
List<DetectedFood> applyDrinkSanity(List<DetectedFood> foods) {
  final coffees = [
    for (final f in foods)
      if (coffeeKindOf(f) != null) f,
  ];
  if (coffees.length < 2) return foods;
  final firstKind = coffeeKindOf(coffees.first);
  final mixed = coffees.any((f) => coffeeKindOf(f) != firstKind);
  if (!mixed) return foods;
  final keep = coffees.first;
  return [
    for (final f in foods)
      if (coffeeKindOf(f) == null || identical(f, keep)) f,
  ];
}

/// Matches foods without summing repeated rows. Grams come from typical
/// portions in the offline database. Unmatched names remain visible.
List<DetectedFood> parseFoodPhotoAnswer(String raw, FoodDatabase db) {
  final items = _photoItems(raw);
  if (items == null) return const [];
  final out = <DetectedFood>[];
  final seen = <String>{};
  for (final item in items.take(12)) {
    if (item is! Map) continue;
    if (item['name'] is! String) continue;
    final name = (item['name'] as String).trim();
    if (name.isEmpty || name.length > 60) continue;
    final rawCount = item['count'];
    final modelCount = rawCount is num && rawCount.isFinite && rawCount > 0
        ? rawCount.round().clamp(1, 20)
        : null;
    final size = PortionSize.parse(item['size']);
    final food = db.match(name);
    // Only foods with a per-unit portion can be counted. For beans, lettuce,
    // rice or sauces a "2 unid." from the model must not double anything.
    final count = food != null && food.portionUnits == null ? 1 : modelCount;
    final fallback = item['grams'] is num
        ? (item['grams'] as num).toDouble()
        : null;
    final grams = estimatedGrams(
      food: food,
      count: count ?? 1,
      size: size,
      fallbackGrams: food == null ? fallback : null,
    );
    final key = food?.key ?? name.toLowerCase();
    if (!seen.add(key)) {
      final i = out.indexWhere(
        (d) => (d.food?.key ?? d.label.toLowerCase()) == key,
      );
      final prev = out[i];
      out[i] = DetectedFood(
        food: prev.food,
        label: prev.label,
        grams: prev.grams > grams ? prev.grams : grams,
        count: prev.count == null && count == null
            ? null
            : (prev.count ?? 1) > (count ?? 1)
            ? prev.count
            : count,
        size: (prev.size?.factor ?? 1) >= size.factor ? prev.size : size,
        source: VisionSource.systemAi,
      );
      continue;
    }
    out.add(
      DetectedFood(
        food: food,
        label: food?.namePt ?? name,
        grams: grams,
        count: count,
        size: size,
        source: VisionSource.systemAi,
      ),
    );
  }
  return out;
}

/// System model when the phone has it, always combined with the offline
/// region classifier. Falls back to regions alone on failure or iOS.
class FoodVisionPipeline implements MultiPhotoFoodVisionService {
  FoodVisionPipeline({
    required this.llm,
    required this.system,
    required this.regions,
  });

  final OnDeviceLlm llm;
  final FoodVisionService system;
  final FoodVisionService regions;

  @override
  Future<FoodVisionResult> analyse(Uint8List imageBytes) =>
      _analyse(imageBytes, null);

  @override
  Future<FoodVisionResult> analyseViews(
    Uint8List primary,
    Uint8List secondary,
  ) => _analyse(primary, secondary);

  Future<FoodVisionResult> _analyse(
    Uint8List imageBytes,
    Uint8List? secondaryImage,
  ) async {
    final quality = await compute(assessPhotoBytes, imageBytes);
    // Attach handlers immediately: a fast offline failure must never escape.
    Future<({FoodVisionResult? value, Object? error})> capture(
      Future<FoodVisionResult> Function() action,
    ) async {
      try {
        return (value: await action(), error: null);
      } catch (error) {
        return (value: null, error: error);
      }
    }

    final offline = capture(() async {
      final first = await regions.analyse(imageBytes);
      if (secondaryImage == null) return first;
      try {
        final second = await regions.analyse(secondaryImage);
        return fuseVisionResults(first, second).withNote('secondViewOffline');
      } catch (_) {
        return first;
      }
    });
    final status = await llm.status();
    if (status == LlmStatus.available) {
      final primary = await capture(
        () => secondaryImage != null && system is MultiPhotoFoodVisionService
            ? (system as MultiPhotoFoodVisionService).analyseViews(
                imageBytes,
                secondaryImage,
              )
            : system.analyse(imageBytes),
      );
      final secondary = await offline;
      if (primary.value != null) {
        final result = primary.value!;
        if (result.confirmedEmpty || secondary.value == null) {
          return _withQuality(result, quality);
        }
        return fuseVisionResults(
          result,
          secondary.value!,
          qualityNote: quality.note,
        );
      }
      if (secondary.value != null) {
        final result = secondary.value!;
        return _withQuality(
          result.withNote(
            primary.error is MissingPluginException
                ? result.note
                : 'systemFailed',
            detail: '${primary.error}',
          ),
          quality,
        );
      }
      throw LlmException('vision_failed: ${primary.error}; ${secondary.error}');
    }
    final secondary = await offline;
    if (secondary.value == null)
      throw LlmException('vision_failed: ${secondary.error}');
    return _withQuality(secondary.value!, quality);
  }
}

FoodVisionResult _withQuality(FoodVisionResult result, PhotoQuality quality) {
  if (quality.note == null) return result;
  return result.withNote(
    [if (result.note != null) result.note!, quality.note!].join(','),
  );
}
