import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../app/theme/vyro_chrome.dart';
import '../../app/theme/vyro_shell.dart';
import '../../app/theme/vyro_theme.dart';
import '../../core/database/app_database.dart';
import '../nutrition/domain/food_product.dart';
import '../nutrition/domain/portion.dart';
import '../nutrition/meals.dart';
import '../nutrition/portion_labels.dart';

/// Confirms a scanned product and how much was eaten.
///
/// The amount can be entered in servings, units (bars, yoghurts…), whole
/// packages or grams. Every choice is converted to grams, and calories are
/// always per-100 g values × grams — the barcode itself carries no nutrients.
class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.product,
    required this.day,
    this.initialMeal,
  });
  final FoodProduct product;
  final DateTime day;
  final String? initialMeal;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late List<PortionOption> _options;
  late PortionOption _selected;
  final _count = TextEditingController();
  final _unitWeight = TextEditingController();
  late String _meal;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _options = portionOptionsFor(widget.product);
    _selected = defaultPortion(_options);
    _meal = widget.initialMeal ?? mealForTime(DateTime.now());
  }

  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Number formatting depends on the locale, which is only readable here.
    if (_initialised) return;
    _initialised = true;
    _count.text = _format(defaultCount(_selected.kind));
    if (_selected.gramsPerUnit != null && _selected.kind != PortionKind.grams) {
      _unitWeight.text = _format(_selected.gramsPerUnit!);
    }
  }

  @override
  void dispose() {
    _count.dispose();
    _unitWeight.dispose();
    super.dispose();
  }

  bool get _english => stringsOf(context).isEnglish;

  String _format(double value) =>
      formatAmount(value, english: stringsOf(context).isEnglish);

  double? get _countValue =>
      double.tryParse(_count.text.trim().replaceAll(',', '.'));

  double? get _grams {
    final count = _countValue;
    return count == null ? null : gramsFor(_selected, count);
  }

  void _select(PortionOption option) {
    if (option.kind == _selected.kind) return;
    setState(() {
      _selected = option;
      _count.text = _format(defaultCount(option.kind));
      _unitWeight.text = option.gramsPerUnit == null
          ? ''
          : _format(option.gramsPerUnit!);
    });
  }

  void _setCount(double value) {
    final min = _selected.kind == PortionKind.grams ? 1.0 : 0.25;
    final clamped = value.clamp(min, 9999.0);
    setState(() => _count.text = _format(clamped));
  }

  void _setUnitWeight(String raw) {
    final grams = double.tryParse(raw.trim().replaceAll(',', '.'));
    setState(() {
      final updated = grams != null && grams > 0
          ? _selected.withGrams(grams)
          : PortionOption(
              kind: _selected.kind,
              gramsPerUnit: null,
              declared: false,
            );
      _options = [
        for (final option in _options)
          option.kind == _selected.kind ? updated : option,
      ];
      _selected = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final p = widget.product;
    final grams = _grams;
    final kcal = grams == null
        ? null
        : nutrientForPortion(p.kcalPer100g, grams);
    return VyroSubpageScaffold(
      title: t.get('product'),
      footer: VyroPrimaryButton(
        label: kcal == null
            ? t.get('addToDiary')
            : '${t.get('addToDiary')} · ${kcal.round()} kcal',
        icon: Icons.check_rounded,
        loading: _saving,
        onPressed: grams == null ? null : _addToDiary,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _ProductHero(product: p),
          const SizedBox(height: 22),
          VyroSectionTitle(label: t.get('howMuch')),
          _PortionChips(
            options: _options,
            selected: _selected,
            liquid: p.liquid,
            onSelect: _select,
          ),
          const SizedBox(height: 14),
          VyroCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AmountStepper(
                  controller: _count,
                  caption: _selected.kind == PortionKind.grams
                      ? massUnit(liquid: p.liquid)
                      : portionNoun(t, _selected.kind, _countValue ?? 0),
                  onMinus: () =>
                      _setCount((_countValue ?? 0) - stepFor(_selected.kind)),
                  onPlus: () =>
                      _setCount((_countValue ?? 0) + stepFor(_selected.kind)),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                _QuickAmounts(
                  values: _selected.kind == PortionKind.grams
                      ? const [50, 100, 150, 200]
                      : const [0.5, 1, 2, 3],
                  current: _countValue,
                  english: _english,
                  onPick: _setCount,
                ),
                if (_selected.kind != PortionKind.grams) ...[
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 12),
                  _UnitWeightRow(
                    option: _selected,
                    liquid: p.liquid,
                    controller: _unitWeight,
                    onChanged: _setUnitWeight,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _NutritionResult(product: p, grams: grams),
          const SizedBox(height: 22),
          VyroSectionTitle(label: t.get('meal')),
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
          Text(
            t.get('offAttribution'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Future<void> _addToDiary() async {
    final grams = _grams;
    final count = _countValue;
    if (grams == null || count == null) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final t = stringsOf(context);
    try {
      await AppServicesScope.of(context).nutritionRepository.addEntry(
        FoodEntriesCompanion.insert(
          day: dayKey(widget.day),
          mealType: _meal,
          name: widget.product.name,
          brand: Value(widget.product.brand),
          quantityGrams: grams,
          kcalPer100g: Value(widget.product.kcalPer100g),
          proteinPer100g: Value(widget.product.proteinPer100g),
          carbsPer100g: Value(widget.product.carbsPer100g),
          fatPer100g: Value(widget.product.fatPer100g),
          source: const Value('open_food_facts'),
          portionUnit: Value(_selected.kind.key),
          portionCount: Value(count),
        ),
      );
      messenger?.showSnackBar(SnackBar(content: Text(t.get('addedToDiary'))));
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ProductHero extends StatelessWidget {
  const _ProductHero({required this.product});
  final FoodProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = stringsOf(context);
    final accent = theme.colorScheme.primary;
    final meta = [
      if (product.brand != null) product.brand!,
      if (product.quantity != null) product.quantity!,
    ].join(' · ');
    return VyroCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              product.liquid
                  ? Icons.local_drink_outlined
                  : Icons.inventory_2_outlined,
              color: VyroTheme.accentTextOf(context),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: theme.textTheme.titleLarge),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(meta, style: theme.textTheme.bodySmall),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.barcode_reader,
                      size: 14,
                      color: theme.textTheme.labelSmall?.color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      product.barcode,
                      semanticsLabel: '${t.get('barcode')} ${product.barcode}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (product.nutriScore != null)
            _NutriScoreBadge(grade: product.nutriScore!),
        ],
      ),
    );
  }
}

class _NutriScoreBadge extends StatelessWidget {
  const _NutriScoreBadge({required this.grade});
  final String grade;

  @override
  Widget build(BuildContext context) {
    final letter = grade.toUpperCase();
    final color = switch (letter) {
      'A' => const Color(0xFF1E8F4E),
      'B' => const Color(0xFF7AC143),
      'C' => const Color(0xFFF5C400),
      'D' => const Color(0xFFEF7D00),
      'E' => const Color(0xFFE63E11),
      _ => Theme.of(context).colorScheme.outline,
    };
    return Semantics(
      label: 'Nutri-Score $letter',
      child: ExcludeSemantics(
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: letter == 'C' ? VyroTheme.ink : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Nutri-Score',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 8.5,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortionChips extends StatelessWidget {
  const _PortionChips({
    required this.options,
    required this.selected,
    required this.liquid,
    required this.onSelect,
  });
  final List<PortionOption> options;
  final PortionOption selected;
  final bool liquid;
  final ValueChanged<PortionOption> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Builder(
              builder: (context) {
                final option = options[i];
                final active = option.kind == selected.kind;
                final weight = option.kind == PortionKind.grams
                    ? '100 ${massUnit(liquid: liquid)}'
                    : option.gramsPerUnit == null
                    ? '— ${massUnit(liquid: liquid)}'
                    : '${formatAmount(option.gramsPerUnit!, english: t.isEnglish)} ${massUnit(liquid: liquid)}';
                return Semantics(
                  button: true,
                  selected: active,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      color: active
                          ? scheme.primary.withValues(alpha: dark ? 0.14 : 0.16)
                          : (dark ? const Color(0xFF15181E) : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: active ? scheme.primary : scheme.outline,
                        width: active ? 1.5 : 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onSelect(option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 4,
                          ),
                          child: Column(
                            children: [
                              Text(
                                portionKindName(t, option.kind, liquid: liquid),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: active
                                      ? VyroTheme.accentTextOf(context)
                                      : scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                weight,
                                maxLines: 1,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11.5,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _AmountStepper extends StatelessWidget {
  const _AmountStepper({
    required this.controller,
    required this.caption,
    required this.onMinus,
    required this.onPlus,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String caption;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = stringsOf(context);
    return Row(
      children: [
        _StepButton(icon: Icons.remove_rounded, tooltip: '−', onTap: onMinus),
        Expanded(
          child: Column(
            children: [
              TextField(
                controller: controller,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: onChanged,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontSize: 40,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  semanticCounterText: t.get('quantity'),
                ),
              ),
              Text(caption, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        _StepButton(icon: Icons.add_rounded, tooltip: '+', onTap: onPlus),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.primary.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: VyroTheme.accentTextOf(context)),
          ),
        ),
      ),
    );
  }
}

class _QuickAmounts extends StatelessWidget {
  const _QuickAmounts({
    required this.values,
    required this.current,
    required this.english,
    required this.onPick,
  });
  final List<double> values;
  final double? current;
  final bool english;
  final ValueChanged<double> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => onPick(values[i]),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
                backgroundColor: current == values[i]
                    ? scheme.primary.withValues(alpha: 0.14)
                    : null,
                side: BorderSide(
                  color: current == values[i] ? scheme.primary : scheme.outline,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                values[i] == 0.5
                    ? '½'
                    : formatAmount(values[i], english: english),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _UnitWeightRow extends StatefulWidget {
  const _UnitWeightRow({
    required this.option,
    required this.liquid,
    required this.controller,
    required this.onChanged,
  });
  final PortionOption option;
  final bool liquid;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<_UnitWeightRow> createState() => _UnitWeightRowState();
}

class _UnitWeightRowState extends State<_UnitWeightRow> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final option = widget.option;
    final unit = massUnit(liquid: widget.liquid);
    final label = switch (option.kind) {
      PortionKind.serving => t.get('weightPerServing'),
      PortionKind.package => t.get('weightPerPackage'),
      _ => t.get('weightPerUnit'),
    };
    final missing = option.gramsPerUnit == null;
    if (missing || _editing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.controller,
            autofocus: _editing,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              labelText: label,
              suffixText: unit,
              prefixIcon: const Icon(Icons.scale_outlined),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t.get(missing ? 'portionEnterWeight' : 'portionNotDeclared'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        Icon(
          Icons.scale_outlined,
          size: 18,
          color: theme.textTheme.bodySmall?.color,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1 ${portionNoun(t, option.kind, 1)} = '
                '${formatAmount(option.gramsPerUnit!, english: t.isEnglish)} $unit',
                style: theme.textTheme.titleSmall,
              ),
              Text(
                t.get(
                  option.declared ? 'portionDeclared' : 'portionNotDeclared',
                ),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () => setState(() {
            widget.controller.text = formatAmount(
              option.gramsPerUnit!,
              english: t.isEnglish,
            );
            _editing = true;
          }),
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: Text(t.get('edit')),
        ),
      ],
    );
  }
}

class _NutritionResult extends StatelessWidget {
  const _NutritionResult({required this.product, required this.grams});
  final FoodProduct product;
  final double? grams;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final g = grams;
    String amount(double? per100) {
      final value = g == null ? null : nutrientForPortion(per100, g);
      return value == null
          ? '—'
          : formatAmount((value * 10).round() / 10, english: t.isEnglish);
    }

    final kcal = g == null ? null : nutrientForPortion(product.kcalPer100g, g);
    final unit = massUnit(liquid: product.liquid);
    return VyroCard(
      tint: scheme.primary.withValues(alpha: dark ? 0.07 : 0.09),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${t.get('forThisAmount')} · ${g == null ? '—' : formatAmount(g.roundToDouble(), english: t.isEnglish)} $unit',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        text: kcal == null ? '—' : kcal.round().toString(),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        children: [
                          TextSpan(
                            text: ' kcal',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                product.kcalPer100g == null
                    ? t.get('notAvailable')
                    : '${product.kcalPer100g!.round()} kcal ${t.get(product.liquid ? 'per100ml' : 'per100g')}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Macro(
                label: t.get('protein'),
                value: amount(product.proteinPer100g),
                color: scheme.primary,
              ),
              _Macro(
                label: t.get('carbs'),
                value: amount(product.carbsPer100g),
                color: scheme.tertiary,
              ),
              _Macro(
                label: t.get('fat'),
                value: amount(product.fatPer100g),
                color: scheme.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 4,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value g',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
