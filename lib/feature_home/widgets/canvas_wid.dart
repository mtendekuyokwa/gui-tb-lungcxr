import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_colors.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/case_state.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';
import 'package:gui_lungcxr/feature_home/widgets/adjustment_panel.dart';
import 'package:gui_lungcxr/feature_home/widgets/lesion_label_panel.dart';
import 'package:gui_lungcxr/feature_home/widgets/mark_layer.dart';
import 'package:gui_lungcxr/feature_home/widgets/viewer_toolbar.dart';
import 'package:gui_lungcxr/feature_home/widgets/xray_image.dart';
import 'package:provider/provider.dart';

/// X-ray viewer: zoomable image with colour adjustments and a mark layer.
class CanvasWid extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<ImageEditorState>();
    final cases = context.watch<CaseState>();
    final selected = cases.selected!;
    final hasHeatmap = selected.prediction?.hasOverlay ?? false;

    return ClipRect(
      child: ColoredBox(
        color: AppColors.xrayBackdrop,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportCenter = constraints.biggest.center(Offset.zero);
            return Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    transformationController: editor.transform,
                    minScale: ImageEditorState.minScale,
                    maxScale: ImageEditorState.maxScale,
                    boundaryMargin: const .all(AppSizes.canvasBoundaryMargin),
                    // Dragging draws in mark mode; wheel/pinch zoom still work.
                    panEnabled: editor.tool != .mark,
                    child: Center(
                      child: Padding(
                        padding: const .all(AppSizes.gap24),
                        child: XrayImage(
                          url: cases.imageUrl(selected.id),
                          headers: cases.imageHeaders,
                          heatmapUrl: editor.xaiEnabled && hasHeatmap
                              ? cases.overlayUrl(selected.id)
                              : null,
                          overlay: MarkLayer(editor: editor),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: AppSizes.gap12,
                  left: AppSizes.gap12,
                  right: AppSizes.gap12,
                  child: Row(
                    crossAxisAlignment: .start,
                    children: [
                      if (editor.activeMark case final index?)
                        LesionLabelPanel(
                          // Fresh panel state per mark.
                          key: ValueKey((index, editor.marks.length)),
                          editor: editor,
                        )
                      else if (editor.tool.isAdjustment)
                        AdjustmentPanel(editor: editor)
                      else if (editor.tool == .mark)
                        FBadge(
                          variant: .secondary,
                          child: Text(
                            editor.locked ? Strings.readOnly : Strings.markHint,
                          ),
                        ),
                      const Spacer(),
                      ViewerToolbar(
                        editor: editor,
                        viewportCenter: viewportCenter,
                      ),
                    ],
                  ),
                ),
                if (editor.xaiEnabled && !hasHeatmap)
                  Positioned(
                    left: AppSizes.gap12,
                    bottom: AppSizes.gap12,
                    child: FBadge(
                      variant: .secondary,
                      child: const Text(Strings.xaiUnavailable),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
