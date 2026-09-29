import 'package:flutter_test/flutter_test.dart';
import 'package:gui_lungcxr/feature_home/utils/color_matrix.dart';

/// Applies a 4x5 colour matrix to an RGBA pixel (0..255).
List<double> apply(List<double> m, List<double> rgba) => [
  for (var r = 0; r < 4; r++)
    m[r * 5] * rgba[0] +
        m[r * 5 + 1] * rgba[1] +
        m[r * 5 + 2] * rgba[2] +
        m[r * 5 + 3] * rgba[3] +
        m[r * 5 + 4],
];

void main() {
  const grey = [100.0, 100.0, 100.0, 255.0];

  test('neutral inputs give the identity matrix', () {
    final m = adjustmentMatrix();
    expect(m, hasLength(20));
    expect(apply(m, [10, 20, 30, 255]), [
      for (final v in [10, 20, 30, 255]) moreOrLessEquals(v.toDouble()),
    ]);
  });

  test('brightness shifts RGB but not alpha', () {
    final out = apply(adjustmentMatrix(brightness: 0.5), grey);
    expect(out[0], moreOrLessEquals(100 + 127.5));
    expect(out[3], moreOrLessEquals(255));
  });

  test('contrast pivots around mid-grey', () {
    final m = adjustmentMatrix(contrast: 0.5);
    expect(apply(m, [128, 128, 128, 255])[0], moreOrLessEquals(128));
    expect(apply(m, grey)[0], lessThan(100));
  });

  test('hue and saturation leave greys unchanged', () {
    final m = adjustmentMatrix(hue: 0.3, saturation: -0.7);
    final out = apply(m, grey);
    for (var i = 0; i < 3; i++) {
      expect(out[i], moreOrLessEquals(100, epsilon: 1e-6));
    }
  });
}
