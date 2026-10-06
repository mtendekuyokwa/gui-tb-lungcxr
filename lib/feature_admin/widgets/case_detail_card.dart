import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/utils/case_summary.dart';
import 'package:gui_lungcxr/feature_admin/widgets/admin_section.dart';
import 'package:gui_lungcxr/feature_admin/widgets/case_decision.dart';
import 'package:gui_lungcxr/feature_admin/widgets/case_preview.dart';
import 'package:gui_lungcxr/feature_admin/widgets/detail_line.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:gui_lungcxr/feature_home/utils/case_text.dart';
import 'package:provider/provider.dart';

/// The opened case: its image, the model's reading, the doctor's review and,
/// once submitted, the accept / return actions.
class CaseDetailCard extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final item = context.watch<AdminState>().open;
    final catalog = context.watch<SessionState>().catalog;
    final theme = context.theme;
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    if (item == null) {
      return AdminSection(
        title: Strings.caseDetail,
        children: [Text(Strings.selectCase, style: muted)],
      );
    }
    final review = item.review;

    return AdminSection(
      title: caseDetailTitle(item),
      children: [
        CasePreview(caseId: item.id),
        DetailLine(Strings.doctor, item.doctorName ?? Strings.statusUnassigned),
        DetailLine(Strings.modelReading, modelReading(item.prediction)),
        if (review == null)
          Text(Strings.noReviewYet, style: muted)
        else ...[
          DetailLine(
            Strings.verdict,
            catalog.label(catalog.verdicts, review.verdict),
          ),
          if (review.diseases.isNotEmpty)
            DetailLine(Strings.diseases, diseasesSummary(review, catalog)),
          if (review.note.isNotEmpty) DetailLine(Strings.notes, review.note),
          DetailLine(Strings.marks, marksSummary(review)),
          if (review.feedbackKind != null)
            DetailLine(
              Strings.flagModelWrong,
              feedbackSummary(review, catalog),
            ),
          if (review.tests.isNotEmpty)
            DetailLine(
              Strings.flagNeedsTesting,
              testingSummary(review, catalog),
            ),
        ],
        if (item.status == .submitted) CaseDecision(caseId: item.id),
      ],
    );
  }
}
