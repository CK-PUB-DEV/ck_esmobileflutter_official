import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pushtrial/shared/widgets/ui/ui.dart';

/// One destination in a [TabNavigation].
class TabNavItem {
  const TabNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Linear blend of [a] and [b]; 0 gives [a], 1 gives [b].
double _mix(double a, double b, double t) => a + (b - a) * t;

/// The floating bottom navigation: a fully rounded pill that sits clear of the screen edges.
///
/// A screen passes its tabs, the selected index and a callback. The selected tab keeps full-ink
/// text with a bold label and a soft bubble in [accent] (the school colour) behind its icon;
/// the others recede to the muted tone. Use it as a Scaffold's `bottomNavigationBar` together
/// with `extendBody: true`, so the page shows around and behind the pill.
///
/// While [collapsed] is true the pill morphs to a small icons-only capsule (labels fold away and
/// the width shrinks); flipping it back restores the full bar. One controller drives every part
/// of the morph, so the motion stays in sync and can be reversed mid-way without a jump.
class TabNavigation extends StatefulWidget {
  const TabNavigation({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    this.accent,
    this.collapsed = false,
  });

  final List<TabNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final Color? accent;
  final bool collapsed;

  @override
  State<TabNavigation> createState() => _TabNavigationState();
}

class _TabNavigationState extends State<TabNavigation>
    with SingleTickerProviderStateMixin {
  static const double _maxWidth = 440;
  static const double _compactItemWidth = 52;
  static const double _padding = Gap.sm;

  // Heights of the pill (item + padding + 1px border on each side). The slot the Scaffold
  // reserves is always as tall as the full bar, so the morph never changes the page's layout.
  static const double _fullHeight = 52 + _padding * 2 + 2;
  static const double _compactHeight = 44 + _padding * 2 + 2;
  static const double _slotHeight = _fullHeight + Gap.sm;

  late final AnimationController _morph = AnimationController(
    vsync: this,
    value: widget.collapsed ? 1 : 0,
  );

  @override
  void didUpdateWidget(TabNavigation old) {
    super.didUpdateWidget(old);
    if (old.collapsed == widget.collapsed) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    _morph.animateTo(
      widget.collapsed ? 1 : 0,
      duration: reduce
          ? Duration.zero
          : Duration(milliseconds: widget.collapsed ? 340 : 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _morph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accent ?? shad.primary;

    // The Scaffold sees a fixed-size box, so the morph below only repaints this subtree; the pages
    // behind (extendBody) are neither re-laid out nor rebuilt while it runs.
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: Gap.md),
      child: SizedBox(
        height: _slotHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fullWidth = constraints.maxWidth.clamp(0.0, _maxWidth);
              final compactWidth =
                  widget.items.length * _compactItemWidth + _padding * 2;

              return RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _morph,
                  builder: (context, _) {
                    final t = _morph.value;
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        key: const ValueKey('tab_navigation_pill'),
                        width: _mix(fullWidth, compactWidth, t),
                        height: _mix(_fullHeight, _compactHeight, t),
                        padding: const EdgeInsets.all(_padding),
                        decoration: BoxDecoration(
                          color: shad.card,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: shad.border.withValues(alpha: isDark ? 0.9 : 0.6),
                          ),
                          // One offset, soft shadow: cheap to repaint while the pill resizes.
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            for (var i = 0; i < widget.items.length; i++)
                              Expanded(
                                child: _TabButton(
                                  item: widget.items[i],
                                  selected: i == widget.currentIndex,
                                  accent: accent,
                                  collapse: t,
                                  onTap: () {
                                    if (i != widget.currentIndex) {
                                      HapticFeedback.selectionClick();
                                    }
                                    widget.onChanged(i);
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.item,
    required this.selected,
    required this.accent,
    required this.collapse,
    required this.onTap,
  });

  final TabNavItem item;
  final bool selected;
  final Color accent;

  /// 0 = full bar (icon + label), 1 = collapsed (icon only).
  final double collapse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final shad = theme.colorScheme;
    final reduce = MediaQuery.disableAnimationsOf(context);

    // The selected/unselected change runs on its own 0..1 value; every size below is then a plain
    // function of (selected, collapse), so nothing animates toward a moving target.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: selected ? 1 : 0),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, s, _) {
        final foreground = Color.lerp(shad.mutedForeground, shad.foreground, s)!;
        final bubbleWidth = _mix(
          _mix(36, 40, collapse),
          _mix(52, 46, collapse),
          s,
        );
        final bubbleHeight = _mix(30, 40, collapse);
        final labelStyle = TextStyle.lerp(
          theme.textTheme.small.copyWith(fontWeight: FontWeight.w500),
          theme.textTheme.small.copyWith(fontWeight: FontWeight.w700),
          s,
        )!.copyWith(color: foreground, fontSize: 11, height: 1.1);
        final labelOpacity = (1 - collapse * 1.6).clamp(0.0, 1.0);

        return Semantics(
          button: true,
          selected: selected,
          label: item.label,
          excludeSemantics: true,
          child: InkResponse(
            onTap: onTap,
            radius: 44,
            highlightShape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(999),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: _mix(kMinTap + 8, kMinTap, collapse),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: bubbleWidth,
                    height: bubbleHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16 * s),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Transform.scale(
                      scale: 1 + 0.08 * s,
                      child: Icon(item.icon, size: IconSize.nav - 2, color: foreground),
                    ),
                  ),
                  // The label folds away: its height and opacity follow the morph, so the bar
                  // shrinks smoothly instead of the text popping out.
                  if (collapse < 1)
                    ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: 1 - collapse,
                        child: Padding(
                          padding: const EdgeInsets.only(top: Gap.xs),
                          child: Text(
                            item.label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                            style: labelStyle.copyWith(
                              color: foreground.withValues(
                                alpha: foreground.a * labelOpacity,
                              ),
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
      },
    );
  }
}
