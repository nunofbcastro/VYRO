import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/l10n/strings.dart';
import '../../../core/ui/vyro_ui.dart';
import '../data/food_database.dart';
import '../food_vision/food_screening.dart';
import '../food_vision/food_vision.dart';
import '../photo/review_model.dart';
import 'food_picker_sheet.dart' show foodCategoryIcon, foodSourceTag;

/// Dims the photo and sweeps a thin band over it while the phone's model
/// works. The band stops when the OS asks to reduce motion.
class PhotoScanOverlay extends StatefulWidget {
  const PhotoScanOverlay({super.key, required this.label});

  final String label;

  @override
  State<PhotoScanOverlay> createState() => _PhotoScanOverlayState();
}

class _PhotoScanOverlayState extends State<PhotoScanOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _scan.stop();
    } else if (!_scan.isAnimating) {
      _scan.repeat();
    }
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black.withValues(alpha: 0.38)),
        AnimatedBuilder(
          animation: _scan,
          builder: (context, _) {
            if (!_scan.isAnimating) return const SizedBox.shrink();
            return Align(
              alignment: Alignment(0, -1.3 + 2.6 * _scan.value),
              child: Container(
                height: 72,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accent.withValues(alpha: 0),
                      accent.withValues(alpha: 0.28),
                      accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One button under the photo.
class PhotoAction {
  const PhotoAction({required this.icon, required this.label, this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
}

/// Compact tonal buttons in one line, spread evenly. On narrow screens the
/// row scrolls sideways instead of wrapping.
class PhotoActionRow extends StatelessWidget {
  const PhotoActionRow({super.key, required this.actions});

  final List<PhotoAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: box.maxWidth),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final action in actions)
                FilledButton.tonalIcon(
                  onPressed: action.onPressed,
                  icon: Icon(action.icon, size: 18),
                  label: Text(action.label),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
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

/// Small status label ("parcial", "a confirmar").
class ReviewPill extends StatelessWidget {
  const ReviewPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: 0.6)),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Meal kcal and macros for the lines that are in the review. Says "parcial"
/// while some lines have no database values.
class ReviewSummary extends StatelessWidget {
  const ReviewSummary({super.key, required this.items});

  final List<ReviewItem> items;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final live = items.where((i) => !i.removing);
    double sum(double Function(FoodRef) pick) => live.fold(
      0,
      (total, i) =>
          total + (i.food == null ? 0 : pick(i.food!) * i.grams / 100),
    );
    final kcal = sum((f) => f.kcal);
    final grams = live.fold<double>(0, (total, i) => total + i.grams);
    final counts = countReview(items);
    final macros = [
      (t.get('protein'), sum((f) => f.protein), scheme.primary),
      (t.get('carbs'), sum((f) => f.carbs), scheme.tertiary),
      (t.get('fat'), sum((f) => f.fat), scheme.secondary),
    ];
    return VyroCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              VyroAnimatedNumber(
                value: kcal,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('kcal', style: theme.textTheme.titleMedium),
              ),
              const Spacer(),
              if (counts.hasUnresolved || counts.pending > 0)
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: counts.hasUnresolved
                        ? ReviewPill(
                            label: t.get('photoPartial'),
                            color: scheme.tertiary,
                          )
                        : ReviewPill(
                            label: t.get('photoPillConfirm'),
                            color: scheme.onSurfaceVariant,
                          ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            counts.hasUnresolved
                ? t
                      .get('photoPartialHint')
                      .replaceAll('{n}', '${counts.unresolved}')
                : '≈ ${grams.round()} g',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (label, value, color) in macros)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${value.round()} g',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Name of the question asked for a generic item ("Que bebida?").
String askKeyFor(GenericKind? kind) => switch (kind) {
  GenericKind.drink => 'photoAskDrink',
  GenericKind.sandwich => 'photoAskSandwich',
  GenericKind.sauce => 'photoAskSauce',
  GenericKind.meat => 'photoAskMeat',
  GenericKind.fish => 'photoAskFish',
  GenericKind.fruit => 'photoAskFruit',
  GenericKind.dessert => 'photoAskDessert',
  GenericKind.food || null => 'photoAskFood',
};

/// One food line: name, one subtitle line, grams stepper. Details (source,
/// per-100 g values, position in the photo, clarify) are collapsed.
class FoodReviewCard extends StatefulWidget {
  const FoodReviewCard({
    super.key,
    required this.item,
    required this.onChange,
    required this.onGrams,
    required this.onRemove,
    required this.onClarify,
  });

  final ReviewItem item;

  /// Opens the food picker. Null while the line is still pending.
  final VoidCallback? onChange;
  final ValueChanged<double> onGrams;

  /// Null while the line is still pending.
  final VoidCallback? onRemove;
  final VoidCallback onClarify;

  @override
  State<FoodReviewCard> createState() => _FoodReviewCardState();
}

class _FoodReviewCardState extends State<FoodReviewCard> {
  late final _grams = TextEditingController(text: _format(widget.item.grams));
  final _focus = FocusNode();
  bool _open = false;

  static String _format(double g) => g.round().toString();

  @override
  void didUpdateWidget(FoodReviewCard old) {
    super.didUpdateWidget(old);
    final text = _format(widget.item.grams);
    if (!_focus.hasFocus && _grams.text != text) _grams.text = text;
  }

  @override
  void dispose() {
    _grams.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _step(int direction) {
    final step = widget.item.grams >= 200 ? 25.0 : 10.0;
    final next = (widget.item.grams + direction * step).clamp(0.0, 2000.0);
    _grams.text = _format(next);
    widget.onGrams(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = widget.item;
    final food = item.food;
    final detected = item.detected;
    final unresolved = item.unresolved;
    final accent = unresolved ? scheme.tertiary : scheme.primary;
    // A model name without a database match is never the card title (it is
    // English): the question asks for the food; the raw name stays in the
    // technical details. A generic name asks for its kind ("Que bebida?").
    final title =
        food?.name(t.isEnglish) ??
        (detected.needsChoice
            ? t.get(askKeyFor(genericKindOf(detected.label)))
            : t.get('photoAskFood'));
    final pill =
        !item.pending &&
            food != null &&
            detected.source != VisionSource.user &&
            !detected.corroborated
        ? t.get('photoPillConfirm')
        : null;

    final Widget subtitle;
    if (item.pending) {
      subtitle = Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            t.get('photoPendingFull'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    } else if (food == null) {
      subtitle = Text(
        t.get('photoChooseFood'),
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.tertiary,
          fontWeight: FontWeight.w700,
        ),
      );
    } else {
      subtitle = Text(
        '${item.grams.round()} g · ${(item.kcal ?? 0).round()} kcal',
        style: theme.textTheme.bodySmall,
      );
    }

    return Container(
      foregroundDecoration: unresolved
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.tertiary, width: 1.5),
            )
          : null,
      child: VyroCard(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
        tint: unresolved ? scheme.tertiary.withValues(alpha: 0.08) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: item.pending ? null : widget.onChange,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: accent.withValues(alpha: 0.13),
                    child: Icon(
                      food == null
                          ? Icons.help_outline_rounded
                          : foodCategoryIcon(food.category),
                      size: 20,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (pill != null) ...[
                              const SizedBox(width: 8),
                              ReviewPill(
                                label: pill,
                                color: scheme.onSurfaceVariant,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        subtitle,
                      ],
                    ),
                  ),
                  if (unresolved)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: FilledButton.tonal(
                        onPressed: widget.onChange,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: Text(t.get('photoChoose')),
                      ),
                    ),
                  if (!item.pending)
                    IconButton(
                      tooltip: t.get('delete'),
                      onPressed: widget.onRemove,
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                if (food != null && !item.pending) ...[
                  _StepButton(
                    icon: Icons.remove_rounded,
                    onTap: () => _step(-1),
                  ),
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: _grams,
                      focusNode: _focus,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      onChanged: (text) => widget.onGrams(
                        double.tryParse(text.replaceAll(',', '.')) ?? 0,
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        suffixText: 'g',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  _StepButton(icon: Icons.add_rounded, onTap: () => _step(1)),
                ],
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _open = !_open),
                  icon: AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.expand_more_rounded, size: 18),
                  ),
                  label: Text(t.get('photoDetailsToggle')),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: _open
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                      child: _FoodDetails(
                        item: item,
                        onClarify: widget.onClarify,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodDetails extends StatelessWidget {
  const _FoodDetails({required this.item, required this.onClarify});

  final ReviewItem item;
  final VoidCallback onClarify;

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final food = item.food;
    final detected = item.detected;
    final lines = [
      if (food != null)
        '${foodSourceTag(food)} · ${food.kcal.round()} kcal/100 g',
      if (food == null)
        t.get(detected.needsChoice ? 'photoGenericHint' : 'photoNoMatchRow'),
      if (detected.count != null && detected.count! > 1)
        '${detected.count} ${t.get('pieces')}',
      // The model's location is English: shown in English only. In other
      // languages it stays in the technical details ("Detalhes da análise").
      if (detected.where != null && t.isEnglish)
        '${t.get('photoWhere')}: ${detected.where}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(line, style: theme.textTheme.bodySmall),
          ),
        if (!item.pending)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onClarify,
              icon: const Icon(Icons.help_outline, size: 18),
              label: Text(t.get('photoClarify')),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            ),
          ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    icon: Icon(icon, size: 20),
    style: IconButton.styleFrom(
      side: BorderSide(color: Theme.of(context).colorScheme.outline),
    ),
  );
}

/// Horizontal row of chips under a small heading (suggestions, quick adds).
class ReviewChipRow extends StatelessWidget {
  const ReviewChipRow({super.key, required this.title, required this.chips});

  final String title;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final chip in chips)
              Padding(padding: const EdgeInsets.only(right: 8), child: chip),
          ],
        ),
      ),
    ],
  );
}

/// Collapses its child (fade and height) when [collapsing] turns true, then
/// calls [onGone] once. Used when a review line is removed, so the list does
/// not jump. The element stays in place, so the card keeps its state.
class ReviewCollapse extends StatefulWidget {
  const ReviewCollapse({
    super.key,
    required this.collapsing,
    required this.onGone,
    required this.child,
  });

  final bool collapsing;
  final VoidCallback onGone;
  final Widget child;

  @override
  State<ReviewCollapse> createState() => _ReviewCollapseState();
}

class _ReviewCollapseState extends State<ReviewCollapse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onGone();
    });
    if (widget.collapsing) _controller.forward();
  }

  @override
  void didUpdateWidget(ReviewCollapse old) {
    super.didUpdateWidget(old);
    if (widget.collapsing && !old.collapsing) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shrink = ReverseAnimation(_controller);
    return SizeTransition(
      sizeFactor: shrink,
      alignment: Alignment.topCenter,
      child: FadeTransition(opacity: shrink, child: widget.child),
    );
  }
}
