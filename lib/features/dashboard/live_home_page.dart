import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../app/theme/vyro_chrome.dart';
import '../../app/theme/vyro_shell.dart';
import '../../app/theme/vyro_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/widgets/vyro_widgets.dart';
import '../nutrition/domain/food_product.dart';
import '../nutrition/meals.dart';
import '../nutrition/nutrition_diary_page.dart';
import 'home_shell.dart';
import '../workouts/data/workout_repository.dart';

class LiveHomePage extends StatefulWidget {
  const LiveHomePage({super.key});

  @override
  State<LiveHomePage> createState() => _LiveHomePageState();
}

class _LiveHomePageState extends State<LiveHomePage> {
  AppServices? _services;
  Future<WorkoutPlanData>? _planFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppServicesScope.of(context);
    if (!identical(services, _services)) {
      _services = services;
      _planFuture = services.workoutRepository.reloadPlan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = _services!;
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
            final remaining = (calorieGoal - totals.kcal).clamp(
              0.0,
              double.infinity,
            );
            return VyroPageScaffold(
              eyebrow: t.get('today'),
              title: name.isEmpty
                  ? t.get('helloGeneric')
                  : '${t.get('helloPrefix')}, $name',
              actions: [
                VyroRoundButton(
                  icon: Icons.person_outline_rounded,
                  tooltip: t.get('profile'),
                  onPressed: () => _openTab(context, 4, '/profile'),
                ),
              ],
              body: VyroPageBody(
                children: [
                  _CalorieHero(
                    consumed: totals.kcal,
                    goal: calorieGoal,
                    remaining: remaining,
                  ),
                  if (entries.any(
                    (e) =>
                        e.kcalPer100g == null ||
                        e.proteinPer100g == null ||
                        e.carbsPer100g == null ||
                        e.fatPer100g == null,
                  )) ...[
                    const SizedBox(height: 10),
                    Text(
                      t.get('totalsPartial'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
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
                          accent: Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MetricCard(
                          label: t.get('fat'),
                          value: totals.fat.round().toString(),
                          unit: '/ ${fatGoal.round()} g',
                          progress: (totals.fat / fatGoal).clamp(0.0, 1.0),
                          accent: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  VyroSectionTitle(label: t.get('quickAdd')),
                  QuickLogRow(
                    onScan: () => Navigator.pushNamed(context, '/barcode'),
                    onPhoto: () =>
                        Navigator.pushNamed(context, '/photo-camera'),
                    onManual: () => _openTab(context, 1, '/nutrition'),
                  ),
                  const SizedBox(height: 20),
                  VyroSectionTitle(
                    label: t.get('meals'),
                    action: t.get('nutrition'),
                    onAction: () => _openTab(context, 1, '/nutrition'),
                  ),
                  _TodayMeals(
                    entries: entries,
                    onTap: () => _openTab(context, 1, '/nutrition'),
                  ),
                  const SizedBox(height: 20),
                  VyroSectionTitle(label: t.get('nextWorkout')),
                  FutureBuilder<WorkoutPlanData>(
                    future: _planFuture,
                    builder: (context, planSnapshot) {
                      final plan = planSnapshot.data;
                      final firstDay = (plan?.days.isNotEmpty ?? false)
                          ? plan!.days.first.day
                          : null;
                      final dayName = firstDay == null
                          ? null
                          : (t.isEnglish ? firstDay.nameEn : firstDay.namePt);
                      return ActionCard(
                        icon: Icons.fitness_center_rounded,
                        title: dayName ?? t.get('starterPlan'),
                        subtitle: plan == null
                            ? t.get('nextWorkoutLocal')
                            : '${t.get('plans')} · ${plan.days.length} ${t.get('setupDays')}',
                        onTap: () => _openTab(context, 2, '/training'),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Daily energy card: progress ring on the left, goal and remaining on the
/// right. Numbers use tabular figures so they do not shift while logging.
void _openTab(BuildContext context, int index, String route) {
  if (!HomeShell.selectTab(context, index)) {
    Navigator.pushNamed(context, route);
  }
}

/// One compact row per meal with today's calories.
class _TodayMeals extends StatelessWidget {
  const _TodayMeals({required this.entries, required this.onTap});
  final List<FoodEntryRecord> entries;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    return VyroCard(
      radius: 22,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final meal in mealTypes)
                  Builder(
                    builder: (context) {
                      final items = entries
                          .where((e) => e.mealType == meal)
                          .toList();
                      final kcal = _Totals.from(items).kcal;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              mealIcon(meal),
                              size: 18,
                              color: items.isEmpty
                                  ? theme.textTheme.bodySmall?.color
                                  : VyroTheme.accentTextOf(context),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                mealLabel(t, meal),
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            Text(
                              items.isEmpty ? '—' : '${kcal.round()} kcal',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: items.isEmpty
                                    ? theme.textTheme.bodySmall?.color
                                    : null,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalorieHero extends StatelessWidget {
  const _CalorieHero({
    required this.consumed,
    required this.goal,
    required this.remaining,
  });

  final double consumed;
  final double goal;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final accent = VyroTheme.accentTextOf(context);
    final value = goal <= 0 ? 0.0 : (consumed / goal).clamp(0.0, 1.0);
    return VyroCard(
      tint: scheme.primary.withValues(alpha: dark ? 0.07 : 0.10),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(
        children: [
          SizedBox(
            width: 128,
            height: 128,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    backgroundColor: scheme.outline.withValues(alpha: 0.55),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      consumed.round().toString(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      stringsOf(context).get('eaten'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9.5,
                      ),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stringsOf(context).get('calories'),
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  '${goal.round()} ${stringsOf(context).get('goal')}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                Text(
                  '${remaining.round()} ${stringsOf(context).get('remaining')}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: accent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
