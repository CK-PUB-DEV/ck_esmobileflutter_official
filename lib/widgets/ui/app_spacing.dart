import 'package:flutter/widgets.dart';

/// 4-point spacing scale. Use these instead of literal numbers.
///
/// - page side padding: [lg] (16)
/// - gap between cards: [md] (12)
/// - padding inside a card: [lg] (16)
/// - gap between sections: [xl] (24)
abstract final class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets pageAll = EdgeInsets.all(lg);
  static const EdgeInsets card = EdgeInsets.all(lg);

  static const SizedBox hXs = SizedBox(height: xs);
  static const SizedBox hSm = SizedBox(height: sm);
  static const SizedBox hMd = SizedBox(height: md);
  static const SizedBox hLg = SizedBox(height: lg);
  static const SizedBox hXl = SizedBox(height: xl);
  static const SizedBox hXxl = SizedBox(height: xxl);

  static const SizedBox wXs = SizedBox(width: xs);
  static const SizedBox wSm = SizedBox(width: sm);
  static const SizedBox wMd = SizedBox(width: md);
  static const SizedBox wLg = SizedBox(width: lg);
}

/// Icon sizes: 16 inline with text, 20 in buttons and rows, 24 in navigation.
abstract final class IconSize {
  static const double inline = 16;
  static const double row = 20;
  static const double nav = 24;
}

/// Minimum touch target.
const double kMinTap = 44;
