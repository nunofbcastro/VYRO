import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'splash_page.dart';
import '../features/dashboard/home_shell.dart';
import '../features/onboarding/onboarding_flow.dart';

/// Decides what the app opens with:
/// 1. the animated splash while local settings load (kept until its short
///    intro finishes, so it never flashes);
/// 2. tutorial + base data when onboarding is not complete;
/// 3. the five-tab shell afterwards.
///
/// Switching between these uses a short fade without scaling the screens.
class VyroRoot extends StatefulWidget {
  const VyroRoot({super.key});

  @override
  State<VyroRoot> createState() => _VyroRootState();
}

class _VyroRootState extends State<VyroRoot> {
  bool _introDone = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(
      SplashPage.introDuration + const Duration(milliseconds: 250),
      () {
        if (mounted) setState(() => _introDone = true);
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final Widget child;
    if (settings.error != null) {
      child = SplashPage(
        key: const ValueKey('error'),
        error: settings.error,
        onRetry: () => settings.load(settings.services),
      );
    } else if (!settings.ready || !_introDone) {
      child = SplashPage(
        key: const ValueKey('splash'),
        onRetry: () => settings.load(settings.services),
      );
    } else if (!settings.onboardingCompleted) {
      child = const OnboardingFlow(key: ValueKey('onboarding'));
    } else {
      child = const HomeShell(key: ValueKey('home'));
    }
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: child,
    );
  }
}
