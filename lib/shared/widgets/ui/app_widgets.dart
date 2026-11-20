import 'package:pushtrial/core/config/app_transitions.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:pushtrial/shared/widgets/ui/app_spacing.dart';
import 'package:pushtrial/shared/widgets/ui/app_tokens.dart';
import 'package:pushtrial/shared/widgets/ui/school_surface.dart';

/// Section title with an optional trailing action, 24px above and 12px below.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.topGap = true});

  final String title;
  final Widget? trailing;
  final bool topGap;

  @override
  Widget build(BuildContext context) {
    final text = ShadTheme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(top: topGap ? Gap.xl : 0, bottom: Gap.md),
      child: Row(
        children: [
          AccentBar(SchoolTone.current(context)),
          Gap.wSm,
          Expanded(
            child: Text(title, style: text.large, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Rounded card with the standard 16px padding (the shared [RoundedCard] look). Use instead of
/// `Card`/shadowed containers.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.title,
    this.description,
    this.padding = Gap.card,
    this.onTap,
    this.margin = const EdgeInsets.only(bottom: Gap.md),
  });

  final Widget child;
  final String? title;
  final String? description;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = ShadTheme.of(context).textTheme;
    return RoundedCard(
      radius: AppRadius.row,
      padding: padding,
      margin: margin,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) Text(title!, style: text.large),
          if (description != null) ...[
            Gap.hXs,
            Text(description!, style: text.muted),
          ],
          if (title != null || description != null) Gap.hMd,
          child,
        ],
      ),
    );
  }
}

/// `Label ........ value` row. The label is muted, the value wraps instead of clipping.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.icon, this.emphasis = false});

  final String label;
  final String value;
  final IconData? icon;

  /// Bold value, for totals.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final text = theme.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: IconSize.inline, color: theme.colorScheme.mutedForeground),
            Gap.wSm,
          ],
          Expanded(flex: 4, child: Text(label, style: text.muted)),
          Gap.wMd,
          Expanded(
            flex: 5,
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.end,
              style: emphasis ? text.strong : text.p,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small stat: muted label over a large value (balance, total, count).
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.icon, this.tone});

  final String label;
  final String value;
  final IconData? icon;

  /// Value colour; defaults to the foreground colour.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final text = theme.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: IconSize.inline, color: theme.colorScheme.mutedForeground),
              Gap.wXs,
            ],
            Flexible(
              child: Text(label, style: text.muted, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        Gap.hXs,
        Text(
          value,
          style: text.h4.copyWith(color: tone ?? theme.colorScheme.foreground),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

enum AppStatus { success, warning, danger, info, neutral }

/// Status pill: paid, overdue, due soon, pending...
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.status = AppStatus.neutral});

  final String label;
  final AppStatus status;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final child = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    ShadBadge toned(StatusTone tone) => ShadBadge(
      backgroundColor: tone.background,
      hoverBackgroundColor: tone.background,
      foregroundColor: tone.foreground,
      child: child,
    );
    switch (status) {
      case AppStatus.danger:
        return ShadBadge.destructive(child: child);
      case AppStatus.neutral:
        return ShadBadge.secondary(child: child);
      case AppStatus.success:
        return toned(dark ? StatusTone.success.dark : StatusTone.success.light);
      case AppStatus.warning:
        return toned(dark ? StatusTone.warning.dark : StatusTone.warning.light);
      case AppStatus.info:
        return toned(dark ? StatusTone.info.dark : StatusTone.info.light);
    }
  }
}

/// Icon-only button with a 44px touch target and a tooltip/semantic label.
class AppIconButton extends StatelessWidget {
  const AppIconButton({super.key, required this.icon, required this.label, this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ShadIconButton.ghost(
        icon: Icon(icon, size: IconSize.row),
        onPressed: onPressed,
      ),
    );
  }
}

/// One row in a list: optional leading widget, title, optional subtitle, optional trailing widget.
/// The tap-history row, as a shared component. At least [kTapTarget] tall.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.margin = const EdgeInsets.only(bottom: Gap.sm),
    this.semanticLabel,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  /// Read by screen readers instead of the visible text, when that text alone is unclear.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final text = ShadTheme.of(context).textTheme;
    final row = RoundedCard(
      radius: AppRadius.row,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.md),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kTapTarget - Gap.md * 2),
        child: Row(
          children: [
            if (leading != null) ...[leading!, Gap.wMd],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: text.strong,
                  ),
                  if (subtitle != null) ...[
                    Gap.hXs,
                    Text(subtitle!, style: text.muted),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[Gap.wMd, trailing!],
          ],
        ),
      ),
    );
    if (semanticLabel == null) return row;
    return Semantics(label: semanticLabel, button: onTap != null, child: ExcludeSemantics(child: row));
  }
}

/// Fully rounded button shape for the primary action of a screen (submit, upload, log out).
ShadDecoration appPillDecoration() => ShadDecoration(
  border: ShadBorder.all(radius: BorderRadius.circular(AppRadius.pill)),
);

/// Solid school-colour summary card for a screen's one headline number (balance, total paid...).
///
/// [label] sits next to [icon], [pill] (e.g. the school year) at the top right, [value] is the big
/// number, [captions] are small lines under it and [stats] are secondary figures side by side.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.pill,
    this.captions = const [],
    this.stats = const [],
    this.progress,
    this.margin = const EdgeInsets.only(bottom: Gap.md),
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? pill;
  final List<String> captions;
  final List<({String label, String value})> stats;

  /// 0..1: a rounded progress bar under the figures (e.g. classes evaluated).
  final double? progress;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final text = ShadTheme.of(context).textTheme;
    final tone = SchoolTone.current(context);
    final on = tone.onSolid;
    return SolidCard(
      tone: tone,
      margin: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: on, size: IconSize.row),
                Gap.wSm,
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.small.copyWith(
                    color: on.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (pill != null) ...[
                Gap.wSm,
                Flexible(child: SchoolPill(pill!, tone, onCard: true)),
              ],
            ],
          ),
          Gap.hLg,
          // Scales down instead of overflowing when the amount is long or the text size is large.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: text.h1.copyWith(color: on)),
          ),
          for (final caption in captions) ...[
            Gap.hXs,
            Text(
              caption,
              style: text.small.copyWith(color: on.withValues(alpha: 0.85)),
            ),
          ],
          if (progress != null) ...[
            Gap.hMd,
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: on.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(on),
              ),
            ),
          ],
          if (stats.isNotEmpty) ...[
            Gap.hLg,
            Container(height: 1, color: on.withValues(alpha: 0.2)),
            Gap.hMd,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) Gap.wLg,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stats[i].label,
                          style: text.small.copyWith(
                            color: on.withValues(alpha: 0.75),
                          ),
                        ),
                        Gap.hXs,
                        Text(
                          stats[i].value,
                          style: text.p.copyWith(
                            color: on,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The app's toggle buttons (report card tabs, billing and payment tabs, semester filters): a
/// fully rounded gray track, the selected option a white pill. It draws
/// itself, so it does not depend on the shadcn tabs theme. Content below is switched by the
/// caller from [value].
class PillToggle<T> extends StatelessWidget {
  const PillToggle({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<({T value, String label})> options;
  final T value;
  final ValueChanged<T> onChanged;

  static const double _height = 44;
  static const double _inset = 4;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final duration = AppMotion.of(context, const Duration(milliseconds: 280));
    final selected = options.indexWhere((o) => o.value == value);

    // Gray track; a white pill slides under the selected option and the label colours fade.
    return Container(
      padding: const EdgeInsets.all(_inset),
      decoration: BoxDecoration(
        color: scheme.muted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segment = constraints.maxWidth / options.length;
          return SizedBox(
            height: _height,
            child: Stack(
              children: [
                if (selected >= 0)
                  AnimatedPositioned(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    left: segment * selected,
                    top: 0,
                    bottom: 0,
                    width: segment,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.card,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.10),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                Row(
                  children: [
                    for (final option in options)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: option.value == value,
                          label: option.label,
                          excludeSemantics: true,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            onTap: () => onChanged(option.value),
                            child: Container(
                              height: _height,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                              child: AnimatedDefaultTextStyle(
                                duration: duration,
                                curve: Curves.easeOut,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.small.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: option.value == value
                                      ? scheme.foreground
                                      : scheme.mutedForeground,
                                ),
                                child: Text(option.label),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Row of pill chips for filtering a list or picking a day. The selected chip is filled with the
/// school colour; the others are white pills. Scrolls sideways when the chips do not fit.
class FilterChips<T> extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<({T value, String label})> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final tone = SchoolTone.current(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final duration = AppMotion.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) Gap.wSm,
            Semantics(
              button: true,
              selected: options[i].value == value,
              label: options[i].label,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(options[i].value),
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOut,
                  constraints: const BoxConstraints(minHeight: kMinTap, minWidth: kMinTap),
                  padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: options[i].value == value ? tone.solid : scheme.card,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: dark && options[i].value != value
                        ? Border.all(color: scheme.border)
                        : null,
                    boxShadow: options[i].value == value
                        ? const []
                        : AppShadow.soft(dark),
                  ),
                  child: Text(
                    options[i].label,
                    maxLines: 1,
                    style: theme.textTheme.small.copyWith(
                      fontWeight: options[i].value == value
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: options[i].value == value
                          ? tone.onSolid
                          : scheme.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One pill that sums up the filters in force (e.g. "SY 2026-2027 · 1st Semester") and opens the
/// picker when tapped. Replaces a stack of full-width dropdowns above a screen's data.
class ContextPill extends StatelessWidget {
  const ContextPill({super.key, required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: 'Change: $label',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: kMinTap),
            padding: const EdgeInsets.only(left: Gap.lg, right: Gap.md),
            decoration: BoxDecoration(
              color: scheme.card,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: dark ? Border.all(color: scheme.border) : null,
              boxShadow: AppShadow.soft(dark),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: IconSize.inline, color: scheme.mutedForeground),
                  Gap.wSm,
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.smallStrong,
                  ),
                ),
                Gap.wSm,
                Icon(LucideIcons.chevronDown, size: IconSize.inline, color: scheme.mutedForeground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet that holds a screen's pickers (school year, semester...) behind a [ContextPill].
/// The sheet only hosts [child]; the screen keeps its own select widgets and state. Same look as
/// the app's other sheets: rounded top corners, drag handle, app background.
Future<void> showPickerSheet(
  BuildContext context, {
  required String title,
  required Widget child,
}) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: AppTransitions.sheet,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 480),
    backgroundColor: ShadTheme.of(context).colorScheme.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Gap.xl,
          Gap.xs,
          Gap.xl,
          Gap.lg + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetHeader(title: title),
              Gap.hLg,
              child,
              Gap.hLg,
              // Colours are set here, not read from the theme's primary, so Done is always the
              // neutral ink button. Red is reserved for destructive actions.
              ShadButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                height: kMinTap + 8,
                backgroundColor: ShadTheme.of(sheetContext).colorScheme.foreground,
                hoverBackgroundColor:
                    ShadTheme.of(sheetContext).colorScheme.foreground.withValues(alpha: 0.9),
                pressedBackgroundColor:
                    ShadTheme.of(sheetContext).colorScheme.foreground.withValues(alpha: 0.85),
                foregroundColor: ShadTheme.of(sheetContext).colorScheme.background,
                decoration: appPillDecoration(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Sheet title with a round close button on the right.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(title, style: theme.textTheme.h4)),
              if (subtitle != null) ...[
                Gap.hXs,
                Text(subtitle!, style: theme.textTheme.muted),
              ],
            ],
          ),
        ),
        Gap.wMd,
        Semantics(
          button: true,
          label: 'Close',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: kMinTap - 8,
              height: kMinTap - 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.muted),
              child: Icon(LucideIcons.x, size: IconSize.inline + 2, color: theme.colorScheme.foreground),
            ),
          ),
        ),
      ],
    );
  }
}

/// One choice in a [showOptionSheet].
typedef SheetOption<T> = ({T value, String label, String? hint});

/// Bottom sheet for choosing one value from a list (month, school year, term...). Each option is
/// a rounded row; the chosen one is highlighted and carries a check in a school-colour circle.
/// Tapping an option calls [onSelected] and closes the sheet, so there is no Done button.
Future<void> showOptionSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<SheetOption<T>> options,
  required T value,
  required ValueChanged<T> onSelected,
}) {
  HapticFeedback.selectionClick();
  final screenHeight = MediaQuery.sizeOf(context).height;
  return showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: AppTransitions.sheet,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 480),
    backgroundColor: ShadTheme.of(context).colorScheme.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (sheetContext) {
      final theme = ShadTheme.of(sheetContext);
      final scheme = theme.colorScheme;
      final tone = SchoolTone.current(sheetContext);
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xs, Gap.xl, Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetHeader(title: title, subtitle: subtitle),
              Gap.hLg,
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: screenHeight * 0.55),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, _) => Gap.hSm,
                  itemBuilder: (context, i) {
                    final o = options[i];
                    final selected = o.value == value;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: o.label,
                      excludeSemantics: true,
                      child: Material(
                        color: selected ? scheme.muted : scheme.card,
                        borderRadius: BorderRadius.circular(AppRadius.row),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            onSelected(o.value);
                          },
                          child: Container(
                            constraints: const BoxConstraints(minHeight: kTapTarget + 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: Gap.lg,
                              vertical: Gap.md,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.row),
                              border: Border.all(color: scheme.border.withValues(alpha: 0.7)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        o.label,
                                        style: selected ? theme.textTheme.strong : theme.textTheme.p,
                                      ),
                                      if (o.hint != null) ...[
                                        Gap.hXs,
                                        Text(o.hint!, style: theme.textTheme.muted),
                                      ],
                                    ],
                                  ),
                                ),
                                if (selected) ...[
                                  Gap.wMd,
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: tone.solid,
                                    ),
                                    child: Icon(LucideIcons.check, size: IconSize.inline, color: tone.onSolid),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
