import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../core/database/app_database.dart';
import '../../core/platform/image_temp_file.dart';
import '../../core/ui/vyro_ui.dart';
import 'data/food_database.dart';
import 'domain/food_product.dart' show dayKey;
import 'food_vision/food_vision.dart';
import 'food_vision/region_food_vision.dart';
import 'food_vision/system_food_vision.dart';
import 'meals.dart';
import 'widgets/food_picker_sheet.dart';

/// Photo → foods → grams → diary. Recognition runs on the device
/// ([FoodVisionPipeline]); nutrients come from the offline database and
/// every food and amount is confirmed by the user before saving.
class PhotoFoodPage extends StatefulWidget {
  const PhotoFoodPage({super.key, this.day});
  final DateTime? day;

  @override
  State<PhotoFoodPage> createState() => _PhotoFoodPageState();
}

/// One editable line of the review list.
class _Item {
  _Item(this.detected) : grams = detected.grams;
  DetectedFood detected;
  double grams;

  FoodRef? get food => detected.food;
  double? get kcal => food == null ? null : food!.kcal * grams / 100;
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

List<String> _quickKeysFor(String meal, List<_Item> items) {
  final breakfastLike =
      meal == 'breakfast' ||
      meal == 'snack' ||
      items.any((i) => i.food?.category == 'padaria');
  return breakfastLike
      ? [..._breakfastQuickKeys, ..._plateQuickKeys]
      : [..._plateQuickKeys, ..._breakfastQuickKeys];
}

class _PhotoFoodPageState extends State<PhotoFoodPage> {
  final _picker = ImagePicker();
  FoodDatabase? _db;
  Uint8List? _photo;
  List<_Item>? _items;
  FoodVisionResult? _result;
  late String _meal = mealForTime(DateTime.now());
  bool _busy = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    FoodDatabase.load().then((db) {
      if (mounted) setState(() => _db = db);
    });
  }

  @override
  void dispose() {
    _photo = null; // the photo lives in memory only
    super.dispose();
  }

  // ------------------------------------------------------------ actions

  Future<void> _choose(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      // The picker's temporary file is deleted as soon as bytes are read.
      await deleteTemporaryImage(file.path);
      if (!mounted) return;
      setState(() {
        _photo = bytes;
        _items = null;
        _result = null;
        _error = null;
        _busy = true;
      });
      await _analyse(bytes);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'cameraError';
          _busy = false;
        });
      }
    }
  }

  Future<void> _analyse(Uint8List bytes) async {
    final services = AppServicesScope.of(context);
    try {
      final db = _db ?? await FoodDatabase.load();
      final pipeline = FoodVisionPipeline(
        llm: services.llm,
        system: SystemFoodVision(db),
        regions: RegionFoodVision(db),
      );
      final result = await pipeline.analyse(bytes);
      if (!mounted) return;
      setState(() {
        _db = db;
        _result = result;
        _items = [for (final f in result.foods) _Item(f)];
      });
    } on FormatException {
      if (mounted) setState(() => _error = 'photoInvalidImage');
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'photoModelError';
          _items = [];
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _change(_Item item) async {
    final db = _db;
    if (db == null) return;
    final food = await showFoodPicker(
      context,
      db,
      initialQuery: item.food == null ? item.detected.label : '',
    );
    if (food == null || !mounted) return;
    setState(() {
      item.detected = item.detected.copyWith(
        food: food,
        source: VisionSource.user,
      );
      // An unmatched line had no sensible amount yet: use the food's portion.
      if (item.food == null) item.grams = food.portionG;
    });
  }

  Future<void> _addFromPicker() async {
    final db = _db;
    if (db == null) return;
    final food = await showFoodPicker(context, db);
    if (food != null) _addFood(food);
  }

  void _addFood(FoodRef food) {
    setState(
      () => (_items ??= []).add(
        _Item(
          DetectedFood(
            food: food,
            label: food.namePt,
            grams: food.portionG,
            source: VisionSource.user,
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final items = _items ?? const <_Item>[];
    final ready = items.where((i) => i.food != null && i.grams > 0).toList();
    if (ready.isEmpty) return;
    final t = stringsOf(context);
    final repository = AppServicesScope.of(context).nutritionRepository;
    setState(() => _saving = true);
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.get('photoSaved').replaceAll('{n}', '${ready.length}')),
      ),
    );
    Navigator.pop(context);
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final items = _items;
    final ready = items?.where((i) => i.food != null && i.grams > 0) ?? [];
    return VyroSubpageScaffold(
      title: t.get('photo'),
      footer: items == null || items.isEmpty
          ? null
          : VyroPrimaryButton(
              label: t.get('photoSaveN').replaceAll('{n}', '${ready.length}'),
              icon: Icons.check_rounded,
              loading: _saving,
              onPressed: ready.isEmpty || _saving ? null : _save,
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          if (_photo == null)
            _Hero(onPick: kIsWeb || _busy ? null : _choose)
          else
            _PhotoHeader(
              photo: _photo!,
              busy: _busy,
              source: _result?.source,
              onRetake: _busy ? null : () => _choose(ImageSource.camera),
              onGallery: _busy ? null : () => _choose(ImageSource.gallery),
            ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _Notice(
              icon: Icons.info_outline_rounded,
              text: '${t.get(_error!)} ${t.get('photoManualFallback')}',
            ),
          ],
          if (items != null && !_busy) ...[
            const SizedBox(height: 18),
            _Totals(items: items),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final meal in mealTypes)
                  VyroPillChip(
                    label: mealLabel(t, meal),
                    selected: _meal == meal,
                    onTap: () => setState(() => _meal = meal),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            VyroSectionTitle(
              label: '${t.get('photoFoundFoods')} · ${items.length}',
            ),
            if (_result?.source == VisionSource.regionClassifier)
              _Notice(
                icon: Icons.auto_awesome_outlined,
                text: t.get(
                  _result?.note == 'systemFailed'
                      ? 'photoSystemFailedNote'
                      : 'photoRegionsNote',
                ),
              ),
            if (items.isEmpty)
              _Notice(
                icon: Icons.search_off_rounded,
                text: t.get('photoNothingFound'),
              ),
            for (final item in items) ...[
              const SizedBox(height: 10),
              VyroFadeSlideIn(
                key: ObjectKey(item),
                child: _FoodRow(
                  item: item,
                  onChange: () => _change(item),
                  onGrams: (g) => setState(() => item.grams = g),
                  onRemove: () => setState(() => items.remove(item)),
                ),
              ),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _db == null ? null : _addFromPicker,
              icon: const Icon(Icons.add_rounded),
              label: Text(t.get('photoAddFood')),
            ),
            if (_db case final db?) ...[
              const SizedBox(height: 14),
              _QuickAdd(
                foods: [
                  for (final key in _quickKeysFor(_meal, items))
                    if (db.byKey(key) case final food?)
                      if (!items.any((i) => i.food?.key == key)) food,
                ].take(8).toList(),
                onAdd: _addFood,
              ),
            ],
            const SizedBox(height: 22),
            Text(
              '${t.get('photoEstimateNote')}\n${t.get('nutritionSourcesNote')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_result?.detail case final detail?) ...[
              const SizedBox(height: 8),
              _AnalysisDetail(detail: detail),
            ],
          ],
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onPick});
  final ValueChanged<ImageSource>? onPick;

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
              onPressed: onPick == null
                  ? null
                  : () => onPick!(ImageSource.camera),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onPick == null
                  ? null
                  : () => onPick!(ImageSource.gallery),
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

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({
    required this.photo,
    required this.busy,
    required this.source,
    required this.onRetake,
    required this.onGallery,
  });

  final Uint8List photo;
  final bool busy;
  final VisionSource? source;
  final VoidCallback? onRetake;
  final VoidCallback? onGallery;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 230,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(photo, fit: BoxFit.cover, gaplessPlayback: true),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: busy ? 0.6 : 0.45),
                  ],
                ),
              ),
            ),
            if (busy)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t.get('photoAnalyzing'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else
              Positioned(
                left: 14,
                right: 10,
                bottom: 10,
                child: Row(
                  children: [
                    // Expanded (not Flexible + Spacer) so the tag gets all
                    // the free width and is not cut to "IA do tel…".
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: source == null
                            ? null
                            : _GlassTag(
                                icon: source == VisionSource.systemAi
                                    ? Icons.auto_awesome_rounded
                                    : Icons.grid_view_rounded,
                                label: t.get(
                                  source == VisionSource.systemAi
                                      ? 'photoSourceSystem'
                                      : 'photoSourceRegions',
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: t.get('choosePhoto'),
                      onPressed: onGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                    ),
                    IconButton.filledTonal(
                      tooltip: t.get('photoRetake'),
                      onPressed: onRetake,
                      icon: const Icon(Icons.photo_camera_outlined),
                    ),
                  ],
                ),
              ),
          ],
        ),
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

/// Meal totals: kcal and macros of the matched foods.
class _Totals extends StatelessWidget {
  const _Totals({required this.items});
  final List<_Item> items;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    double sum(double Function(FoodRef) pick) => items.fold(
      0,
      (total, i) =>
          total + (i.food == null ? 0 : pick(i.food!) * i.grams / 100),
    );
    final kcal = sum((f) => f.kcal);
    final macros = [
      (t.get('protein'), sum((f) => f.protein), scheme.primary),
      (t.get('carbs'), sum((f) => f.carbs), scheme.tertiary),
      (t.get('fat'), sum((f) => f.fat), scheme.secondary),
    ];
    final grams = items.fold<double>(0, (total, i) => total + i.grams);
    return VyroCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              VyroAnimatedNumber(
                value: kcal,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('kcal', style: theme.textTheme.titleMedium),
              ),
              const Spacer(),
              Text(
                '≈ ${grams.round()} g',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final (label, value, color) in macros)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${value.round()} g',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FoodRow extends StatefulWidget {
  const _FoodRow({
    required this.item,
    required this.onChange,
    required this.onGrams,
    required this.onRemove,
  });

  final _Item item;
  final VoidCallback onChange;
  final ValueChanged<double> onGrams;
  final VoidCallback onRemove;

  @override
  State<_FoodRow> createState() => _FoodRowState();
}

class _FoodRowState extends State<_FoodRow> {
  late final _grams = TextEditingController(text: _format(widget.item.grams));
  final _focus = FocusNode();

  static String _format(double g) => g.round().toString();

  @override
  void didUpdateWidget(_FoodRow old) {
    super.didUpdateWidget(old);
    final text = _format(widget.item.grams);
    if (!_focus.hasFocus && _grams.text != text) _grams.text = text;
  }

  @override
  void dispose() {
    _grams.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _step(int direction) {
    final step = widget.item.grams >= 200 ? 25.0 : 10.0;
    final next = (widget.item.grams + direction * step).clamp(0.0, 2000.0);
    _grams.text = _format(next);
    widget.onGrams(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = widget.item;
    final food = item.food;
    final detected = item.detected;
    final accent = food == null ? scheme.tertiary : scheme.primary;
    final details = food == null
        ? t.get('photoNoMatchRow')
        : [
            '${food.kcal.round()} kcal/100 g',
            foodSourceTag(food),
            if (detected.count != null && detected.count! > 1)
              '${detected.count} ${t.get('pieces')}',
            if (detected.confidence != null)
              '${(detected.confidence! * 100).round()}% ${t.get('photoConfidence')}',
          ].join(' · ');
    return VyroCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onChange,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: accent.withValues(alpha: 0.13),
                  child: Icon(
                    food == null
                        ? Icons.help_outline_rounded
                        : foodCategoryIcon(food.category),
                    size: 21,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              food?.name(t.isEnglish) ?? detected.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.unfold_more_rounded,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        details,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: food == null ? scheme.tertiary : null,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: t.get('delete'),
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 54),
              _StepButton(icon: Icons.remove_rounded, onTap: () => _step(-1)),
              SizedBox(
                width: 78,
                child: TextField(
                  controller: _grams,
                  focusNode: _focus,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onChanged: (text) => widget.onGrams(
                    double.tryParse(text.replaceAll(',', '.')) ?? 0,
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    suffixText: 'g',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              _StepButton(icon: Icons.add_rounded, onTap: () => _step(1)),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  item.kcal == null ? '— kcal' : '${item.kcal!.round()} kcal',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    visualDensity: VisualDensity.compact,
    icon: Icon(icon, size: 20),
    style: IconButton.styleFrom(
      side: BorderSide(color: Theme.of(context).colorScheme.outline),
    ),
  );
}

class _QuickAdd extends StatelessWidget {
  const _QuickAdd({required this.foods, required this.onAdd});
  final List<FoodRef> foods;
  final ValueChanged<FoodRef> onAdd;

  @override
  Widget build(BuildContext context) {
    if (foods.isEmpty) return const SizedBox.shrink();
    final t = stringsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.get('photoQuickAdd'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final food in foods)
              ActionChip(
                avatar: Icon(foodCategoryIcon(food.category), size: 16),
                label: Text(food.name(t.isEnglish)),
                onPressed: () => onAdd(food),
              ),
          ],
        ),
      ],
    );
  }
}

/// Collapsed by default: the model's raw answer or the fallback error, so a
/// wrong suggestion can be understood and reported.
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
