import 'package:flutter/material.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/feature_home/models/mark.dart';
import 'package:gui_lungcxr/feature_home/utils/mark_style.dart';

/// Paints the user's marks. Mark points are image-relative (0..1).
class PaintboardWid extends CustomPainter {
  PaintboardWid({
    required this.marks,
    required this.revision,
    required this.activeMark,
    required this.colorOf,
  });

  final List<Mark> marks;

  /// Bumped by the editor whenever [marks] changes, since the list itself is
  /// mutated in place.
  final int revision;
  final int? activeMark;
  final Color Function(Mark) colorOf;

  @override
  void paint(Canvas canvas, Size size) {
    final width = markStrokeWidth(size);

    for (final (i, mark) in marks.indexed) {
      final paint = Paint()
        ..color = colorOf(mark)
        ..style = .stroke
        ..strokeWidth = i == activeMark
            ? width * AppSizes.activeMarkStrokeScale
            : width
        ..strokeCap = .round
        ..strokeJoin = .round;
      final points = [
        for (final p in mark.points)
          Offset(p.dx * size.width, p.dy * size.height),
      ];
      if (points.length == 1) {
        canvas.drawCircle(
          points.first,
          paint.strokeWidth / 2,
          paint..style = .fill,
        );
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
      oldDelegate.marks != marks ||
      oldDelegate.activeMark != activeMark;
}
