import 'package:flutter/material.dart';

import 'l10n/strings.dart';
import 'theme/vyro_chrome.dart';
import 'theme/vyro_theme.dart';

/// Animated brand intro shown while local settings load.
///
/// Sequence (≈1.6 s): the tile springs in, the V draws itself (left arm down,
/// right arm up), "VYRO" letters rise one by one, then the tagline fades in.
/// Two soft rings keep pulsing behind the tile while loading continues.
/// With "reduce motion" enabled, everything appears at once.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, this.error, this.onRetry});

  final Object? error;
  final VoidCallback? onRetry;

  /// Length of the intro; [VyroRoot] keeps the splash at least this long.
  static const introDuration = Duration(milliseconds: 1600);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: SplashPage.introDuration,
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
      _pulse.stop();
    } else if (!_intro.isAnimating && _intro.value == 0) {
      _intro.forward();
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Maps the intro controller to a sub-interval with a curve.
  double _phase(double begin, double end, [Curve curve = Curves.easeOut]) =>
      curve.transform(((_intro.value - begin) / (end - begin)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final dark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: VyroBackdrop(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_intro, _pulse]),
                  builder: (context, _) {
                    final tileIn = _phase(0, 0.38, Curves.easeOutBack);
                    final draw = _phase(0.18, 0.72, Curves.linear);
                    final tagline = _phase(0.78, 1);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 240,
                          height: 240,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      accent.withValues(
                                        alpha: (dark ? 0.16 : 0.26) * tileIn,
                                      ),
                                      accent.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                              for (final shift in const [0.0, 0.5])
                                _PulseRing(
                                  value: (_pulse.value + shift) % 1,
                                  color: accent,
                                  visible: tileIn,
                                ),
                              Opacity(
                                opacity: tileIn.clamp(0.0, 1.0),
                                child: Transform.scale(
                                  scale: 0.6 + 0.4 * tileIn,
                                  child: VyroBrandTile(
                                    size: 96,
                                    markProgress: draw,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _StaggeredWord(
                          word: 'VYRO',
                          progress: _phase(0.5, 0.92, Curves.linear),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 7,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Opacity(
                          opacity: tagline,
                          child: Transform.translate(
                            offset: Offset(0, 8 * (1 - tagline)),
                            child: Text(
                              t.get('splashLine'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (widget.error == null)
                          Opacity(
                            opacity: tagline,
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: VyroTheme.accentTextOf(context),
                              ),
                            ),
                          )
                        else ...[
                          Text(
                            t.get('storageError'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t.get('storageErrorBody'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: widget.onRetry,
                            child: Text(t.get('retry')),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A thin ring that grows and fades out; two offset rings read as a pulse.
class _PulseRing extends StatelessWidget {
  const _PulseRing({
    required this.value,
    required this.color,
    required this.visible,
  });

  final double value;
  final Color color;
  final double visible;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOut.transform(value);
    return IgnorePointer(
      child: Container(
        width: 110 + 120 * eased,
        height: 110 + 120 * eased,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(
              alpha: (0.35 * (1 - eased) * visible).clamp(0.0, 1.0),
            ),
            width: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Letters fade in and rise one after another.
class _StaggeredWord extends StatelessWidget {
  const _StaggeredWord({
    required this.word,
    required this.progress,
    this.style,
  });

  final String word;
  final double progress;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final count = word.length;
    return Semantics(
      label: word,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++)
              Builder(
                builder: (context) {
                  final start = i / (count + 1);
                  final local = Curves.easeOutCubic.transform(
                    ((progress - start) * (count + 1) / 2).clamp(0.0, 1.0),
                  );
                  return Opacity(
                    opacity: local,
                    child: Transform.translate(
                      offset: Offset(0, 14 * (1 - local)),
                      child: Text(word[i], style: style),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
