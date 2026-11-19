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

/// The floating bottom navigation: a white, fully rounded pill that sits clear of the screen edges
/// (a dark surface in dark mode).
///
/// Inactive tabs are icon-only in a muted tone. The selected tab becomes a school-colour capsule that grows
/// to carry its label, so the bar names where you are without printing four labels. A screen
/// passes its tabs, the selected index and a callback. Use it as a Scaffold's `bottomNavigationBar`
/// together with `extendBody: true`, so the page shows around and behind the pill.
///
/// While [collapsed] is true the pill morphs to a small icons-only capsule (the selected label folds
/// away and the width shrinks); flipping it back restores the full bar. One controller drives the
/// morph, so the motion stays in sync and can be reversed mid-way without a jump.
///
/// The selected capsule takes [accent] (the school colour); its icon and label flip to ink when
/// that colour is light, so the label stays readable on any school.
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
  static const double _compactItemWidth = 44;
  static const double _padding = Gap.sm;

  // Heights of the pill (item + padding on each side). The slot the Scaffold reserves is always as
  // tall as the full bar, so the morph never changes the page's layout.
  static const double _fullHeight = 52 + _padding * 2;
  static const double _compactHeight = 44 + _padding * 2;
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
          : Duration(milliseconds: widget.collapsed ? 420 : 460),
      curve: Curves.easeOutQuart,
    );
  }

  @override
  void dispose() {
    _morph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accent ?? ShadTheme.of(context).colorScheme.primary;
    final palette = _NavPalette.of(isDark, accent);

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
                    final pillWidth = _mix(fullWidth, compactWidth, t);
                    // Room left for the selected label once every tab has its icon slot. Passed
                    // down so the label gets all of it (a Flexible would split it four ways).
                    final labelRoom = (pillWidth -
                            _padding * 2 -
                            widget.items.length * _compactItemWidth -
                            Gap.md)
                        .clamp(0.0, double.infinity);
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        key: const ValueKey('tab_navigation_pill'),
                        width: pillWidth,
                        height: _mix(_fullHeight, _compactHeight, t),
                        padding: const EdgeInsets.all(_padding),
                        decoration: BoxDecoration(
                          color: palette.pill,
                          borderRadius: BorderRadius.circular(999),
                          // One offset, soft shadow: cheap to repaint while the pill resizes.
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.14),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (var i = 0; i < widget.items.length; i++)
                              _TabButton(
                                item: widget.items[i],
                                selected: i == widget.currentIndex,
                                palette: palette,
                                collapse: t,
                                labelRoom: labelRoom,
                                onTap: () {
                                  if (i != widget.currentIndex) {
                                    HapticFeedback.selectionClick();
                                  }
                                  widget.onChanged(i);
                                },
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

/// Colours of the bar: a neutral pill, with the selected capsule in the school colour.
class _NavPalette {
  const _NavPalette({
    required this.pill,
    required this.idle,
    required this.capsule,
    required this.onCapsule,
  });

  final Color pill;
  final Color idle;
  final Color capsule;
  final Color onCapsule;

  static _NavPalette of(bool isDark, Color accent) {
    // Same rule as the school-colour cards: a little darker at night, and the text flips to ink
    // when the school colour is light (yellow) so the label always stays readable.
    final capsule = isDark ? Color.lerp(accent, Colors.black, 0.28)! : accent;
    final onCapsule = capsule.computeLuminance() > 0.55
        ? const Color(0xFF111111)
        : Colors.white;
    return _NavPalette(
      pill: isDark ? const Color(0xFF1F2123) : Colors.white,
      idle: isDark ? const Color(0xFF9EA5AB) : const Color(0xFF6A7076),
      capsule: capsule,
      onCapsule: onCapsule,
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.item,
    required this.selected,
    required this.palette,
    required this.collapse,
    required this.labelRoom,
    required this.onTap,
  });

  final TabNavItem item;
  final bool selected;
  final _NavPalette palette;

  /// Widest the label may be before it ends in an ellipsis.
  final double labelRoom;

  /// 0 = full bar (selected tab shows its label), 1 = collapsed (icon only).
  final double collapse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);

    // The selected/unselected change runs on its own 0..1 value; every size below is then a plain
    // function of (selected, collapse), so nothing animates toward a moving target.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: selected ? 1 : 0),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 340),
      curve: Curves.easeOutQuart,
      builder: (context, s, _) {
        final foreground = Color.lerp(palette.idle, palette.onCapsule, s)!;
        final height = _mix(52, 44, collapse);
        // How much of the label is revealed: only the selected tab, and not while collapsed.
        final reveal = s * (1 - collapse);

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
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: palette.capsule.withValues(alpha: s),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: _TabNavigationState._compactItemWidth,
                    child: Icon(item.icon, size: IconSize.nav - 2, color: foreground),
                  ),
                  if (reveal > 0)
                    ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: reveal,
                        child: Padding(
                          padding: const EdgeInsets.only(right: Gap.md),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: labelRoom),
                            child: Text(
                              item.label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.smallStrong.copyWith(
                                color: foreground.withValues(alpha: Curves.easeIn.transform(reveal)),
                                height: 1.1,
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
