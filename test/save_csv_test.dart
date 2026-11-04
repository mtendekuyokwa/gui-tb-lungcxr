import 'package:flutter_test/flutter_test.dart';
import 'package:gui_lungcxr/feature_admin/utils/save_csv.dart';

void main() {
  test('export file names carry the kind and the day', () {
    expect(
      exportFileName('model_feedback', DateTime(2026, 3, 7)),
      'lungcxr-model-feedback-2026-03-07.csv',
    );
    expect(
      exportFileName('reviews', DateTime(2026, 11, 4, 23, 59)),
      'lungcxr-reviews-2026-11-04.csv',
    );
  });
}
