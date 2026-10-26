import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/case_state.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';
import 'package:provider/provider.dart';

/// Horizontal tool strip for narrow screens: the same tools as [SidebarWid]
/// in a scrollable row under the canvas header.
class ToolStrip extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<ImageEditorState>();
    final hasMask = context.select<CaseState, bool>(
      (s) => s.selected?.prediction?.hasMask ?? false,
    );

    // Plain labels, not Flexible ones: this row scrolls horizontally, so
    // its width is unbounded and flex children are illegal. The scroll
    // handles long labels instead of ellipsis.
    Widget tool(EditorTool tool, IconData icon, String label) => FButton(
      variant: editor.tool == tool ? .secondary : .ghost,
      size: .sm,
      onPress: () => editor.selectTool(tool),
      prefix: Icon(icon),
      child: Text(label),
    );

    return SingleChildScrollView(
      scrollDirection: .horizontal,
      padding: const .symmetric(
        horizontal: AppSizes.gap8,
        vertical: AppSizes.gap6,
      ),
      child: Row(
        spacing: AppSizes.gap6,
        children: [
          tool(.pan, FLucideIcons.hand, Strings.pan),
          tool(.mark, FLucideIcons.pen, Strings.mark),
          FButton(
            variant: editor.tool == .segment ? .secondary : .ghost,
            size: .sm,
            // Same rule as the sidebar: without a model mask there is
            // nothing to correct yet.
            onPress: hasMask
                ? () => editor.selectTool(.segment)
                : () => showFToast(
                    context: context,
                    icon: const Icon(FLucideIcons.spline),
                    title: const Text(Strings.segAwaitingModel),
                    description: const Text(Strings.segUnavailable),
                  ),
            prefix: const Icon(FLucideIcons.spline),
            child: const Text(Strings.Segmentation),
          ),
          tool(.brightness, FLucideIcons.flame, Strings.Brightness),
          tool(.contrast, FLucideIcons.contrast, Strings.Contrast),
          tool(.hue, FLucideIcons.blend, Strings.Hue),
          tool(.saturation, FLucideIcons.spotlight, Strings.Saturation),
        ],
      ),
    );
  }
}
