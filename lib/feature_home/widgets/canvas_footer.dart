import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';
import 'package:gui_lungcxr/feature_home/state/patient_state.dart';
import 'package:provider/provider.dart';

/// Bar under the canvas: the model's result and the XAI toggle.
class CanvasFooter extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final result = context.select<PatientState, String?>(
      (s) => s.selected.result,
    );
    final editor = context.watch<ImageEditorState>();
    final theme = context.theme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.background,
        border: Border(top: BorderSide(color: theme.colors.border)),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 16, vertical: 10),
        child: Row(
          spacing: 10,
          children: [
            Expanded(
              child: Row(
                spacing: 10,
                children: [
                  Text(
                    Strings.result,
                    style: theme.typography.body.sm.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                  Flexible(
                    child: FBadge(
                      variant: switch (result) {
                        null => .outline,
                        'Positive' => .destructive,
                        _ => .secondary,
                      },
                      child: Text(
                        result ?? Strings.awaitingModel,
                        overflow: .ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // FSwitch's own label gets squeezed to zero width after a Spacer,
            // so the label sits beside it and toggles it too.
            GestureDetector(
              onTap: () => editor.setXai(!editor.xaiEnabled),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  Strings.activateXai,
                  style: theme.typography.body.sm.copyWith(fontWeight: .w500),
                ),
              ),
            ),
            FSwitch(
              semanticsLabel: Strings.activateXai,
              value: editor.xaiEnabled,
              onChange: editor.setXai,
            ),
          ],
        ),
      ),
    );
  }
}
