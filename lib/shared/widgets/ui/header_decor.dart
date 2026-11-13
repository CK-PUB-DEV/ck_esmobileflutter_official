import 'package:flutter/material.dart';

/// Soft translucent circles painted behind a coloured header. Each circle is
/// (x fraction, y fraction, radius); pick a preset or pass your own [circles].
class HeaderDecorPainter extends CustomPainter {
  const HeaderDecorPainter(this.color, {this.circles = login});

  final Color color;
  final List<(double, double, double)> circles;

  static const login = [
    (0.92, 0.10, 90.0),
    (0.02, 0.38, 60.0),
    (0.80, 0.88, 46.0),
  ];
  static const school = [
    (0.94, 0.12, 80.0),
    (0.04, 0.46, 54.0),
    (0.76, 0.34, 34.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final (x, y, r) in circles) {
      canvas.drawCircle(Offset(size.width * x, size.height * y), r, paint);
    }
  }

  @override
  bool shouldRepaint(HeaderDecorPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.circles != circles;
}
