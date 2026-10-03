import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:gui_lungcxr/feature_home/state/case_state.dart';
import 'package:gui_lungcxr/feature_home/widgets/patient_avatar.dart';
import 'package:provider/provider.dart';

/// Bar above the canvas: whose X-ray is on screen, the case status, and the
/// signed-in doctor.
class CanvasHeader extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final cases = context.watch<CaseState>();
    final patient = cases.selected!;
    final session = context.watch<SessionState>();
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
            PatientAvatar(initials: patient.initials, size: 36),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                mainAxisSize: .min,
                spacing: 2,
                children: [
                  Text(
                    patient.patientName,
                    overflow: .ellipsis,
                    style: theme.typography.body.md.copyWith(fontWeight: .w600),
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: '${Strings.clientId}  '),
                        TextSpan(
                          text: patient.displayId,
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
            FBadge(
              variant: switch (patient.status) {
                CaseStatus.returned => .destructive,
                CaseStatus.submitted || CaseStatus.accepted => .secondary,
                _ => .outline,
              },
              child: Text(patient.status.label),
            ),
            Text(session.user?.fullName ?? '', style: muted),
            FTooltip(
              tipBuilder: (_, _) => const Text(Strings.refresh),
              child: FButton.icon(
                variant: .ghost,
                size: .sm,
                onPress: cases.load,
                child: const Icon(FLucideIcons.refreshCw),
              ),
            ),
            FTooltip(
              tipBuilder: (_, _) => const Text(Strings.signOut),
              child: FButton.icon(
                variant: .ghost,
                size: .sm,
                onPress: session.logout,
                child: const Icon(FLucideIcons.logOut),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
