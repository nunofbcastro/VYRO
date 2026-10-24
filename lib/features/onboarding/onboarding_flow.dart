import 'package:flutter/material.dart';

import 'setup_wizard_page.dart';
import 'tutorial_page.dart';

/// Tutorial → base data → app. Used as the root gate when onboarding is not
/// complete, and as a preview from the design system.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, this.preview = false});

  final bool preview;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  bool inSetup = false;

  @override
  Widget build(BuildContext context) {
    final child = inSetup
        ? SetupWizardPage(
            key: const ValueKey('setup'),
            preview: widget.preview,
            onBackToTutorial: () => setState(() => inSetup = false),
            onFinished: widget.preview
                ? (_) {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  }
                : null,
          )
        : TutorialPage(
            key: const ValueKey('tutorial'),
            preview: widget.preview,
            onComplete: () => setState(() => inSetup = true),
          );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.03, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
