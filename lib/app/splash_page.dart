import 'package:flutter/material.dart';

import 'l10n/strings.dart';
import 'theme/vyro_chrome.dart';

/// One calm entrance while local settings load. The complete mark stays
/// intact; only opacity and a small vertical offset animate once.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, this.error, this.onRetry});

  final Object? error;
  final VoidCallback? onRetry;

  static const introDuration = Duration(milliseconds: 700);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: SplashPage.introDuration,
  );
  late final Animation<double> _entrance = CurvedAnimation(
    parent: _intro,
    curve: Curves.easeOutCubic,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else if (_intro.value == 0 && !_intro.isAnimating) {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: FadeTransition(
                opacity: _entrance,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.025),
                    end: Offset.zero,
                  ).animate(_entrance),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const RepaintBoundary(child: VyroBrandTile(size: 96)),
                      const SizedBox(height: 28),
                      Text(
                        'VYRO',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 7,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        t.get('splashLine'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 32),
                      if (widget.error == null)
                        SizedBox(
                          width: 40,
                          child: LinearProgressIndicator(
                            value: reduceMotion ? 0.5 : null,
                            minHeight: 2,
                            borderRadius: BorderRadius.circular(2),
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
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
