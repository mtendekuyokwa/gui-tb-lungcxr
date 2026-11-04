import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/utils/dashboard_text.dart';
import 'package:gui_lungcxr/feature_admin/widgets/count_row.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:provider/provider.dart';

/// How the TB model compares with the doctors. The agreement rate only
/// shows once enough reviews were compared; before that, the raw count and
/// a note say why. Then how doctors flagged the model, and their verdicts.
class ModelQualityCard extends StatelessWidget {
  const new({required this.stats, this.onOpen, super.key});

  final AdminStats stats;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<SessionState>().catalog;
    final theme = context.theme;
    final muted = theme.typography.body.sm.copyWith(
      color: theme.colors.mutedForeground,
    );
    final heading = theme.typography.body.sm.copyWith(fontWeight: .w600);
    final flagged = flaggedTotal(stats);
    final verdictTotal = stats.verdicts.values.fold(0, (a, b) => a + b);
    // Labelled exactly like the tile groups beside it: heading above the
    // card, description below, in the tile group's own styles.
    final group = theme.tileGroupStyle;

    final Widget agreement;
    if (stats.compared == 0) {
      agreement = Text(Strings.agreeNone, style: muted);
    } else if (!agreementIsMeaningful(stats)) {
      agreement = Column(
        crossAxisAlignment: .start,
        spacing: AppSizes.gap2,
        children: [
          Text(agreementCount(stats), style: theme.typography.body.md),
          Text(tooFewToJudge(), style: muted),
        ],
      );
    } else {
      final healthy = agreementIsHealthy(stats);
      agreement = Row(
        spacing: AppSizes.gap12,
        children: [
          Text(
            agreementPercent(stats),
            style: theme.typography.body.xl2.copyWith(fontWeight: .w600),
          ),
          Expanded(child: Text(agreementCount(stats), style: muted)),
          FBadge(
            variant: healthy ? .secondary : .destructive,
            child: Text(healthy ? Strings.agreeHealthy : Strings.agreeLow),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Padding(
          padding: group.labelPadding,
          child: Text(Strings.modelTitle, style: group.labelTextStyle.base),
        ),
        Padding(
          padding: group.childPadding,
          child: FCard(
            builder: (context, style, _) => Padding(
              padding: style.padding,
              child: Column(
                crossAxisAlignment: .stretch,
                spacing: AppSizes.gap10,
                children: [
                  agreement,
                  const FDivider(),
                  Text(Strings.flaggedKinds, style: heading),
                  if (flagged == 0)
                    Text(Strings.noneYet, style: muted)
                  else ...[
                    for (final option in catalog.feedbackKinds)
                      if ((stats.feedback[option.code] ?? 0) > 0)
                        CountRow(
                          label: option.label,
                          count: stats.feedback[option.code]!,
                          of: flagged,
                        ),
                    Align(
                      alignment: .centerLeft,
                      child: FButton(
                        variant: .outline,
                        size: .sm,
                        onPress: () {
                          context.read<AdminState>().showOnly(
                            flag: CaseFlag.modelWrong,
                          );
                          onOpen?.call();
                        },
                        child: const Text(Strings.reviewFlagged),
                      ),
                    ),
                  ],
                  const FDivider(),
                  Text(Strings.verdictMix, style: heading),
                  if (verdictTotal == 0)
                    Text(Strings.noneYet, style: muted)
                  else
                    for (final option in catalog.verdicts)
                      if ((stats.verdicts[option.code] ?? 0) > 0)
                        CountRow(
                          label: option.label,
                          count: stats.verdicts[option.code]!,
                          of: verdictTotal,
                        ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: group.descriptionPadding,
          child: Text(
            Strings.modelHint,
            style: group.descriptionTextStyle.base,
          ),
        ),
      ],
    );
  }
}
