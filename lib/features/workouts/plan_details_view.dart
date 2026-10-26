import 'package:flutter/material.dart';

import '../../app/l10n/strings.dart';
import '../../core/ui/vyro_ui.dart';
import 'domain/plan_details.dart';
import 'domain/plan_generator.dart';

/// "Semana 2 de 4" for the block, with a "Descarga" badge in the deload week
/// and "Bloco concluído" once the block is over. The badge carries its text,
/// so the state never relies on colour alone.
class PlanBlockLine extends StatelessWidget {
  const PlanBlockLine({super.key, required this.details, this.today});

  final PlanDetails details;

  /// Defaults to now; tests pass a fixed day.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final position = details.blockPosition(today ?? DateTime.now());
    final label = position.finished
        ? t.get('blockFinished')
        : '${t.get('blockWeek')} ${position.week} ${t.get('blockOf')} '
              '${position.weeks}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 20,
              color: VyroTheme.accentTextOf(context),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
            if (position.deload) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: theme.colorScheme.primary),
                ),
                child: Text(
                  t.get('deloadBadge'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: VyroTheme.accentTextOf(context),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (position.deload) ...[
          const SizedBox(height: 8),
          Text(t.get('deloadNote'), style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// The warm-up of one workout (5 minutes, chosen for the day's focus).
class PlanWarmupCard extends StatelessWidget {
  const PlanWarmupCard({super.key, required this.note});

  final PlanNote note;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    return VyroCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.self_improvement_rounded,
            size: 22,
            color: VyroTheme.accentTextOf(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.get('warmupTitle'), style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(note.text(t.isEnglish), style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Sobre este plano": block, warnings and the rationale ("Porque este
/// plano"), with the on-device summary first when there is one.
class PlanAboutCard extends StatelessWidget {
  const PlanAboutCard({super.key, required this.details, this.today});

  final PlanDetails details;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final english = t.isEnglish;
    final warnings = details.warnings;
    return VyroCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PlanBlockLine(details: details, today: today),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final warning in warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: scheme.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        warning.text(english),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text(t.get('aboutPlanWhy'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (details.summary != null) ...[
            Text(details.summary!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 10),
          ],
          for (final note in details.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•', style: theme.textTheme.bodyMedium),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      note.text(english),
                      style: theme.textTheme.bodyMedium,
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
