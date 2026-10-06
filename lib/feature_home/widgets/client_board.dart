import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/case_state.dart';
import 'package:gui_lungcxr/feature_home/utils/case_text.dart';
import 'package:gui_lungcxr/feature_home/widgets/patient_avatar.dart';
import 'package:provider/provider.dart';

/// The cases assigned to the signed-in doctor.
class ClientBoard extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CaseState>();
    final selectedId = state.selected?.id;

    return Padding(
      padding: const .all(AppSizes.gap8),
      child: FTileGroup(
        style: const .delta(dividerWidth: AppSizes.dividerWidth),
        divider: .indented,
        label: const Text(Strings.Patient),
        children: [
          for (final c in state.cases)
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
    );
  }
}
