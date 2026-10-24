import 'package:flutter/material.dart';

import '../../app/l10n/strings.dart';
import '../../core/widgets/vyro_widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final cs = Theme.of(context).colorScheme;
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
                    '${t.get('dateBrief')} · ${t.get('today')}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.get('hello'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
            const DemoBadge(),
            const SizedBox(width: 4),
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
                          value: 0.67,
                          strokeWidth: 10,
                          strokeCap: StrokeCap.round,
                          backgroundColor: cs.outline.withValues(alpha: 0.35),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '1,640',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            t.get('eaten'),
                            style: Theme.of(context).textTheme.labelSmall,
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
                        '2,450 ${t.get('goal')}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '810 ${t.get('remaining')}',
                        style: TextStyle(
                          color: cs.primary,
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
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: t.get('protein'),
                value: '96',
                unit: '/ 140 g',
                progress: .69,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricCard(
                label: t.get('carbs'),
                value: '172',
                unit: '/ 260 g',
                progress: .66,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricCard(
                label: t.get('fat'),
                value: '48',
                unit: '/ 75 g',
                progress: .64,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SectionTitle(t.get('nextWorkout')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.fitness_center, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.get('upper'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '18:30',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '6 ${t.get('exerciseCount')} · 45 ${t.get('minutes')}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/session'),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(t.get('startWorkout')),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SectionTitle(t.get('week')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                7,
                (i) => Column(
                  children: [
                    Text(
                      t.get('weekdays').split(' ')[i],
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 9),
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: i == 3
                          ? cs.primary
                          : cs.primary.withValues(alpha: i < 3 ? .25 : .08),
                      child: i < 3
                          ? Icon(Icons.check, size: 15, color: cs.primary)
                          : i == 3
                          ? Icon(Icons.circle, size: 8, color: cs.onPrimary)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
