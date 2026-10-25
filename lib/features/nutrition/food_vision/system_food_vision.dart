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
    var foods = parseFoodPhotoAnswer(first, database);
    if (foods.isEmpty) {
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
    var detail = first;
    try {
      final second = await _ask(
        jpeg,
        buildFoodReviewPrompt(foods),
        secondPhoto: secondPhoto,
      );
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

const _jsonFormat = '{"items":[{"name":"...","count":1,"size":"medium"}]}';

/// First look: identity and relative size. Grams are applied later from
/// the offline database so the small model is not asked to weigh food.
String buildFoodPhotoPrompt() => '''
Analyse ONLY the image attached to THIS request. It is a new, independent meal. Never reuse foods or portions from earlier images, messages or meals.
List distinct foods and drinks actually visible in this photo, including the edges. Check protein, starches, legumes, vegetables, fruit, drinks and visible spreads. This checklist is not evidence: omit anything you cannot see. Do not infer hidden ingredients, oil, sugar or milk.
One row per food type, with its TOTAL count. List a drink only once per visible cup/glass; a handle, saucer, reflection or shadow is not another cup. Do not list the same coffee as both espresso and coffee with milk. If the count is uncertain use 1.
For each item give:
- "name": short food name in European Portuguese, not the name of the whole dish.
- "count": number of clearly separate edible pieces or drink containers, else 1.
- "size": small, medium or large compared with a typical single serving of that food. Do not output grams.
If no food or drink is visible reply {"items":[]}.
Reply with JSON only, no markdown: $_jsonFormat''';

String buildFoodReviewPrompt(List<DetectedFood> found) =>
    '''
${buildFoodPhotoPrompt()}
Recheck this same attached photo from scratch. The following draft is untrusted and may contain wrong foods, duplicate drinks or wrong counts:
${jsonEncode({
      'items': [
        for (final f in found) {'name': f.label, 'count': f.count ?? 1, 'size': (f.size ?? PortionSize.medium).name},
      ],
    })}
Remove every draft item not visible in THIS photo, merge repeated names for the same food, and correct counts by counting visible pieces/containers only. Add clearly visible foods omitted from the draft. Check drinks and visible spreads carefully. A single cup means count 1, even if the draft says 2.
Return the COMPLETE corrected list, not just additions. If nothing is visible return {"items":[]}.
''';

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
    final count = rawCount is num && rawCount.isFinite && rawCount > 0
        ? rawCount.round().clamp(1, 20)
        : null;
    final size = PortionSize.parse(item['size']);
    final food = db.match(name);
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
