import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';

/// Floating correction tools for the segment tool: brush, pen and eraser,
/// a stroke-width slider, undo and reset-to-model-mask.
class SegmentPanel extends StatelessWidget {
  const new({required this.editor, super.key});

  final ImageEditorState editor;

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.typography;
    final subtool = editor.segmentSubtool;
    final canEdit = editor.hasMaskEdits && !editor.locked;

    Widget subtoolButton(SegmentSubtool value, IconData icon, String tip) =>
        FTooltip(
          tipBuilder: (_, _) => Text(tip),
          child: FButton.icon(
            variant: subtool == value ? .primary : .outline,
            size: .sm,
            onPress: editor.locked
                ? null
                : () => editor.selectSegmentSubtool(value),
            child: Icon(icon),
          ),
        );

    return SizedBox(
      width: AppSizes.adjustmentPanelWidth,
      child: FCard(
        child: Padding(
          padding: const .fromLTRB(
            AppSizes.gap16,
            AppSizes.gap12,
            AppSizes.gap8,
            AppSizes.gap8,
          ),
          child: Column(
            crossAxisAlignment: .stretch,
            spacing: AppSizes.gap8,
            children: [
              Row(
                children: [
                  Text(
                    Strings.Segmentation,
                    style: typography.body.sm.copyWith(fontWeight: .w600),
                  ),
                  const Spacer(),
                  FTooltip(
                    tipBuilder: (_, _) => const Text(Strings.close),
                    child: FButton.icon(
                      variant: .ghost,
                      size: .sm,
                      // Back to pan; the overlay stays visible until its
                      // switch hides it, so closing never loses the mask.
                      onPress: () => editor.selectTool(.segment),
                      child: const Icon(FLucideIcons.x),
                    ),
                  ),
                ],
              ),
              Row(
                spacing: AppSizes.gap6,
                children: [
                  subtoolButton(
                    .brush,
                    FLucideIcons.brush,
                    Strings.segmentBrush,
                  ),
                  subtoolButton(.pen, FLucideIcons.pen, Strings.segmentPen),
                  subtoolButton(
                    .eraser,
                    FLucideIcons.eraser,
                    Strings.segmentEraser,
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    Strings.segmentWidth,
                    style: typography.body.sm.copyWith(fontWeight: .w600),
                  ),
                  const Spacer(),
                  Text(
                    '${(editor.maskWidth * 100).round()}%',
                    style: typography.body.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                      fontFeatures: const [.tabularFigures()],
                    ),
                  ),
                ],
              ),
              FSlider(
                key: ValueKey(subtool),
                control: .managedContinuous(
                  initial: FSliderValue(max: _toSlider(editor.maskWidth)),
                  onChange: (v) => editor.setMaskWidth(_toWidth(v.max)),
                ),
              ),
              Column(
                crossAxisAlignment: .stretch,
                spacing: AppSizes.gap6,
                children: [
                  FButton(
                    variant: .outline,
                    size: .sm,
                    onPress: canEdit ? editor.undoMaskEdit : null,
                    prefix: const Icon(FLucideIcons.undo2),
                    child: const Text(Strings.undo),
                  ),
                  FButton(
                    variant: .outline,
                    size: .sm,
                    onPress: canEdit ? editor.clearMaskEdits : null,
                    prefix: const Icon(FLucideIcons.rotateCcw),
                    child: const Flexible(
                      child: Text(
                        Strings.resetSegmentEdits,
                        overflow: .ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _toSlider(double width) =>
    (width - AppSizes.maskEditMinWidth) /
    (AppSizes.maskEditMaxWidth - AppSizes.maskEditMinWidth);

double _toWidth(double position) =>
    AppSizes.maskEditMinWidth +
    position * (AppSizes.maskEditMaxWidth - AppSizes.maskEditMinWidth);
