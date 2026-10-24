import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../../core/ui/components/vyro_glass.dart';
import 'vyro_chrome.dart';
import 'vyro_theme.dart';

/// Tab page chrome in the iOS "large title" style.
///
/// The big title sits under a transparent bar; as the body scrolls, it slides
/// away and a compact centred title fades in on a frosted-glass bar. Actions
/// stay pinned on the right; pushed copies of a tab page get a back button.
///
/// The body is laid out full-height under the header. The header height is
/// passed down as top [MediaQuery] padding, which [VyroPageBody] honours, so
/// content starts below the large title and scrolls beneath the glass.
class VyroPageScaffold extends StatefulWidget {
  const VyroPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.eyebrow,
    this.actions = const [],
    this.showDemo = false,
  });

  final String title;

  /// Small accent label above the large title (e.g. the selected day).
  final String? eyebrow;
  final List<Widget> actions;
  final Widget body;
  final bool showDemo;

  @override
  State<VyroPageScaffold> createState() => _VyroPageScaffoldState();
}

class _VyroPageScaffoldState extends State<VyroPageScaffold> {
  static const _barHeight = 52.0;
  final _offset = ValueNotifier<double>(0);

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  double get _largeHeight => widget.eyebrow == null ? 52 : 70;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth == 0 && notification.metrics.axis == Axis.vertical) {
      _offset.value = notification.metrics.pixels;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final headerHeight = _barHeight + _largeHeight;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: VyroBackdrop(
        waves: false,
        alignment: const Alignment(0, -1.1),
        child: Stack(
          children: [
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: MediaQuery(
                  data: media.copyWith(
                    padding: media.padding.copyWith(
                      top: media.padding.top + headerHeight,
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: widget.body,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<double>(
                valueListenable: _offset,
                builder: (context, offset, _) => _LargeTitleHeader(
                  title: widget.title,
                  eyebrow: widget.eyebrow,
                  actions: [
                    if (widget.showDemo) const _DemoPill(),
                    ...widget.actions,
                  ],
                  canPop: canPop,
                  offset: offset,
                  topInset: media.padding.top,
                  barHeight: _barHeight,
                  largeHeight: _largeHeight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LargeTitleHeader extends StatelessWidget {
  const _LargeTitleHeader({
    required this.title,
    required this.eyebrow,
    required this.actions,
    required this.canPop,
    required this.offset,
    required this.topInset,
    required this.barHeight,
    required this.largeHeight,
  });

  final String title;
  final String? eyebrow;
  final List<Widget> actions;
  final bool canPop;
  final double offset;
  final double topInset;
  final double barHeight;
  final double largeHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scroll = offset.clamp(0.0, largeHeight);
    // 0 → expanded, 1 → collapsed.
    final progress = scroll / largeHeight;
    final compact = ((progress - 0.6) / 0.4).clamp(0.0, 1.0);
    final height = topInset + barHeight + largeHeight - scroll;
    return SizedBox(
      height: height,
      child: VyroGlass(
        opacity: compact,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: compact),
            width: 0.8,
          ),
        ),
        child: ClipRect(
          child: Stack(
            children: [
              // Large title, scrolling up with the content.
              Positioned(
                left: 0,
                right: 0,
                top: topInset + barHeight - scroll,
                height: largeHeight,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Opacity(
                      opacity: (1 - progress * 1.4).clamp(0.0, 1.0),
                      child: Container(
                        width: double.infinity,
                        alignment: Alignment.bottomLeft,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (eyebrow != null) ...[
                              Text(
                                eyebrow!.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.6,
                                  color: VyroTheme.accentTextOf(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: 32,
                                letterSpacing: -1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Compact bar: back button, centred title, actions.
              Positioned(
                left: 0,
                right: 0,
                top: topInset,
                height: barHeight,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          if (canPop)
                            VyroRoundButton(
                              icon: Icons.arrow_back_rounded,
                              tooltip: stringsOf(context).get('back'),
                              size: 38,
                              onPressed: () => Navigator.maybePop(context),
                            )
                          else
                            const VyroWordmark(),
                          Expanded(
                            child: Opacity(
                              opacity: compact,
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 38),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < actions.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 8),
                                  actions[i],
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoPill extends StatelessWidget {
  const _DemoPill();

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: stringsOf(context).get('demo'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
        ),
        child: Text(
          stringsOf(context).get('demo'),
          style: TextStyle(
            color: VyroTheme.accentTextOf(context),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
          ),
        ),
      ),
    );
  }
}

/// Scrollable page body with the shared horizontal rhythm.
class VyroPageBody extends StatelessWidget {
  const VyroPageBody({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 6, 20, 28),
    this.controller,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => ListView(
    controller: controller,
    // Inside the tab shell the Scaffold reports the floating navigation bar
    // as bottom padding; add it so the last card is never hidden.
    padding: padding.copyWith(
      top: padding.top + MediaQuery.paddingOf(context).top,
      bottom: padding.bottom + MediaQuery.paddingOf(context).bottom,
    ),
    children: children,
  );
}

/// Section heading with an optional text action.
class VyroSectionTitle extends StatelessWidget {
  const VyroSectionTitle({
    super.key,
    required this.label,
    this.action,
    this.onAction,
  });

  final String label;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: VyroTheme.accentTextOf(context),
                minimumSize: const Size(44, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// Floating bottom navigation with the lime indicator.
class VyroNavBar extends StatelessWidget {
  const VyroNavBar({
    super.key,
    required this.index,
    required this.onSelect,
    required this.items,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final List<VyroNavItem> items;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: (dark ? Colors.black : const Color(0xFF2C3A1B))
                    .withValues(alpha: dark ? 0.5 : 0.10),
                blurRadius: 30,
                spreadRadius: -10,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: VyroGlass(
            borderRadius: BorderRadius.circular(28),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: _NavButton(
                          item: items[i],
                          selected: i == index,
                          onTap: () => onSelect(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VyroNavItem {
  const VyroNavItem({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final VyroNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final active = VyroTheme.accentTextOf(context);
    final idle = Theme.of(context).textTheme.bodySmall?.color;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  height: 30,
                  width: 46,
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary.withValues(alpha: dark ? 0.18 : 0.20)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: selected ? active : idle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: 0.1,
                    color: selected ? active : idle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pushed (non-tab) page: round back button, compact title, optional trailing
/// actions and a sticky footer for the primary action. Uses the same backdrop
/// as the tab pages so navigation never flashes a different surface.
class VyroSubpageScaffold extends StatelessWidget {
  const VyroSubpageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.footer,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: VyroBackdrop(
        alignment: const Alignment(0, -1),
        child: SafeArea(
          bottom: footer == null,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    child: Row(
                      children: [
                        VyroRoundButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: t.get('back'),
                          onPressed: () => Navigator.maybePop(context),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        ...actions,
                      ],
                    ),
                  ),
                  Expanded(child: body),
                  if (footer != null)
                    VyroFooter(elevated: true, child: footer!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact brand lockup (V mark + "VYRO") shown at the top-left of tab pages.
class VyroWordmark extends StatelessWidget {
  const VyroWordmark({super.key, this.height = 20});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'VYRO',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: height,
              child: CustomPaint(painter: VyroMarkPainter.of(context)),
            ),
            SizedBox(width: height * 0.4),
            Text(
              'VYRO',
              style: TextStyle(
                fontSize: height * 0.78,
                fontWeight: FontWeight.w900,
                letterSpacing: height * 0.22,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
