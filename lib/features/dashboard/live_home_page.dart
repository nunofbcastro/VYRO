import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../core/database/app_database.dart';
import '../../core/widgets/vyro_widgets.dart';
import '../nutrition/domain/food_product.dart';

class LiveHomePage extends StatelessWidget {
  const LiveHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);
    final t = stringsOf(context);
    final today = dayKey(DateTime.now());
    return StreamBuilder<List<FoodEntryRecord>>(
      stream: services.database.watchEntriesForDay(today),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <FoodEntryRecord>[];
        final totals = _Totals.from(entries);
        return FutureBuilder<VyroProfile?>(
          future: services.database.getUserProfile(),
          builder: (context, profileSnapshot) {
            final profile = profileSnapshot.data ?? const VyroProfile();
            final calorieGoal = profile.calorieGoal;
            final proteinGoal = profile.proteinGoal;
            final carbsGoal = profile.carbsGoal;
            final fatGoal = profile.fatGoal;
            final name = profile.name.trim();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.get('today'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name.isEmpty
                                ? t.get('helloGeneric')
                                : '${t.get('helloPrefix')}, $name',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pushNamed(context, '/profile'),
                      icon: const Icon(Icons.account_circle_outlined),
                      tooltip: t.get('profile'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 126,
                          height: 126,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.expand(
                                child: CircularProgressIndicator(
                                  value: (totals.kcal / calorieGoal).clamp(
                                    0.0,
                                    1.0,
                                  ),
                                  strokeWidth: 10,
                                  strokeCap: StrokeCap.round,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.outline.withValues(alpha: .35),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    totals.kcal.round().toString(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    t.get('eaten'),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.get('calories'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${calorieGoal.round()} ${t.get('goal')}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${(calorieGoal - totals.kcal).clamp(0, double.infinity).round()} ${t.get('remaining')}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (entries.any(
                  (e) =>
                      e.kcalPer100g == null ||
                      e.proteinPer100g == null ||
                      e.carbsPer100g == null ||
                      e.fatPer100g == null,
                )) ...[
                  const SizedBox(height: 8),
                  Text(
                    t.get('totalsPartial'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        label: t.get('protein'),
                        value: totals.protein.round().toString(),
                        unit: '/ ${proteinGoal.round()} g',
                        progress: (totals.protein / proteinGoal).clamp(
                          0.0,
                          1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MetricCard(
                        label: t.get('carbs'),
                        value: totals.carbs.round().toString(),
                        unit: '/ ${carbsGoal.round()} g',
                        progress: (totals.carbs / carbsGoal).clamp(0.0, 1.0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MetricCard(
                        label: t.get('fat'),
                        value: totals.fat.round().toString(),
                        unit: '/ ${fatGoal.round()} g',
                        progress: (totals.fat / fatGoal).clamp(0.0, 1.0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (entries.isEmpty)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.restaurant_outlined),
                      title: Text(t.get('noMeals')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pushNamed(context, '/nutrition'),
                    ),
                  ),
                SectionTitle(t.get('nextWorkout')),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.fitness_center),
                    title: Text(t.get('starterPlan')),
                    subtitle: Text(t.get('nextWorkoutLocal')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(context, '/training'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Totals {
  const _Totals(this.kcal, this.protein, this.carbs, this.fat);
  final double kcal, protein, carbs, fat;
  factory _Totals.from(List<FoodEntryRecord> entries) {
    double sum(double? Function(FoodEntryRecord) pick) =>
        entries.fold(0, (value, entry) {
          final nutrient = pick(entry);
          return value +
              (nutrient == null ? 0 : nutrient * entry.quantityGrams / 100);
        });
    return _Totals(
      sum((e) => e.kcalPer100g),
      sum((e) => e.proteinPer100g),
      sum((e) => e.carbsPer100g),
      sum((e) => e.fatPer100g),
    );
  }
}
