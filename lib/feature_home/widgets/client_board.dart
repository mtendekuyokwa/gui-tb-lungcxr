import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/case_state.dart';
import 'package:gui_lungcxr/feature_home/utils/case_text.dart';
import 'package:gui_lungcxr/feature_home/widgets/patient_avatar.dart';
import 'package:provider/provider.dart';

/// The cases assigned to the signed-in doctor, with a search box.
class ClientBoard extends StatefulWidget {
  const new({super.key});

  @override
  State<ClientBoard> createState() => _ClientBoardState();
}

class _ClientBoardState extends State<ClientBoard> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearch);
  }

  void _onSearch() => context.read<CaseState>().setSearchQuery(_search.text);

  @override
  void dispose() {
    _search
      ..removeListener(_onSearch)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CaseState>();
    final selectedId = state.selected?.id;
    final visible = state.visibleCases;

    return Padding(
      padding: const .all(AppSizes.gap8),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: AppSizes.gap8,
        children: [
          FTextField(
            control: .managed(controller: _search),
            label: const Text(Strings.searchClients),
            hint: Strings.searchClientsHint,
            clearable: (value) => value.text.isNotEmpty,
            prefixBuilder: (_, _, _) => const Padding(
              padding: .only(left: AppSizes.gap8),
              child: Icon(FLucideIcons.search, size: AppSizes.icon16),
            ),
          ),
          if (visible.isEmpty)
            Text(
              state.cases.isEmpty
                  ? Strings.noCasesDetail
                  : Strings.noClientMatch,
              style: context.theme.typography.body.sm.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            )
          else
            FTileGroup(
              style: const .delta(dividerWidth: AppSizes.dividerWidth),
              divider: .indented,
              label: const Text(Strings.Patient),
              children: [
                for (final c in visible)
                  .tile(
                    prefix: PatientAvatar(
                      initials: c.initials,
                      size: AppSizes.avatarSm,
                    ),
                    title: Text(c.patientName),
                    subtitle: Text(caseSubtitle(c)),
                    selected: c.id == selectedId,
                    suffix: c.id == selectedId
                        ? const Icon(FLucideIcons.check)
                        : null,
                    onPress: () => state.select(c.id),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
