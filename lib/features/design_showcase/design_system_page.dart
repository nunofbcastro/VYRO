import 'package:flutter/material.dart';

import '../../app/l10n/strings.dart';
import '../../app/theme/vyro_theme.dart';
import '../../core/widgets/vyro_widgets.dart';

class DesignSystemPage extends StatelessWidget {
  const DesignSystemPage({super.key});

  static const _screens = <(String, IconData)>[
    ('splash', Icons.bolt_rounded),
    ('onboarding', Icons.waving_hand_outlined),
    ('profile-setup', Icons.tune_rounded),
    ('home', Icons.grid_view_rounded),
    ('nutrition', Icons.restaurant_rounded),
    ('photo-camera', Icons.photo_camera_outlined),
    ('food-review', Icons.fact_check_outlined),
    ('barcode', Icons.qr_code_scanner),
    ('product', Icons.shopping_bag_outlined),
    ('training', Icons.fitness_center),
    ('workout-day', Icons.view_list_rounded),
    ('session', Icons.timer_outlined),
    ('motion', Icons.accessibility_new),
    ('coach', Icons.chat_bubble_outline),
    ('progress', Icons.show_chart),
    ('profile', Icons.person_outline),
    ('empty', Icons.inbox_outlined),
    ('loading', Icons.hourglass_empty),
    ('error', Icons.error_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final cs = Theme.of(context).colorScheme;
    return ContentPage(
      title: t.get('design'),
      children: [
        const DemoBadge(),
        const SizedBox(height: 12),
        Text(t.get('demoNote'), style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        SectionTitle(t.get('colors')),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Swatch(
              label: t.get('colorCanvas'),
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            _Swatch(label: t.get('colorSurface'), color: cs.surface),
            _Swatch(
              label: t.get('colorElevated'),
              color: cs.surfaceContainerHighest,
            ),
            _Swatch(label: t.get('colorAccent'), color: cs.primary),
            _Swatch(label: t.get('colorBorder'), color: cs.outline),
          ],
        ),
        const SizedBox(height: 24),
        SectionTitle(t.get('typography')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aa 123',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  t.get('typeScale'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  t.get('spacingScale'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SectionTitle(t.get('components')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(onPressed: () {}, child: Text(t.get('continue'))),
            OutlinedButton(onPressed: () {}, child: Text(t.get('edit'))),
            const DemoBadge(),
          ],
        ),
        const SizedBox(height: 8),
        MetricCard(
          label: t.get('sampleCalories'),
          value: '1,640',
          unit: '/ 2,450',
          progress: .67,
        ),
        const SizedBox(height: 24),
        SectionTitle(t.get('screens')),
        Text(
          t.get('screenGalleryNote'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        ..._screens.map(
          (screen) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ActionCard(
              icon: screen.$2,
              title: _screenTitle(t, screen.$1),
              subtitle: '/${screen.$1}',
              onTap: () => Navigator.pushNamed(context, '/${screen.$1}'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Dark · ${VyroTheme.ink.toARGB32().toRadixString(16).toUpperCase()}     Light · ${VyroTheme.lightBg.toARGB32().toRadixString(16).toUpperCase()}',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }

  static String _screenTitle(VyroStrings t, String id) {
    const map = <String, String>{
      'splash': 'splash',
      'onboarding': 'onboarding',
      'profile-setup': 'profileSetup',
      'home': 'home',
      'nutrition': 'nutrition',
      'food-review': 'foodReview',
      'barcode': 'barcode',
      'product': 'product',
      'training': 'training',
      'workout-day': 'workoutDay',
      'session': 'session',
      'motion': 'motion',
      'coach': 'coach',
      'progress': 'progress',
      'profile': 'profile',
    };
    if (id == 'photo-camera') return t.get('photo');
    if (id == 'empty') return t.get('emptyExample');
    if (id == 'loading') return t.get('loadingExample');
    if (id == 'error') return t.get('errorExample');
    return t.get(map[id] ?? id);
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 104,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 104,
          height: 60,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}
