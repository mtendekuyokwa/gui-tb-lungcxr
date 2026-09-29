import 'package:flutter/material.dart';

/// Paints the user's marks. Stroke points are image-relative (0..1).
class PaintboardWid extends CustomPainter {
  PaintboardWid({
    required this.strokes,
    required this.revision,
    required this.color,
  });

  final List<List<Offset>> strokes;

  /// Bumped by the editor whenever [strokes] changes, since the list itself is
  /// mutated in place.
  final int revision;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = .stroke
      ..strokeWidth = (size.shortestSide * 0.006).clamp(1.5, 4)
      ..strokeCap = .round
      ..strokeJoin = .round;

    for (final stroke in strokes) {
      final points = [
        for (final p in stroke) Offset(p.dx * size.width, p.dy * size.height),
      ];
      if (points.length == 1) {
        canvas.drawCircle(
          points.first,
          paint.strokeWidth / 2,
          paint..style = .fill,
        );
        paint.style = .stroke;
        continue;
      }
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(PaintboardWid oldDelegate) =>
      oldDelegate.revision != revision ||
      oldDelegate.strokes != strokes ||
      oldDelegate.color != color;
}
