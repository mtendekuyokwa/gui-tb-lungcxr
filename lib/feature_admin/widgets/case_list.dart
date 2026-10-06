import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/widgets/case_row.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:gui_lungcxr/feature_home/widgets/choice_chips.dart';
import 'package:provider/provider.dart';

/// The status filter over every case the admin can see.
class CaseList extends StatelessWidget {
  const new({super.key});

  static const _all = 'all';

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final theme = context.theme;

    return Padding(
      padding: const .all(AppSizes.gap12),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: AppSizes.gap12,
        children: [
          ChoiceChips(
            options: [
              const Option(_all, Strings.all),
              for (final status in CaseStatus.values)
                Option(status.code, status.label),
            ],
            selected: {admin.statusFilter?.code ?? _all},
            onTap: (code) => admin.setStatusFilter(
              code == _all ? null : CaseStatus.fromCode(code),
            ),
          ),
          Expanded(
            child: admin.cases.isEmpty
                ? Center(
                    child: Text(
                      Strings.noCasesAdmin,
                      style: theme.typography.body.sm.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: admin.cases.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSizes.gap6),
                    itemBuilder: (_, i) => CaseRow(item: admin.cases[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
