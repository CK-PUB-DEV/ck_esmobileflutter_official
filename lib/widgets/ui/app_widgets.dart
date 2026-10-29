import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'app_spacing.dart';

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
          Expanded(
            child: Text(title, style: text.large, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Bordered card with the standard 16px padding. Use instead of `Card`/shadowed containers.
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
    final card = ShadCard(
      width: double.infinity,
      padding: padding,
      title: title == null ? null : Text(title!, style: text.large),
      description: description == null ? null : Text(description!, style: text.muted),
      child: title == null && description == null
          ? child
          : Padding(padding: const EdgeInsets.only(top: Gap.md), child: child),
    );
    return Padding(
      padding: margin,
      child: onTap == null
          ? card
          : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: card),
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
              style: emphasis ? text.p.copyWith(fontWeight: FontWeight.w600) : text.p,
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
    switch (status) {
      case AppStatus.danger:
        return ShadBadge.destructive(child: child);
      case AppStatus.neutral:
        return ShadBadge.secondary(child: child);
      case AppStatus.success:
        return ShadBadge(
          backgroundColor: dark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7),
          hoverBackgroundColor: dark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7),
          foregroundColor: dark ? const Color(0xFFBBF7D0) : const Color(0xFF166534),
          child: child,
        );
      case AppStatus.warning:
        return ShadBadge(
          backgroundColor: dark ? const Color(0xFF713F12) : const Color(0xFFFEF3C7),
          hoverBackgroundColor: dark ? const Color(0xFF713F12) : const Color(0xFFFEF3C7),
          foregroundColor: dark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
          child: child,
        );
      case AppStatus.info:
        return ShadBadge(
          backgroundColor: dark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
          hoverBackgroundColor: dark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
          foregroundColor: dark ? const Color(0xFFBFDBFE) : const Color(0xFF1E40AF),
          child: child,
        );
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
