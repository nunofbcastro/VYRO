import 'package:flutter/material.dart';

import '../root_gate.dart';
import '../splash_page.dart';
import '../../features/dashboard/home_shell.dart';
import '../../features/assistant/assistant_page.dart';
import '../../features/assistant/local_intelligence_page.dart';
import '../../features/barcode/barcode_scanner_page.dart';
import '../../features/design_showcase/design_system_page.dart';
import '../../features/demo/demo_page.dart';
import '../../features/nutrition/nutrition_diary_page.dart';
import '../../features/nutrition/photo_food_page.dart';
import '../../features/nutrition/nutrition_targets_page.dart';
import '../../features/onboarding/onboarding_flow.dart';
import '../../features/onboarding/setup_wizard_page.dart';
import '../../features/motion_engine/workout_camera/motion_coach_page.dart';
import '../../features/profile/profile_settings_page.dart';
import '../../features/profile/privacy_policy_page.dart';
import '../../features/progress/progress_page.dart';
import '../../features/workouts/training_home_page.dart';

class VyroRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute<void>(builder: (_) => const VyroRoot());
      case '/splash':
        return MaterialPageRoute<void>(builder: (_) => const SplashPage());
      case '/onboarding':
        return MaterialPageRoute<void>(
          builder: (_) => const OnboardingFlow(preview: true),
        );
      case '/profile-setup':
        return MaterialPageRoute<void>(
          builder: (_) => const SetupWizardPage(preview: true),
        );
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
      case '/nutrition-targets':
        return MaterialPageRoute<void>(
          builder: (_) => const NutritionTargetsPage(),
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
      case '/assistant':
        return MaterialPageRoute<void>(builder: (_) => const AssistantPage());
      case '/local-intelligence':
        return MaterialPageRoute<void>(
          builder: (_) => LocalIntelligencePage(
            day: settings.arguments is DateTime
                ? settings.arguments as DateTime
                : null,
          ),
        );
      case '/motion':
        return MaterialPageRoute<void>(
          builder: (_) => const MotionCoachPage(
            exerciseKey: 'goblet_squat',
            exerciseName: 'Agachamento',
          ),
        );
      case '/training':
        return MaterialPageRoute<void>(builder: (_) => const TrainingPage());
      case '/progress':
        return MaterialPageRoute<void>(builder: (_) => const ProgressPage());
      case '/profile':
        return MaterialPageRoute<void>(
          builder: (_) => const ProfileSettingsPage(),
        );
      case '/privacy':
        return MaterialPageRoute<void>(
          builder: (_) => const PrivacyPolicyPage(),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => DemoPage(screenId: settings.name ?? 'home'),
        );
    }
  }
}
