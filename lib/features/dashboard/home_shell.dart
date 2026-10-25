import 'package:flutter/material.dart';

import '../../app/l10n/strings.dart';
import '../../app/theme/vyro_shell.dart';
import '../../core/ui/components/vyro_motion.dart';
import '../nutrition/nutrition_diary_page.dart';
import '../profile/profile_settings_page.dart';
import '../progress/progress_page.dart';
import '../workouts/training_home_page.dart';
import 'live_home_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();

  /// Switches the visible tab when [context] is inside the shell. Returns
  /// false when it is not (e.g. a pushed route), so callers can navigate.
  static bool selectTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_HomeShellState>();
    if (state == null) return false;
    state.select(index);
    return true;
  }
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  void select(int value) => setState(() => index = value);

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final pages = [
      const LiveHomePage(),
      const NutritionDiaryPage(),
      const TrainingPage(),
      const ProgressPage(),
      const ProfileSettingsPage(),
    ];
    final items = [
      VyroNavItem(label: t.get('home'), icon: Icons.grid_view_rounded),
      VyroNavItem(label: t.get('nutrition'), icon: Icons.restaurant_rounded),
      VyroNavItem(label: t.get('training'), icon: Icons.fitness_center_rounded),
      VyroNavItem(label: t.get('progress'), icon: Icons.show_chart_rounded),
      VyroNavItem(label: t.get('profile'), icon: Icons.person_rounded),
    ];
    // extendBody lets each page's backdrop run behind the floating bar, so
    // there is never a bare strip under it; pages pad by the bar height.
    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: VyroFadeIndexedStack(index: index, children: pages),
      bottomNavigationBar: VyroNavBar(
        index: index,
        onSelect: (value) => setState(() => index = value),
        items: items,
      ),
    );
  }
}
