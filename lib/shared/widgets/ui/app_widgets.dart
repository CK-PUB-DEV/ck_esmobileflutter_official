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
