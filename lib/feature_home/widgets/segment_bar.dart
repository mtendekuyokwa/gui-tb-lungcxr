import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/case_state.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';
import 'package:gui_lungcxr/feature_home/state/review_state.dart';
import 'package:gui_lungcxr/feature_home/utils/case_text.dart';
import 'package:gui_lungcxr/widgets/busy_icon.dart';
import 'package:provider/provider.dart';

/// The segment tool's controls as a strip docked above the canvas (never
/// over the X-ray): brush / pen / eraser, stroke width, undo, reset to the
/// model mask, and sending the corrected mask back to the model. Takes no
/// space while another tool is active.
class SegmentBar extends StatelessWidget {
  const new({super.key});

  Future<void> _reevaluate(BuildContext context, ReviewState review) async {
    final ok = await review.reevaluate();
    if (!context.mounted) return;
    // With the models present the reading comes back in the same request;
    // otherwise the worker answers later and the footer updates by itself.
    final prediction = review.detail?.prediction;
    final answered = ok && prediction != null && prediction.state != 'queued';
    showFToast(
      context: context,
      icon: Icon(ok ? FLucideIcons.refreshCw : FLucideIcons.circleAlert),
      title: Text(
        !ok
            ? Strings.reevaluateFailed
            : answered
            ? Strings.reevaluated
            : Strings.reevaluateSent,
      ),
      description: Text(
        !ok
            ? review.error ?? ''
            : answered
            ? modelReading(prediction)
            : Strings.reevaluateSentDetail,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<ImageEditorState>();
    if (editor.tool != .segment) return const SizedBox.shrink();
    final review = context.watch<ReviewState>();
    final prediction = context.select<CaseState, (bool, bool)>(
      (s) => (
        s.selected?.prediction?.hasMask ?? false,
        s.selected?.prediction?.state == 'queued',
      ),
    );
    final (hasMask, modelReading) = prediction;
    final theme = context.theme;
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    final subtool = editor.segmentSubtool;
    final canEdit = editor.hasMaskEdits && !editor.locked;
    final canSend = review.canReevaluate && hasMask && !modelReading;

    Widget subtoolButton(SegmentSubtool value, IconData icon, String tip) =>
        FTooltip(
          tipBuilder: (_, _) => Text(tip),
          child: FButton.icon(
            variant: subtool == value ? .primary : .ghost,
            size: .sm,
            onPress: editor.locked
                ? null
                : () => editor.selectSegmentSubtool(value),
            child: Icon(icon),
          ),
        );

    Widget divider() => Container(
      width: AppSizes.dividerWidth,
      height: AppSizes.icon24,
      color: theme.colors.border,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.background,
        border: Border(bottom: BorderSide(color: theme.colors.border)),
      ),
      child: Row(
        children: [
          // Wraps onto a second row when narrow, so every control stays
          // visible instead of scrolling off the edge.
          Expanded(
            child: Padding(
              padding: const .symmetric(
                horizontal: AppSizes.gap8,
                vertical: AppSizes.gap6,
              ),
              child: Wrap(
                spacing: AppSizes.gap6,
                runSpacing: AppSizes.gap6,
                crossAxisAlignment: .center,
                children: [
                  // Groups stay together when the bar wraps.
                  Row(
                    mainAxisSize: .min,
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
                      divider(),
                    ],
                  ),
                  Row(
                    mainAxisSize: .min,
                    spacing: AppSizes.gap6,
                    children: [
                      Text(Strings.segmentWidth, style: muted),
                      SizedBox(
                        width: AppSizes.segmentSliderWidth,
                        child: FSlider(
                          key: ValueKey(subtool),
                          control: .managedContinuous(
                            initial: FSliderValue(
                              max: _toSlider(editor.maskWidth),
                            ),
                            onChange: (v) =>
                                editor.setMaskWidth(_toWidth(v.max)),
                          ),
                        ),
                      ),
                      Text(
                        '${(editor.maskWidth * 100).round()}%',
                        style: muted.copyWith(
                          fontFeatures: const [.tabularFigures()],
                        ),
                      ),
                      divider(),
                    ],
                  ),
                  Row(
                    mainAxisSize: .min,
                    spacing: AppSizes.gap6,
                    children: [
                      FTooltip(
                        tipBuilder: (_, _) => const Text(Strings.undo),
                        child: FButton.icon(
                          variant: .ghost,
                          size: .sm,
                          onPress: canEdit ? editor.undoMaskEdit : null,
                          child: const Icon(FLucideIcons.undo2),
                        ),
                      ),
                      FTooltip(
                        tipBuilder: (_, _) =>
                            const Text(Strings.resetSegmentEdits),
                        child: FButton.icon(
                          variant: .ghost,
                          size: .sm,
                          onPress: canEdit ? editor.clearMaskEdits : null,
                          child: const Icon(FLucideIcons.rotateCcw),
                        ),
                      ),
                    ],
                  ),
                  FTooltip(
                    tipBuilder: (_, _) => const Text(Strings.reevaluateTip),
                    child: FButton(
                      size: .sm,
                      mainAxisSize: .min,
                      onPress: canSend
                          ? () => _reevaluate(context, review)
                          : null,
                      prefix: BusyIcon(
                        busy: review.reevaluating || modelReading,
                        icon: FLucideIcons.refreshCw,
                      ),
                      child: Text(
                        modelReading
                            ? Strings.modelReadingNow
                            : Strings.reevaluate,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          FTooltip(
            tipBuilder: (_, _) => const Text(Strings.close),
            child: FButton.icon(
              variant: .ghost,
              size: .sm,
              // Back to pan; the mask stays visible until its switch hides
              // it, so closing never loses the corrections.
              onPress: () => editor.selectTool(.segment),
              child: const Icon(FLucideIcons.x),
            ),
          ),
          const SizedBox(width: AppSizes.gap8),
        ],
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
