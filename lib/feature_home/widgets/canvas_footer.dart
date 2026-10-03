import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:gui_lungcxr/feature_home/state/case_state.dart';
import 'package:provider/provider.dart';

/// Bar under the canvas: the model's reading and the XAI toggle.
class CanvasFooter extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final prediction = context.select<CaseState, Prediction?>(
      (s) => s.selected?.prediction,
    );
    final percent = ((prediction?.tbProbability ?? 0) * 100).round();
    final isTb = prediction?.label == 'tb';
    final result = switch (prediction?.state) {
      'done' when isTb => '${Strings.modelTb} · $percent%',
      'done' => '${Strings.modelNormal} · TB $percent%',
      'failed' => Strings.modelFailed,
      _ => Strings.awaitingModel,
    };
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
                    Strings.modelReading,
                    style: theme.typography.body.sm.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                  Flexible(
                    child: FBadge(
                      variant: switch (prediction?.state) {
                        'done' when isTb => .destructive,
                        'done' => .secondary,
                        _ => .outline,
                      },
                      child: Text(result, overflow: .ellipsis),
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
