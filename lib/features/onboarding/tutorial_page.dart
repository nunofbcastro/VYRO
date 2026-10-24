import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../app/l10n/strings.dart';
import '../../app/theme/appearance_sheet.dart';
import '../../app/theme/vyro_chrome.dart';
import '../../app/theme/vyro_theme.dart';

class TutorialPage extends StatefulWidget {
  const TutorialPage({super.key, this.preview = false, this.onComplete});

  final bool preview;
  final VoidCallback? onComplete;

  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends State<TutorialPage> {
  final controller = PageController();
  int page = 0;

  static const _slides = <_Slide>[
    _Slide(
      title: 'tutorialWelcomeTitle',
      body: 'tutorialWelcomeBody',
      graphic: _Graphic.welcome,
    ),
    _Slide(
      title: 'tutorialNutritionTitle',
      body: 'tutorialNutritionBody',
      graphic: _Graphic.nutrition,
    ),
    _Slide(
      title: 'tutorialTrainingTitle',
      body: 'tutorialTrainingBody',
      graphic: _Graphic.training,
    ),
    _Slide(
      title: 'tutorialPrivacyTitle',
      body: 'tutorialPrivacyBody',
      graphic: _Graphic.privacy,
    ),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _goTo(int value) {
    controller.animateToPage(
      value,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final settings = SettingsScope.maybeOf(context);
    final isLast = page == _slides.length - 1;
    final brightness = theme.brightness;
    final locale = Localizations.localeOf(context).languageCode.toUpperCase();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: VyroBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                    child: VyroBrandRow(
                      localeLabel: locale,
                      themeIcon: brightness == Brightness.dark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      themeTooltip: t.get('appearance'),
                      onLanguage: settings == null
                          ? null
                          : () => showAppearanceSheet(context),
                      onTheme: settings == null
                          ? null
                          : () {
                              settings.setTheme(
                                brightness == Brightness.dark
                                    ? ThemeMode.light
                                    : ThemeMode.dark,
                              );
                            },
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: controller,
                      itemCount: _slides.length,
                      onPageChanged: (value) => setState(() => page = value),
                      itemBuilder: (context, index) => _SlideView(
                        slide: _slides[index],
                        t: t,
                        index: index,
                        total: _slides.length,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      children: [
                        VyroDots(index: page, count: _slides.length),
                        const SizedBox(height: 20),
                        VyroPrimaryButton(
                          label: isLast
                              ? t.get('tutorialStart')
                              : t.get('tutorialNext'),
                          onPressed: () {
                            if (isLast) {
                              widget.onComplete?.call();
                            } else {
                              _goTo(page + 1);
                            }
                          },
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 40,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (page > 0)
                                TextButton(
                                  onPressed: () => _goTo(page - 1),
                                  child: Text(t.get('tutorialBack')),
                                ),
                              if (page > 0 && !isLast) const SizedBox(width: 4),
                              if (!isLast)
                                TextButton(
                                  onPressed: widget.onComplete,
                                  child: Text(t.get('tutorialSkip')),
                                ),
                            ],
                          ),
                        ),
                        if (widget.preview)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              t.get('tutorialPreviewNote'),
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.title,
    required this.body,
    required this.graphic,
  });
  final String title;
  final String body;
  final _Graphic graphic;
}

enum _Graphic { welcome, nutrition, training, privacy }

class _SlideView extends StatelessWidget {
  const _SlideView({
    required this.slide,
    required this.t,
    required this.index,
    required this.total,
  });

  final _Slide slide;
  final VyroStrings t;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final heroHeight = (constraints.maxHeight * 0.48).clamp(220.0, 400.0);
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: heroHeight,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 320,
                        height: 300,
                        child: _GraphicView(graphic: slide.graphic),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    '${(index + 1).toString().padLeft(2, '0')} — ${total.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.4,
                      color: VyroTheme.accentTextOf(context),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t.get(slide.title),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Text(
                      t.get(slide.body),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GraphicView extends StatelessWidget {
  const _GraphicView({required this.graphic});
  final _Graphic graphic;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (graphic) {
      _Graphic.welcome => _WelcomeHero(accent: scheme.primary),
      _Graphic.nutrition => _PreviewHero(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 74,
                  height: 74,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: 0.64,
                          strokeWidth: 7,
                          strokeCap: StrokeCap.round,
                          backgroundColor: scheme.outline.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 22,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Bar(width: 96, height: 13, color: scheme.onSurface),
                      const SizedBox(height: 9),
                      const _Bar(width: 58, height: 8),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            for (final value in const [0.86, 0.6, 0.38]) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 9,
                  backgroundColor: scheme.outline.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
      _Graphic.training => _PreviewHero(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.fitness_center_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: _Bar(width: 120, height: 11)),
              ],
            ),
            const SizedBox(height: 20),
            for (var index = 0; index < 3; index++) ...[
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: index == 0 ? scheme.primary : scheme.outline,
                        width: 1.4,
                      ),
                      color: index == 0
                          ? scheme.primary.withValues(alpha: 0.22)
                          : null,
                    ),
                    child: index == 0
                        ? Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: scheme.primary,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Bar(
                      width: double.infinity,
                      height: 10,
                      color: index == 0
                          ? scheme.onSurface.withValues(alpha: 0.65)
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
      _Graphic.privacy => _PreviewHero(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.28),
                    scheme.primary.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                color: scheme.primary,
                size: 26,
              ),
            ),
            const SizedBox(height: 18),
            for (final key in const [
              'localOnly',
              'onboardingDataNote',
              'photoNoImage',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: VyroTheme.accentTextOf(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stringsOf(context).get(key),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    };
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.height, this.color});

  final double width;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? scheme.outline.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

/// Concentric rings with the monogram at the centre.
class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget ring(double size, double alpha) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: alpha)),
      ),
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 292,
          height: 292,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                accent.withValues(alpha: dark ? 0.16 : 0.26),
                accent.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        ring(288, 0.10),
        ring(228, 0.16),
        ring(176, 0.22),
        const VyroBrandTile(size: 116),
        Positioned(top: 40, right: 34, child: _dot(9, accent)),
        Positioned(bottom: 52, left: 40, child: _dot(6, accent)),
        Positioned(top: 116, left: 18, child: _dot(7, accent)),
      ],
    );
  }

  Widget _dot(double size, Color accent) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: accent.withValues(alpha: 0.55),
    ),
  );
}

/// Floating card preview used by the non-welcome slides.
class _PreviewHero extends StatelessWidget {
  const _PreviewHero({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                accent.withValues(alpha: dark ? 0.14 : 0.22),
                accent.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 300,
          child: VyroCard(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            child: child,
          ),
        ),
      ],
    );
  }
}
