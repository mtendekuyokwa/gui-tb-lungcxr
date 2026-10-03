import 'dart:ui';

import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/models/lesion.dart';
import 'package:gui_lungcxr/feature_home/models/mark.dart';

/// Where a case is in the admin → doctor → admin workflow.
enum CaseStatus {
  unassigned('unassigned', Strings.statusUnassigned),
  assigned('assigned', Strings.statusAssigned),
  inReview('in_review', Strings.statusInReview),
  submitted('submitted', Strings.statusSubmitted),
  returned('returned', Strings.statusReturned),
  accepted('accepted', Strings.statusAccepted);

  const CaseStatus(this.code, this.label);

  final String code;
  final String label;

  /// Whether the assigned doctor may still change the review.
  bool get editable => switch (this) {
    assigned || inReview || returned => true,
    unassigned || submitted || accepted => false,
  };

  /// Whether the admin may hand the case to a (different) doctor.
  bool get assignable => this == unassigned || editable;

  static CaseStatus fromCode(String code) =>
      values.firstWhere((s) => s.code == code);
}

/// The TB model's reading of one image.
class Prediction {
  const new({
    required this.state,
    this.label,
    this.tbProbability,
    this.hasOverlay = false,
  });

  /// `queued`, `done` or `failed`.
  final String state;

  /// `tb` or `normal` once [state] is `done`.
  final String? label;
  final double? tbProbability;
  final bool hasOverlay;

  bool get done => state == 'done';

  static Prediction fromJson(Map<String, dynamic> json) => Prediction(
    state: json['state'] as String,
    label: json['label'] as String?,
    tbProbability: (json['tb_probability'] as num?)?.toDouble(),
    hasOverlay: json['has_overlay'] as bool? ?? false,
  );
}

/// A doctor's review as stored on the backend.
class Review {
  const new({
    required this.submitted,
    this.verdict,
    this.note = '',
    this.marks = const [],
    this.diseases = const [],
    this.feedbackKind,
    this.feedbackNote = '',
    this.feedbackDerived = false,
    this.tests = const [],
    this.urgency,
    this.doctorName,
  });

  final bool submitted;
  final String? verdict;
  final String note;
  final List<Mark> marks;
  final List<String> diseases;
  final String? feedbackKind;
  final String feedbackNote;

  /// True when the backend recorded the model error itself, because the
  /// verdict contradicted the model.
  final bool feedbackDerived;
  final List<String> tests;
  final String? urgency;
  final String? doctorName;

  static Review fromJson(Map<String, dynamic> json) {
    final feedback = json['model_feedback'] as Map<String, dynamic>?;
    final testing = json['further_testing'] as Map<String, dynamic>?;
    return Review(
      submitted: json['state'] == 'submitted',
      verdict: json['verdict'] as String?,
      note: json['note'] as String? ?? '',
      marks: [for (final mark in json['marks'] as List) markFromJson(mark)],
      diseases: [
        for (final tag in json['disease_tags'] as List) tag['code'] as String,
      ],
      feedbackKind: feedback?['kind'] as String?,
      feedbackNote: feedback?['note'] as String? ?? '',
      feedbackDerived: feedback?['derived'] as bool? ?? false,
      tests: [...?(testing?['tests'] as List?)?.cast<String>()],
      urgency: testing?['urgency'] as String?,
      doctorName:
          (json['doctor'] as Map<String, dynamic>?)?['full_name'] as String?,
    );
  }
}

Mark markFromJson(dynamic json) {
  final mark = Mark([
    for (final point in json['points'] as List)
      Offset((point[0] as num).toDouble(), (point[1] as num).toDouble()),
  ]);
  mark.lesion = LesionType.values.asNameMap()[json['finding']];
  return mark;
}

Map<String, dynamic> markToJson(Mark mark) => {
  'finding': mark.lesion?.name,
  'points': [
    for (final point in mark.points) [point.dx, point.dy],
  ],
};

/// One chest X-ray of one patient, with the model's reading attached.
class CxrCase {
  const new({
    required this.id,
    required this.status,
    required this.patientName,
    this.hospitalNumber,
    this.prediction,
    this.doctorId,
    this.doctorName,
    this.review,
    this.returnNote,
    this.verdict,
    this.modelWrong = false,
    this.needsTesting = false,
  });

  final int id;
  final CaseStatus status;
  final String patientName;
  final String? hospitalNumber;
  final Prediction? prediction;
  final int? doctorId;
  final String? doctorName;

  /// Only present on a case fetched by id.
  final Review? review;

  /// Why the admin sent the case back, while it is open again.
  final String? returnNote;

  // Summary fields, only present in the admin's list.
  final String? verdict;
  final bool modelWrong;
  final bool needsTesting;

  /// Shown wherever the mockup says "Client ID".
  String get displayId => hospitalNumber ?? '#$id';

  String get initials => patientName
      .split(' ')
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  static CxrCase fromJson(Map<String, dynamic> json) {
    final patient = json['patient'] as Map<String, dynamic>;
    final doctor = json['assigned_to'] as Map<String, dynamic>?;
    final prediction = json['prediction'] as Map<String, dynamic>?;
    final review = json['review'] as Map<String, dynamic>?;
    return CxrCase(
      id: json['id'] as int,
      status: CaseStatus.fromCode(json['status'] as String),
      patientName: patient['name'] as String,
      hospitalNumber: patient['hospital_number'] as String?,
      prediction: prediction == null ? null : Prediction.fromJson(prediction),
      doctorId: doctor?['id'] as int?,
      doctorName: doctor?['full_name'] as String?,
      review: review == null ? null : Review.fromJson(review),
      returnNote: json['return_note'] as String?,
      verdict: json['verdict'] as String?,
      modelWrong: json['model_wrong'] as bool? ?? false,
      needsTesting: json['needs_testing'] as bool? ?? false,
    );
  }
}
