import 'package:flutter/material.dart';

import '../../app/l10n/strings.dart';
import '../../core/widgets/vyro_widgets.dart';

class TrainingPage extends StatelessWidget {
  const TrainingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    return ContentPage(
      title: t.get('training'),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DemoBadge(),
                const SizedBox(height: 16),
                Text(
                  t.get('todayTraining'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '${t.get('upper')} · 6 ${t.get('exerciseCount')} · 45 ${t.get('minutes')}',
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
        const SizedBox(height: 22),
        SectionTitle(t.get('week')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: t
                  .get('weekdays')
                  .split(' ')
                  .asMap()
                  .entries
                  .map(
                    (e) => Column(
                      children: [
                        Text(
                          e.value,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 10),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: e.key < 3
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          child: e.key < 3
                              ? Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                )
                              : null,
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 22),
        SectionTitle(t.get('screens')),
        ActionCard(
          icon: Icons.view_list_rounded,
          title: t.get('workoutDay'),
          subtitle: t.get('exercisePreview'),
          onTap: () => Navigator.pushNamed(context, '/workout-day'),
        ),
        const SizedBox(height: 8),
        ActionCard(
          icon: Icons.accessibility_new,
          title: t.get('motion'),
          subtitle: t.get('motionPreview'),
          onTap: () => Navigator.pushNamed(context, '/motion'),
        ),
        const SizedBox(height: 20),
        const DemoBadge(),
        const SizedBox(height: 8),
        Text(
          t.get('trainingDemoNote'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
