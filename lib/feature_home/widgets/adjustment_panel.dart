import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';

/// Floating slider for the active adjustment tool.
class AdjustmentPanel extends StatelessWidget {
  const new({required this.editor, super.key});

  final ImageEditorState editor;

  static String _label(EditorTool tool) => switch (tool) {
    .brightness => Strings.Brightness,
    .contrast => Strings.Contrast,
    .hue => Strings.Hue,
    .saturation => Strings.Saturation,
    .pan || .mark => '',
  };

  /// Displays a -1..1 value as -100..100 (hue as degrees).
  static String _format(EditorTool tool, double value) {
    final shown = tool == .hue ? value * 180 : value * 100;
    final rounded = shown.round();
    final suffix = tool == .hue ? '°' : '';
    return '${rounded > 0 ? '+' : ''}$rounded$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final tool = editor.tool;
    final value = editor.adjustment(tool);
    final typography = context.theme.typography;

    return SizedBox(
      width: 320,
      child: FCard(
        child: Padding(
          padding: const .fromLTRB(16, 12, 8, 4),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              Row(
                children: [
                  Text(
                    _label(tool),
                    style: typography.body.sm.copyWith(fontWeight: .w600),
                  ),
                  const Spacer(),
                  Text(
                    _format(tool, value),
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
                  initial: FSliderValue(max: (value + 1) / 2),
                  onChange: (v) => editor.setAdjustment(tool, v.max * 2 - 1),
                ),
                tooltipBuilder: (_, v) => Text(_format(tool, v * 2 - 1)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
