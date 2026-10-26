import 'package:flutter/material.dart';

import '../../core/ui/vyro_ui.dart';

import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../core/database/app_database.dart';
import '../nutrition/domain/food_product.dart';
import '../nutrition/domain/nutrition_targets_rules.dart';
import '../nutrition/nutrition_targets_page.dart';
import '../../app/app.dart';
import 'body_weight_sheet.dart';
import 'domain/body_weight.dart';
import 'line_chart.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  int _rangeDays = 30;

  /// Entries swiped away but not yet gone from the stream. Keeps a dismissed
  /// row out of the tree while the database update is in flight.
  final Set<int> _dismissedIds = {};

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final repository = AppServicesScope.of(context).workoutRepository;
    final database = AppServicesScope.of(context).database;
    final cutoff = DateTime.now().subtract(Duration(days: _rangeDays));
    final cutoffDay = dayKey(cutoff);
    return ContentPage(
      title: t.get('progress'),
      children: [
        VyroSegmentedControl<int>(
          value: _rangeDays,
          segments: {
            7: '7D',
            30: '30D',
            90: '90D',
            365: t.isEnglish ? '1Y' : '1A',
          },
          onChanged: (value) => setState(() => _rangeDays = value),
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<WorkoutSession>>(
          stream: repository.watchSessions(),
          builder: (context, snapshot) {
            final sessions = (snapshot.data ?? const <WorkoutSession>[])
                .where(
                  (session) =>
                      session.status == 'completed' &&
                      !session.startedAt.isBefore(cutoff),
                )
                .length;
            return MetricCard(
              label: t.get('sessions'),
              value: '$sessions',
              unit: t.get('completed'),
              icon: Icons.fitness_center,
            );
          },
        ),
        const SizedBox(height: 12),
        StreamBuilder<double>(
          stream: repository.watchTrainingVolume(),
          builder: (context, snapshot) => MetricCard(
            label: t.get('volume'),
            value: _compactNumber(snapshot.data ?? 0),
            unit: 'kg · ${t.get('allTime')}',
            icon: Icons.show_chart,
          ),
        ),
        const SizedBox(height: 12),
        _caloriesCard(context, database, cutoffDay),
        const SizedBox(height: 20),
        _weightCard(context, database, cutoff),
        const SizedBox(height: 16),
        Text(
          t.get('progressLocalNote'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _caloriesCard(
    BuildContext context,
    AppDatabase database,
    String cutoffDay,
  ) {
    final t = stringsOf(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.get('calories'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              t.get('calorieHistoryLocal'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<FoodEntryRecord>>(
              stream: database.watchEntriesSince(cutoffDay),
              builder: (context, snapshot) {
                final daily = <String, double>{};
                for (final entry
                    in snapshot.data ?? const <FoodEntryRecord>[]) {
                  final kcal = entry.kcalPer100g;
                  if (kcal == null) continue;
                  daily.update(
                    entry.day,
                    (sum) => sum + kcal * entry.quantityGrams / 100,
                    ifAbsent: () => kcal * entry.quantityGrams / 100,
                  );
                }
                final days = daily.keys.toList()..sort();
                if (days.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(t.get('noMeals')),
                  );
                }
                final values = days.map((day) => daily[day]!).toList();
                return Column(
                  children: [
                    if ((snapshot.data ?? const <FoodEntryRecord>[]).any(
                      (entry) => entry.kcalPer100g == null,
                    ))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            t.get('totalsPartial'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    LineChart(
                      values: values,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text(days.first), Text(days.last)],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _weightCard(
    BuildContext context,
    AppDatabase database,
    DateTime cutoff,
  ) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.get('weight'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: t.get('logWeight'),
                  onPressed: () => _handleSheet(context, database),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<BodyMeasurement>>(
              stream: database.watchBodyWeights(),
              builder: (context, snapshot) {
                final all = snapshot.data ?? const <BodyMeasurement>[];
                if (all.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      t.get('weightEmpty'),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                // The headline shows the newest entry overall, not the
                // newest one inside the selected range.
                final latest = all.last;
                final inRange = all
                    .where(
                      (measurement) => !measurement.measuredAt.isBefore(cutoff),
                    )
                    .toList();
                final visible = inRange
                    .where(
                      (measurement) => !_dismissedIds.contains(measurement.id),
                    )
                    .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatBodyWeight(latest.weightKg, english: t.isEnglish),
                      style: theme.textTheme.headlineMedium,
                    ),
                    Text(
                      t
                          .get('weightLatestOn')
                          .replaceAll(
                            '{date}',
                            formatBodyDate(bodyDay(latest.measuredAt)),
                          ),
                      style: theme.textTheme.labelSmall,
                    ),
                    const SizedBox(height: 20),
                    if (visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          t.get('weightNoEntriesInRange'),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else ...[
                      LineChart(
                        height: 150,
                        color: theme.colorScheme.primary,
                        values: [for (final m in visible) m.weightKg],
                        onIndexTap: (index) => _handleSheet(
                          context,
                          database,
                          entry: visible[index],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatBodyDate(bodyDay(visible.first.measuredAt)),
                            style: theme.textTheme.labelSmall,
                          ),
                          if (visible.length > 1)
                            Text(
                              formatBodyDate(bodyDay(visible.last.measuredAt)),
                              style: theme.textTheme.labelSmall,
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        t.get('weightHistory'),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.get('weightHistoryHint'),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      for (final entry in visible.reversed)
                        _weightRow(context, database, entry),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _weightRow(
    BuildContext context,
    AppDatabase database,
    BodyMeasurement entry,
  ) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey('weight-${entry.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onError),
      ),
      onDismissed: (_) => _deleteEntry(context, database, entry),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _handleSheet(context, database, entry: entry),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formatBodyDate(bodyDay(entry.measuredAt)),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                Text(
                  formatBodyWeight(entry.weightKg, english: t.isEnglish),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Opens the add sheet, or the edit sheet when [entry] is given, and
  /// applies the result.
  Future<void> _handleSheet(
    BuildContext context,
    AppDatabase database, {
    BodyMeasurement? entry,
  }) async {
    final result = await showBodyWeightSheet(context, entry: entry);
    if (!mounted || result == null) return;
    switch (result) {
      case BodyWeightDeleteRequested():
        // The sheet has already asked for confirmation.
        if (entry != null) await _deleteEntry(context, database, entry);
      case BodyWeightSaved(:final weightKg, :final day):
        await _saveEntry(
          context,
          database,
          weightKg: weightKg,
          day: day,
          existing: entry,
        );
    }
  }

  /// Saves a weight for [day]. One entry per day: if another entry already
  /// exists there, the user is asked before it is replaced.
  Future<void> _saveEntry(
    BuildContext context,
    AppDatabase database, {
    required double weightKg,
    required DateTime day,
    BodyMeasurement? existing,
  }) async {
    final measuredAt = bodyMeasuredAt(
      day: day,
      now: DateTime.now(),
      original: existing?.measuredAt,
    );
    final before = await TargetsState.load(database);
    try {
      await database.saveBodyWeight(
        id: existing?.id,
        measuredAt: measuredAt,
        weightKg: weightKg,
      );
    } on BodyWeightDayConflict catch (conflict) {
      if (!mounted) return;
      final replace = await _confirmReplace(context, conflict.existing);
      if (!replace || !mounted) return;
      await database.saveBodyWeight(
        id: existing?.id,
        measuredAt: measuredAt,
        weightKg: weightKg,
        replaceSameDay: true,
      );
    }
    if (!mounted) return;
    await _afterTargetsMayChange(context, database, before);
  }

  /// Refreshes the profile the screens read, then tells the user when the
  /// weight change moved the targets.
  Future<void> _afterTargetsMayChange(
    BuildContext context,
    AppDatabase database,
    TargetsState before,
  ) async {
    final settings = SettingsScope.maybeOf(context);
    await settings?.refreshProfile();
    if (!mounted) return;
    final after = await TargetsState.load(database);
    if (!mounted) return;
    showWeightTargetsFeedback(
      context,
      t: stringsOf(context),
      before: before,
      after: after,
      onRecalculate: () async {
        await database.useAutomaticTargets();
        await settings?.refreshProfile();
      },
    );
  }

  Future<bool> _confirmReplace(
    BuildContext context,
    BodyMeasurement existing,
  ) async {
    final t = stringsOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.get('weightReplaceTitle')),
        content: Text(
          t
              .get('weightReplaceBody')
              .replaceAll(
                '{value}',
                formatBodyWeight(existing.weightKg, english: t.isEnglish),
              )
              .replaceAll(
                '{date}',
                formatBodyDate(bodyDay(existing.measuredAt)),
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.get('weightReplace')),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Removes [entry] and offers "Anular" to put it back.
  Future<void> _deleteEntry(
    BuildContext context,
    AppDatabase database,
    BodyMeasurement entry,
  ) async {
    final t = stringsOf(context);
    setState(() => _dismissedIds.add(entry.id));
    await database.deleteBodyWeight(entry.id);
    if (!mounted) return;
    await SettingsScope.maybeOf(context)?.refreshProfile();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(t.get('weightDeleted')),
          action: SnackBarAction(
            label: t.get('weightUndo'),
            onPressed: () => _restoreEntry(context, database, entry),
          ),
        ),
      );
  }

  Future<void> _restoreEntry(
    BuildContext context,
    AppDatabase database,
    BodyMeasurement entry,
  ) async {
    final t = stringsOf(context);
    setState(() => _dismissedIds.remove(entry.id));
    final restored = await database.restoreBodyWeight(entry);
    if (!mounted) return;
    await SettingsScope.maybeOf(context)?.refreshProfile();
    if (!mounted || restored) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(t.get('weightRestoreBlocked'))));
  }
}

String _compactNumber(double value) => value >= 1000
    ? '${(value / 1000).toStringAsFixed(1)}k'
    : value.toStringAsFixed(0);
