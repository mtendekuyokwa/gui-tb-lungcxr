import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/utils/case_summary.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:provider/provider.dart';

/// One case in the admin's list: tick it for assignment, tap it to open.
class CaseRow extends StatelessWidget {
  const new({required this.item, super.key});

  final CxrCase item;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final catalog = context.watch<SessionState>().catalog;
    final theme = context.theme;
    final ticked = admin.ticked.contains(item.id);
    final isOpen = admin.open?.id == item.id;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: .opaque,
        onTap: () => admin.openCase(item.id),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isOpen ? theme.colors.secondary : theme.colors.background,
            border: .all(color: theme.colors.border),
            borderRadius: .circular(AppSizes.radius8),
          ),
          child: Padding(
            padding: const .symmetric(
              horizontal: AppSizes.gap8,
              vertical: AppSizes.gap6,
            ),
            child: Row(
              spacing: AppSizes.gap10,
              children: [
                FButton.icon(
                  variant: .ghost,
                  size: .sm,
                  // Submitted and accepted cases cannot be reassigned.
                  onPress: item.status.assignable
                      ? () => admin.toggleTicked(item.id)
                      : null,
                  child: Icon(
                    ticked ? FLucideIcons.squareCheck : FLucideIcons.square,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: AppSizes.gap2,
                    children: [
                      Text(
                        '${item.patientName}  ${item.displayId}',
                        overflow: .ellipsis,
                        style: theme.typography.body.sm.copyWith(
                          fontWeight: .w600,
                        ),
                      ),
                      Text(
                        caseRowDetails(item, catalog),
                        overflow: .ellipsis,
                        style: theme.typography.body.xs.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.modelWrong)
                  const FTooltip(
                    tipBuilder: _modelWrongTip,
                    child: Icon(FLucideIcons.bot, size: AppSizes.icon16),
                  ),
                if (item.needsTesting)
                  const FTooltip(
                    tipBuilder: _needsTestingTip,
                    child: Icon(
                      FLucideIcons.flaskConical,
                      size: AppSizes.icon16,
                    ),
                  ),
                FBadge(
                  variant: switch (item.status) {
                    .submitted => .primary,
                    .returned => .destructive,
                    .accepted => .secondary,
                    _ => .outline,
                  },
                  child: Text(item.status.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _modelWrongTip(BuildContext _, FTooltipController _) =>
      const Text(Strings.flagModelWrong);

  static Widget _needsTestingTip(BuildContext _, FTooltipController _) =>
      const Text(Strings.flagNeedsTesting);
}
