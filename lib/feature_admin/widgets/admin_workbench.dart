import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/widgets/case_detail_card.dart';
import 'package:gui_lungcxr/feature_admin/widgets/assign_card.dart';
import 'package:provider/provider.dart';

/// The rail beside the case list on the Cases page: the opened case, and
/// intake (hand ticked cases to a doctor; new cases are filed from the
/// create pop-up). Team and export live on their own pages, reached from
/// the sidebar.
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
          child: _page(const [AssignCard()]),
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
