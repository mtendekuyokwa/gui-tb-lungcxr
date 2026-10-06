import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';
import 'package:gui_lungcxr/feature_home/utils/adjustment_text.dart';

/// Floating slider for the active adjustment tool.
class AdjustmentPanel extends StatelessWidget {
  const new({required this.editor, super.key});

  final ImageEditorState editor;

  @override
  Widget build(BuildContext context) {
    final tool = editor.tool;
    final value = editor.adjustment(tool);
    final typography = context.theme.typography;

    return SizedBox(
      width: AppSizes.adjustmentPanelWidth,
      child: FCard(
        child: Padding(
          padding: const .fromLTRB(
            AppSizes.gap16,
            AppSizes.gap12,
            AppSizes.gap8,
            AppSizes.gap4,
          ),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              Row(
                children: [
                  Text(
                    adjustmentLabel(tool),
                    style: typography.body.sm.copyWith(fontWeight: .w600),
                  ),
                  const Spacer(),
                  Text(
                    formatAdjustment(tool, value),
                    style: typography.body.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                      fontFeatures: const [.tabularFigures()],
                    ),
                  ),
                  FTooltip(
                    tipBuilder: (_, _) => const Text(Strings.reset),
                    child: FButton.icon(
                      variant: .ghost,
                      size: .sm,
                      onPress: value == 0
                          ? null
                          : () => editor.resetAdjustment(tool),
                      child: const Icon(FLucideIcons.rotateCcw),
                    ),
                  ),
                ],
              ),
              FSlider(
                // Managed sliders only read `initial` once, so rebuild on
                // tool change or reset.
                key: ValueKey((tool, editor.resetCount)),
                control: .managedContinuous(
                  initial: FSliderValue(max: adjustmentToSlider(value)),
                  onChange: (v) =>
                      editor.setAdjustment(tool, sliderToAdjustment(v.max)),
                ),
                tooltipBuilder: (_, v) =>
                    Text(formatAdjustment(tool, sliderToAdjustment(v))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
