import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../../core/ai/on_device_llm.dart';
import '../data/food_database.dart';
import 'food_vision.dart';

/// Multi-food recognition with the phone's own multimodal model (Gemini
/// Nano through ML Kit GenAI / AICore). On-device; the photo is not sent
/// anywhere. Counts pieces and estimates grams — estimates the user confirms.
class SystemFoodVision implements FoodVisionService {
  SystemFoodVision(this.database, {MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('vyro/on_device_llm');

  final FoodDatabase database;
  final MethodChannel _channel;

  /// Longest image side sent to the model (keeps memory and latency low).
  static const maxSide = 768;

  @override
  Future<FoodVisionResult> analyse(Uint8List imageBytes) async {
    final jpeg = await compute(_downscale, imageBytes);
    final first = await _ask(jpeg, buildFoodPhotoPrompt());
    var foods = parseFoodPhotoAnswer(first, database);
    if (foods.isEmpty) throw LlmException('no_foods: ${_clip(first)}');
    // Small models list the obvious items and skip the rest (beans under
    // sauce, lettuce under the meat, the coffee cup): ask once more.
    var detail = first;
    try {
      final second = await _ask(jpeg, buildMissingFoodsPrompt(foods));
      foods = mergeDetectedFoods(foods, parseFoodPhotoAnswer(second, database));
      detail = '$first\n---\n$second';
    } catch (_) {
      // The second look is optional.
    }
    return FoodVisionResult(
      foods: foods,
      source: VisionSource.systemAi,
      detail: detail,
    );
  }

  /// One multimodal request, retried once (AICore can be briefly busy).
  Future<String> _ask(Uint8List jpeg, String prompt) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final raw = await _channel.invokeMethod<String>('describeImage', {
          'image': jpeg,
          'prompt': prompt,
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

const _jsonFormat = '{"items":[{"name":"...","count":1,"grams":100}]}';

/// First look: every food and drink, guided by a checklist of what small
/// models tend to miss. Names come back in Portuguese and are matched
/// against the database (names and aliases) by [parseFoodPhotoAnswer].
String buildFoodPhotoPrompt() => '''
You are a food recognition assistant for a nutrition diary. Look carefully at the whole photo, including the edges and what is under other food, and list EVERY distinct food and drink visible, separately.
Check each group: main protein (chicken, beef, pork, fish, eggs); rice, pasta, potatoes, bread or toast; beans, chickpeas or other legumes (often brown, in sauce); salad leaves such as lettuce, tomato and other vegetables; fruit; drinks in cups or glasses (coffee, milk, tea, juice); spreads and sauces (butter, jam, olive oil).
A plate with rice, beans in sauce, two grilled chicken fillets, lettuce and tomato slices is 5 items. Name only what you can see; do not name the whole dish; do not guess fruit that is not there.
For each item give:
- "name": short name in European Portuguese, e.g. Arroz branco cozido, Feijão cozido, Peito de frango grelhado, Alface, Tomate, Pão torrado, Manteiga, Café expresso, Café com leite.
- "count": number of pieces when countable (2 chicken fillets, 3 tomato slices), else 1.
- "grams": estimated edible weight. Use a 26 cm dinner plate for scale. References: chicken fillet 120 g, scoop of cooked rice 150 g, ladle of beans 120 g, lettuce leaves 30 g, tomato slice 20 g, slice of toast 30 g, butter on one toast 5 g, espresso 30 g, cup of coffee with milk 200 g.
Reply with JSON only, no markdown: $_jsonFormat''';

/// Second look: only what is missing from the first answer.
String buildMissingFoodsPrompt(List<DetectedFood> found) {
  final names = found.map((f) => f.label).join(', ');
  return '''
Look at this meal photo again. These items were already listed: $names.
Is any other food or drink clearly visible that is missing from that list? Check especially beans or sauces, salad leaves under other food, drinks in cups or glasses, and butter or other spreads on bread. Do not repeat listed items and do not invent items.
Reply with JSON only, no markdown, in the same format (name in European Portuguese, count, grams): $_jsonFormat
If nothing is missing reply {"items":[]}''';
}

/// Adds the foods of [extra] that are not already in [found].
List<DetectedFood> mergeDetectedFoods(
  List<DetectedFood> found,
  List<DetectedFood> extra,
) {
  String key(DetectedFood d) => d.food?.key ?? d.label.toLowerCase();
  final seen = {for (final d in found) key(d)};
  return [
    ...found,
    for (final d in extra)
      if (seen.add(key(d))) d,
  ];
}

/// Parses the model's JSON into foods matched against the database.
/// Unmatched names are kept (with no nutrients) so the user can fix them.
List<DetectedFood> parseFoodPhotoAnswer(String raw, FoodDatabase db) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) return const [];
  Map<String, dynamic> json;
  try {
    json = jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
  } catch (_) {
    return const [];
  }
  final items = json['items'];
  if (items is! List) return const [];
  final out = <DetectedFood>[];
  final seen = <String>{};
  for (final item in items.take(12)) {
    if (item is! Map) continue;
    final name = (item['name'] as String? ?? '').trim();
    if (name.isEmpty || name.length > 60) continue;
    final count = (item['count'] as num?)?.round().clamp(1, 20);
    final food = db.match(name);
    var grams = (item['grams'] as num?)?.toDouble();
    if (grams == null || !grams.isFinite || grams <= 0) {
      grams = (food?.portionG ?? 100) * (count ?? 1);
    }
    grams = grams.clamp(5, 1500).roundToDouble();
    // Same food listed twice (e.g. two fillets separately): merge.
    final key = food?.key ?? name.toLowerCase();
    if (!seen.add(key)) {
      final i = out.indexWhere(
        (d) => (d.food?.key ?? d.label.toLowerCase()) == key,
      );
      final prev = out[i];
      out[i] = DetectedFood(
        food: prev.food,
        label: prev.label,
        grams: prev.grams + grams,
        count: (prev.count ?? 1) + (count ?? 1),
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
        source: VisionSource.systemAi,
      ),
    );
  }
  return out;
}

/// Uses the system model when the phone has it, otherwise the offline
/// region classifier. Falls back on any system-model failure.
class FoodVisionPipeline implements FoodVisionService {
  FoodVisionPipeline({
    required this.llm,
    required this.system,
    required this.regions,
  });

  final OnDeviceLlm llm;
  final FoodVisionService system;
  final FoodVisionService regions;

  @override
  Future<FoodVisionResult> analyse(Uint8List imageBytes) async {
    if (await llm.status() == LlmStatus.available) {
      try {
        return await system.analyse(imageBytes);
      } on MissingPluginException {
        // Text-only system model (e.g. iOS): photo analysis not supported.
        return regions.analyse(imageBytes);
      } catch (error) {
        final fallback = await regions.analyse(imageBytes);
        return FoodVisionResult(
          foods: fallback.foods,
          source: fallback.source,
          dishGuess: fallback.dishGuess,
          note: 'systemFailed',
          detail: '$error',
        );
      }
    }
    return regions.analyse(imageBytes);
  }
}
