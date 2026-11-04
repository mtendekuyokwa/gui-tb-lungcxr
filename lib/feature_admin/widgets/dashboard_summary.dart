import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/utils/dashboard_text.dart';
import 'package:provider/provider.dart';

/// The dashboard's opening line: in one plain sentence, what waits for the
/// admin and where the rest of the work is. Beneath it, a quiet note while
/// the model still has readings to make.
class DashboardSummary extends StatelessWidget {
  const new({required this.stats, super.key});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final waiting = context.select<AdminState, bool>((a) => a.waitingOnModel);

    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(
          dashboardSummary(stats),
          style: theme.typography.body.xl2.copyWith(
            fontWeight: .w600,
            height: 1.3,
          ),
        ),
        if (waiting)
          Text(
            Strings.statsWaiting,
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
      ],
    );
  }
}
