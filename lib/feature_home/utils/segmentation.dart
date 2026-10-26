import 'dart:ui';

/// Builds a 4x5 colour matrix (see [ColorFilter.matrix], 0..255 units) that
/// turns the backend's white-on-black lung mask into a translucent wash of
/// [tint]: white becomes [tint] at [opacity], black becomes transparent.
List<double> maskTintMatrix(Color tint, double opacity) {
  final r = tint.r * 255;
  final g = tint.g * 255;
  final b = tint.b * 255;
  return [
    0, 0, 0, 0, r, //
    0, 0, 0, 0, g, //
    0, 0, 0, 0, b, //
    opacity, 0, 0, 0, 0, //
  ];
}
