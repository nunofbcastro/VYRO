import 'package:flutter/material.dart';

import '../../features/dashboard/home_shell.dart';
import '../../features/barcode/barcode_scanner_page.dart';
import '../../features/design_showcase/design_system_page.dart';
import '../../features/demo/demo_page.dart';
import '../../features/nutrition/nutrition_diary_page.dart';
import '../../features/nutrition/photo_food_page.dart';
import '../../features/pose/motion_page.dart';
import '../../features/profile/profile_settings_page.dart';
import '../../features/progress/progress_page.dart';
import '../../features/workouts/training_home_page.dart';

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
        return MaterialPageRoute<void>(
          builder: (_) => const NutritionDiaryPage(),
        );
      case '/barcode':
        return MaterialPageRoute<void>(
          builder: (_) => BarcodeScannerPage(
            day: settings.arguments is DateTime
                ? settings.arguments! as DateTime
                : DateTime.now(),
          ),
        );
      case '/photo-camera':
        return MaterialPageRoute<void>(
          builder: (_) => PhotoFoodPage(
            day: settings.arguments is DateTime
                ? settings.arguments! as DateTime
                : DateTime.now(),
          ),
        );
      case '/motion':
        return MaterialPageRoute<void>(builder: (_) => const MotionPage());
      case '/training':
        return MaterialPageRoute<void>(builder: (_) => const TrainingPage());
      case '/progress':
        return MaterialPageRoute<void>(builder: (_) => const ProgressPage());
      case '/profile':
        return MaterialPageRoute<void>(
          builder: (_) => const ProfileSettingsPage(),
        );
      case '/profile-setup':
        return MaterialPageRoute<void>(
          builder: (_) => const ProfileSettingsPage(),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => DemoPage(screenId: settings.name ?? 'home'),
        );
    }
  }
}
