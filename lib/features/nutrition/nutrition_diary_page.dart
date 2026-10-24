import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../core/database/app_database.dart';
import '../../core/widgets/vyro_widgets.dart';
import 'domain/food_product.dart';

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
    final day = dayKey(selectedDay);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.get('nutrition')),
        actions: [
          IconButton(
            tooltip: t.get('scan'),
            onPressed: () => Navigator.pushNamed(
              context,
              '/barcode',
              arguments: selectedDay,
            ),
            icon: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<FoodEntryRecord>>(
        stream: services.nutritionRepository.watchEntriesForDay(day),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? const <FoodEntryRecord>[];
          if (snapshot.hasError) {
            return Center(child: Text(t.get('error')));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              _DaySelector(
                day: selectedDay,
                onChanged: (value) => setState(() => selectedDay = value),
              ),
              const SizedBox(height: 18),
              _DailySummary(entries: entries, t: t),
              if (entries.any(
                (entry) =>
                    entry.kcalPer100g == null ||
                    entry.proteinPer100g == null ||
                    entry.carbsPer100g == null ||
                    entry.fatPer100g == null,
              )) ...[
                const SizedBox(height: 8),
                Text(
                  t.get('totalsPartial'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 22),
              for (final meal in _meals)
                _MealSection(
                  mealType: meal,
                  entries: entries
                      .where((entry) => entry.mealType == meal)
                      .toList(),
                  onAdd: () => _editEntry(context, services, day, meal, null),
                  onEdit: (entry) =>
                      _editEntry(context, services, day, meal, entry),
                  onDelete: (entry) => _deleteEntry(context, services, entry),
                ),
              if (entries.isEmpty) ...[
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(t.get('noMeals')),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/photo-camera',
                      arguments: selectedDay,
                    ),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(t.get('photo')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/barcode',
                      arguments: selectedDay,
                    ),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(t.get('scan')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _editEntry(context, services, day, 'snack', null),
                    icon: const Icon(Icons.edit_note),
                    label: Text(t.get('manual')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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

  Future<void> _editEntry(
    BuildContext context,
    AppServices services,
    String day,
    String meal,
    FoodEntryRecord? existing,
  ) async {
    final draft = await showDialog<_FoodEntryDraft>(
      context: context,
      builder: (_) => _FoodEntryDialog(meal: meal, existing: existing),
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
          TextButton(
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

const _meals = ['breakfast', 'lunch', 'dinner', 'snack'];

class _DaySelector extends StatelessWidget {
  const _DaySelector({required this.day, required this.onChanged});
  final DateTime day;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final date = t.isEnglish
        ? '${day.month}/${day.day}/${day.year}'
        : '${day.day}/${day.month}/${day.year}';
    return Card(
      child: Row(
        children: [
          IconButton(
            onPressed: () => onChanged(day.subtract(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  t.get('today'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(date, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            onPressed: () => onChanged(day.add(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _DailySummary extends StatelessWidget {
  const _DailySummary({required this.entries, required this.t});
  final List<FoodEntryRecord> entries;
  final VyroStrings t;

  @override
  Widget build(BuildContext context) {
    final kcal = _sum(entries, (entry) => entry.kcalPer100g);
    final protein = _sum(entries, (entry) => entry.proteinPer100g);
    final carbs = _sum(entries, (entry) => entry.carbsPer100g);
    final fat = _sum(entries, (entry) => entry.fatPer100g);
    String value(double? amount) =>
        amount == null ? t.get('notAvailable') : amount.round().toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.get('daySummary'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: t.get('calories'),
                    value: value(kcal),
                    unit: 'kcal',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetricCard(
                    label: t.get('protein'),
                    value: value(protein),
                    unit: 'g',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: t.get('carbs'),
                    value: value(carbs),
                    unit: 'g',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetricCard(
                    label: t.get('fat'),
                    value: value(fat),
                    unit: 'g',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

double? _sum(
  List<FoodEntryRecord> entries,
  double? Function(FoodEntryRecord) getPer100g,
) {
  if (entries.isEmpty) return 0;
  var total = 0.0;
  for (final entry in entries) {
    final nutrient = nutrientForPortion(getPer100g(entry), entry.quantityGrams);
    if (nutrient == null) return null;
    total += nutrient;
  }
  return total;
}

class _MealSection extends StatelessWidget {
  const _MealSection({
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
    final heading = switch (mealType) {
      'breakfast' => t.get('breakfast'),
      'lunch' => t.get('lunch'),
      'dinner' => t.get('dinner'),
      _ => t.get('snack'),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          SectionTitle(heading, action: t.get('addMeal'), onAction: onAdd),
          if (entries.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: Text(t.get('addMeal')),
                onTap: onAdd,
              ),
            ),
          for (final entry in entries)
            Card(
              child: ListTile(
                title: Text(entry.name),
                subtitle: Text(
                  '${entry.quantityGrams.round()} ${t.get('grams')} · '
                  '${_entryKcal(entry, t)} · '
                  '${entry.source == 'open_food_facts'
                      ? t.get('mealSourceOff')
                      : entry.source.startsWith('local_reference_')
                      ? '${t.get('mealSourceLocalReference')} · FDC ${entry.source.substring('local_reference_'.length)}'
                      : entry.source == 'photo_suggestion'
                      ? t.get('photoSource')
                      : t.get('mealSourceManual')}',
                ),
                onTap: () => onEdit(entry),
                trailing: PopupMenuButton<String>(
                  tooltip: t.get('settings'),
                  onSelected: (value) =>
                      value == 'edit' ? onEdit(entry) : onDelete(entry),
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'edit', child: Text(t.get('edit'))),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(t.get('delete')),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _entryKcal(FoodEntryRecord entry, VyroStrings t) {
    final kcal = nutrientForPortion(entry.kcalPer100g, entry.quantityGrams);
    return kcal == null ? t.get('notAvailable') : '${kcal.round()} kcal';
  }
}

class _FoodEntryDialog extends StatefulWidget {
  const _FoodEntryDialog({required this.meal, this.existing});
  final String meal;
  final FoodEntryRecord? existing;

  @override
  State<_FoodEntryDialog> createState() => _FoodEntryDialogState();
}

class _FoodEntryDialogState extends State<_FoodEntryDialog> {
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

  TextEditingController _controller(double? value) =>
      TextEditingController(text: value?.toString() ?? '');

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
    return AlertDialog(
      title: Text(t.get(widget.existing == null ? 'addMeal' : 'editEntry')),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _meal,
                decoration: InputDecoration(labelText: t.get('selectMeal')),
                items: [
                  for (final value in _meals)
                    DropdownMenuItem(
                      value: value,
                      child: Text(_mealLabel(t, value)),
                    ),
                ],
                onChanged: (value) => setState(() => _meal = value ?? _meal),
              ),
              _textField(_name, t.get('foodName'), required: true),
              _textField(
                _quantity,
                '${t.get('quantity')} (${t.get('grams')})',
                required: true,
                number: true,
              ),
              _textField(_kcal, t.get('kcalPer100'), number: true),
              _textField(_protein, t.get('proteinPer100'), number: true),
              _textField(_carbs, t.get('carbsPer100'), number: true),
              _textField(_fat, t.get('fatPer100'), number: true),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.get('cancel')),
        ),
        FilledButton(onPressed: _save, child: Text(t.get('save'))),
      ],
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool number = false,
  }) => TextFormField(
    controller: controller,
    keyboardType: number
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final raw = value?.trim() ?? '';
      if (required && raw.isEmpty) return stringsOf(context).get('error');
      if (number && raw.isNotEmpty && _parse(raw) == null)
        return stringsOf(context).get('error');
      if (identical(controller, _quantity) && (_parse(raw) ?? 0) <= 0)
        return stringsOf(context).get('error');
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

String _mealLabel(VyroStrings t, String meal) => switch (meal) {
  'breakfast' => t.get('breakfast'),
  'lunch' => t.get('lunch'),
  'dinner' => t.get('dinner'),
  _ => t.get('snack'),
};

double? _parse(String raw) => raw.trim().isEmpty
    ? null
    : double.tryParse(raw.trim().replaceAll(',', '.'));
