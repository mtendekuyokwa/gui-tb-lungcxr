import 'dart:math' as math;

/// Builds a 4x5 colour matrix for [ColorFilter.matrix]. All inputs are in the
/// range -1..1, where 0 leaves the image unchanged.
List<double> adjustmentMatrix({
  double brightness = 0,
  double contrast = 0,
  double hue = 0,
  double saturation = 0,
}) {
  var m = _identity;
  m = _multiply(_saturation(1 + saturation), m);
  m = _multiply(_hueRotation(hue * math.pi), m);
  m = _multiply(_contrast(1 + contrast), m);
  m = _multiply(_brightness(brightness * 255), m);
  return [for (var r = 0; r < 4; r++) ...m.sublist(r * 5, r * 5 + 5)];
}

// Matrices are stored as 5x5 row-major so they can be multiplied; the last
// row is always [0, 0, 0, 0, 1].
const _identity = <double>[
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0, //
  0, 0, 0, 0, 1, //
];

List<double> _multiply(List<double> a, List<double> b) => [
  for (var r = 0; r < 5; r++)
    for (var c = 0; c < 5; c++)
      [for (var k = 0; k < 5; k++) a[r * 5 + k] * b[k * 5 + c]]
          .fold(0.0, (s, v) => s + v),
];

List<double> _brightness(double offset) => [
  1, 0, 0, 0, offset, //
  0, 1, 0, 0, offset, //
  0, 0, 1, 0, offset, //
  0, 0, 0, 1, 0, //
  0, 0, 0, 0, 1, //
];

List<double> _contrast(double factor) {
  final t = 128 * (1 - factor);
  return [
    factor, 0, 0, 0, t, //
    0, factor, 0, 0, t, //
    0, 0, factor, 0, t, //
    0, 0, 0, 1, 0, //
    0, 0, 0, 0, 1, //
  ];
}

// Rec. 709 luminance weights.
const _lr = 0.2126, _lg = 0.7152, _lb = 0.0722;

List<double> _saturation(double s) {
  final inv = 1 - s;
  return [
    _lr * inv + s, _lg * inv, _lb * inv, 0, 0, //
    _lr * inv, _lg * inv + s, _lb * inv, 0, 0, //
    _lr * inv, _lg * inv, _lb * inv + s, 0, 0, //
    0, 0, 0, 1, 0, //
    0, 0, 0, 0, 1, //
  ];
}

List<double> _hueRotation(double radians) {
  final c = math.cos(radians), s = math.sin(radians);
  return [
    _lr + c * (1 - _lr) + s * -_lr,
    _lg + c * -_lg + s * -_lg,
    _lb + c * -_lb + s * (1 - _lb),
    0,
    0, //
    _lr + c * -_lr + s * 0.143,
    _lg + c * (1 - _lg) + s * 0.140,
    _lb + c * -_lb + s * -0.283,
    0,
    0, //
    _lr + c * -_lr + s * -(1 - _lr),
    _lg + c * -_lg + s * _lg,
    _lb + c * (1 - _lb) + s * _lb,
    0,
    0, //
    0, 0, 0, 1, 0, //
    0, 0, 0, 0, 1, //
  ];
}
