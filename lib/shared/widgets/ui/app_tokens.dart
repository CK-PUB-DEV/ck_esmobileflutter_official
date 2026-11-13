import 'package:flutter/material.dart';

/// Design tokens shared by every screen. Surfaces, headers and states read these instead of
/// hard-coding numbers, so a change here changes the whole app consistently.

/// Corner radii.
abstract final class AppRadius {
  /// Hero and section cards.
  static const double card = 28;

  /// List rows and compact cards.
  static const double row = 24;

  /// Bottom corners of the lifted page header.
  static const double header = 22;

  /// Pills, inputs, dropdowns, round buttons.
  static const double pill = 999;
}

/// Durations. Use [of] so animations switch off when the phone asks for reduced motion.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration pulse = Duration(milliseconds: 1100);

  static Duration of(BuildContext context, [Duration duration = fast]) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

/// Shadows for raised surfaces. Light mode uses a soft two-layer shadow; dark mode uses a border
/// instead (see `RoundedCard`), so [soft] is empty there.
abstract final class AppShadow {
  static List<BoxShadow> soft(bool dark) => dark
      ? const []
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
        ];

  /// Shadow under a solid school-colour card, tinted with that colour.
  static List<BoxShadow> solid(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.35),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  /// Header lifted over scrolling content.
  static List<BoxShadow> lifted(bool dark) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: dark ? 0.40 : 0.07),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];
}

/// Status tones (paid, pending, overdue...). One place for the green, amber and blue pairs.
class StatusTone {
  const StatusTone(this.background, this.foreground);

  final Color background;
  final Color foreground;

  static const success = (
    light: StatusTone(Color(0xFFDCFCE7), Color(0xFF166534)),
    dark: StatusTone(Color(0xFF14532D), Color(0xFFBBF7D0)),
  );
  static const warning = (
    light: StatusTone(Color(0xFFFEF3C7), Color(0xFF92400E)),
    dark: StatusTone(Color(0xFF713F12), Color(0xFFFDE68A)),
  );
  static const info = (
    light: StatusTone(Color(0xFFDBEAFE), Color(0xFF1E40AF)),
    dark: StatusTone(Color(0xFF1E3A8A), Color(0xFFBFDBFE)),
  );
}

/// Touch target for new controls. [kMinTap] (44) stays for the existing layouts.
const double kTapTarget = 48;
