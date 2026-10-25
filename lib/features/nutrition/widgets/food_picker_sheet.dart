import 'package:flutter/material.dart';

import '../../../app/l10n/strings.dart';
import '../data/food_database.dart';

/// Bottom sheet to pick a food from the offline database (USDA, Ciqual,
/// TACO). Used by photo review and anywhere a food must be corrected.
///
/// ```dart
/// final food = await showFoodPicker(context, db, initialQuery: 'arroz');
/// ```
Future<FoodRef?> showFoodPicker(
  BuildContext context,
  FoodDatabase database, {
  String initialQuery = '',
  List<FoodRef> suggestions = const [],
}) => showModalBottomSheet<FoodRef>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _FoodPickerSheet(
    database: database,
    initialQuery: initialQuery,
    suggestions: suggestions,
  ),
);

/// Icon for a database category (`carne`, `peixe`, `legumes`…).
IconData foodCategoryIcon(String category) => switch (category) {
  'carne' => Icons.kebab_dining_outlined,
  'peixe' => Icons.set_meal_outlined,
  'cereais' || 'padaria' => Icons.bakery_dining_outlined,
  'leguminosas' => Icons.grain_outlined,
  'legumes' => Icons.eco_outlined,
  'fruta' => Icons.apple_outlined,
  'laticínios' => Icons.icecream_outlined,
  'ovos' => Icons.egg_outlined,
  'bebidas' => Icons.local_drink_outlined,
  'pratos' => Icons.dinner_dining_outlined,
  'tubérculos' => Icons.spa_outlined,
  'sobremesas' => Icons.cake_outlined,
  _ => Icons.restaurant_outlined,
};

/// Short provenance tag: "TACO · BR", "Ciqual · PT", "USDA".
String foodSourceTag(FoodRef food) {
  final region = switch (food.region) {
    'pt' => ' · PT',
    'br' => ' · BR',
    'eu' => ' · EU',
    _ => '',
  };
  return '${food.sourceName}$region';
}

class _FoodPickerSheet extends StatefulWidget {
  const _FoodPickerSheet({
    required this.database,
    required this.initialQuery,
    required this.suggestions,
  });

  final FoodDatabase database;
  final String initialQuery;
  final List<FoodRef> suggestions;

  @override
  State<_FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<_FoodPickerSheet> {
  late final _query = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final results = widget.database.search(_query.text, limit: 40);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t.get('foodPickerTitle'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.suggestions.isNotEmpty) ...[
                    Text(
                      t.isEnglish
                          ? 'Previously chosen by you — confirm'
                          : 'Já escolheste antes — confirma',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final f in widget.suggestions)
                          ActionChip(
                            label: Text(f.name(t.isEnglish)),
                            onPressed: () => Navigator.pop(context, f),
                          ),
                      ],
                    ),
                  ],
                  TextField(
                    controller: _query,
                    autofocus: widget.initialQuery.isEmpty,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: t.get('foodPickerHint'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: t.get('clear'),
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(_query.clear),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          t.get('foodPickerEmpty'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 2),
                      itemBuilder: (context, i) {
                        final food = results[i];
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.12),
                            child: Icon(
                              foodCategoryIcon(food.category),
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          title: Text(food.name(t.isEnglish)),
                          subtitle: Text(
                            '${food.kcal.round()} kcal/100 g · '
                            '${food.portion(t.isEnglish)} · ${foodSourceTag(food)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.pop(context, food),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
