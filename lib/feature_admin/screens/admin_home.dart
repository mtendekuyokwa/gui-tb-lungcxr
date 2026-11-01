import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/widgets/admin_header.dart';
import 'package:gui_lungcxr/feature_admin/widgets/admin_workbench.dart';
import 'package:gui_lungcxr/feature_admin/widgets/charts.dart';
import 'package:gui_lungcxr/feature_admin/widgets/case_list.dart';
import 'package:gui_lungcxr/feature_admin/widgets/dashboard_strip.dart';
import 'package:gui_lungcxr/widgets/narrow_tabs.dart';
import 'package:provider/provider.dart';

/// The hospital admin's workspace: a dashboard strip answering "what needs
/// me today", every case on the left, and a tabbed work rail on the right.
/// Under [AppSizes.narrowBreakpoint] the workspace becomes bottom tabs.
class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final theme = context.theme;

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const AdminHeader(),
        if (admin.error case final error?)
          Padding(
            padding: const .fromLTRB(
              AppSizes.gap16,
              AppSizes.gap8,
              AppSizes.gap16,
              0,
            ),
            child: Text(
              error,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.destructive,
              ),
            ),
          ),
        Expanded(
          child: admin.loading
              ? const Center(child: FCircularProgress())
              : LayoutBuilder(
                  builder: (context, constraints) =>
                      constraints.maxWidth < AppSizes.narrowBreakpoint
                      ? NarrowTabs(
                          tabs: [
                            NarrowTab(
                              label: Strings.dashboard,
                              icon: FLucideIcons.layoutDashboard,
                              page: SingleChildScrollView(
                                padding: const .all(AppSizes.gap12),
                                child: Column(
                                  crossAxisAlignment: .stretch,
                                  spacing: AppSizes.gap12,
                                  children: const [
                                    DashboardStrip(),
                                    AdminCharts(),
                                  ],
                                ),
                              ),
                            ),
                            NarrowTab(
                              label: Strings.casesTab,
                              icon: FLucideIcons.layers,
                              page: const CaseList(),
                            ),
                            NarrowTab(
                              label: Strings.manageTab,
                              icon: FLucideIcons.settings,
                              page: const SingleChildScrollView(
                                padding: .all(AppSizes.gap12),
                                child: AdminWorkbench(),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: .stretch,
                          spacing: AppSizes.gap8,
                          children: [
                            Padding(
                              padding: const .fromLTRB(
                                AppSizes.gap16,
                                AppSizes.gap12,
                                AppSizes.gap16,
                                0,
                              ),
                              child: DashboardStrip(),
                            ),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: .stretch,
                                children: [
                                  Expanded(child: CaseList()),
                                  SizedBox(
                                    width: AppSizes.adminPanelWidth,
                                    child: SingleChildScrollView(
                                      padding: const .fromLTRB(
                                        0,
                                        AppSizes.gap12,
                                        AppSizes.gap12,
                                        AppSizes.gap12,
                                      ),
                                      child: const AdminWorkbench(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
        ),
      ],
    );
  }
}
