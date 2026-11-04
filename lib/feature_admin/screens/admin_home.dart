import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/widgets/admin_header.dart';
import 'package:gui_lungcxr/feature_admin/widgets/admin_sidebar.dart';
import 'package:gui_lungcxr/feature_admin/widgets/admin_workbench.dart';
import 'package:gui_lungcxr/feature_admin/widgets/case_detail_card.dart';
import 'package:gui_lungcxr/feature_admin/widgets/case_list.dart';
import 'package:gui_lungcxr/feature_admin/widgets/admin_dashboard.dart';
import 'package:gui_lungcxr/feature_admin/widgets/doctor_list.dart';
import 'package:gui_lungcxr/feature_admin/widgets/export_card.dart';
import 'package:gui_lungcxr/feature_admin/widgets/hospital_list.dart';
import 'package:gui_lungcxr/feature_admin/widgets/new_user.dart';
import 'package:gui_lungcxr/feature_admin/widgets/assign_card.dart';
import 'package:gui_lungcxr/widgets/create_fab.dart';
import 'package:gui_lungcxr/widgets/new_case_form.dart';
import 'package:gui_lungcxr/widgets/narrow_tabs.dart';
import 'package:provider/provider.dart';

/// The hospital admin's workspace as a dashboard, not a wall of buttons:
/// a sidebar picks the page and each page answers one concern — the
/// overview (what needs me today), case management (the queue beside its
/// work rail), the team, and exports. Under [AppSizes.narrowBreakpoint]
/// the sidebar becomes bottom tabs with the same pages.
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  AdminPage _page = AdminPage.dashboard;

  void _go(AdminPage page) => setState(() => _page = page);

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final theme = context.theme;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: .stretch,
          children: [
            AdminHeader(title: _title(_page)),
            // Every admin action is async; a thin bar says one is running.
            if (admin.busy && !admin.loading) const FProgress(),
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
                      builder: (context, constraints) {
                        final wide =
                            constraints.maxWidth >= AppSizes.narrowBreakpoint;
                        if (wide) {
                          return Row(
                            crossAxisAlignment: .stretch,
                            children: [
                              AdminSidebar(page: _page, onSelect: _go),
                              Expanded(child: _pageOf(_page, wide: true)),
                            ],
                          );
                        }
                        return NarrowTabs(
                          index: _page.index,
                          onChanged: (i) => _go(AdminPage.values[i]),
                          tabs: [
                            for (final page in AdminPage.values)
                              NarrowTab(
                                label: _title(page),
                                icon: _icon(page),
                                page: _pageOf(page, wide: false),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
        // Files cases and adds users from any page.
        CreateFab(
          actions: [
            CreateAction(
              label: Strings.uploadCase,
              icon: FLucideIcons.image,
              builder: (origin, onDone) => _provided(
                origin: origin,
                builder: (admin) => NewCaseForm(
                  upload:
                      ({
                        required patientName,
                        required hospitalNumber,
                        hospitalId,
                        required bytes,
                        required filename,
                      }) => admin.upload(
                        patientName: patientName,
                        hospitalNumber: hospitalNumber,
                        hospitalId: hospitalId,
                        bytes: bytes,
                        filename: filename,
                      ),
                  search: admin.patients,
                  searchHospitals: admin.hospitals,
                  createHospital: admin.createHospital,
                  busy: admin.busy,
                  error: admin.error,
                  onDone: onDone,
                ),
              ),
            ),
            CreateAction(
              label: Strings.createUser,
              icon: FLucideIcons.userPlus,
              builder: (origin, onDone) => _provided(
                origin: origin,
                builder: (admin) => NewUser(onDone: onDone),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The pop-up panel mounts outside the workspace, below the navigator, so
  /// re-provide the admin state it needs and keep the form reacting to it.
  Widget _provided({
    required BuildContext origin,
    required Widget Function(AdminState admin) builder,
  }) {
    final admin = origin.read<AdminState>();
    return ChangeNotifierProvider<AdminState>.value(
      value: admin,
      child: Consumer<AdminState>(builder: (_, admin, _) => builder(admin)),
    );
  }

  String _title(AdminPage page) => switch (page) {
    AdminPage.dashboard => Strings.dashboard,
    AdminPage.cases => Strings.cases,
    AdminPage.team => Strings.teamTab,
    AdminPage.export => Strings.export,
  };

  IconData _icon(AdminPage page) => switch (page) {
    AdminPage.dashboard => FLucideIcons.layoutDashboard,
    AdminPage.cases => FLucideIcons.layers,
    AdminPage.team => FLucideIcons.users,
    AdminPage.export => FLucideIcons.download,
  };

  /// Every number on the dashboard lands on the Cases page, filtered to
  /// what it counts.
  Widget _pageOf(AdminPage page, {required bool wide}) => switch (page) {
    AdminPage.dashboard => AdminDashboard(onOpen: () => _go(AdminPage.cases)),
    AdminPage.cases => wide ? _CasesWide() : _CasesNarrow(),
    AdminPage.team => _CenteredPage(
      children: const [DoctorList(), HospitalList()],
    ),
    AdminPage.export => _CenteredPage(children: const [ExportCard()]),
  };
}

/// Case management on its own page: the queue on the left, the work rail
/// (opened case, intake) on the right.
class _CasesWide extends StatelessWidget {
  const _CasesWide();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: .stretch,
      children: [
        Expanded(child: const CaseList()),
        SizedBox(
          width: AppSizes.adminPanelWidth,
          child: SingleChildScrollView(
            padding: const .fromLTRB(
              0,
              AppSizes.gap12,
              AppSizes.gap12,
              AppSizes.gap12,
            ),
            child: AdminWorkbench(),
          ),
        ),
      ],
    );
  }
}

/// The narrow case page: queue first, the opened case and intake as sub-tabs
/// so list, detail and filing never fight for one column.
class _CasesNarrow extends StatelessWidget {
  const _CasesNarrow();

  @override
  Widget build(BuildContext context) {
    final openId = context.select<AdminState, int?>((a) => a.open?.id);

    return FTabs(
      expands: true,
      children: [
        FTabEntry(label: Text(Strings.casesTab), child: const CaseList()),
        FTabEntry(
          label: Text(Strings.detailTab),
          child: SingleChildScrollView(
            padding: const .all(AppSizes.gap12),
            child: CaseDetailCard(key: ValueKey(openId)),
          ),
        ),
        FTabEntry(
          label: Text(Strings.intakeTab),
          child: SingleChildScrollView(
            padding: const .all(AppSizes.gap12),
            child: const AssignCard(),
          ),
        ),
      ],
    );
  }
}

/// A settings-style page: one centered column at a readable width. Full
/// 1400px lines of form fields are harder to read than paper.
class _CenteredPage extends StatelessWidget {
  const _CenteredPage({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const .all(AppSizes.gap16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSizes.adminPageMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: .stretch,
            spacing: AppSizes.gap12,
            children: children,
          ),
        ),
      ),
    );
  }
}
