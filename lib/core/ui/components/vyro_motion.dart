import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Motion primitives shared by every screen.
///
/// All of them animate once (never loop), are short (≤ 450 ms) and are
/// skipped when the OS asks to reduce motion
/// (`MediaQuery.disableAnimationsOf`).
class VyroMotion {
  static const fast = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);
  static const curve = Curves.easeOutCubic;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Fades and slides its child up the first time it is built.
///
/// ```dart
/// VyroFadeSlideIn(delay: Duration(milliseconds: 80), child: VyroCard(...))
/// ```
class VyroFadeSlideIn extends StatefulWidget {
  const VyroFadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 14,
    this.duration = VyroMotion.slow,
  });

  final Widget child;
  final Duration delay;

  /// Starting vertical offset in logical pixels.
  final double offset;
  final Duration duration;

  @override
  State<VyroFadeSlideIn> createState() => _VyroFadeSlideInState();
}

class _VyroFadeSlideInState extends State<VyroFadeSlideIn>
    with SingleTickerProviderStateMixin {
  // The delay is part of the animation (an Interval), so no timers are
  // left pending when the widget goes away.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.inMicroseconds /
          (widget.delay + widget.duration).inMicroseconds,
      1,
      curve: VyroMotion.curve,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (VyroMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = _animation;
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, widget.offset * (1 - animation.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Wraps [children] in [VyroFadeSlideIn] with increasing delays, capped so
/// long lists never feel slow.
List<Widget> vyroStagger(
  List<Widget> children, {
  Duration step = const Duration(milliseconds: 45),
  Duration maxDelay = const Duration(milliseconds: 360),
}) => [
  for (var i = 0; i < children.length; i++)
    VyroFadeSlideIn(
      delay: step * i > maxDelay ? maxDelay : step * i,
      child: children[i],
    ),
];

/// Number that counts to its new value (calories, grams, reps).
///
/// ```dart
/// VyroAnimatedNumber(value: kcal, style: theme.textTheme.headlineSmall)
/// ```
class VyroAnimatedNumber extends StatelessWidget {
  const VyroAnimatedNumber({
    super.key,
    required this.value,
    this.style,
    this.decimals = 0,
    this.suffix = '',
    this.textAlign,
  });

  final double value;
  final TextStyle? style;
  final int decimals;
  final String suffix;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final text = (double v) => '${v.toStringAsFixed(decimals)}$suffix';
    if (VyroMotion.reduced(context)) {
      return Text(text(value), style: style, textAlign: textAlign);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: VyroMotion.slow,
      curve: VyroMotion.curve,
      builder: (context, animated, _) => Text(
        text(animated),
        style: style?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        textAlign: textAlign,
        semanticsLabel: text(value),
      ),
    );
  }
}

/// Subtle press feedback: scales down while pressed and gives a light
/// haptic tick on tap. Put it around any tappable card or tile.
class VyroPressable extends StatefulWidget {
  const VyroPressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 0.97,
    this.haptic = true,
  });

  final Widget child;
  final bool enabled;
  final double scale;
  final bool haptic;

  @override
  State<VyroPressable> createState() => _VyroPressableState();
}

class _VyroPressableState extends State<VyroPressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || VyroMotion.reduced(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) {
        _set(false);
        if (widget.haptic) HapticFeedback.selectionClick();
      },
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: VyroMotion.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// [IndexedStack] that fades and lifts the newly selected child in, keeping
/// every child's state (used by the tab shell).
class VyroFadeIndexedStack extends StatefulWidget {
  const VyroFadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<VyroFadeIndexedStack> createState() => _VyroFadeIndexedStackState();
}

class _VyroFadeIndexedStackState extends State<VyroFadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: VyroMotion.normal,
    value: 1,
  );

  @override
  void didUpdateWidget(VyroFadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && !VyroMotion.reduced(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: VyroMotion.curve,
    );
    return FadeTransition(
      opacity: Tween(begin: 0.0, end: 1.0).animate(animation),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 10 * (1 - animation.value)),
          child: child,
        ),
        child: IndexedStack(index: widget.index, children: widget.children),
      ),
    );
  }
}
