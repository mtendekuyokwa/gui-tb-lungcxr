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

/// Every case the admin can see, narrowed down at the top: a search box
/// over patient names and case numbers, a row of status pills, and (behind
/// the funnel button) the doctor and flag filters, which only surface when
/// they are wanted. Selection works per row, or all shown at once.
class CaseList extends StatefulWidget {
  const CaseList({super.key});

  @override
  State<CaseList> createState() => _CaseListState();
}

class _CaseListState extends State<CaseList> {
  static const _all = 'all';

  final _search = TextEditingController();
  var _showFilters = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Client-side narrowing on top of the list the server already filtered:
  /// match what the admin typed against patient and case id.
  bool _matches(CxrCase item) {
    final term = _search.text.trim().toLowerCase();
    if (term.isEmpty) return true;
    return '${item.patientName} ${item.displayId}'.toLowerCase().contains(term);
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final theme = context.theme;
    final muted = theme.typography.body.xs2.copyWith(
      color: theme.colors.mutedForeground,
    );
    final visible = [
      for (final c in admin.cases)
        if (_matches(c)) c,
    ];
    final extraFilters =
        (admin.doctorFilter != null ? 1 : 0) +
        (admin.flagFilter == null ? 0 : 1);

    return Padding(
      padding: const .all(AppSizes.gap12),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: AppSizes.gap8,
        children: [
          Row(
            crossAxisAlignment: .start,
            spacing: AppSizes.gap8,
            children: [
              Expanded(
                child: FTextField(
                  control: .managed(controller: _search),
                  hint: Strings.searchCases,
                  size: .sm,
                  clearable: (value) => value.text.isNotEmpty,
                  prefixBuilder: (context, style, variants) =>
                      FTextField.prefixIconBuilder(
                        context,
                        style,
                        variants,
                        const Icon(FLucideIcons.search),
                      ),
                ),
              ),
              // The rarer filters hide behind the funnel; the funnel lights
              // up when one of them is doing work.
              FTooltip(
                tipBuilder: (_, _) => Text(
                  _showFilters ? Strings.fewerFilters : Strings.moreFilters,
                ),
                child: FButton.icon(
                  variant: _showFilters || extraFilters > 0
                      ? .secondary
                      : .outline,
                  size: .sm,
                  onPress: () => setState(() => _showFilters = !_showFilters),
                  child: Icon(
                    extraFilters == 0
                        ? FLucideIcons.funnel
                        : FLucideIcons.funnelPlus,
                  ),
                ),
              ),
            ],
          ),
          if (_showFilters) ...[
            _filterGroup(
              context,
              label: Strings.filterDoctor,
              child: ChoiceChips(
                options: [
                  const Option(_all, Strings.all),
                  for (final doctor in admin.doctors)
                    Option('${doctor.id}', doctor.fullName),
                ],
                selected: {
                  admin.doctorFilter == null ? _all : '${admin.doctorFilter}',
                },
                onTap: (code) => admin.setDoctorFilter(
                  code == _all ? null : int.parse(code),
                ),
                enabled: !admin.busy,
              ),
            ),
            _filterGroup(
              context,
              label: Strings.filterFlag,
              child: ChoiceChips(
                options: const [
                  Option(_all, Strings.flagAll),
                  Option('model_wrong', Strings.flagModelWrongShort),
                  Option('needs_testing', Strings.flagNeedsTestingShort),
                ],
                selected: {admin.flagFilter?.code ?? _all},
                onTap: (code) => admin.setFlagFilter(
                  code == _all
                      ? null
                      : CaseFlag.values.firstWhere((f) => f.code == code),
                ),
                enabled: !admin.busy,
              ),
            ),
          ],
          if (admin.ticked.isNotEmpty)
            _SelectionBar(
              count: admin.ticked.length,
              onSelectAll: visible.isEmpty
                  ? null
                  : () => admin.selectShown(visible),
            ),
          if (admin.waitingOnModel) Text(Strings.waitingOnModel, style: muted),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: .min,
                      spacing: AppSizes.gap8,
                      children: [
                        Icon(
                          FLucideIcons.layers,
                          size: AppSizes.icon32,
                          color: theme.colors.mutedForeground,
                        ),
                        Text(
                          _search.text.isEmpty
                              ? Strings.noCasesAdmin
                              : Strings.noCasesMatch,
                          style: muted,
                          textAlign: .center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSizes.gap6),
                    itemBuilder: (_, i) => CaseRow(item: visible[i]),
                  ),
          ),
        ],
      ),
    );
  }

  /// A tiny caption followed by a filter row, so the extra filters keep
  /// names even while they are hidden pills.
  Widget _filterGroup(
    BuildContext context, {
    required String label,
    required Widget child,
  }) => Column(
    crossAxisAlignment: .start,
    spacing: AppSizes.gap4,
    children: [
      Text(
        label,
        style: context.theme.typography.body.xs3.copyWith(
          color: context.theme.colors.mutedForeground,
        ),
      ),
      child,
    ],
  );
}

/// What the list says while the admin is picking cases: how many are
/// ticked and the one-tap ways to add or discard.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.count, required this.onSelectAll});

  final int count;
  final VoidCallback? onSelectAll;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final theme = context.theme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.primary.withValues(alpha: 0.08),
        border: Border.all(color: theme.colors.primary.withValues(alpha: 0.35)),
        borderRadius: .circular(AppSizes.radius8),
      ),
      child: Padding(
        padding: const .symmetric(
          horizontal: AppSizes.gap10,
          vertical: AppSizes.gap6,
        ),
        child: Row(
          spacing: AppSizes.gap8,
          children: [
            Icon(
              FLucideIcons.checkCheck,
              size: AppSizes.icon16,
              color: theme.colors.primary,
            ),
            Text(
              '$count ${Strings.tickedCases}',
              overflow: .ellipsis,
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.primary,
                fontWeight: .w600,
              ),
            ),
            const Spacer(),
            if (onSelectAll != null)
              FButton(
                variant: .ghost,
                size: .xs,
                onPress: onSelectAll,
                child: Text(Strings.selectAllShown),
              ),
            FButton.icon(
              variant: .ghost,
              size: .xs,
              onPress: admin.clearTicked,
              child: const Icon(FLucideIcons.circleX),
            ),
          ],
        ),
      ),
    );
  }
}
