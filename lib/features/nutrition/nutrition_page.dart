import 'package:flutter/material.dart';

import '../../app/l10n/strings.dart';
import '../../core/widgets/vyro_widgets.dart';

class NutritionPage extends StatelessWidget {
  const NutritionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final meals = [
      (
        'breakfast',
        t.get('breakfastSample'),
        '420 kcal',
        Icons.wb_sunny_outlined,
      ),
      ('lunch', t.get('lunchSample'), '680 kcal', Icons.lunch_dining_outlined),
      ('snack', t.get('snackSample'), '240 kcal', Icons.apple_outlined),
      ('dinner', '—', '—', Icons.dinner_dining_outlined),
    ];
    return ContentPage(
      title: t.get('nutrition'),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          t.get('today'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${t.get('dateBrief')} · 1,640 kcal',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SectionTitle(t.get('meals')),
        ...meals.map(
          (meal) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Icon(meal.$4, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.get(meal.$1),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            meal.$2,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      meal.$3,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SectionTitle(t.get('addMeal')),
        ActionCard(
          icon: Icons.qr_code_scanner,
          title: t.get('scan'),
          subtitle: t.get('offDemo'),
          onTap: () => Navigator.pushNamed(context, '/barcode'),
        ),
        const SizedBox(height: 8),
        ActionCard(
          icon: Icons.photo_camera_outlined,
          title: t.get('photo'),
          subtitle: t.get('recognitionDemo'),
          onTap: () => Navigator.pushNamed(context, '/photo-camera'),
        ),
        const SizedBox(height: 8),
        ActionCard(
          icon: Icons.edit_note,
          title: t.get('manual'),
          onTap: () => Navigator.pushNamed(context, '/food-review'),
        ),
      ],
    );
  }
}
