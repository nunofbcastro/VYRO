import 'package:flutter/material.dart';

import '../../app/l10n/strings.dart';
import '../../core/widgets/vyro_widgets.dart';

class DemoPage extends StatelessWidget {
  const DemoPage({super.key, required this.screenId});
  final String screenId;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    switch (screenId) {
      case '/splash':
        return _SplashPage(t: t);
      case '/onboarding':
        return _OnboardingPage(t: t);
      case '/profile-setup':
        return _ProfileSetupPage(t: t);
      case '/photo-camera':
        return _CameraPage(
          t: t,
          title: t.get('photo'),
          icon: Icons.photo_camera_outlined,
          footnote: t.get('uncertain'),
        );
      case '/barcode':
        return _CameraPage(
          t: t,
          title: t.get('barcode'),
          icon: Icons.qr_code_scanner,
          footnote: t.get('barcodeDetails'),
        );
      case '/food-review':
        return _FoodReviewPage(t: t);
      case '/product':
        return _ProductPage(t: t);
      case '/workout-day':
        return _WorkoutDayPage(t: t);
      case '/session':
        return _SessionPage(t: t);
      case '/motion':
        return _CameraPage(
          t: t,
          title: t.get('motion'),
          icon: Icons.accessibility_new,
          footnote:
              'Uma pré-visualização não analisa postura nem valida segurança.',
        );
      case '/coach':
        return _CoachPage(t: t);
      case '/empty':
        return _StatePage(
          t: t,
          icon: Icons.inbox_outlined,
          message: t.get('empty'),
        );
      case '/loading':
        return _StatePage(
          t: t,
          icon: Icons.hourglass_empty,
          message: t.get('loading'),
          loading: true,
        );
      case '/error':
        return _StatePage(
          t: t,
          icon: Icons.error_outline,
          message: t.get('error'),
          error: true,
        );
      default:
        return _StatePage(
          t: t,
          icon: Icons.widgets_outlined,
          message: t.get('demoNote'),
        );
    }
  }
}

class _SplashPage extends StatelessWidget {
  const _SplashPage({required this.t});
  final VyroStrings t;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DemoBadge(),
            const SizedBox(height: 28),
            Icon(
              Icons.bolt_rounded,
              size: 76,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'VYRO',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(t.get('splashLine')),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/'),
              child: Text(t.get('continue')),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProfileSetupPage extends StatelessWidget {
  const _ProfileSetupPage({required this.t});
  final VyroStrings t;

  @override
  Widget build(BuildContext context) => ContentPage(
    title: t.get('profileSetup'),
    children: [
      const DemoBadge(),
      const SizedBox(height: 18),
      LinearProgressIndicator(
        value: .35,
        borderRadius: BorderRadius.circular(8),
      ),
      const SizedBox(height: 24),
      Text(
        t.get('goalPrompt'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      for (final option in [
        t.get('goalStrength'),
        t.get('goalNutrition'),
        t.get('goalRoutine'),
      ])
        Card(
          child: ListTile(
            leading: const Icon(Icons.radio_button_unchecked),
            title: Text(option),
            onTap: () {},
          ),
        ),
      const SizedBox(height: 12),
      FilledButton(onPressed: () {}, child: Text(t.get('continue'))),
    ],
  );
}

class _OnboardingPage extends StatefulWidget {
  const _OnboardingPage({required this.t});
  final VyroStrings t;

  @override
  State<_OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<_OnboardingPage> {
  int step = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(widget.t.get('skip')),
              ),
            ),
            const Spacer(),
            Center(
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 36),
            Text(
              widget.t.get('onboarding'),
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              widget.t.get(
                ['onboardingBody', 'onboardingBody2', 'onboardingBody3'][step],
              ),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Spacer(),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (index) => Container(
                    width: index == step ? 20 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index == step
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(child: DemoBadge()),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (step < 2) {
                    setState(() => step++);
                  } else {
                    Navigator.pushReplacementNamed(context, '/');
                  }
                },
                child: Text(widget.t.get(step < 2 ? 'continue' : 'start')),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CameraPage extends StatelessWidget {
  const _CameraPage({
    required this.t,
    required this.title,
    required this.icon,
    required this.footnote,
  });
  final VyroStrings t;
  final String title;
  final IconData icon;
  final String footnote;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const DemoBadge(),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, color: Colors.white38, size: 72),
                    Positioned(
                      bottom: 20,
                      child: Text(
                        t.get('noCamera'),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              footnote,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.keyboard),
              label: Text(t.get('manual')),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FoodReviewPage extends StatelessWidget {
  const _FoodReviewPage({required this.t});
  final VyroStrings t;
  @override
  Widget build(BuildContext context) => ContentPage(
    title: t.get('foodReview'),
    children: [
      const DemoBadge(),
      const SizedBox(height: 16),
      Container(
        height: 150,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: Icon(Icons.image_outlined, size: 48)),
      ),
      const SizedBox(height: 12),
      Text(t.get('uncertain'), style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 18),
      for (final item in [
        t.get('foodRice'),
        t.get('foodChicken'),
        t.get('foodVegetables'),
      ])
        Card(
          child: ListTile(
            title: Text(item),
            subtitle: Text(t.get('portionUnknown')),
            trailing: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
        ),
      const SizedBox(height: 12),
      FilledButton(onPressed: () {}, child: Text(t.get('save'))),
    ],
  );
}

class _ProductPage extends StatelessWidget {
  const _ProductPage({required this.t});
  final VyroStrings t;
  @override
  Widget build(BuildContext context) => ContentPage(
    title: t.get('product'),
    children: [
      const DemoBadge(),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 64),
              const SizedBox(height: 12),
              Text(
                t.get('productDemo'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'EAN 5600000000000',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      MetricCard(label: t.get('energy100'), value: '—', unit: 'kcal'),
      const SizedBox(height: 8),
      for (final name in [t.get('protein'), t.get('carbs'), t.get('fat')])
        Card(
          child: ListTile(
            title: Text(name),
            trailing: Text(t.get('notAvailable')),
          ),
        ),
      const SizedBox(height: 12),
      Text(
        t.get('missingNutrients'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      FilledButton(onPressed: () {}, child: Text(t.get('addMeal'))),
    ],
  );
}

class _WorkoutDayPage extends StatelessWidget {
  const _WorkoutDayPage({required this.t});
  final VyroStrings t;
  @override
  Widget build(BuildContext context) => ContentPage(
    title: t.get('workoutDay'),
    children: [
      const DemoBadge(),
      const SizedBox(height: 14),
      Text(
        '${t.get('upper')} · 45 ${t.get('minutes')}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      for (final exercise in [
        t.get('exerciseBench'),
        t.get('exerciseRow'),
        t.get('exerciseShoulder'),
        t.get('exercisePulldown'),
      ])
        Card(
          child: ListTile(
            leading: const Icon(Icons.drag_handle),
            title: Text(exercise),
            subtitle: Text(t.get('rest90')),
            trailing: const Icon(Icons.edit_outlined),
          ),
        ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: () => Navigator.pushNamed(context, '/session'),
        child: Text(t.get('startWorkout')),
      ),
    ],
  );
}

class _SessionPage extends StatelessWidget {
  const _SessionPage({required this.t});
  final VyroStrings t;
  @override
  Widget build(BuildContext context) => ContentPage(
    title: t.get('session'),
    children: [
      const DemoBadge(),
      const SizedBox(height: 14),
      MetricCard(
        label: t.get('timer'),
        value: '12:48',
        unit: 'min',
        icon: Icons.timer_outlined,
      ),
      const SizedBox(height: 14),
      Text(
        t.get('exerciseBench').split(' · ').first,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 10),
      Card(
        child: Column(
          children: [
            ListTile(
              title: Text(t.get('set')),
              trailing: Text(t.get('repsWeight')),
            ),
            const Divider(height: 1),
            const ListTile(title: Text('1'), trailing: Text('10 · 16 kg')),
            const ListTile(title: Text('2'), trailing: Text('10 · 16 kg')),
            const ListTile(title: Text('3'), trailing: Text('— · —')),
          ],
        ),
      ),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: Text(t.get('edit')),
      ),
      FilledButton(onPressed: () {}, child: Text(t.get('finishDemo'))),
    ],
  );
}

class _CoachPage extends StatelessWidget {
  const _CoachPage({required this.t});
  final VyroStrings t;
  @override
  Widget build(BuildContext context) => ContentPage(
    title: t.get('coach'),
    children: [
      const DemoBadge(),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            t.get('coachDemo'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
      const SizedBox(height: 12),
      ActionCard(
        icon: Icons.restaurant,
        title: t.get('nutrition'),
        subtitle: t.get('sampleSuggestions'),
      ),
      ActionCard(
        icon: Icons.fitness_center,
        title: t.get('training'),
        subtitle: t.get('samplePlan'),
      ),
      const SizedBox(height: 14),
      TextField(
        decoration: InputDecoration(
          hintText: t.get('messageHint'),
          suffixIcon: IconButton(
            onPressed: () {},
            icon: const Icon(Icons.send),
          ),
        ),
      ),
    ],
  );
}

class _StatePage extends StatelessWidget {
  const _StatePage({
    required this.t,
    required this.icon,
    required this.message,
    this.loading = false,
    this.error = false,
  });
  final VyroStrings t;
  final IconData icon;
  final String message;
  final bool loading;
  final bool error;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(t.get('screens'))),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DemoBadge(),
            const SizedBox(height: 20),
            if (loading)
              const CircularProgressIndicator()
            else
              Icon(
                icon,
                size: 52,
                color: error
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (error)
              OutlinedButton(onPressed: () {}, child: Text(t.get('back'))),
          ],
        ),
      ),
    ),
  );
}
