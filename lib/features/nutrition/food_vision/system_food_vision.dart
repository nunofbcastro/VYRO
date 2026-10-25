import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../../core/ai/on_device_llm.dart';
import '../data/food_database.dart';
import 'food_screening.dart';
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
    // Non-food objects (towel, napkin, plate...) never reach verification.
    final split = dropNonFood(draft);
    final kept = split.kept;
    final nonFoodLines = [
      for (final label in split.dropped)
        decisionLine(label, ItemAction.dropped, 'non-food'),
    ];
    if (kept.isEmpty) {
      return FoodVisionResult(
        foods: const [],
        source: VisionSource.systemAi,
        detail: _joinDetail([
          first,
          _droppedLine(split.dropped),
          ...nonFoodLines,
        ]),
      );
    }
    // Verification only removes items (explicit visible:false); it never adds
    // foods. An omitted verdict keeps the item as uncertain; an unparseable
    // answer keeps the whole first list.
    List<bool?>? verdicts;
    var detail = first;
    try {
      final verify = await _ask(
        jpeg,
        buildFoodVerifyPrompt(kept),
        secondPhoto: secondPhoto,
      );
      verdicts = parseFoodVerifyAnswer(verify, kept.length);
      detail = verdicts == null
          ? '$first\n---\nverify: unparsed\n$verify'
          : '$first\n---\n$verify';
      if (verdicts != null && verdicts.contains(null)) {
        detail = '$detail\nverify: incomplete, omitted items kept as uncertain';
      }
    } catch (error) {
      detail = '$first\n---\nverify: failed ($error)';
    }
    final decision = decideDraft(kept, verdicts: verdicts);
    // One cup, one drink: a duplicate coffee is a suggestion, not a total.
    final sanity = applyDrinkSanity(decision.foods);
    final duplicates = sanity.duplicates;
    final generic = [
      for (final f in kept)
        if (f.needsChoice) f.label,
    ];
    final decisionLines = [
      for (final d in decision.decisions)
        if (duplicates.any((f) => identical(f, d.item)))
          decisionLine(d.item.label, ItemAction.suggestion, 'duplicate coffee')
        else
          decisionLine(d.item.label, d.action, d.reason),
    ];
    return FoodVisionResult(
      foods: sanity.kept,
      suggestions: duplicates,
      source: VisionSource.systemAi,
      confirmedEmpty: decision.confirmedEmpty && sanity.kept.isEmpty,
      detail: _joinDetail([
        detail,
        _droppedLine(split.dropped),
        if (generic.isNotEmpty) 'generic: ${generic.join(', ')}',
        ...nonFoodLines,
        ...decisionLines,
      ]),
    );
  }

  static String? _droppedLine(List<String> dropped) =>
      dropped.isEmpty ? null : 'dropped non-food: ${dropped.join(', ')}';

  static String _joinDetail(List<String?> lines) =>
      lines.whereType<String>().join('\n');

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
List only the foods and drinks that are actually in this photo. Include every drink in a glass, cup, bottle or can, and every food on a plate, board or packaging. Never add side dishes, salads, vegetables, legumes, spreads or garnishes that are not clearly visible. Do not infer hidden ingredients, oil, sugar or milk. Do not list non-food objects such as the table, napkins, towels or cutlery.
One row per food type, with its TOTAL count. A single cup or glass is ONE drink, even with a saucer, handle or shadow. Never list the same coffee twice.
For each item give:
- "name": short food name in European Portuguese.
- "where": short location in the photo, e.g. "centre of plate" or "cup top-left". It helps us check the item; leave it as "" if you cannot tell.
- "count": number of clearly separate pieces or containers, else 1.
- "size": small, medium or large compared with a typical single serving. Do not output grams.
If no food or drink is visible reply {"items":[]}.
Reply with JSON only, no markdown: $_jsonFormat''';

/// Verification: yes/no per draft item. It must not add or rename foods.
/// Partly visible or small items count as visible; only a confident "not in
/// the photo" is false.
String buildFoodVerifyPrompt(List<DetectedFood> draft) {
  final items = [
    for (var i = 0; i < draft.length; i++) '$i: ${draft[i].label}',
  ].join('\n');
  return '''
Look ONLY at the attached photo (any attached view of it). Check each numbered item below.
Answer "visible": true if that food or drink can be seen in THIS photo, even partly, small or at the edge of the frame.
Answer "visible": false only if you are confident it is NOT in the photo. If unsure, answer true.
Do not name any other food and do not rename items.
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

/// One verdict per draft index: `true`/`false` as answered, `null` when the
/// index is missing or its verdict is not a boolean. Null overall (unparseable)
/// only when the answer has no "checks" list at all.
List<bool?>? parseFoodVerifyAnswer(String raw, int draftCount) {
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
  return verdicts;
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
/// listed, only the first coffee listed by the model is kept; the others are
/// returned as duplicates (suggestions, never totals). Pure function.
({List<DetectedFood> kept, List<DetectedFood> duplicates}) applyDrinkSanity(
  List<DetectedFood> foods,
) {
  final coffees = [
    for (final f in foods)
      if (coffeeKindOf(f) != null) f,
  ];
  if (coffees.length < 2) return (kept: foods, duplicates: const []);
  final firstKind = coffeeKindOf(coffees.first);
  final mixed = coffees.any((f) => coffeeKindOf(f) != firstKind);
  if (!mixed) return (kept: foods, duplicates: const []);
  final keep = coffees.first;
  return (
    kept: [
      for (final f in foods)
        if (coffeeKindOf(f) == null || identical(f, keep)) f,
    ],
    duplicates: [
      for (final f in coffees)
        if (!identical(f, keep)) f,
    ],
  );
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
    final whereRaw = item['where'] is String
        ? (item['where'] as String).trim()
        : '';
    final where = whereRaw.isEmpty
        ? null
        : (whereRaw.length > 80 ? whereRaw.substring(0, 80) : whereRaw);
    // A generic name ("bebida") has no sensible database match: the user
    // must name the food, so it gets no nutrients from a random match.
    final needsChoice = genericKindOf(name) != null;
    final food = needsChoice ? null : db.match(name);
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
        where: prev.where ?? where,
        needsChoice: prev.needsChoice,
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
        where: where,
        needsChoice: needsChoice,
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
        final missing = primary.error is MissingPluginException;
        return _withQuality(
          result.withNote(
            missing ? result.note : 'systemFailed',
            detail: '${primary.error}',
            failure: missing
                ? VisionFailure.unavailable
                : VisionFailure.fromError(primary.error),
          ),
          quality,
        );
      }
      throw LlmException('vision_failed: ${primary.error}; ${secondary.error}');
    }
    final secondary = await offline;
    if (secondary.value == null) {
      throw LlmException('vision_failed: ${secondary.error}');
    }
    // Downloading the model counts as busy; unsupported or off as unavailable.
    final failure = status == LlmStatus.downloading
        ? VisionFailure.busy
        : VisionFailure.unavailable;
    return _withQuality(
      secondary.value!.withNote(null, failure: failure),
      quality,
    );
  }
}

FoodVisionResult _withQuality(FoodVisionResult result, PhotoQuality quality) {
  if (quality.note == null) return result;
  return result.withNote(
    [if (result.note != null) result.note!, quality.note!].join(','),
  );
}
