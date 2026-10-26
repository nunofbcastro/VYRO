import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app.dart';
import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../core/ui/vyro_ui.dart';
import '../../core/database/app_database.dart';
import 'domain/food_product.dart';
import 'meals.dart';
import 'nutrition_targets_page.dart';
import 'portion_labels.dart';

class NutritionDiaryPage extends StatefulWidget {
  const NutritionDiaryPage({super.key});

  @override
  State<NutritionDiaryPage> createState() => _NutritionDiaryPageState();
}

class _NutritionDiaryPageState extends State<NutritionDiaryPage> {
  DateTime selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final services = AppServicesScope.of(context);
    final profile =
        SettingsScope.maybeOf(context)?.profile ?? const VyroProfile();
    final day = dayKey(selectedDay);
    return VyroPageScaffold(
      title: t.get('nutrition'),
      eyebrow: dayLabel(t, selectedDay),
      actions: [
        VyroRoundButton(
          icon: Icons.menu_book_outlined,
          tooltip: t.isEnglish ? 'Your recipes' : 'Receitas habituais',
          onPressed: () => Navigator.pushNamed(
            context,
            '/local-intelligence',
            arguments: selectedDay,
          ),
        ),
        VyroRoundButton(
          icon: Icons.barcode_reader,
          tooltip: t.get('scan'),
          onPressed: () => _openScanner(context),
        ),
      ],
      body: StreamBuilder<List<FoodEntryRecord>>(
        stream: services.nutritionRepository.watchEntriesForDay(day),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? const <FoodEntryRecord>[];
          if (snapshot.hasError) {
            return Center(child: Text(t.get('error')));
          }
          final partial = entries.any(
            (entry) =>
                entry.kcalPer100g == null ||
                entry.proteinPer100g == null ||
                entry.carbsPer100g == null ||
                entry.fatPer100g == null,
          );
          return VyroPageBody(
            children: [
              _DaySelector(
                day: selectedDay,
                onChanged: (value) => setState(() => selectedDay = value),
              ),
              const SizedBox(height: 14),
              _DailySummary(entries: entries, profile: profile),
              const NutritionTargetsLink(),
              if (partial) ...[
                const SizedBox(height: 8),
                Text(
                  t.get('totalsPartial'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 14),
              QuickLogRow(
                onScan: () => _openScanner(context),
                onPhoto: () => Navigator.pushNamed(
                  context,
                  '/photo-camera',
                  arguments: selectedDay,
                ),
                onManual: () => _editEntry(
                  context,
                  services,
                  day,
                  mealForTime(DateTime.now()),
                  null,
                ),
              ),
              const SizedBox(height: 22),
              for (final meal in mealTypes) ...[
                _MealCard(
                  mealType: meal,
                  entries: entries
                      .where((entry) => entry.mealType == meal)
                      .toList(),
                  onAdd: () => _editEntry(context, services, day, meal, null),
                  onEdit: (entry) =>
                      _editEntry(context, services, day, meal, entry),
                  onDelete: (entry) => _deleteEntry(context, services, entry),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 4),
              Text(
                t.get('offAttribution'),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          );
        },
      ),
    );
  }

  void _openScanner(BuildContext context) =>
      Navigator.pushNamed(context, '/barcode', arguments: selectedDay);

  Future<void> _editEntry(
    BuildContext context,
    AppServices services,
    String day,
    String meal,
    FoodEntryRecord? existing,
  ) async {
    final draft = await showModalBottomSheet<_FoodEntryDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _FoodEntrySheet(meal: meal, existing: existing),
    );
    if (draft == null) return;
    if (existing == null) {
      await services.nutritionRepository.addEntry(
        FoodEntriesCompanion.insert(
          day: day,
          mealType: draft.meal,
          name: draft.name,
          quantityGrams: draft.quantityGrams,
          kcalPer100g: Value(draft.kcalPer100g),
          proteinPer100g: Value(draft.proteinPer100g),
          carbsPer100g: Value(draft.carbsPer100g),
          fatPer100g: Value(draft.fatPer100g),
          source: Value(draft.source),
        ),
      );
    } else {
      // Keep "2 unidades" meaningful when only the grams were edited.
      final oldCount = existing.portionCount;
      final scaledCount = oldCount == null || existing.quantityGrams <= 0
          ? null
          : oldCount * draft.quantityGrams / existing.quantityGrams;
      await services.nutritionRepository.updateEntry(
        existing.copyWith(
          mealType: draft.meal,
          name: draft.name,
          quantityGrams: draft.quantityGrams,
          kcalPer100g: Value(draft.kcalPer100g),
          proteinPer100g: Value(draft.proteinPer100g),
          carbsPer100g: Value(draft.carbsPer100g),
          fatPer100g: Value(draft.fatPer100g),
          source: draft.source,
          portionCount: Value(scaledCount),
        ),
      );
    }
  }

  Future<void> _deleteEntry(
    BuildContext context,
    AppServices services,
    FoodEntryRecord entry,
  ) async {
    final t = stringsOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.get('deleteEntry')),
        content: Text(t.get('deleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.get('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.get('delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await services.nutritionRepository.deleteEntry(entry.id);
    }
  }
}

/// "Hoje", "Ontem", "Amanhã" or a short date.
String dayLabel(VyroStrings t, DateTime day) {
  final today = DateTime.now();
  final a = DateTime(day.year, day.month, day.day);
  final b = DateTime(today.year, today.month, today.day);
  final diff = a.difference(b).inDays;
  if (diff == 0) return t.get('todayShort');
  if (diff == -1) return t.get('yesterday');
  if (diff == 1) return t.get('tomorrow');
  return shortDate(t, day);
}

String shortDate(VyroStrings t, DateTime day) {
  final dd = day.day.toString().padLeft(2, '0');
  final mm = day.month.toString().padLeft(2, '0');
  return t.isEnglish ? '$mm/$dd/${day.year}' : '$dd/$mm/${day.year}';
}

/// Three equal shortcuts to log food: barcode, photo and manual entry.
class QuickLogRow extends StatelessWidget {
  const QuickLogRow({
    super.key,
    required this.onScan,
    required this.onPhoto,
    required this.onManual,
  });
  final VoidCallback onScan;
  final VoidCallback onPhoto;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    return Row(
      children: [
        Expanded(
          child: VyroActionTile(
            icon: Icons.barcode_reader,
            label: t.get('scanShort'),
            onTap: onScan,
            primary: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: VyroActionTile(
            icon: Icons.photo_camera_outlined,
            label: t.get('photoShort'),
            onTap: onPhoto,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: VyroActionTile(
            icon: Icons.edit_note_rounded,
            label: t.get('manualShort'),
            onTap: onManual,
          ),
        ),
      ],
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({required this.day, required this.onChanged});
  final DateTime day;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    return VyroCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          IconButton(
            tooltip: t.get('yesterday'),
            onPressed: () => onChanged(day.subtract(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: day,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) onChanged(picked);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 15,
                      color: VyroTheme.accentTextOf(context),
                    ),
                    const SizedBox(width: 8),
                    Text(dayLabel(t, day), style: theme.textTheme.titleSmall),
                    if (dayLabel(t, day) != shortDate(t, day)) ...[
                      Text(
                        '  ·  ${shortDate(t, day)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: t.get('tomorrow'),
            onPressed: () => onChanged(day.add(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _DailySummary extends StatelessWidget {
  const _DailySummary({required this.entries, required this.profile});
  final List<FoodEntryRecord> entries;
  final VyroProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final kcal = _sum(entries, (e) => e.kcalPer100g);
    final goal = profile.calorieGoal;
    final progress = goal <= 0 ? 0.0 : (kcal / goal).clamp(0.0, 1.0);
    return VyroCard(
      tint: scheme.primary.withValues(alpha: dark ? 0.06 : 0.08),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        children: [
          VyroRing(
            value: progress,
            size: 104,
            stroke: 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VyroAnimatedNumber(
                  value: kcal,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${t.get('ofGoal')} ${goal.round()}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: [
                VyroMacroBar(
                  label: t.get('protein'),
                  value: _sum(entries, (e) => e.proteinPer100g),
                  goal: profile.proteinGoal,
                  color: scheme.primary,
                ),
                const SizedBox(height: 10),
                VyroMacroBar(
                  label: t.get('carbs'),
                  value: _sum(entries, (e) => e.carbsPer100g),
                  goal: profile.carbsGoal,
                  color: scheme.tertiary,
                ),
                const SizedBox(height: 10),
                VyroMacroBar(
                  label: t.get('fat'),
                  value: _sum(entries, (e) => e.fatPer100g),
                  goal: profile.fatGoal,
                  color: scheme.secondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sum of known nutrient values; unknown values count as zero and the page
/// shows a "partial totals" note instead.
double _sum(
  List<FoodEntryRecord> entries,
  double? Function(FoodEntryRecord) getPer100g,
) {
  var total = 0.0;
  for (final entry in entries) {
    total += nutrientForPortion(getPer100g(entry), entry.quantityGrams) ?? 0;
  }
  return total;
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.mealType,
    required this.entries,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });
  final String mealType;
  final List<FoodEntryRecord> entries;
  final VoidCallback onAdd;
  final ValueChanged<FoodEntryRecord> onEdit;
  final ValueChanged<FoodEntryRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kcal = _sum(entries, (e) => e.kcalPer100g);
    return VyroCard(
      radius: 22,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    mealIcon(mealType),
                    size: 19,
                    color: VyroTheme.accentTextOf(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mealLabel(t, mealType),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        entries.isEmpty
                            ? t.get('mealEmpty')
                            : '${kcal.round()} kcal · ${entries.length}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '${t.get('add')} · ${mealLabel(t, mealType)}',
                  onPressed: onAdd,
                  icon: Icon(
                    Icons.add_circle_rounded,
                    size: 28,
                    color: VyroTheme.accentTextOf(context),
                  ),
                ),
              ],
            ),
          ),
          for (final entry in entries) ...[
            const Divider(indent: 16, endIndent: 16),
            _EntryRow(
              entry: entry,
              onTap: () => onEdit(entry),
              onDelete: () => onDelete(entry),
            ),
          ],
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });
  final FoodEntryRecord entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final kcal = nutrientForPortion(entry.kcalPer100g, entry.quantityGrams);
    final source = entry.source == 'open_food_facts'
        ? Icons.barcode_reader
        : entry.source == 'photo_suggestion'
        ? Icons.photo_camera_outlined
        : entry.source == 'assistant'
        ? Icons.auto_awesome_outlined
        : entry.source.startsWith('local_reference_')
        ? Icons.menu_book_outlined
        : Icons.edit_outlined;
    return InkWell(
      onTap: onTap,
      onLongPress: onDelete,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
        child: Row(
          children: [
            Icon(source, size: 16, color: theme.textTheme.bodySmall?.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    [
                      entryAmountLabel(t, entry),
                      if (entry.brand != null) entry.brand!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              kcal == null ? '—' : '${kcal.round()} kcal',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: t.get('settings'),
              icon: Icon(
                Icons.more_vert_rounded,
                size: 18,
                color: theme.textTheme.bodySmall?.color,
              ),
              onSelected: (value) => value == 'edit' ? onTap() : onDelete(),
              itemBuilder: (context) => [
                PopupMenuItem(value: 'edit', child: Text(t.get('edit'))),
                PopupMenuItem(value: 'delete', child: Text(t.get('delete'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Manual entry / edit form, presented as a bottom sheet.
class _FoodEntrySheet extends StatefulWidget {
  const _FoodEntrySheet({required this.meal, this.existing});
  final String meal;
  final FoodEntryRecord? existing;

  @override
  State<_FoodEntrySheet> createState() => _FoodEntrySheetState();
}

class _FoodEntrySheetState extends State<_FoodEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _quantity;
  late final TextEditingController _kcal;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  late String _meal;

  @override
  void initState() {
    super.initState();
    final entry = widget.existing;
    _meal = entry?.mealType ?? widget.meal;
    _name = TextEditingController(text: entry?.name ?? '');
    _quantity = TextEditingController(
      text: entry?.quantityGrams.toStringAsFixed(0) ?? '100',
    );
    _kcal = _controller(entry?.kcalPer100g);
    _protein = _controller(entry?.proteinPer100g);
    _carbs = _controller(entry?.carbsPer100g);
    _fat = _controller(entry?.fatPer100g);
  }

  TextEditingController _controller(double? value) => TextEditingController(
    text: value == null
        ? ''
        : (value == value.roundToDouble()
              ? value.toInt().toString()
              : value.toStringAsFixed(1)),
  );

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _kcal.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.get(widget.existing == null ? 'addMeal' : 'editEntry'),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in mealTypes)
                    VyroPillChip(
                      label: mealLabel(t, value),
                      selected: _meal == value,
                      onTap: () => setState(() => _meal = value),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _field(_name, t.get('foodName'), required: true),
              const SizedBox(height: 10),
              _field(
                _quantity,
                t.get('quantity'),
                required: true,
                number: true,
                suffix: 'g',
              ),
              const SizedBox(height: 18),
              Text(t.get('nutritionFacts'), style: theme.textTheme.titleSmall),
              Text(t.get('per100g'), style: theme.textTheme.bodySmall),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _kcal,
                      t.get('calories'),
                      number: true,
                      suffix: 'kcal',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      _protein,
                      t.get('protein'),
                      number: true,
                      suffix: 'g',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _carbs,
                      t.get('carbs'),
                      number: true,
                      suffix: 'g',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      _fat,
                      t.get('fat'),
                      number: true,
                      suffix: 'g',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              VyroPrimaryButton(
                label: t.get('save'),
                icon: Icons.check_rounded,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool number = false,
    String? suffix,
  }) => TextFormField(
    controller: controller,
    keyboardType: number
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    inputFormatters: number
        ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
        : null,
    textCapitalization: number
        ? TextCapitalization.none
        : TextCapitalization.sentences,
    decoration: InputDecoration(labelText: label, suffixText: suffix),
    validator: (value) {
      final raw = value?.trim() ?? '';
      final t = stringsOf(context);
      if (required && raw.isEmpty) return t.get('error');
      if (number && raw.isNotEmpty && _parse(raw) == null) {
        return t.get('error');
      }
      if (identical(controller, _quantity) && (_parse(raw) ?? 0) <= 0) {
        return t.get('error');
      }
      return null;
    },
  );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _FoodEntryDraft(
        meal: _meal,
        name: _name.text.trim(),
        quantityGrams: _parse(_quantity.text)!,
        kcalPer100g: _parse(_kcal.text),
        proteinPer100g: _parse(_protein.text),
        carbsPer100g: _parse(_carbs.text),
        fatPer100g: _parse(_fat.text),
        source: widget.existing?.source ?? 'manual',
      ),
    );
  }
}

class _FoodEntryDraft {
  const _FoodEntryDraft({
    required this.meal,
    required this.name,
    required this.quantityGrams,
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.source,
  });
  final String meal;
  final String name;
  final double quantityGrams;
  final double? kcalPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;
  final String source;
}

double? _parse(String raw) => raw.trim().isEmpty
    ? null
    : double.tryParse(raw.trim().replaceAll(',', '.'));
