import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';

// The one-line texts the admin's widgets show for a case and its review.

/// Second line of a case row: who has it and, once reviewed, the verdict.
String caseRowDetails(CxrCase item, Catalog catalog) => [
  item.doctorName ?? Strings.statusUnassigned,
  if (item.verdict != null) catalog.label(catalog.verdicts, item.verdict),
].join(' · ');

String caseDetailTitle(CxrCase item) =>
    '${Strings.caseDetail} ${item.displayId} · ${item.patientName}';

String diseasesSummary(Review review, Catalog catalog) => review.diseases
    .map((code) => catalog.label(catalog.diseases, code))
    .join(', ');

/// How many marks the doctor drew and the distinct findings among them.
String marksSummary(Review review) {
  if (review.marks.isEmpty) return Strings.none;
  final findings = {
    for (final mark in review.marks) mark.lesion?.label ?? Strings.unlabelled,
  };
  return '${review.marks.length} · ${findings.join(', ')}';
}

/// What kind of model error was flagged, by whom, and the doctor's note.
String feedbackSummary(Review review, Catalog catalog) => [
  catalog.label(catalog.feedbackKinds, review.feedbackKind),
  if (review.feedbackDerived) '(${Strings.flaggedByServer})',
  if (review.feedbackNote.isNotEmpty) '— ${review.feedbackNote}',
].join(' ');

/// The requested tests and how urgent they are.
String testingSummary(Review review, Catalog catalog) {
  final tests = review.tests
      .map((code) => catalog.label(catalog.tests, code))
      .join(', ');
  return '$tests · ${catalog.label(catalog.urgencies, review.urgency)}';
}
