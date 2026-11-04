import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/case_state.dart';
import 'package:gui_lungcxr/feature_home/utils/case_text.dart';
import 'package:gui_lungcxr/feature_home/widgets/patient_avatar.dart';
import 'package:provider/provider.dart';

/// The cases assigned to the signed-in doctor, with a search box. Each row
/// can be hidden from the list (with undo). When [collapsible], the list
/// folds away under its header so the review below gets the room.
class ClientBoard extends StatefulWidget {
  const new({this.collapsible = true, this.onNewCase, super.key});

  final bool collapsible;

  /// Opens the new-case form from the header's button.
  final VoidCallback? onNewCase;

  @override
  State<ClientBoard> createState() => _ClientBoardState();
}

class _ClientBoardState extends State<ClientBoard> {
  final _search = TextEditingController();
  bool _collapsed = false;

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

  /// Hides the case and offers to bring it back; nothing is deleted.
  Future<void> _hide(CaseState state, int id) async {
    final ok = await state.hide(id);
    if (!ok || !mounted) return;
    showFToast(
      context: context,
      icon: const Icon(FLucideIcons.eyeOff),
      title: const Text(Strings.caseHidden),
      description: const Text(Strings.caseHiddenDetail),
      suffixBuilder: (context, entry) => FButton(
        size: .sm,
        variant: .outline,
        mainAxisSize: .min,
        onPress: () {
          entry.dismiss();
          state.unhide(id);
        },
        child: const Text(Strings.undo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CaseState>();
    final selectedId = state.selected?.id;
    final visible = state.visibleCases;
    final theme = context.theme;

    return Padding(
      padding: const .all(AppSizes.gap8),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        spacing: AppSizes.gap8,
        children: [
          // Collapsing the list leaves the review the whole column.
          Row(
            spacing: AppSizes.gap6,
            children: [
              Expanded(
                child: Text(
                  '${Strings.Patient} (${state.cases.length})',
                  overflow: .ellipsis,
                  style: theme.typography.body.sm.copyWith(fontWeight: .w600),
                ),
              ),
              if (state.refreshing) const FCircularProgress(size: .sm),
              if (widget.onNewCase case final onNewCase?)
                FButton(
                  size: .sm,
                  mainAxisSize: .min,
                  onPress: onNewCase,
                  prefix: const Icon(FLucideIcons.plus),
                  child: const Text(Strings.uploadCase),
                ),
              if (widget.collapsible)
                FTooltip(
                  tipBuilder: (_, _) => Text(
                    _collapsed ? Strings.showCases : Strings.hideCaseList,
                  ),
                  child: FButton.icon(
                    variant: .ghost,
                    size: .sm,
                    onPress: () => setState(() => _collapsed = !_collapsed),
                    child: Icon(
                      _collapsed
                          ? FLucideIcons.chevronDown
                          : FLucideIcons.chevronUp,
                    ),
                  ),
                ),
            ],
          ),
          if (!_collapsed || !widget.collapsible) ...[
            FTextField(
              control: .managed(controller: _search),
              hint: Strings.searchClientsHint,
              clearable: (value) => value.text.isNotEmpty,
              prefixBuilder: (_, _, _) => const Padding(
                padding: .only(left: AppSizes.gap8),
                child: Icon(FLucideIcons.search, size: AppSizes.icon16),
              ),
            ),
            ConstrainedBox(
              // On a short window the list must not squeeze the review:
              // it takes at most a share of the screen height.
              constraints: BoxConstraints(
                maxHeight: widget.collapsible
                    ? (MediaQuery.heightOf(context) *
                              AppSizes.caseListMaxFraction)
                          .clamp(0, AppSizes.caseListMaxHeight)
                    : double.infinity,
              ),
              child: SingleChildScrollView(
                child: visible.isEmpty
                    ? Text(
                        state.cases.isEmpty
                            ? Strings.noCasesDetail
                            : Strings.noClientMatch,
                        style: theme.typography.body.sm.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      )
                    : FTileGroup(
                        style: const .delta(
                          dividerWidth: AppSizes.dividerWidth,
                        ),
                        divider: .indented,
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
                              suffix: state.hiding == c.id
                                  ? const FCircularProgress(size: .sm)
                                  : FTooltip(
                                      tipBuilder: (_, _) =>
                                          const Text(Strings.hideCase),
                                      child: FButton.icon(
                                        variant: .ghost,
                                        size: .xs,
                                        onPress: state.hiding == null
                                            ? () => _hide(state, c.id)
                                            : null,
                                        child: const Icon(FLucideIcons.eyeOff),
                                      ),
                                    ),
                              onPress: () => state.select(c.id),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
