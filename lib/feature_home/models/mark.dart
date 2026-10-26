import 'dart:ui';

import 'package:gui_lungcxr/feature_home/models/lesion.dart';

/// A hand-drawn stroke on the X-ray, the finding it was labelled with and the
/// doctor's comment describing it.
class Mark {
  new(this.points, {this.note = ''});

  /// Image-relative points (0..1 on both axes), so the mark stays attached to
  /// the image regardless of zoom or window size.
  final List<Offset> points;

  /// Null until the clinician labels the mark.
  LesionType? lesion;

  /// Free-text comment describing the finding, e.g. "Cavity, right upper
  /// zone". Empty until the clinician writes one.
  String note;

  /// Top-most point, where the mark's label tag is anchored.
  Offset get anchor => points.reduce((a, b) => b.dy < a.dy ? b : a);
}
