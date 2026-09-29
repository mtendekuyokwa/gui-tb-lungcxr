import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/patient_state.dart';
import 'package:gui_lungcxr/feature_home/widgets/patient_avatar.dart';
import 'package:provider/provider.dart';

/// Bar above the canvas identifying whose X-ray is on screen.
class CanvasHeader extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<PatientState>().selected;
    final theme = context.theme;
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.background,
        border: Border(bottom: BorderSide(color: theme.colors.border)),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 16, vertical: 10),
        child: Row(
          spacing: 12,
          children: [
            PatientAvatar(patient: patient, size: 36),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                mainAxisSize: .min,
                spacing: 2,
                children: [
                  Text(
                    patient.name,
                    overflow: .ellipsis,
                    style: theme.typography.body.md.copyWith(fontWeight: .w600),
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: '${Strings.clientId}  '),
                        TextSpan(
                          text: patient.id,
                          style: TextStyle(
                            color: theme.colors.foreground,
                            fontFeatures: const [.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    style: muted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
