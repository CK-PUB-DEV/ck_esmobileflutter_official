import 'package:flutter/material.dart';

/// The Essentiel block emblem, cropped to the blocks themselves. The source image is a 1080px
/// square with wide margins and a wordmark that is unreadable at small sizes, so only the
/// blocks' bounding box is shown. Scales to the space it is given.
class EssentielEmblem extends StatelessWidget {
  const EssentielEmblem({super.key});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: ClipRect(
        child: Align(
          alignment: const Alignment(0, -0.51),
          widthFactor: 0.63,
          heightFactor: 0.583,
          child: Image.asset(
            'assets/essentiel.png',
            width: 1080,
            height: 1080,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

/// The emblem in a clean white circle with a soft shadow, for headers on a coloured background.
class EssentielMark extends StatelessWidget {
  const EssentielMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.22),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const EssentielEmblem(),
    );
  }
}
