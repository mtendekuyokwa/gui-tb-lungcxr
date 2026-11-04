import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:gui_lungcxr/feature_home/state/case_state.dart';
import 'package:gui_lungcxr/feature_home/utils/case_text.dart';
import 'package:provider/provider.dart';

/// Bar under the canvas: the model's reading and the XAI toggle.
class CanvasFooter extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final prediction = context.select<CaseState, Prediction?>(
      (s) => s.selected?.prediction,
    );
    final isTb = prediction?.label == 'tb';
    final hasMask = prediction?.hasMask ?? false;
    final editor = context.watch<ImageEditorState>();
    final theme = context.theme;

    Widget layerSwitch(
      String label,
      bool value,
      ValueChanged<bool> onChange, {
      bool enabled = true,
      bool showLabel = true,
    }) => Row(
      spacing: AppSizes.gap6,
      children: [
        // FSwitch's own label gets squeezed to zero width after a
        // Spacer, so the label sits beside it and toggles it too.
        // On narrow screens the label hides and the switch's
        // semantics label speaks for it.
        if (showLabel)
          GestureDetector(
            onTap: enabled ? () => onChange(!value) : null,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                label,
                style: theme.typography.body.sm.copyWith(fontWeight: .w500),
              ),
            ),
          ),
        FSwitch(
          semanticsLabel: label,
          value: value,
          onChange: onChange,
          enabled: enabled,
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.background,
        border: Border(top: BorderSide(color: theme.colors.border)),
      ),
      child: Padding(
        padding: const .symmetric(
          horizontal: AppSizes.gap16,
          vertical: AppSizes.gap10,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= AppSizes.narrowBreakpoint;
            return Row(
              spacing: AppSizes.gap10,
              children: [
                Expanded(
                  child: Row(
                    spacing: AppSizes.gap10,
                    children: [
                      // The badge reading is self-explanatory; the caption
                      // only shows where there is room for it.
                      if (wide)
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
                          child: Text(
                            modelReading(prediction),
                            overflow: .ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // FSwitch's own label gets squeezed to zero width after a Spacer,
                // so the label sits beside it and toggles it too.
                layerSwitch(
                  Strings.Segmentation,
                  editor.segmentationEnabled,
                  editor.setSegmentation,
                  enabled: hasMask,
                  showLabel: wide,
                ),
                layerSwitch(
                  Strings.activateXai,
                  editor.xaiEnabled,
                  editor.setXai,
                  showLabel: wide,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
