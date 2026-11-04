import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/widgets/app_brand.dart';
import 'package:provider/provider.dart';

/// The admin workspace's pages, one concern each: the overview, case
/// management, the team, and exports.
enum AdminPage { dashboard, cases, team, export }

/// Left rail of the admin workspace: which page is on. The Cases item
/// carries a live count of what needs a decision, Linear-inbox style, so
/// the pages answer "anything waiting?" before it is even opened.
class AdminSidebar extends StatelessWidget {
  const new({required this.page, required this.onSelect, super.key});

  final AdminPage page;
  final ValueChanged<AdminPage> onSelect;

  /// Cases that will not move on their own: unassigned, submitted for a
  /// decision, or returned to the hospital. Zero pages stay unlabeled.
  static int _actionable(AdminStats? stats) {
    if (stats == null) return 0;
    return (stats.byStatus[CaseStatus.unassigned.code] ?? 0) +
        (stats.byStatus[CaseStatus.submitted.code] ?? 0) +
        (stats.byStatus[CaseStatus.returned.code] ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final actionable = context.select<AdminState, int>(
      (a) => _actionable(a.stats),
    );

    FSidebarItem item(
      AdminPage target,
      IconData icon,
      String label, {
      int? badge,
    }) => FSidebarItem(
      icon: Icon(icon),
      label: Text(switch (badge) {
        int n when n > 0 => '$label · $n',
        _ => label,
      }, maxLines: 1),
      selected: page == target,
      onPress: () => onSelect(target),
    );

    return FSidebar(
      style: const .delta(
        headerPadding: .value(.fromLTRB(0, AppSizes.gap16, 0, 0)),
      ),
      header: const Padding(
        padding: .symmetric(horizontal: AppSizes.gap16),
        child: Align(alignment: .centerLeft, child: AppBrand()),
      ),
      children: [
        FSidebarGroup(
          label: const Text(Strings.adminNav),
          children: [
            item(
              AdminPage.dashboard,
              FLucideIcons.layoutDashboard,
              Strings.dashboard,
            ),
            item(
              AdminPage.cases,
              FLucideIcons.layers,
              Strings.cases,
              badge: actionable,
            ),
            item(AdminPage.team, FLucideIcons.users, Strings.teamTab),
            item(AdminPage.export, FLucideIcons.download, Strings.export),
          ],
        ),
      ],
    );
  }
}
