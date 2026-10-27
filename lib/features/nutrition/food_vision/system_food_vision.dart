import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../../core/ai/on_device_llm.dart';
import '../data/food_database.dart';
import 'burger_rules.dart';
import 'food_companions.dart';
import 'food_names.dart';
import 'food_screening.dart';
import 'food_vision.dart';
import 'photo_quality.dart';
import 'portion_estimate.dart';

/// Multi-food recognition with the phone's own multimodal model (Gemini Nano
/// through ML Kit GenAI / AICore). On-device; the photo is not sent anywhere.
/// Counts pieces; grams come from the offline typical portion.
class SystemFoodVision
    implements MultiPhotoFoodVisionService, StagedFoodVisionService {
  SystemFoodVision(this.database, {MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('vyro/on_device_llm');

  final FoodDatabase database;
  final MethodChannel _channel;

  /// Longest image side sent to the model (keeps memory and latency low).
  static const maxSide = 768;

  @override
  Future<FoodVisionResult> analyse(Uint8List imageBytes) =>
      _analyse(imageBytes, null, null);

  @override
  Future<FoodVisionResult> analyseViews(
    Uint8List primary,
    Uint8List secondary,
  ) => _analyse(primary, secondary, null);

  @override
  Future<FoodVisionResult> analyseStaged(
    Uint8List imageBytes, {
    Uint8List? secondaryImage,
    void Function(FoodVisionResult draft)? onDraft,
  }) => _analyse(imageBytes, secondaryImage, onDraft);

  Future<FoodVisionResult> _analyse(
    Uint8List imageBytes,
    Uint8List? secondBytes,
    void Function(FoodVisionResult draft)? onDraft,
  ) async {
    final timings = <String, Duration>{};
    final jpeg = await compute(_downscale, imageBytes);
    final secondPhoto = secondBytes == null
        ? null
        : await compute(_downscale, secondBytes);
    final firstWatch = Stopwatch()..start();
    final first = await _ask(
      jpeg,
      buildFoodPhotoPrompt(),
      secondPhoto: secondPhoto,
    );
    timings['first'] = firstWatch.elapsed;
    var history = first;
    var draft = parseFoodPhotoAnswer(first, database);
    if (draft.isEmpty) {
      if (_photoItems(first)?.isEmpty != true) {
        throw LlmException('invalid_foods: ${_clip(first)}');
      }
      // An empty first look is not yet a confirmed empty photo: food can sit
      // in a pan, pot, tray or box. One more look with a fallback prompt.
      final secondWatch = Stopwatch()..start();
      final second = await _ask(
        jpeg,
        buildFoodSecondChancePrompt(),
        secondPhoto: secondPhoto,
      );
      timings['second'] = secondWatch.elapsed;
      history = '$first\n---\nfirst: empty → second chance: $second';
      draft = parseFoodPhotoAnswer(second, database);
      if (draft.isEmpty) {
        if (_photoItems(second)?.isEmpty != true) {
          throw LlmException('invalid_foods: ${_clip(second)}');
        }
        return FoodVisionResult(
          foods: const [],
          source: VisionSource.systemAi,
          detail: history,
          confirmedEmpty: true,
          timings: timings,
        );
      }
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
          history,
          _droppedLine(split.dropped),
          ...nonFoodLines,
        ]),
        timings: timings,
      );
    }
    // The first usable list is available now: report it before verification.
    if (onDraft != null) {
      final pendingDraft = applyDrinkSanity([
        for (final f in kept) f.copyWith(pending: true),
      ]);
      onDraft(
        FoodVisionResult(
          foods: pendingDraft.kept,
          suggestions: pendingDraft.duplicates,
          source: VisionSource.systemAi,
          stage: VisionStage.draft,
          detail: history,
          timings: Map.of(timings),
        ),
      );
    }
    // Verification only removes items (explicit visible:false); it never adds
    // foods. An omitted verdict keeps the item as uncertain; an unparseable
    // answer keeps the whole list; a rejection of every item keeps them all
    // as uncertain (see decideDraft).
    List<bool?>? verdicts;
    var detail = history;
    final verifyWatch = Stopwatch()..start();
    try {
      final verify = await _ask(
        jpeg,
        buildFoodVerifyPrompt(kept),
        secondPhoto: secondPhoto,
      );
      verdicts = parseFoodVerifyAnswer(verify, kept.length);
      detail = verdicts == null
          ? '$history\n---\nverify: unparsed\n$verify'
          : '$history\n---\n$verify';
      if (verdicts != null && verdicts.contains(null)) {
        detail = '$detail\nverify: incomplete, omitted items kept as uncertain';
      }
    } catch (error) {
      detail = '$history\n---\nverify: failed ($error)';
    }
    timings['verify'] = verifyWatch.elapsed;
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
    // Companion foods (gravy with steak, ketchup with fries...) are
    // suggestions only, read from the verified names.
    final companions = mealCompanions(
      sanity.kept,
      database,
      alsoTaken: duplicates,
    );
    return FoodVisionResult(
      foods: sanity.kept,
      suggestions: [...duplicates, ...companions],
      source: VisionSource.systemAi,
      timings: timings,
      detail: _joinDetail([
        detail,
        _droppedLine(split.dropped),
        if (generic.isNotEmpty) 'generic: ${generic.join(', ')}',
        ...nonFoodLines,
        ...decisionLines,
        if (companions.isNotEmpty)
          'companions: ${companions.map((c) => c.label).join(', ')}',
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
/// Names and locations are asked in plain English: the measured best variant
/// (offline eval, F1 0.47 vs 0.35 with European Portuguese names; see
/// docs/FOOD_VISION.md). The database matches English names and aliases first.
String buildFoodPhotoPrompt() => '''
Analyse ONLY the image attached to THIS request. It is a new, independent meal. Never reuse foods from earlier images, messages or meals.
List only the foods and drinks that are actually in this photo. Include every drink in a glass, cup, bottle or can, and every food on a plate, board or packaging. Food can also be served or photographed in a pan, pot, tray, box, packaging or hand: still list the food, not the container. Never add side dishes, salads, vegetables, legumes, spreads or garnishes that are not clearly visible. Do not infer hidden ingredients, oil, sugar or milk. Do not list non-food objects such as the table, napkins, towels or cutlery.
One row per food type, with its TOTAL count. A single cup or glass is ONE drink, even with a saucer, handle or shadow. Never list the same coffee twice.
For each item give:
- "name": the specific food or drink name in plain English, short, common and singular, e.g. "fried egg", "beer", "white rice", "beef steak". Never a general word such as "drink" or "food" when the kind is visible.
- "where": short location in the photo in plain English, e.g. "centre of plate" or "top left glass". It helps us check the item; leave it as "" if you cannot tell.
- "count": number of clearly separate pieces or containers, else 1.
- "size": small, medium or large compared with a typical single serving. Do not output grams.
If no food or drink is visible reply {"items":[]}.
Reply with JSON only, no markdown: $_jsonFormat''';

/// Second look, only after a first answer with no items. Food is often in a
/// pan, pot, tray, box or packaging, or partly eaten, so the prompt names
/// those places and asks for the main foods and drinks by name (in English,
/// same as [buildFoodPhotoPrompt]).
String buildFoodSecondChancePrompt() => '''
Look again ONLY at the image attached to THIS request. It is a new, independent meal, and a first look found no food. Meal photos are often hard to read: food can be in a pan, pot, tray, box, packaging or on a board, or only partly eaten.
Name the main food(s) and drink(s) you can see, even if you are not sure of the exact dish. Name the food itself, not the pan, box or packaging around it. Do not list non-food objects such as the table, napkins, towels or cutlery. If you truly see no food or drink, reply {"items":[]}.
For each item give "name" (the food name in plain English, short, common and singular, e.g. "fried egg", "beer", "white rice"), "where" (short location in plain English, e.g. "centre of pan", or "" if unsure), "count" (1 if unsure) and "size" (small, medium or large). Do not output grams.
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

/// The database food for a model name: English names and aliases first
/// ([matchEnglishFoodName]), then each candidate from [foodNameCandidates] in
/// order, returning the first match.
FoodRef? matchFoodName(FoodDatabase db, List<String> candidates) {
  // English names first: the photo prompt asks for English names, and the
  // database holds English names and aliases for most foods.
  final english = matchEnglishFoodName(db, candidates);
  if (english != null) return english;
  for (final candidate in candidates) {
    final food = db.match(candidate);
    if (food != null) return food;
  }
  return null;
}

/// Matches foods without summing repeated rows. Grams come from typical
/// portions in the offline database. Unmatched names remain visible.
/// Names are normalised before matching: plurals fall back to singulars
/// ("ovos" → ovo) and common English names map to Portuguese ("beer" →
/// cerveja). A generic name ("beverage", "bebida") is never matched.
List<DetectedFood> parseFoodPhotoAnswer(String raw, FoodDatabase db) {
  final items = _photoItems(raw);
  if (items == null) return const [];
  final out = <DetectedFood>[];
  final seen = <String>{};
  // Items the model named only "chicken": grilled by default, see burger_rules.
  final genericChicken = Set<DetectedFood>.identity();
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
    // A generic name ("bebida", "beverage") has no sensible database match:
    // the user must name the food, so it gets no nutrients from a match.
    final candidates = foodNameCandidates(name);
    final needsChoice = candidates.any((c) => genericKindOf(c) != null);
    final food = needsChoice ? null : matchFoodName(db, candidates);
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
      if (genericChicken.remove(prev)) genericChicken.add(out[i]);
      continue;
    }
    final parsed = DetectedFood(
      food: food,
      label: food?.namePt ?? name,
      grams: grams,
      count: count,
      size: size,
      where: where,
      needsChoice: needsChoice,
      source: VisionSource.systemAi,
    );
    out.add(parsed);
    if (food?.key == grilledChickenKey && isGenericChickenName(name)) {
      genericChicken.add(parsed);
    }
  }
  // A bare "chicken" next to a bun is the breaded patty; a burger sandwich
  // next to a bun is the patty (no double bun).
  return reconcileBurgerSandwich(
    reconcileGenericChicken(out, db, genericChicken),
    db,
  );
}

/// System model when the phone has it, always combined with the offline
/// region classifier. Falls back to regions alone on failure or iOS.
///
/// Three entry points: [analyse] / [analyseViews] return the final result;
/// [analyseProgressive] / [analyseViewsProgressive] emit a draft (when the
/// system model produced one) and then the final result on the same stream.
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
      _run(imageBytes, null, null);

  @override
  Future<FoodVisionResult> analyseViews(
    Uint8List primary,
    Uint8List secondary,
  ) => _run(primary, secondary, null);

  /// Draft, then final. Draft: `stage` [VisionStage.draft], items `pending`,
  /// offline suggestions only if the offline pass had already finished. Final:
  /// `stage` [VisionStage.final_], the same result [analyse] returns. Without
  /// the system model there is no draft and only the final event. Errors are
  /// delivered as stream errors (the same error [analyse] would throw).
  Stream<FoodVisionResult> analyseProgressive(Uint8List imageBytes) =>
      _progressive(imageBytes, null);

  /// [analyseProgressive] for two photos of the same meal.
  Stream<FoodVisionResult> analyseViewsProgressive(
    Uint8List primary,
    Uint8List secondary,
  ) => _progressive(primary, secondary);

  Stream<FoodVisionResult> _progressive(Uint8List bytes, Uint8List? second) {
    final controller = StreamController<FoodVisionResult>();
    () async {
      try {
        final result = await _run(bytes, second, (draft) {
          if (!controller.isClosed) controller.add(draft);
        });
        if (!controller.isClosed) controller.add(result);
      } catch (error, stack) {
        if (!controller.isClosed) controller.addError(error, stack);
      } finally {
        await controller.close();
      }
    }();
    return controller.stream;
  }

  Future<FoodVisionResult> _run(
    Uint8List imageBytes,
    Uint8List? secondaryImage,
    void Function(FoodVisionResult draft)? onDraft,
  ) async {
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

    // Offline pass starts before anything else so it runs alongside the
    // system model and the quality check; its timing is recorded as regions.
    FoodVisionResult? offlineReady;
    final offline = capture(() async {
      final watch = Stopwatch()..start();
      var result = await regions.analyse(imageBytes);
      if (secondaryImage != null) {
        try {
          final second = await regions.analyse(secondaryImage);
          result = fuseVisionResults(
            result,
            second,
          ).withNote('secondViewOffline');
        } catch (_) {
          // The first view's result stands.
        }
      }
      return result.copyWith(
        timings: {...result.timings, 'regions': watch.elapsed},
      );
    });
    offline.then((outcome) => offlineReady = outcome.value);
    final quality = await compute(assessPhotoBytes, imageBytes);
    final status = await llm.status();
    if (status == LlmStatus.available) {
      final primary = await capture(() {
        final staged = system;
        if (staged is StagedFoodVisionService) {
          return staged.analyseStaged(
            imageBytes,
            secondaryImage: secondaryImage,
            onDraft: (draft) {
              final offlineNow = offlineReady;
              final view = offlineNow == null
                  ? draft
                  : fuseVisionResults(draft, offlineNow);
              onDraft?.call(
                _finish(view.copyWith(stage: VisionStage.draft), quality),
              );
            },
          );
        }
        return secondaryImage != null && system is MultiPhotoFoodVisionService
            ? (system as MultiPhotoFoodVisionService).analyseViews(
                imageBytes,
                secondaryImage,
              )
            : system.analyse(imageBytes);
      });
      final secondary = await offline;
      if (primary.value != null) {
        final result = primary.value!;
        // A confirmed empty review still shows offline hypotheses (as
        // suggestions only); fuseVisionResults keeps confirmedEmpty.
        if (secondary.value == null) {
          return _finish(result, quality);
        }
        return _finish(fuseVisionResults(result, secondary.value!), quality);
      }
      if (secondary.value != null) {
        // The system model gave no answer: offline foods are only suggestions
        // (see offlineHypothesesOnly), the main list stays empty.
        final missing = primary.error is MissingPluginException;
        return _finish(
          offlineHypothesesOnly(
            secondary.value!,
            systemFailed: !missing,
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
    // No system model: offline guesses are suggestions only, never main items.
    final failure = status == LlmStatus.downloading
        ? VisionFailure.busy
        : VisionFailure.unavailable;
    return _finish(
      offlineHypothesesOnly(secondary.value!, failure: failure),
      quality,
    );
  }
}

/// Quality note, then the `timing:` line in the detail (once per result).
FoodVisionResult _finish(FoodVisionResult result, PhotoQuality quality) {
  final noted = quality.note == null
      ? result
      : result.withNote(
          [if (result.note != null) result.note!, quality.note!].join(','),
        );
  final line = timingLine(noted.timings);
  if (line == null) return noted;
  return noted.copyWith(
    detail: [
      if (noted.detail != null && noted.detail!.isNotEmpty) noted.detail!,
      line,
    ].join('\n'),
  );
}
