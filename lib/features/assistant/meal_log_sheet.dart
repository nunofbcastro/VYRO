import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../core/database/app_database.dart';
import '../../core/ui/vyro_ui.dart';
import '../nutrition/domain/food_product.dart';
import '../nutrition/domain/local_food_reference.dart';
import '../nutrition/meals.dart';
import 'domain/meal_proposal.dart';

/// Review sheet for a meal the assistant proposed. Nutrients never come from
/// the model: each item is matched to the local USDA reference or the user's
/// own history, or looked up on Open Food Facts / typed by the user. Nothing
/// is saved until the user confirms.
Future<int?> showMealLogSheet(BuildContext context, MealProposal proposal) =>
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _MealLogSheet(proposal: proposal),
    );

class _Row {
  _Row(this.item)
    : grams = TextEditingController(text: item.grams.round().toString());
  final ProposedItem item;
  final TextEditingController grams;
  NutrientSource? source;
  bool include = true;

  double get gramsValue =>
      double.tryParse(grams.text.trim().replaceAll(',', '.')) ?? 0;
}

class _MealLogSheet extends StatefulWidget {
  const _MealLogSheet({required this.proposal});
  final MealProposal proposal;

  @override
  State<_MealLogSheet> createState() => _MealLogSheetState();
}

class _MealLogSheetState extends State<_MealLogSheet> {
  late final List<_Row> _rows = [
    for (final item in widget.proposal.items) _Row(item),
  ];
  late String _meal = widget.proposal.meal ?? mealForTime(DateTime.now());
  bool _matched = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_matched) {
      _matched = true;
      _match();
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.grams.dispose();
    }
    super.dispose();
  }

  Future<void> _match() async {
    final english = stringsOf(context).isEnglish;
    final services = AppServicesScope.of(context);
    final local = [
      for (final ref in localFoodReference)
        NutrientSource(
          label: ref.name(english),
          origin: 'local_reference',
          kcal: ref.kcal,
          protein: ref.protein,
          carbs: ref.carbs,
          fat: ref.fat,
          sourceKey: 'local_reference_${ref.fdcId}',
        ),
    ];
    final seen = <String>{};
    final history = <NutrientSource>[];
    for (final e in await services.database.recentFoodEntries()) {
      if (e.kcalPer100g == null || !seen.add(e.name.toLowerCase())) continue;
      history.add(
        NutrientSource(
          label: e.name,
          origin: 'history',
          kcal: e.kcalPer100g,
          protein: e.proteinPer100g,
          carbs: e.carbsPer100g,
          fat: e.fatPer100g,
          sourceKey: e.source,
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      for (final row in _rows) {
        row.source =
            bestMatch(row.item.name, local) ??
            bestMatch(row.item.name, history);
      }
    });
  }

  double _sum(double? Function(NutrientSource) pick) {
    var total = 0.0;
    for (final row in _rows) {
      final source = row.source;
      if (!row.include || source == null) continue;
      total += nutrientForPortion(pick(source), row.gramsValue) ?? 0;
    }
    return total;
  }

  Future<void> _search(_Row row) async {
    final picked = await showDialog<FoodProduct>(
      context: context,
      builder: (_) => _OffSearchDialog(initial: row.item.name),
    );
    if (picked == null) return;
    setState(
      () => row.source = NutrientSource(
        label: picked.name,
        origin: 'open_food_facts',
        kcal: picked.kcalPer100g,
        protein: picked.proteinPer100g,
        carbs: picked.carbsPer100g,
        fat: picked.fatPer100g,
        sourceKey: 'open_food_facts',
      ),
    );
  }

  Future<void> _manual(_Row row) async {
    final t = stringsOf(context);
    final controller = TextEditingController();
    final kcal = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(row.item.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: InputDecoration(labelText: t.get('kcalPer100')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: Text(t.get('save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (kcal == null || kcal < 0) return;
    setState(
      () => row.source = NutrientSource(
        label: row.item.name,
        origin: 'manual',
        kcal: kcal,
        sourceKey: 'manual',
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repository = AppServicesScope.of(context).nutritionRepository;
    var added = 0;
    for (final row in _rows) {
      final grams = row.gramsValue;
      if (!row.include || grams <= 0) continue;
      final s = row.source;
      await repository.addEntry(
        FoodEntriesCompanion.insert(
          day: dayKey(DateTime.now()),
          mealType: _meal,
          name: row.item.name,
          quantityGrams: grams,
          kcalPer100g: Value(s?.kcal),
          proteinPer100g: Value(s?.protein),
          carbsPer100g: Value(s?.carbs),
          fatPer100g: Value(s?.fat),
          source: Value(s?.sourceKey ?? 'assistant'),
          portionUnit: const Value('grams'),
          portionCount: Value(grams),
        ),
      );
      added++;
    }
    if (mounted) Navigator.pop(context, added);
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final kcal = _sum((s) => s.kcal);
    final protein = _sum((s) => s.protein);
    final missing = _rows.where((r) => r.include && r.source == null).length;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              children: [
                Text(
                  t.get('logMealTitle'),
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(t.get('logMealNote'), style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                for (final row in _rows) ...[
                  _ItemRow(
                    row: row,
                    onChanged: () => setState(() {}),
                    onSearch: () => _search(row),
                    onManual: () => _manual(row),
                  ),
                  const SizedBox(height: 10),
                ],
                VyroCard(
                  radius: 18,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${kcal.round()} kcal · ${protein.round()} g ${t.get('protein').toLowerCase()}',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (missing > 0)
                        Text(
                          '$missing ${t.get('logMealMissing')}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          VyroFooter(
            elevated: true,
            child: VyroPrimaryButton(
              label: t.get('addToDiary'),
              icon: Icons.check_rounded,
              loading: _saving,
              onPressed: _rows.any((r) => r.include) ? _save : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.row,
    required this.onChanged,
    required this.onSearch,
    required this.onManual,
  });

  final _Row row;
  final VoidCallback onChanged;
  final VoidCallback onSearch;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final s = row.source;
    final kcal = s == null ? null : nutrientForPortion(s.kcal, row.gramsValue);
    final origin = switch (s?.origin) {
      'local_reference' => t.get('originLocal'),
      'history' => t.get('originHistory'),
      'open_food_facts' => 'Open Food Facts',
      'manual' => t.get('mealSourceManual'),
      _ => t.get('originNone'),
    };
    return Opacity(
      opacity: row.include ? 1 : 0.45,
      child: VyroCard(
        radius: 18,
        padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
        child: Row(
          children: [
            Checkbox(
              value: row.include,
              onChanged: (v) {
                row.include = v ?? true;
                onChanged();
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.item.name, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    s == null
                        ? origin
                        : '$origin · ${kcal?.round() ?? '—'} kcal',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: s == null ? theme.colorScheme.tertiary : null,
                    ),
                  ),
                  if (s == null)
                    Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          onPressed: onSearch,
                          child: Text(t.get('lookup')),
                        ),
                        TextButton(
                          onPressed: onManual,
                          child: Text(t.get('manualShort')),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 74,
              child: TextField(
                controller: row.grams,
                textAlign: TextAlign.end,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(
                  isDense: true,
                  suffixText: 'g',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OffSearchDialog extends StatefulWidget {
  const _OffSearchDialog({required this.initial});
  final String initial;

  @override
  State<_OffSearchDialog> createState() => _OffSearchDialogState();
}

class _OffSearchDialogState extends State<_OffSearchDialog> {
  late final _query = TextEditingController(text: widget.initial);
  List<FoodProduct>? _results;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final services = AppServicesScope.of(context);
    final t = stringsOf(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await services.productLookupRepository.searchByName(
        _query.text,
        languageCode: t.isEnglish ? 'en' : 'pt',
      );
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) setState(() => _error = t.get('lookupOffline'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final results = _results ?? const <FoodProduct>[];
    return AlertDialog(
      title: Text(t.get('lookup')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _run(),
              decoration: InputDecoration(
                suffixIcon: IconButton(
                  onPressed: _loading ? null : _run,
                  icon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else if (_error != null)
              Text(_error!, style: TextStyle(color: theme.colorScheme.error))
            else if (_results != null && results.isEmpty)
              Text(t.get('productNotFound'))
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in results)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          [
                            if (p.brand != null) p.brand!,
                            '${p.kcalPer100g!.round()} kcal / 100 g',
                          ].join(' · '),
                        ),
                        onTap: () => Navigator.pop(context, p),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(t.get('offAttribution'), style: theme.textTheme.labelSmall),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.get('cancel')),
        ),
      ],
    );
  }
}
