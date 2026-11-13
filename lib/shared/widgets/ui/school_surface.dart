import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:pushtrial/shared/widgets/ui/app_spacing.dart';

/// Derives the soft school-colour tones used by the rounded surfaces from one [color].
///
/// A screen builds one of these from the logged-in school's colour and passes it to
/// [RoundedCard] and [SchoolIcon], so every tint on the screen comes from the same place.
class SchoolTone {
  const SchoolTone(this.context, this.color);

  final BuildContext context;
  final Color color;

  ShadColorScheme get _scheme => ShadTheme.of(context).colorScheme;
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  /// The school colour at [alpha] over the card surface.
  Color wash(double alpha) => Color.alphaBlend(
    color.withValues(alpha: _isDark ? alpha * 2 : alpha),
    _scheme.card,
  );

  /// Page background: the surface with a faint school tint, so white cards float on it.
  Color get background =>
      Color.alphaBlend(color.withValues(alpha: 0.05), _scheme.background);

  /// The school colour as a full fill (hero cards, pills, tiles). Colour is used as a background
  /// only: icons and text on neutral surfaces stay neutral.
  Color get solid => color;

  /// Text and icon colour on [solid]: white, or near-black when the school colour is so light that
  /// white would not be readable (e.g. yellow).
  Color get onSolid =>
      color.computeLuminance() > 0.55 ? const Color(0xFF111111) : Colors.white;
}

/// Fully rounded, borderless surface lifted by a soft shadow (a border in dark mode).
class RoundedCard extends StatelessWidget {
  const RoundedCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(Gap.xl),
    this.margin = const EdgeInsets.only(bottom: Gap.md),
    this.radius = 28,
    this.onTap,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shape = BorderRadius.circular(radius);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? scheme.card,
          borderRadius: shape,
          border: isDark ? Border.all(color: scheme.border) : null,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: shape,
          child: InkWell(
            onTap: onTap,
            borderRadius: shape,
            child: SizedBox(
              width: double.infinity,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bare neutral icon in a fixed box so titles and rows stay aligned. Colour is reserved for
/// backgrounds, so the icon takes the foreground colour unless [color] says otherwise.
class SchoolIcon extends StatelessWidget {
  const SchoolIcon(this.icon, {super.key, this.size = 32, this.color});

  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Icon(
        icon,
        size: IconSize.row + 2,
        color: color ?? ShadTheme.of(context).colorScheme.foreground,
      ),
    );
  }
}

/// Hero card filled with the school colour, white (or dark, see [SchoolTone.onSolid]) text, a
/// colour-matched shadow and soft round shapes in the corner so it is not a flat slab.
class SolidCard extends StatelessWidget {
  const SolidCard({
    super.key,
    required this.tone,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.xl),
    this.margin = const EdgeInsets.only(bottom: Gap.md),
    this.radius = 28,
    this.onTap,
  });

  final SchoolTone tone;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    Widget circle(double size, double alpha) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tone.onSolid.withValues(alpha: alpha),
      ),
    );
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.solid,
          borderRadius: shape,
          boxShadow: [
            BoxShadow(
              color: tone.solid.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: shape,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned(right: -36, top: -44, child: circle(150, 0.10)),
                    Positioned(right: 54, bottom: -52, child: circle(104, 0.07)),
                    Padding(padding: padding, child: child),
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

/// Fully filled pill in the school colour with [SchoolTone.onSolid] text. Set [onCard] when it
/// sits on a [SolidCard]: it then becomes a translucent pill so it stays visible.
class SchoolPill extends StatelessWidget {
  const SchoolPill(this.label, this.tone, {super.key, this.onCard = false});

  final String label;
  final SchoolTone tone;
  final bool onCard;

  @override
  Widget build(BuildContext context) {
    final text = ShadTheme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xs + 2),
      decoration: BoxDecoration(
        color: onCard ? tone.onSolid.withValues(alpha: 0.20) : tone.solid,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: text.small.copyWith(
          fontWeight: FontWeight.w700,
          color: tone.onSolid,
        ),
      ),
    );
  }
}

/// Small school-colour bar that sits before a section title.
class AccentBar extends StatelessWidget {
  const AccentBar(this.tone, {super.key});

  final SchoolTone tone;

  @override
  Widget build(BuildContext context) => Container(
    width: 5,
    height: 20,
    decoration: BoxDecoration(
      color: tone.solid,
      borderRadius: BorderRadius.circular(999),
    ),
  );
}
