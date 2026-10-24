import 'package:flutter/material.dart';

import 'vyro_theme.dart';

/// Shared chrome for the first-run experience: organic backdrop, brand row,
/// pill call to action, choice cards and step indicators.
///
/// Everything here is intentionally static (no looping animations) so widget
/// tests can settle and so low-end devices stay smooth.

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// Full-screen background: base colour, soft organic ribbons and a radial
/// accent glow. Wrap page content in this instead of a plain [Scaffold] body.
class VyroBackdrop extends StatelessWidget {
  const VyroBackdrop({
    super.key,
    required this.child,
    this.alignment,
    this.waves = true,
  });

  final Widget child;

  /// Organic ribbons used by the first-run screens. In-app pages turn them
  /// off for a calmer, flatter canvas and keep only a soft top glow.
  final bool waves;

  /// Where the accent glow is centred. Defaults to the upper middle.
  final Alignment? alignment;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final accent = Theme.of(context).colorScheme.primary;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          if (waves)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _WavesPainter(dark: dark, accent: accent),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: alignment ?? const Alignment(0, -0.55),
                child: FractionallySizedBox(
                  widthFactor: 1.25,
                  heightFactor: 0.9,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: dark ? 0.10 : 0.22),
                          accent.withValues(alpha: dark ? 0.03 : 0.06),
                          accent.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _WavesPainter extends CustomPainter {
  _WavesPainter({required this.dark, required this.accent});

  final bool dark;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;
    final base = dark ? accent : const Color(0xFFB7D98A);
    final strength = dark ? 0.05 : 0.30;

    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26)
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          base.withValues(alpha: strength),
          base.withValues(alpha: strength * 0.35),
          base.withValues(alpha: 0),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final upper = Path()
      ..moveTo(-w * 0.08, h * 0.08)
      ..cubicTo(w * 0.16, -h * 0.02, w * 0.30, h * 0.20, w * 0.52, h * 0.13)
      ..cubicTo(w * 0.72, h * 0.06, w * 0.82, h * 0.24, w * 1.08, h * 0.16)
      ..lineTo(w * 1.08, h * 0.33)
      ..cubicTo(w * 0.82, h * 0.42, w * 0.70, h * 0.24, w * 0.50, h * 0.31)
      ..cubicTo(w * 0.28, h * 0.39, w * 0.14, h * 0.15, -w * 0.08, h * 0.25)
      ..close();
    canvas.drawPath(upper, paint);

    final lower = Path()
      ..moveTo(w * 1.08, h * 0.62)
      ..cubicTo(w * 0.86, h * 0.54, w * 0.74, h * 0.76, w * 0.52, h * 0.70)
      ..cubicTo(w * 0.30, h * 0.64, w * 0.18, h * 0.86, -w * 0.08, h * 0.78)
      ..lineTo(-w * 0.08, h * 0.94)
      ..cubicTo(w * 0.18, h * 1.02, w * 0.32, h * 0.80, w * 0.54, h * 0.86)
      ..cubicTo(w * 0.76, h * 0.92, w * 0.88, h * 0.70, w * 1.08, h * 0.78)
      ..close();
    canvas.drawPath(lower, paint);
  }

  @override
  bool shouldRepaint(_WavesPainter oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.accent != accent;
}

/// Circular, low-contrast icon button used for back / close actions.
class VyroRoundButton extends StatelessWidget {
  const VyroRoundButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 42,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final scheme = Theme.of(context).colorScheme;
    final button = Semantics(
      button: true,
      child: Material(
        color: dark
            ? scheme.surface.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.85),
        shape: CircleBorder(side: BorderSide(color: scheme.outline)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: 20, color: scheme.onSurface),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Brand lockup: monogram tile + wordmark, with optional language/theme
/// controls on the trailing edge.
class VyroBrandRow extends StatelessWidget {
  const VyroBrandRow({
    super.key,
    this.onLanguage,
    this.onTheme,
    this.localeLabel,
    this.themeIcon,
    this.themeTooltip,
  });

  final VoidCallback? onLanguage;
  final VoidCallback? onTheme;
  final String? localeLabel;
  final IconData? themeIcon;
  final String? themeTooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = VyroTheme.accentTextOf(context);
    return Row(
      children: [
        const VyroBrandTile(size: 40),
        const SizedBox(width: 12),
        Text(
          'VYRO',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 5,
            fontSize: 15,
            color: scheme.onSurface,
          ),
        ),
        const Spacer(),
        if (onLanguage != null && localeLabel != null)
          TextButton(
            onPressed: onLanguage,
            style: TextButton.styleFrom(
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: const Size(44, 40),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(localeLabel!),
                const SizedBox(width: 2),
                Icon(Icons.expand_more_rounded, size: 18, color: accent),
              ],
            ),
          ),
        if (onTheme != null)
          IconButton(
            onPressed: onTheme,
            tooltip: themeTooltip,
            iconSize: 22,
            color: accent,
            icon: Icon(themeIcon ?? Icons.dark_mode_outlined),
          ),
      ],
    );
  }
}

/// Rounded monogram tile used in the splash, onboarding and brand row. Same
/// artwork as the launcher icon (see `brand/logos/vyro-mark-dark.svg`).
class VyroBrandTile extends StatelessWidget {
  const VyroBrandTile({super.key, this.size = 40, this.markProgress = 1});

  final double size;

  /// 0–1 drawing progress of the V, for the animated splash.
  final double markProgress;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return Semantics(
      label: 'VYRO',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [Color(0xFF181B21), VyroTheme.ink]
                : const [Colors.white, Color(0xFFF3F6F0)],
          ),
          borderRadius: BorderRadius.circular(size * 0.25),
          border: Border.all(
            color: dark ? const Color(0xFF2A2E35) : const Color(0xFFDCE2DB),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.35 : 0.08),
              blurRadius: size * 0.35,
              spreadRadius: -size * 0.1,
              offset: Offset(0, size * 0.1),
            ),
          ],
        ),
        padding: EdgeInsets.all(size * 0.2),
        child: CustomPaint(
          painter: VyroMarkPainter.of(context, progress: markProgress),
        ),
      ),
    );
  }
}

/// The VYRO mark: a solid geometric V in off-white (ink in light mode) whose
/// right arm ends in a lime "progress" cap. Lime is the signal, never the
/// whole mark. Geometry is in a unit box and matches the launcher icons and
/// `brand/logos/*.svg`.
class VyroMarkPainter extends CustomPainter {
  const VyroMarkPainter({
    required this.body,
    required this.accent,
    this.progress = 1,
  });

  /// Theme-aware colours: off-white + lime on dark, ink + green on light.
  factory VyroMarkPainter.of(BuildContext context, {double progress = 1}) {
    final dark = _isDark(context);
    return VyroMarkPainter(
      body: dark ? VyroTheme.textDark : const Color(0xFF171A20),
      accent: dark ? VyroTheme.lime : VyroTheme.green,
      progress: progress,
    );
  }

  final Color body;
  final Color accent;

  /// 0–0.75 draws the V top-down; 0.7–1 slides the lime cap in.
  final double progress;

  static const _body = [
    Offset(0.04, 0.14),
    Offset(0.33, 0.14),
    Offset(0.50, 0.60),
    Offset(0.67, 0.14),
    Offset(0.96, 0.14),
    Offset(0.63, 0.88),
    Offset(0.37, 0.88),
  ];
  static const _capBottom = 0.27;
  static const _gapBottom = 0.296;

  static double _lerpX(Offset a, Offset b, double y) =>
      a.dx + (b.dx - a.dx) * (y - a.dy) / (b.dy - a.dy);

  /// Right-arm band between the top cut and [bottom].
  static List<Offset> _band(double bottom) => [
    _body[3],
    _body[4],
    Offset(_lerpX(_body[4], _body[5], bottom), bottom),
    Offset(_lerpX(_body[2], _body[3], bottom), bottom),
  ];

  Path _path(List<Offset> points, Size size) => Path()
    ..addPolygon([
      for (final p in points) Offset(p.dx * size.width, p.dy * size.height),
    ], true);

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.clamp(0.0, 1.0);
    if (p == 0) return;
    final bodyP = Curves.easeInOutCubic.transform((p / 0.75).clamp(0.0, 1.0));
    final capP = Curves.easeOutCubic.transform(
      ((p - 0.7) / 0.3).clamp(0.0, 1.0),
    );
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(0, 0, size.width, size.height * (0.14 + 0.74 * bodyP)),
    );
    canvas.drawPath(_path(_body, size), Paint()..color = body);
    canvas.restore();
    if (capP > 0) {
      canvas.drawPath(
        _path(_band(_gapBottom), size),
        Paint()..blendMode = BlendMode.clear,
      );
      canvas.save();
      canvas.translate(size.width * 0.06 * (1 - capP), 0);
      canvas.drawPath(
        _path(_band(_capBottom), size),
        Paint()..color = accent.withValues(alpha: accent.a * capP),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(VyroMarkPainter oldDelegate) =>
      oldDelegate.body != body ||
      oldDelegate.accent != accent ||
      oldDelegate.progress != progress;
}

/// Primary pill call to action with the brand lime gradient.
class VyroPrimaryButton extends StatefulWidget {
  const VyroPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  State<VyroPrimaryButton> createState() => _VyroPrimaryButtonState();
}

class _VyroPrimaryButtonState extends State<VyroPrimaryButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.onPressed != null && !widget.loading;
    final radius = BorderRadius.circular(999);
    return Semantics(
      button: true,
      enabled: enabled,
      child: Listener(
        onPointerDown: enabled ? (_) => _setPressed(true) : null,
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? 0.985 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 58,
            decoration: BoxDecoration(
              gradient: enabled ? VyroTheme.ctaGradient(darkMode: dark) : null,
              color: enabled ? null : scheme.surfaceContainerHighest,
              borderRadius: radius,
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(
                          alpha: dark ? 0.26 : 0.34,
                        ),
                        blurRadius: 30,
                        spreadRadius: -6,
                        offset: const Offset(0, 14),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? widget.onPressed : null,
                splashColor: VyroTheme.ink.withValues(alpha: 0.10),
                highlightColor: VyroTheme.ink.withValues(alpha: 0.04),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.loading) ...[
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: VyroTheme.ink,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Flexible(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.1,
                              color: enabled
                                  ? VyroTheme.ink
                                  : scheme.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                        if (widget.icon != null && !widget.loading) ...[
                          const SizedBox(width: 10),
                          Icon(widget.icon, size: 20, color: VyroTheme.ink),
                        ],
                      ],
                    ),
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

/// Small centred page indicator.
class VyroDots extends StatelessWidget {
  const VyroDots({super.key, required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = _isDark(context);
    return Semantics(
      label: '${index + 1} / $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final active = i == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: active ? 9 : 8,
            height: active ? 9 : 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? scheme.primary
                  : scheme.outline.withValues(alpha: dark ? 0.9 : 0.75),
            ),
          );
        }),
      ),
    );
  }
}

/// Segmented progress rail for the base-data wizard.
class VyroStepRail extends StatelessWidget {
  const VyroStepRail({
    super.key,
    required this.index,
    required this.count,
    this.height = 3,
  });

  final int index;
  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Row(
        children: List.generate(count, (i) {
          final done = i < index;
          final active = i == index;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              height: height,
              margin: EdgeInsets.only(right: i == count - 1 ? 0 : 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: active
                    ? scheme.primary
                    : done
                    ? scheme.primary.withValues(alpha: 0.42)
                    : scheme.outline,
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Step counter pill ("1 / 8").
class VyroStepPill extends StatelessWidget {
  const VyroStepPill({super.key, required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = Theme.of(context).textTheme.labelSmall?.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: _isDark(context) ? 0.6 : 1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: scheme.outline),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${index + 1}',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            TextSpan(
              text: ' / $count',
              style: TextStyle(
                color: muted,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centred step heading with an optional lime eyebrow.
class VyroStepHeader extends StatelessWidget {
  const VyroStepHeader({
    super.key,
    required this.title,
    this.body,
    this.eyebrow,
    this.maxWidth = 460,
  });

  final String title;
  final String? body;
  final String? eyebrow;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (eyebrow != null) ...[
            Text(
              eyebrow!.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
                color: VyroTheme.accentTextOf(context),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          if (body != null) ...[
            const SizedBox(height: 10),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// Surface card with a thin border and a soft top-lit gradient.
class VyroCard extends StatelessWidget {
  const VyroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.tint,
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tint ?? (dark ? const Color(0xFF15181E) : Colors.white),
            tint ?? (dark ? const Color(0xFF101318) : const Color(0xFFFCFDFA)),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: scheme.outline),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF2C3A1B).withValues(alpha: 0.06),
                  blurRadius: 24,
                  spreadRadius: -8,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Large tappable option used across onboarding and settings.
class VyroChoiceCard extends StatelessWidget {
  const VyroChoiceCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.icon,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    final radius = BorderRadius.circular(20);
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: dark ? 0.10 : 0.14)
              : (dark ? const Color(0xFF15181E) : Colors.white),
          borderRadius: radius,
          border: Border.all(
            color: selected ? accent : scheme.outline,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: dark ? 0.16 : 0.22),
                    blurRadius: 22,
                    spreadRadius: -6,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: selected
                            ? accent.withValues(alpha: dark ? 0.18 : 0.20)
                            : (dark
                                  ? const Color(0xFF20242B)
                                  : const Color(0xFFF0F4EA)),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        icon,
                        size: 21,
                        color: selected
                            ? VyroTheme.accentTextOf(context)
                            : scheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  trailing ?? _SelectionDot(selected: selected, accent: accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected, required this.accent});

  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? accent : Colors.transparent,
        border: Border.all(
          color: selected ? accent : scheme.outline,
          width: 1.6,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 15, color: VyroTheme.ink)
          : null,
    );
  }
}

/// Compact selectable pill used for sex, diet and equipment.
class VyroPillChip extends StatelessWidget {
  const VyroPillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    final radius = BorderRadius.circular(99);
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: dark ? 0.16 : 0.20)
              : (dark ? const Color(0xFF15181E) : Colors.white),
          borderRadius: radius,
          border: Border.all(
            color: selected ? accent : scheme.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: VyroTheme.accentTextOf(context),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected
                          ? VyroTheme.accentTextOf(context)
                          : scheme.onSurface,
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

/// Sticky bottom action area. Transparent by default so the page backdrop
/// stays continuous; pass [elevated] to add a hairline and surface fill.
class VyroFooter extends StatelessWidget {
  const VyroFooter({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 16),
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = _isDark(context);
    final content = SafeArea(
      top: false,
      child: Padding(padding: padding, child: child),
    );
    if (!elevated) return content;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: scheme.outline)),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF2C3A1B).withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
      ),
      child: content,
    );
  }
}
