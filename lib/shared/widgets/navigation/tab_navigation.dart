import 'package:flutter/material.dart';
import 'package:pushtrial/shared/widgets/ui/ui.dart';

/// One destination in a [TabNavigation].
class TabNavItem {
  const TabNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// The bottom navigation bar. A screen passes its tabs, the selected index and a callback;
/// the selected tab shows its icon in a pill tinted with [accent] (the school colour).
class TabNavigation extends StatelessWidget {
  const TabNavigation({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    this.accent,
  });

  final List<TabNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
        decoration: BoxDecoration(
          color: shad.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _TabButton(
                  item: items[i],
                  selected: i == currentIndex,
                  accent: accent ?? shad.primary,
                  onTap: () => onChanged(i),
                ),
              ),
          ],
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
    required this.onTap,
  });

  final TabNavItem item;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final shad = theme.colorScheme;
    final foreground = selected ? shad.foreground : shad.mutedForeground;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkResponse(
        onTap: onTap,
        radius: 40,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTap + 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: selected ? 56 : 40,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(item.icon, size: IconSize.nav, color: foreground),
              ),
              Gap.hXs,
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.small.copyWith(
                  color: foreground,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
