import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/widgets/case_detail_card.dart';
import 'package:gui_lungcxr/feature_admin/widgets/doctor_list.dart';
import 'package:gui_lungcxr/feature_admin/widgets/export_card.dart';
import 'package:gui_lungcxr/feature_admin/widgets/new_user.dart';
import 'package:gui_lungcxr/feature_admin/widgets/upload_card.dart';
import 'package:gui_lungcxr/feature_admin/widgets/assign_card.dart';
import 'package:gui_lungcxr/feature_admin/widgets/charts.dart';
import 'package:provider/provider.dart';

/// The admin's work rail beside the case list. Four tabs, so no card sits
/// out of sight under a pile of others: the opened case, intake (add a
/// case, then hand ticked ones to a doctor), people (workload and user
/// management) and exports.
class AdminWorkbench extends StatelessWidget {
  const AdminWorkbench({super.key});

  @override
  Widget build(BuildContext context) {
    final openId = context.select<AdminState, int?>((a) => a.open?.id);

    return FTabs(
      children: [
        FTabEntry(
          label: Text(Strings.detailTab),
          child: _page([CaseDetailCard(key: ValueKey(openId))]),
        ),
        FTabEntry(
          label: Text(Strings.intakeTab),
          child: _page([const UploadCard(), const AssignCard()]),
        ),
        FTabEntry(
          label: Text(Strings.peopleTab),
          child: _page([const NewUser(), const DoctorList()]),
        ),
        FTabEntry(
          label: Text(Strings.insightsTab),
          child: _page([const AdminCharts()]),
        ),
        FTabEntry(
          label: Text(Strings.export),
          child: _page([const ExportCard()]),
        ),
      ],
    );
  }

  Widget _page(List<Widget> children) => Padding(
    padding: const .fromLTRB(
      AppSizes.gap12,
      AppSizes.gap12,
      AppSizes.gap12,
      AppSizes.gap12,
    ),
    child: Column(
      crossAxisAlignment: .stretch,
      spacing: AppSizes.gap12,
      children: children,
    ),
  );
}
