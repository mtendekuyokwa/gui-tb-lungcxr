import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/review_state.dart';

/// What the doctor is told next to the submit button: the last error, what
/// is still missing, or how the autosave is doing.
String reviewStatusLine(ReviewState review) {
  if (review.saveStatus == .failed) {
    return '${Strings.saveFailed}: ${review.error ?? ''}';
  }
  if (review.error case final error?) return error;
  if (review.verdict == null) return Strings.verdictRequired;
  if (!review.canSubmit) return Strings.diseaseRequired;
  return switch (review.saveStatus) {
    .unsaved => Strings.saveUnsaved,
    .saving => Strings.saveSaving,
    .saved => Strings.saveSaved,
    .idle || .failed => '',
  };
}
