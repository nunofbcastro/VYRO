import 'package:flutter/material.dart';

import '../../app/l10n/strings.dart';
import '../nutrition/nutrition_diary_page.dart';
import '../profile/profile_page.dart';
import '../progress/progress_page.dart';
import '../workouts/training_page.dart';
import 'home_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final pages = [
      const HomePage(),
      const NutritionDiaryPage(),
      const TrainingPage(),
      const ProgressPage(),
      const ProfilePage(),
    ];
    final labels = ['home', 'nutrition', 'training', 'progress', 'profile'];
    final icons = [
      Icons.grid_view_rounded,
      Icons.restaurant_rounded,
      Icons.fitness_center_rounded,
      Icons.show_chart_rounded,
      Icons.person_rounded,
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: List.generate(
          labels.length,
          (i) => NavigationDestination(
            icon: Icon(icons[i]),
            label: t.get(labels[i]),
          ),
        ),
      ),
    );
  }
}
