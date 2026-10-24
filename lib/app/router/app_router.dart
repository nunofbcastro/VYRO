import 'package:flutter/material.dart';

import '../../features/dashboard/home_shell.dart';
import '../../features/design_showcase/design_system_page.dart';
import '../../features/demo/demo_page.dart';
import '../../features/nutrition/nutrition_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/progress/progress_page.dart';
import '../../features/workouts/training_page.dart';

class VyroRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute<void>(builder: (_) => const HomeShell());
      case '/design-system':
        return MaterialPageRoute<void>(
          builder: (_) => const DesignSystemPage(),
        );
      case '/home':
        return MaterialPageRoute<void>(builder: (_) => const HomeShell());
      case '/nutrition':
        return MaterialPageRoute<void>(builder: (_) => const NutritionPage());
      case '/training':
        return MaterialPageRoute<void>(builder: (_) => const TrainingPage());
      case '/progress':
        return MaterialPageRoute<void>(builder: (_) => const ProgressPage());
      case '/profile':
        return MaterialPageRoute<void>(builder: (_) => const ProfilePage());
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => DemoPage(screenId: settings.name ?? 'home'),
        );
    }
  }
}
