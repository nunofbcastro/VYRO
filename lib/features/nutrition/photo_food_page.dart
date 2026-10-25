import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../core/database/app_database.dart';
import '../../core/platform/image_temp_file.dart';
import '../../core/ui/vyro_ui.dart';
import 'data/food_database.dart';
import 'domain/food_product.dart' show dayKey;
import 'food_vision/food_vision.dart';
import 'food_vision/portion_estimate.dart';
import 'food_vision/region_food_vision.dart';
import 'food_vision/system_food_vision.dart';
import 'meals.dart';
import 'photo/review_model.dart';
import 'widgets/food_picker_sheet.dart';
import 'widgets/photo_region_sheet.dart';
import 'widgets/photo_review_widgets.dart';

/// Photo → foods → grams → diary. Recognition runs on the device
/// ([FoodVisionPipeline]); nutrients come from the offline database and
/// every food and amount is confirmed by the user before saving.
///
/// Several photos can be picked at once: as separate meals (a queue, each
/// analysed and reviewed in turn, the next one analysed in the background)
/// or as two views of one meal. Photos are kept in memory only.
class PhotoFoodPage extends StatefulWidget {
  const PhotoFoodPage({super.key, this.day, this.imagePicker, this.vision});
  final DateTime? day;
  final ImagePicker? imagePicker;
  final FoodVisionService? vision;

  @override
  State<PhotoFoodPage> createState() => _PhotoFoodPageState();
}

/// Foods offered as one-tap additions when the detector missed them.
/// Spreads and drinks are hard to see in a photo (butter on toast, coffee
/// in a cup), so breakfast-like meals offer those first.
const _plateQuickKeys = [
  'rice_white_cooked',
  'beans_red_cooked',
  'chicken_breast_roasted',
  'lettuce_raw',
  'tomato_raw',
  'green_salad',
  'potato_boiled',
  'pasta_cooked',
  'olive_oil',
  'egg_fried',
];
const _breakfastQuickKeys = [
  'butter_salted',
  'espresso',
  'coffee_with_milk',
  'jam',
  'ham_cooked',
  'cheese_gouda',
  'orange_juice',
  'milk_semi',
  'tea',
  'egg_boiled',
];

List<String> _quickKeysFor(String meal, List<ReviewItem> items) {
  final breakfastLike =
      meal == 'breakfast' ||
      meal == 'snack' ||
      items.any((i) => i.food?.category == 'padaria');
  return breakfastLike
      ? [..._breakfastQuickKeys, ..._plateQuickKeys]
      : [..._plateQuickKeys, ..._breakfastQuickKeys];
}

class _PhotoFoodPageState extends State<PhotoFoodPage> {
  late final _picker = widget.imagePicker ?? ImagePicker();
  final _scroll = ScrollController();
  FoodDatabase? _db;
  FoodVisionService? _service;

  /// Photos to review, in order. One shot unless several were picked.
  List<ReviewShot> _shots = [];
  int _index = 0;

  /// Bumped for every new batch and on dispose: late events are ignored.
  int _session = 0;
  late String _meal = mealForTime(DateTime.now());
  bool _busy = false;
  bool _saving = false;
  String? _error;
  int _removed = 0, _added = 0;

  ReviewShot? get _shot => _shots.isEmpty ? null : _shots[_index];
  bool get _queue => _shots.length > 1;

  @override
  void initState() {
    super.initState();
    FoodDatabase.load().then((db) {
      if (mounted) setState(() => _db = db);
    });
  }

  @override
  void dispose() {
    _session++;
    for (final shot in _shots) {
      _discard(shot);
    }
    _scroll.dispose();
    super.dispose();
  }

  // ------------------------------------------------------- photo batches

  /// Releases a shot's photo and deletes its picker file if never read.
  void _discard(ReviewShot shot) {
    final file = shot.file;
    final second = shot.secondFile;
    shot.file = null;
    shot.secondFile = null;
    shot.release();
    if (file != null) deleteTemporaryImage(file.path).ignore();
    if (second != null) deleteTemporaryImage(second.path).ignore();
  }

  /// Reads the picker files of a shot (once) and deletes the temporary copies.
  Future<void> _load(ReviewShot shot) async {
    final file = shot.file;
    if (shot.bytes == null && file != null) {
      shot.file = null;
      try {
        shot.bytes = await file.readAsBytes();
      } finally {
        await deleteTemporaryImage(file.path);
      }
    }
    final second = shot.secondFile;
    if (shot.second == null && second != null) {
      shot.secondFile = null;
      try {
        shot.second = await second.readAsBytes();
      } finally {
        await deleteTemporaryImage(second.path);
      }
    }
  }

  /// Replaces the review with [shots] and starts the first one.
  void _startBatch(List<ReviewShot> shots) {
    if (shots.isEmpty || !mounted) return;
    _session++;
    for (final shot in _shots) {
      _discard(shot);
    }
    setState(() {
      _shots = shots;
      _index = 0;
      _removed = 0;
      _added = 0;
      _error = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _startShot(shots.first);
  }

  bool _isCurrent(int session, ReviewShot shot, int generation) =>
      mounted &&
      session == _session &&
      shot.generation == generation &&
      shot.state == ShotState.analysing;

  /// Analyses one shot. Draft and final events are applied as they arrive.
  Future<void> _startShot(ReviewShot shot) async {
    if (!mounted) return;
    final session = _session;
    final generation = ++shot.generation;
    final services = AppServicesScope.of(context);
    shot
      ..state = ShotState.analysing
      ..items = null
      ..result = null
      ..failure = null
      ..error = null
      ..reviewClock.reset();
    setState(() {});
    try {
      await _load(shot);
      final bytes = shot.bytes;
      if (bytes == null) throw const FormatException('no image');
      final db = _db ?? await FoodDatabase.load();
      if (!_isCurrent(session, shot, generation)) return;
      _db = db;
      final service = _service ??=
          widget.vision ??
          FoodVisionPipeline(
            llm: services.llm,
            system: SystemFoodVision(db),
            regions: RegionFoodVision(db),
          );
      await _analyse(service, bytes, shot.second, (event) {
        if (!_isCurrent(session, shot, generation)) return;
        setState(() {
          shot.result = event;
          shot.failure = event.failure;
          shot.items = mergeReviewItems(shot.items, event.foods);
        });
        _pumpAhead();
      });
    } on FormatException {
      if (_isCurrent(session, shot, generation)) {
        shot.error = 'photoInvalidImage';
      }
    } catch (error) {
      if (_isCurrent(session, shot, generation)) {
        shot.failure = VisionFailure.fromError(error);
        shot.result = null;
      }
    }
    if (!_isCurrent(session, shot, generation)) return;
    shot
      ..state = ShotState.ready
      ..items ??= []
      ..reviewClock.start();
    setState(() {});
    _pumpAhead();
  }

  /// Keeps at most one analysis running in the background: the next waiting
  /// photo starts while the current one is being reviewed.
  void _pumpAhead() {
    if (!mounted) return;
    if (_shots.any((s) => s.state == ShotState.analysing)) return;
    final next = _shots.indexWhere((s) => s.state == ShotState.waiting, _index);
    if (next < 0 || next > _index + 1) return;
    _startShot(_shots[next]);
  }

  /// Reports each event to [onEvent] in order: the draft (when the phone's
  /// model has one), then the final result. The pipeline streams its events;
  /// other services are called directly, which keeps tests free of stream
  /// timing. Errors are thrown, as [FoodVisionPipeline.analyse] would.
  Future<void> _analyse(
    FoodVisionService service,
    Uint8List bytes,
    Uint8List? second,
    void Function(FoodVisionResult event) onEvent,
  ) async {
    if (service is FoodVisionPipeline) {
      final events = second == null
          ? service.analyseProgressive(bytes)
          : service.analyseViewsProgressive(bytes, second);
      await for (final event in events) {
        onEvent(event);
      }
      return;
    }
    if (service is StagedFoodVisionService) {
      onEvent(
        await service.analyseStaged(
          bytes,
          secondaryImage: second,
          onDraft: onEvent,
        ),
      );
      return;
    }
    onEvent(
      second != null && service is MultiPhotoFoodVisionService
          ? await service.analyseViews(bytes, second)
          : await service.analyse(bytes),
    );
  }

  /// Moves to the next photo (or leaves when the queue is finished). The
  /// current photo is released; nothing is kept for it.
  void _advance() {
    final shot = _shot;
    if (shot == null) return;
    _discard(shot);
    shot.state = ShotState.done;
    final next = _index + 1;
    if (next >= _shots.length) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _index = next;
      _removed = 0;
      _added = 0;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    final upcoming = _shots[next];
    if (upcoming.state == ShotState.waiting) _startShot(upcoming);
    _pumpAhead();
  }

  // -------------------------------------------------------- picking

  Future<Uint8List?> _readAndDelete(XFile file) async {
    try {
      return await file.readAsBytes();
    } finally {
      await deleteTemporaryImage(file.path);
    }
  }

  bool get _analysing => _shot?.state == ShotState.analysing;

  Future<void> _takePhoto() async {
    if (_busy || _saving || _analysing) return;
    setState(() => _busy = true);
    Uint8List? bytes;
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );
      if (file != null) bytes = await _readAndDelete(file);
    } catch (_) {
      if (mounted) setState(() => _error = 'cameraError');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (bytes == null || !mounted) return;
    _startBatch([ReviewShot(bytes: bytes)]);
  }

  Future<void> _pickGallery() async {
    if (_busy || _saving || _analysing) return;
    setState(() => _busy = true);
    var files = const <XFile>[];
    try {
      files = await _picker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'photoGalleryError');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted || files.isEmpty) return;
    var sameMeal = false;
    if (files.length > 1) {
      sameMeal = await _askSameMeal(files.length) ?? false;
      if (!mounted) return;
    }
    if (sameMeal) {
      _startBatch([
        ReviewShot(
          file: files[0],
          secondFile: files[1],
          limitNote: files.length > 2,
        ),
      ]);
    } else {
      _startBatch([for (final file in files) ReviewShot(file: file)]);
    }
  }

  /// Null when dismissed (treated as different meals by the caller).
  Future<bool?> _askSameMeal(int count) {
    final t = stringsOf(context);
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.get('photoSameMealQ')),
        content: Text(
          '${t.get('photoSameMealBody')}'
          '${count > 2 ? '\n\n${t.get('photoSameMealLimit')}' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(t.get('photoSameMeal')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(t.get('photoDifferentMeals')),
          ),
        ],
      ),
    );
  }

  /// Runs the analysis again on the same photo (no new capture).
  void _retry() {
    final shot = _shot;
    if (shot == null || !shot.hasPhoto || _busy || _saving || _analysing) {
      return;
    }
    shot.state = ShotState.waiting;
    _startShot(shot);
  }

  // ------------------------------------------------------- review edits

  void _addItem(ReviewItem item) {
    final shot = _shot;
    if (shot == null) return;
    _added++;
    setState(() => (shot.items ??= []).add(item));
  }

  void _addFood(FoodRef food, {double? grams}) => _addItem(
    ReviewItem(
      DetectedFood(
        food: food,
        label: food.namePt,
        grams: grams ?? food.portionG,
        source: VisionSource.user,
      ),
    ),
  );

  void _removeItem(ReviewItem item) {
    _removed++;
    setState(() => item.removing = true);
  }

  void _dropItem(ReviewItem item) {
    setState(() => _shot?.items?.remove(item));
  }

  Future<void> _change(ReviewItem item) async {
    final db = _db;
    if (db == null) return;
    final suggestions = await AppServicesScope.of(
      context,
    ).localIntelligence.correctionSuggestions(item.original.label, db);
    if (!mounted) return;
    final food = await showFoodPicker(
      context,
      db,
      suggestions: suggestions,
      initialQuery: item.food == null ? item.detected.label : '',
    );
    if (food == null || !mounted) return;
    final wasUnmatched = item.food == null;
    setState(() {
      item.detected = item.detected.copyWith(
        food: food,
        source: VisionSource.user,
      );
      // An unmatched line had no sensible amount yet: use the food's portion.
      if (wasUnmatched) item.grams = food.portionG;
    });
  }

  Future<void> _addFromPicker() async {
    final db = _db;
    if (db == null) return;
    final food = await showFoodPicker(context, db);
    if (food != null) _addFood(food);
  }

  /// Second angle (camera) or a region of the photo: candidates to add.
  Future<void> _extraPhoto({required bool region}) async {
    final shot = _shot;
    final photo = shot?.bytes;
    if (shot == null || photo == null || _busy || _saving || _analysing) {
      return;
    }
    Uint8List? bytes;
    try {
      if (region) {
        bytes = await selectPhotoRegion(context, photo);
      } else {
        final file = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 88,
        );
        if (file != null) bytes = await _readAndDelete(file);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'cameraError');
      return;
    }
    final db = _db;
    if (bytes == null || !mounted || db == null) return;
    final session = _session;
    final generation = shot.generation;
    if (!region) shot.angle = bytes;
    setState(() => _busy = true);
    try {
      final service = _service ??=
          widget.vision ??
          FoodVisionPipeline(
            llm: AppServicesScope.of(context).llm,
            system: SystemFoodVision(db),
            regions: RegionFoodVision(db),
          );
      FoodVisionResult? result;
      await _analyse(
        service,
        region ? bytes : photo,
        region ? null : bytes,
        (event) => result = event,
      );
      final value = result;
      if (value == null ||
          !mounted ||
          session != _session ||
          shot.generation != generation) {
        return;
      }
      final candidates = <String, DetectedFood>{};
      for (final f in [...value.foods, ...value.suggestions]) {
        if (f.food != null &&
            !(shot.items ?? []).any((i) => i.food?.key == f.food!.key)) {
          candidates[f.food!.key] = f;
        }
      }
      if (!mounted) return;
      await _pickCandidates(candidates.values.toList());
    } catch (_) {
      if (mounted) setState(() => _error = 'photoModelError');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickCandidates(List<DetectedFood> candidates) async {
    final chosen = <DetectedFood>{};
    final t = stringsOf(context);
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.get('photoConfirmExtra'),
                  style: Theme.of(c).textTheme.titleLarge,
                ),
                Text(t.get('photoExtraHint')),
                if (candidates.isEmpty) Text(t.get('photoNothingFound')),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final f in candidates)
                        CheckboxListTile(
                          title: Text(f.food!.name(t.isEnglish)),
                          subtitle: Text(
                            '${f.grams.round()} g · ${t.get('photoUncertain')}',
                          ),
                          value: chosen.contains(f),
                          onChanged: (v) => update(() {
                            if (v == true) {
                              chosen.add(f);
                            } else {
                              chosen.remove(f);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(t.get('add')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (accepted == true && mounted) {
      for (final f in chosen) {
        _addFood(f.food!, grams: f.grams);
      }
    }
  }

  Future<void> _clarify(ReviewItem item) async {
    final food = item.food;
    if (food == null) return _change(item);
    final t = stringsOf(context);
    final alternatives = [
      for (final f in _shot?.result?.suggestions ?? <DetectedFood>[])
        if (f.food != null &&
            f.food!.category == food.category &&
            f.food!.key != food.key)
          f.food!,
    ];
    if (alternatives.isNotEmpty) {
      final selected = await showDialog<FoodRef>(
        context: context,
        builder: (c) => SimpleDialog(
          title: Text(t.get('photoWhichFood')),
          children: [
            for (final candidate in [food, ...alternatives])
              SimpleDialogOption(
                onPressed: () => Navigator.pop(c, candidate),
                child: Text(candidate.name(t.isEnglish)),
              ),
          ],
        ),
      );
      if (selected != null && mounted) {
        setState(() {
          item.detected = item.detected.copyWith(
            food: selected,
            source: VisionSource.user,
          );
          item.grams = selected.portionG;
        });
      }
      return;
    }
    final units = food.portionUnits;
    final amount = await showDialog<double>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(
          units == null
              ? (t.isEnglish
                    ? 'How large is this serving?'
                    : 'Qual é o tamanho desta porção?')
              : (t.isEnglish
                    ? 'How many pieces or containers?'
                    : 'Quantas peças ou recipientes?'),
        ),
        children: [
          if (units != null)
            for (final count in [1, 2, 3, 4, 6])
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.pop(c, estimatedGrams(food: food, count: count)),
                child: Text(
                  '$count · ${estimatedGrams(food: food, count: count).round()} g',
                ),
              ),
          if (units == null)
            for (final size in PortionSize.values)
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.pop(c, estimatedGrams(food: food, size: size)),
                child: Text(
                  '${t.isEnglish ? size.name : switch (size) {
                          PortionSize.small => "Pequena",
                          PortionSize.medium => "Média",
                          PortionSize.large => "Grande",
                        }} · ${estimatedGrams(food: food, size: size).round()} g',
                ),
              ),
        ],
      ),
    );
    if (amount != null && mounted) setState(() => item.grams = amount);
  }

  Future<void> _pickRecipe() async {
    final recipes = await AppServicesScope.of(
      context,
    ).localIntelligence.recipes();
    if (!mounted) return;
    final picked = await showModalBottomSheet<FoodRef>(
      context: context,
      useSafeArea: true,
      builder: (c) => ListView(
        shrinkWrap: true,
        children: [
          if (recipes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                stringsOf(c).isEnglish
                    ? 'Create your recipes in Nutrition → Your recipes.'
                    : 'Cria as tuas receitas em Nutrição → Receitas habituais.',
              ),
            ),
          for (final recipe in recipes)
            ListTile(
              title: Text(recipe.name),
              subtitle: Text('${recipe.asFood().kcal.round()} kcal/100 g'),
              onTap: () => Navigator.pop(c, recipe.asFood()),
            ),
        ],
      ),
    );
    if (picked != null && mounted) _addFood(picked);
  }

  // ----------------------------------------------------------- saving

  /// Saves the savable lines of the current photo, then moves on.
  Future<void> _save() async {
    final shot = _shot;
    if (shot == null || shot.state != ShotState.ready || _saving || _busy) {
      return;
    }
    final ready = [
      for (final item in shot.items ?? const <ReviewItem>[])
        if (item.savable) item,
    ];
    if (ready.isEmpty) return;
    final t = stringsOf(context);
    final services = AppServicesScope.of(context);
    final repository = services.nutritionRepository;
    setState(() => _saving = true);
    try {
      await services.database.transaction(() async {
        for (final item in ready) {
          final food = item.food!;
          await repository.addEntry(
            FoodEntriesCompanion.insert(
              day: dayKey(widget.day ?? DateTime.now()),
              mealType: _meal,
              name: food.name(t.isEnglish),
              quantityGrams: item.grams,
              kcalPer100g: Value(food.kcal),
              proteinPer100g: Value(food.protein),
              carbsPer100g: Value(food.carbs),
              fatPer100g: Value(food.fat),
              source: Value(food.sourceKey),
              portionUnit: const Value('grams'),
              portionCount: Value(item.grams),
            ),
          );
        }
        final local = services.localIntelligence;
        var corrected = 0;
        for (final item in ready) {
          if (item.food?.key != item.original.food?.key ||
              item.grams != item.original.grams) {
            corrected++;
          }
          if (item.food?.key != item.original.food?.key &&
              item.original.source != VisionSource.user) {
            await local.recordCorrection(item.original.label, item.food!.key);
          }
        }
        await local.recordPhotoReview(
          corrected: corrected,
          removed: _removed,
          added: _added,
          elapsed: shot.reviewClock.elapsed,
        );
      });
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.get('localError'))));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.get('photoSaved').replaceAll('{n}', '${ready.length}')),
      ),
    );
    _advance();
  }

  void _scrollToUnresolved() {
    ReviewItem? first;
    for (final item in _shot?.items ?? const <ReviewItem>[]) {
      if (item.unresolved) {
        first = item;
        break;
      }
    }
    if (first == null) return;
    final target = first.anchor.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
        alignment: 0.3,
      );
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(stringsOf(context).get('photoChooseFirst'))),
      );
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final shot = _shot;
    final items = shot?.items;
    final live = [
      for (final item in items ?? const <ReviewItem>[])
        if (!item.removing) item,
    ];
    final counts = countReview(items ?? const <ReviewItem>[]);
    final analysing = _analysing;
    final result = shot?.result;
    final draft = shot?.draftShown ?? false;
    final suggestions = [
      for (final s in result?.suggestions ?? const <DetectedFood>[])
        if (s.food != null && !live.any((i) => i.food?.key == s.food!.key)) s,
    ];
    final busy = _busy || _saving;

    return VyroSubpageScaffold(
      title: t.get('photo'),
      footer: shot == null
          ? null
          : _ReviewFooter(
              counts: counts,
              queue: _queue,
              analysing: analysing,
              saving: _saving,
              enabled: !busy && shot.state == ShotState.ready,
              onSave: _save,
              onAdvance: _advance,
              onScrollToUnresolved: _scrollToUnresolved,
            ),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          if (shot == null)
            _Hero(
              onCamera: kIsWeb || busy ? null : _takePhoto,
              onGallery: kIsWeb || busy ? null : _pickGallery,
            )
          else ...[
            if (_queue)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  t
                      .get('photoQueueOf')
                      .replaceAll('{n}', '${_index + 1}')
                      .replaceAll('{m}', '${_shots.length}'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            _PhotoBlock(
              shot: shot,
              analysing: analysing,
              draft: draft,
              source: result?.source,
              onRetake: busy || analysing ? null : _takePhoto,
            ),
            const SizedBox(height: 12),
            PhotoActionRow(
              actions: [
                PhotoAction(
                  icon: Icons.crop,
                  label: t.get('photoActZone'),
                  onPressed: busy || analysing || shot.bytes == null
                      ? null
                      : () => _extraPhoto(region: true),
                ),
                PhotoAction(
                  icon: Icons.add_a_photo_outlined,
                  label: t.get('photoActSecond'),
                  onPressed: busy || analysing || shot.bytes == null
                      ? null
                      : () => _extraPhoto(region: false),
                ),
                PhotoAction(
                  icon: Icons.menu_book_outlined,
                  label: t.get('photoActRecipe'),
                  onPressed: busy || analysing || _db == null
                      ? null
                      : _pickRecipe,
                ),
                PhotoAction(
                  icon: Icons.photo_library_outlined,
                  label: t.get('photoActMore'),
                  onPressed: busy || analysing ? null : _pickGallery,
                ),
              ],
            ),
            if (_error != null)
              _Notice(
                icon: Icons.info_outline_rounded,
                text: '${t.get(_error!)} ${t.get('photoManualFallback')}',
              ),
            if (shot.error != null)
              _Notice(
                icon: Icons.info_outline_rounded,
                text: t.get(shot.error!),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final meal in mealTypes)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: VyroPillChip(
                          label: mealLabel(t, meal),
                          selected: _meal == meal,
                          onTap: () => setState(() => _meal = meal),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (items != null) ...[
              const SizedBox(height: 16),
              ReviewSummary(items: items),
              if (result?.source == VisionSource.regionClassifier)
                _Notice(
                  icon: Icons.auto_awesome_outlined,
                  text: t.get(
                    (result?.notes.contains('systemFailed') ?? false)
                        ? 'photoSystemFailedNote'
                        : 'photoRegionsNote',
                  ),
                ),
              for (final note in result?.notes ?? <String>{})
                if (note != 'systemFailed')
                  _Notice(icon: Icons.info_outline_rounded, text: t.get(note)),
              if (shot.limitNote)
                _Notice(
                  icon: Icons.info_outline_rounded,
                  text: t.get('photoSameMealLimit'),
                ),
              if (live.isNotEmpty) ...[
                const SizedBox(height: 22),
                VyroSectionTitle(
                  label: '${t.get('photoFoundFoods')} · ${live.length}',
                ),
              ],
              // An empty review always offers a retry (same photo, or analyse
              // an area or add by hand). A confirmed empty photo says so.
              if (live.isEmpty && !analysing)
                _FailureCard(
                  reason: t.get(switch (shot.failure) {
                    VisionFailure.busy => 'photoFailBusy',
                    VisionFailure.unavailable => 'photoFailUnavailable',
                    VisionFailure.other => 'photoFailOther',
                    null =>
                      (result?.confirmedEmpty ?? false)
                          ? 'photoEmptyConfirmed'
                          : 'photoNothingFound',
                  }),
                  hint: t.get('photoFailHint'),
                  retryLabel: t.get('photoRetry'),
                  onRetry: busy || !shot.hasPhoto ? null : _retry,
                ),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: ReviewCollapse(
                    key: ObjectKey(item),
                    collapsing: item.removing,
                    onGone: () => _dropItem(item),
                    child: VyroFadeSlideIn(
                      child: FoodReviewCard(
                        key: item.anchor,
                        item: item,
                        onChange: item.pending || item.removing
                            ? null
                            : () => _change(item),
                        onGrams: (g) => setState(() => item.grams = g),
                        onRemove: item.pending || item.removing
                            ? null
                            : () => _removeItem(item),
                        onClarify: () => _clarify(item),
                      ),
                    ),
                  ),
                ),
              if (suggestions.isNotEmpty && !analysing) ...[
                const SizedBox(height: 18),
                ReviewChipRow(
                  title: t.get('photoSuggestions'),
                  chips: [
                    for (final s in suggestions)
                      ActionChip(
                        label: Text(s.food!.name(t.isEnglish)),
                        onPressed: () => _addFood(s.food!),
                      ),
                  ],
                ),
              ],
              if (!analysing) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _db == null || busy ? null : _addFromPicker,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(t.get('photoAddFood')),
                ),
              ],
              if (!analysing && _db != null) ...[
                const SizedBox(height: 18),
                _QuickAddRow(
                  foods: _quickFoods(_db!, live, suggestions),
                  onAdd: _addFood,
                ),
              ],
              const SizedBox(height: 22),
              Text(
                '${t.get('photoEstimateNote')}\n${t.get('nutritionSourcesNote')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_analysisDetail(result) case final detail?) ...[
                const SizedBox(height: 8),
                _AnalysisDetail(detail: detail),
              ],
            ],
          ],
        ],
      ),
    );
  }

  /// Common foods the photo may have missed, without repeats.
  List<FoodRef> _quickFoods(
    FoodDatabase db,
    List<ReviewItem> live,
    List<DetectedFood> suggestions,
  ) => [
    for (final key in _quickKeysFor(_meal, live))
      if (db.byKey(key) case final food?)
        if (!live.any((i) => i.food?.key == key) &&
            !suggestions.any((s) => s.food?.key == key))
          food,
  ].take(8).toList();

  /// Technical detail with the timing line appended (when not already there).
  String? _analysisDetail(FoodVisionResult? result) {
    if (result == null) return null;
    final timing = timingLine(result.timings);
    final detail = result.detail;
    if (timing == null) return detail;
    if (detail == null || detail.isEmpty) return timing;
    return detail.contains('timing:') ? detail : '$detail\n$timing';
  }
}

/// Sticky footer: the primary action counts the savable foods, and says what
/// is still unresolved instead of skipping it silently.
class _ReviewFooter extends StatelessWidget {
  const _ReviewFooter({
    required this.counts,
    required this.queue,
    required this.analysing,
    required this.saving,
    required this.enabled,
    required this.onSave,
    required this.onAdvance,
    required this.onScrollToUnresolved,
  });

  final ReviewCounts counts;
  final bool queue;
  final bool analysing;
  final bool saving;
  final bool enabled;
  final VoidCallback onSave;
  final VoidCallback onAdvance;
  final VoidCallback onScrollToUnresolved;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final savable = counts.savable;
    final String label;
    final VoidCallback? action;
    final IconData icon;
    if (analysing || !enabled && !saving) {
      label = t.get('photoSaveN').replaceAll('{n}', '$savable');
      action = null;
      icon = Icons.check_rounded;
    } else if (counts.hasUnresolved) {
      label = t.get('photoSaveN').replaceAll('{n}', '$savable');
      action = onScrollToUnresolved;
      icon = Icons.check_rounded;
    } else if (savable > 0) {
      label = t.get('photoSaveN').replaceAll('{n}', '$savable');
      action = onSave;
      icon = Icons.check_rounded;
    } else if (queue) {
      label = t.get('photoNext');
      action = onAdvance;
      icon = Icons.arrow_forward_rounded;
    } else {
      label = t.get('photoSaveN').replaceAll('{n}', '0');
      action = null;
      icon = Icons.check_rounded;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (counts.hasUnresolved && !analysing)
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: onScrollToUnresolved,
              icon: Icon(
                Icons.help_outline_rounded,
                size: 18,
                color: theme.colorScheme.tertiary,
              ),
              label: Text(
                t
                    .get('photoOneToChoose')
                    .replaceAll('{n}', '${counts.unresolved}'),
                style: TextStyle(color: theme.colorScheme.tertiary),
              ),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            ),
          ),
        VyroPrimaryButton(
          label: label,
          icon: icon,
          loading: saving,
          onPressed: action,
        ),
        if (queue || (counts.hasUnresolved && savable > 0))
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (queue && !saving)
                TextButton(
                  onPressed: analysing ? null : onAdvance,
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  child: Text(t.get('photoSkip')),
                ),
              if (counts.hasUnresolved && savable > 0 && !analysing)
                TextButton(
                  onPressed: saving ? null : onSave,
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  child: Text(
                    t.get('photoSaveOnly').replaceAll('{n}', '$savable'),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// The photo: rounded, with the source tag, a scan overlay while analysing,
/// and a small thumbnail of a second angle.
class _PhotoBlock extends StatelessWidget {
  const _PhotoBlock({
    required this.shot,
    required this.analysing,
    required this.draft,
    required this.source,
    required this.onRetake,
  });

  final ReviewShot shot;
  final bool analysing;
  final bool draft;
  final VisionSource? source;
  final VoidCallback? onRetake;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final bytes = shot.bytes;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 230,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
            else
              ColoredBox(color: theme.colorScheme.surfaceContainerHighest),
            if (!analysing)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),
            if (analysing)
              PhotoScanOverlay(
                label: t.get(draft ? 'photoStepConfirm' : 'photoStepIdentify'),
              ),
            if (!analysing && source != null)
              Positioned(
                left: 12,
                bottom: 10,
                child: _GlassTag(
                  icon: source == VisionSource.systemAi
                      ? Icons.auto_awesome_rounded
                      : Icons.grid_view_rounded,
                  label: t.get(
                    source == VisionSource.systemAi
                        ? 'photoSourceSystem'
                        : source == VisionSource.fused
                        ? 'photoSourceFused'
                        : 'photoSourceRegions',
                  ),
                ),
              ),
            if (shot.angle != null)
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white70),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(shot.angle!, fit: BoxFit.cover),
                ),
              ),
            if (!analysing)
              Positioned(
                right: 10,
                bottom: 8,
                child: IconButton.filledTonal(
                  tooltip: t.get('photoRetake'),
                  onPressed: onRetake,
                  icon: const Icon(Icons.photo_camera_outlined),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({
    required this.reason,
    required this.hint,
    required this.retryLabel,
    required this.onRetry,
  });
  final String reason;
  final String hint;
  final String retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: VyroCard(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(reason, style: theme.textTheme.bodySmall)),
              ],
            ),
            const SizedBox(height: 6),
            Text(hint, style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onCamera, required this.onGallery});
  final VoidCallback? onCamera;
  final VoidCallback? onGallery;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return VyroCard(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.restaurant_rounded, size: 34, color: accent),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            t.get('photoHeroTitle'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.get('photoHeroBody'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 22),
          if (kIsWeb)
            Text(t.get('photoNativeOnly'), textAlign: TextAlign.center)
          else ...[
            VyroPrimaryButton(
              label: t.get('takePhoto'),
              icon: Icons.photo_camera_outlined,
              onPressed: onCamera,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(t.get('choosePhoto')),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.get('photoLocalPrivacy'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlassTag extends StatelessWidget {
  const _GlassTag({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: Colors.white24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _QuickAddRow extends StatelessWidget {
  const _QuickAddRow({required this.foods, required this.onAdd});
  final List<FoodRef> foods;
  final ValueChanged<FoodRef> onAdd;

  @override
  Widget build(BuildContext context) {
    if (foods.isEmpty) return const SizedBox.shrink();
    final t = stringsOf(context);
    return ReviewChipRow(
      title: t.get('photoQuickAdd'),
      chips: [
        for (final food in foods)
          ActionChip(
            avatar: Icon(foodCategoryIcon(food.category), size: 16),
            label: Text(food.name(t.isEnglish)),
            onPressed: () => onAdd(food),
          ),
      ],
    );
  }
}

/// Collapsed by default: the model's raw answer, the timing line and the
/// fallback error, so a wrong suggestion can be understood and reported.
class _AnalysisDetail extends StatelessWidget {
  const _AnalysisDetail({required this.detail});
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(
          stringsOf(context).get('photoDetail'),
          style: theme.textTheme.bodySmall,
        ),
        children: [
          SelectableText(
            detail,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: VyroCard(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
          ],
        ),
      ),
    );
  }
}
