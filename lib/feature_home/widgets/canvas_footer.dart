import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';
import 'package:gui_lungcxr/feature_home/state/patient_state.dart';
import 'package:provider/provider.dart';

/// Bar under the canvas: patient identity, model result and XAI toggle.
class CanvasFooter extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<PatientState>().selected;
    final editor = context.watch<ImageEditorState>();
    final colors = context.theme.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 16, vertical: 12),
        child: Row(
          spacing: 12,
          children: [
            Expanded(
              child: _Field(
                icon: FLucideIcons.idCard,
                label: Strings.clientId,
                child: Text(patient.id),
              ),
            ),
            Expanded(
              flex: 2,
              child: _Field(
                icon: FLucideIcons.user,
                label: Strings.name,
                child: Text(patient.name, overflow: .ellipsis),
              ),
            ),
            Expanded(
              child: _Field(
                icon: FLucideIcons.activity,
                label: Strings.result,
                child: Align(
                  alignment: .centerLeft,
                  child: FBadge(
                    variant: switch (patient.result) {
                      null => .outline,
                      'Positive' => .destructive,
                      _ => .secondary,
                    },
                    child: Text(patient.result ?? Strings.awaitingModel),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: _Field(
                icon: FLucideIcons.sparkles,
                label: 'XAI',
                child: FSwitch(
                  label: const Text(Strings.activateXai),
                  value: editor.xaiEnabled,
                  onChange: editor.setXai,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const new({required this.icon, required this.label, required this.child});

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return FCard(
      child: Padding(
        padding: const .symmetric(horizontal: 12, vertical: 8),
        child: Row(
          spacing: 10,
          children: [
            Icon(icon, size: 18, color: theme.colors.mutedForeground),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                mainAxisSize: .min,
                spacing: 2,
                children: [
                  Text(
                    label,
                    style: theme.typography.body.xs.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                  DefaultTextStyle.merge(
                    style: theme.typography.body.sm.copyWith(fontWeight: .w600),
                    child: child,
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
