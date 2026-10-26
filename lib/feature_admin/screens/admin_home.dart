import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/widgets/admin_header.dart';
import 'package:gui_lungcxr/feature_admin/widgets/assign_card.dart';
import 'package:gui_lungcxr/feature_admin/widgets/case_detail_card.dart';
import 'package:gui_lungcxr/feature_admin/widgets/case_list.dart';
import 'package:gui_lungcxr/feature_admin/widgets/doctor_list.dart';
import 'package:gui_lungcxr/feature_admin/widgets/export_card.dart';
import 'package:gui_lungcxr/feature_admin/widgets/new_user.dart';
import 'package:gui_lungcxr/feature_admin/widgets/stats_card.dart';
import 'package:gui_lungcxr/feature_admin/widgets/upload_card.dart';
import 'package:gui_lungcxr/widgets/narrow_tabs.dart';
import 'package:provider/provider.dart';

/// The hospital admin's workspace: every case on the left; upload, assign
/// and the selected case's review on the right. Under
/// [AppSizes.narrowBreakpoint] the two sides become bottom tabs.
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
                              label: Strings.casesTab,
                              icon: FLucideIcons.layers,
                              page: const CaseList(),
                            ),
                            NarrowTab(
                              label: Strings.manageTab,
                              icon: FLucideIcons.settings,
                              page: const SingleChildScrollView(
                                child: AdminPanels(),
                              ),
                            ),
                          ],
                        )
                      : const Row(
                          crossAxisAlignment: .stretch,
                          children: [
                            Expanded(child: CaseList()),
                            SizedBox(
                              width: AppSizes.adminPanelWidth,
                              child: SingleChildScrollView(
                                padding: .fromLTRB(
                                  0,
                                  AppSizes.gap12,
                                  AppSizes.gap12,
                                  AppSizes.gap12,
                                ),
                                child: AdminPanels(),
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

/// Upload, assignment, users, statistics, export and the opened case.
class AdminPanels extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final openId = context.select<AdminState, int?>((a) => a.open?.id);
    return Column(
      crossAxisAlignment: .stretch,
      spacing: AppSizes.gap12,
      children: [
        const UploadCard(),
        const AssignCard(),
        const NewUser(),
        const DoctorList(),
        const StatsCard(),
        const ExportCard(),
        CaseDetailCard(key: ValueKey(openId)),
      ],
    );
  }
}
