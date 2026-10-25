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
    final raw = await _channel.invokeMethod<String>('describeImage', {
      'image': jpeg,
      'prompt': buildFoodPhotoPrompt(database),
    });
    if (raw == null || raw.trim().isEmpty) throw const LlmException('empty');
    final foods = parseFoodPhotoAnswer(raw, database);
    if (foods.isEmpty) throw const LlmException('no_foods');
    return FoodVisionResult(foods: foods, source: VisionSource.systemAi);
  }
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

/// Prompt listing the database foods so names can be matched reliably.
String buildFoodPhotoPrompt(FoodDatabase db) {
  final names = db.foods.map((f) => f.namePt).join('; ');
  return '''
You are a food recognition assistant for a nutrition diary. Look at the photo of a meal and list EVERY distinct food visible, separately. A typical plate such as rice, beans, two grilled chicken fillets and a lettuce and tomato salad is 4 items: rice, beans, chicken (count 2) and salad. Do not name the whole dish when its components are visible.
For each item give:
- "name": the closest name from this Portuguese list when one fits: $names. Otherwise a short Portuguese name.
- "count": number of pieces when countable (e.g. 2 chicken fillets, 3 tomato slices), else 1.
- "grams": your estimate of the total edible weight of that item on the plate. Use a standard 26 cm dinner plate for scale. References: one chicken fillet 100–130 g, a scoop of cooked rice 150 g, a ladle of cooked beans 120 g, a side salad 80 g.
Reply with JSON only, no markdown:
{"items":[{"name":"Peito de frango grelhado","count":2,"grams":240},{"name":"Arroz branco cozido","count":1,"grams":150}]}''';
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
      } catch (_) {
        final fallback = await regions.analyse(imageBytes);
        return FoodVisionResult(
          foods: fallback.foods,
          source: fallback.source,
          dishGuess: fallback.dishGuess,
          note: 'systemFailed',
        );
      }
    }
    return regions.analyse(imageBytes);
  }
}
