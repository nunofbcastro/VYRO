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
    if (foods.isEmpty) {
      if (_photoItems(first)?.isEmpty != true) {
        throw LlmException('invalid_foods: ${_clip(first)}');
      }
      // An explicit empty answer is not a model failure. Do not ask the
      // fallback classifier to invent a meal from a non-food image.
      return FoodVisionResult(
        foods: const [],
        source: VisionSource.systemAi,
        detail: first,
      );
    }
    // Recheck the whole list, allowing the model to REMOVE hallucinations
    // and correct counts. An additive second pass can only accumulate errors.
    var detail = first;
    try {
      final second = await _ask(jpeg, buildFoodReviewPrompt(foods));
      final reviewed = _photoItems(second);
      final corrected = parseFoodPhotoAnswer(second, database);
      if (reviewed != null && (reviewed.isEmpty || corrected.isNotEmpty)) {
        foods = corrected;
      }
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
Analyse ONLY the image attached to THIS request. It is a new, independent meal. Never reuse foods or portions from earlier images, messages or meals.
List distinct foods and drinks actually visible in this photo, including the edges. Check protein, starches, legumes, vegetables, fruit, drinks and visible spreads. This checklist is not evidence: omit anything you cannot see. Do not infer hidden ingredients, oil, sugar or milk.
One row per food type, with its TOTAL count and TOTAL grams. List a drink only once per visible cup/glass; a handle, saucer, reflection or shadow is not another cup. Do not list the same coffee as both espresso and coffee with milk. If the count is uncertain use 1.
For each item give:
- "name": short food name in European Portuguese, not the name of the whole dish.
- "count": number of clearly separate edible pieces or drink containers, else 1.
- "grams": estimated TOTAL edible weight for that row, not per piece. Plate size and typical portions are uncertain; never count crockery as food.
If no food or drink is visible reply {"items":[]}.
Reply with JSON only, no markdown: $_jsonFormat''';

/// Full verification, not a union with the first answer. Only candidates
/// from the current image are passed; diary entries never enter the prompt.
String buildFoodReviewPrompt(List<DetectedFood> found) =>
    '''
${buildFoodPhotoPrompt()}
Recheck this same attached photo from scratch. The following draft is untrusted and may contain wrong foods, duplicate drinks or wrong counts:
${jsonEncode({
      'items': [
        for (final f in found) {'name': f.label, 'count': f.count ?? 1, 'grams': f.grams},
      ],
    })}
Remove every draft item not visible in THIS photo, merge repeated names for the same food, and correct counts by counting visible pieces/containers only. Add clearly visible foods omitted from the draft. Check drinks and visible spreads carefully. A single cup means count 1, even if the draft says 2.
Return the COMPLETE corrected list, not just additions. If nothing is visible return {"items":[]}.
''';

/// Distinguishes a valid empty result from a malformed answer.
List<dynamic>? _photoItems(String raw) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    final json = jsonDecode(raw.substring(start, end + 1));
    if (json is! Map || json['items'] is! List) return null;
    return json['items'] as List;
  } catch (_) {
    return null;
  }
}

/// Matches foods without summing repeated rows. Unmatched names remain
/// visible without nutrients so the user can correct them.
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
    final count = rawCount is num && rawCount.isFinite && rawCount > 0
        ? rawCount.round().clamp(1, 20)
        : null;
    final food = db.match(name);
    var grams = item['grams'] is num ? (item['grams'] as num).toDouble() : null;
    if (grams == null || !grams.isFinite || grams <= 0) {
      grams = (food?.portionG ?? 100) * (count ?? 1);
    }
    grams = grams.clamp(5, 1500).roundToDouble();
    // Rows describe totals, not instances. Repetition must not double a
    // single cup or portion. Explicit count:2 in one row remains supported.
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
