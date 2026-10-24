import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../core/database/app_database.dart';
import '../../core/widgets/vyro_widgets.dart';
import '../nutrition/domain/food_product.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.product,
    required this.day,
  });
  final FoodProduct product;
  final DateTime day;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final _quantity = TextEditingController(text: '100');
  String _meal = 'snack';
  bool _saving = false;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final p = widget.product;
    final kcal = nutrientForPortion(
      p.kcalPer100g,
      double.tryParse(_quantity.text) ?? 0,
    );
    return Scaffold(
      appBar: AppBar(title: Text(t.get('product'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const DemoBadge(),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    p.name,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (p.brand != null)
                    Text(
                      p.brand!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  Text(
                    '${t.get('barcode')}: ${p.barcode}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  if (p.quantity != null)
                    Text(
                      p.quantity!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          MetricCard(
            label: t.get('kcalPer100'),
            value: p.kcalPer100g == null
                ? t.get('notAvailable')
                : p.kcalPer100g!.round().toString(),
            unit: 'kcal',
          ),
          for (final nutrient in [
            (t.get('protein'), p.proteinPer100g),
            (t.get('carbs'), p.carbsPer100g),
            (t.get('fat'), p.fatPer100g),
          ])
            Card(
              child: ListTile(
                title: Text(nutrient.$1),
                trailing: Text(
                  nutrient.$2 == null
                      ? t.get('notAvailable')
                      : '${nutrient.$2!.toStringAsFixed(1)} g',
                ),
              ),
            ),
          if (p.nutriScore != null)
            Card(
              child: ListTile(
                title: const Text('Nutri-Score'),
                trailing: Text(p.nutriScore!.toUpperCase()),
              ),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _meal,
            decoration: InputDecoration(labelText: t.get('selectMeal')),
            items: [
              for (final meal in _meals)
                DropdownMenuItem(value: meal, child: Text(_mealLabel(t, meal))),
            ],
            onChanged: (value) => setState(() => _meal = value ?? _meal),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '${t.get('quantity')} (${t.get('grams')})',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(
            '${t.get('calories')}: ${kcal == null ? t.get('notAvailable') : '${kcal.round()} kcal'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _saving ? null : _addToDiary,
            child: Text(t.get('addMeal')),
          ),
          const SizedBox(height: 10),
          Text(
            t.get('offAttribution'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Future<void> _addToDiary() async {
    final amount = double.tryParse(_quantity.text.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) return;
    setState(() => _saving = true);
    try {
      await AppServicesScope.of(context).nutritionRepository.addEntry(
        FoodEntriesCompanion.insert(
          day: dayKey(widget.day),
          mealType: _meal,
          name: widget.product.name,
          brand: Value(widget.product.brand),
          quantityGrams: amount,
          kcalPer100g: Value(widget.product.kcalPer100g),
          proteinPer100g: Value(widget.product.proteinPer100g),
          carbsPer100g: Value(widget.product.carbsPer100g),
          fatPer100g: Value(widget.product.fatPer100g),
          source: const Value('open_food_facts'),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

const _meals = ['breakfast', 'lunch', 'dinner', 'snack'];

String _mealLabel(VyroStrings t, String meal) => switch (meal) {
  'breakfast' => t.get('breakfast'),
  'lunch' => t.get('lunch'),
  'dinner' => t.get('dinner'),
  _ => t.get('snack'),
};
