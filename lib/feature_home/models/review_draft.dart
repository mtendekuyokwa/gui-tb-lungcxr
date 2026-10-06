import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:gui_lungcxr/feature_home/models/mark.dart';

/// The whole review as the doctor has it now, in the shape the backend's
/// `PUT /cases/{id}/review` expects.
class ReviewDraft {
  const new({
    required this.verdict,
    required this.note,
    required this.marks,
    required this.diseases,
    required this.feedbackKind,
    required this.feedbackNote,
    required this.tests,
    required this.urgency,
  });

  final String? verdict;
  final String note;
  final List<Mark> marks;
  final List<String> diseases;

  /// Null when the doctor did not flag the model as wrong.
  final String? feedbackKind;
  final String feedbackNote;

  /// Empty when no further testing is requested.
  final List<String> tests;
  final String urgency;

  Map<String, dynamic> toJson() => {
    'verdict': verdict,
    'note': note,
    'marks': [for (final mark in marks) markToJson(mark)],
    'disease_tags': diseases,
    'model_feedback': feedbackKind == null
        ? null
        : {'kind': feedbackKind, 'note': feedbackNote},
    'further_testing': tests.isEmpty
        ? null
        : {'tests': tests, 'urgency': urgency},
  };
}
