import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/widgets/admin_section.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:provider/provider.dart';

/// Counts by status, workload totals and model agreement from
/// `GET /admin/stats`.
class StatsCard extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.select<AdminState, AdminStats?>((a) => a.stats);
    final theme = context.theme;
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    if (stats == null) return const SizedBox.shrink();

    String count(CaseStatus status) => '${stats.byStatus[status.code] ?? 0}';

    return AdminSection(
      title: Strings.stats,
      children: [
        Wrap(
          spacing: AppSizes.gap8,
          runSpacing: AppSizes.gap8,
          children: [
            FBadge(
              variant: .outline,
              child: Text('${Strings.statsOpen}: ${stats.open}'),
            ),
            FBadge(
              variant: .primary,
              child: Text('${Strings.statsSubmitted}: ${stats.submitted}'),
            ),
            FBadge(
              variant: .secondary,
              child: Text('${Strings.statsAccepted}: ${stats.accepted}'),
            ),
          ],
        ),
        Text(
          [
            for (final status in CaseStatus.values)
              '${status.label} ${count(status)}',
          ].join(' · '),
          style: muted,
        ),
        Text(
          stats.compared == 0
              ? '${Strings.statsAgreement}: ${Strings.none}'
              : '${Strings.statsAgreement}: ${stats.agreed}/${stats.compared}'
                '${stats.rate == null ? '' : ' (${(stats.rate! * 100).toStringAsFixed(1)}%)'}',
          style: theme.typography.body.sm,
        ),
      ],
    );
  }
}
