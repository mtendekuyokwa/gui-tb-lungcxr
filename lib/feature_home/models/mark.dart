import 'dart:ui';

import 'package:gui_lungcxr/feature_home/models/lesion.dart';

/// A hand-drawn stroke on the X-ray and the finding it was labelled with.
class Mark {
  new(this.points);

  /// Image-relative points (0..1 on both axes), so the mark stays attached to
  /// the image regardless of zoom or window size.
  final List<Offset> points;

  /// Null until the clinician labels the mark.
  LesionType? lesion;

  /// Top-most point, where the mark's label tag is anchored.
  Offset get anchor => points.reduce((a, b) => b.dy < a.dy ? b : a);
}
