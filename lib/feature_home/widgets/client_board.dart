import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/patient_state.dart';
import 'package:provider/provider.dart';

class ClientBoard extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PatientState>();
    final selectedId = state.selected.id;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FTileGroup(
        style: const .delta(dividerWidth: 1),
        divider: .indented,
        label: const Text(Strings.Patient),
        children: [
          for (final patient in state.patients)
            .tile(
              prefix: const Icon(FLucideIcons.user),
              title: Text(patient.name),
              subtitle: Text(patient.id),
              selected: patient.id == selectedId,
              suffix: patient.id == selectedId
                  ? const Icon(FLucideIcons.check)
                  : null,
              onPress: () => state.select(patient.id),
            ),
        ],
      ),
    );
  }
}
