import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/utils/dashboard_text.dart';
import 'package:gui_lungcxr/feature_admin/widgets/dashboard_summary.dart';
import 'package:gui_lungcxr/feature_admin/widgets/queue_group.dart';
import 'package:gui_lungcxr/feature_admin/widgets/model_quality_card.dart';
import 'package:gui_lungcxr/feature_admin/widgets/workload_card.dart';
import 'package:provider/provider.dart';

/// The admin's overview, read top to bottom: what needs the admin now,
/// where every case sits, how the model compares with the doctors, and who
/// carries the work. Every number opens the case list on what it counts;
/// [onOpen] moves the admin there.
class AdminDashboard extends StatelessWidget {
  const new({this.onOpen, super.key});

  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final stats = context.select<AdminState, AdminStats?>((a) => a.stats);

    return SingleChildScrollView(
      // Room at the bottom so the create button never covers a card.
      padding: const .fromLTRB(
        AppSizes.gap16,
        AppSizes.gap16,
        AppSizes.gap16,
        AppSizes.fabSize + AppSizes.gap24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSizes.dashboardMaxWidth,
          ),
          child: stats == null
              ? const _DeferredNote()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // Left: the work waiting on the admin. Right: who can
                    // take more, and how the model is doing.
                    final left = [
                      QueueGroup(
                        kind: AdminQueueKind.signOff,
                        queue: stats.signOff,
                        onOpen: onOpen,
                      ),
                      QueueGroup(
                        kind: AdminQueueKind.overdue,
                        queue: stats.overdue,
                        onOpen: onOpen,
                      ),
                      QueueGroup(
                        kind: AdminQueueKind.unassigned,
                        queue: stats.unassigned,
                        onOpen: onOpen,
                      ),
                    ];
                    final right = [
                      WorkloadCard(stats: stats, onOpen: onOpen),
                      ModelQualityCard(stats: stats, onOpen: onOpen),
                    ];
                    final wide =
                        constraints.maxWidth >= AppSizes.dashboardTwoColumn;
                    return _column([
                      DashboardSummary(stats: stats),
                      if (wide)
                        Row(
                          crossAxisAlignment: .start,
                          spacing: AppSizes.gap24,
                          children: [
                            Expanded(child: _column(left)),
                            Expanded(child: _column(right)),
                          ],
                        )
                      else ...[
                        ...left,
                        ...right,
                      ],
                    ]);
                  },
                ),
        ),
      ),
    );
  }

  Widget _column(List<Widget> children) => Column(
    crossAxisAlignment: .stretch,
    spacing: AppSizes.gap24,
    children: children,
  );
}

/// Stands in for the whole dashboard when the stats endpoint fails, so the
/// page says what is missing instead of showing zeros.
class _DeferredNote extends StatelessWidget {
  const _DeferredNote();

  @override
  Widget build(BuildContext context) {
    return const FAlert(
      icon: Icon(FLucideIcons.chartColumn),
      title: Text(Strings.stats),
      subtitle: Text(Strings.statsDeferred),
    );
  }
}
