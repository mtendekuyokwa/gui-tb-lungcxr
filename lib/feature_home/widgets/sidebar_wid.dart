import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';
import 'package:gui_lungcxr/widgets/app_brand.dart';
import 'package:provider/provider.dart';

/// Left rail: the canvas tools, the image adjustments and their reset.
class SidebarWid extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<ImageEditorState>();

    FSidebarItem toolItem(EditorTool tool, IconData icon, String label) =>
        FSidebarItem(
          icon: Icon(icon),
          label: Text(label),
          selected: editor.tool == tool,
          onPress: () => editor.selectTool(tool),
        );

    return FSidebar(
      style: const .delta(
        headerPadding: .value(.fromLTRB(0, AppSizes.gap16, 0, 0)),
      ),
      header: const Padding(
        padding: .symmetric(horizontal: AppSizes.gap16),
        child: Align(alignment: .centerLeft, child: AppBrand()),
      ),
      footer: Padding(
        padding: const .symmetric(horizontal: AppSizes.gap16),
        child: FButton(
          variant: .outline,
          onPress: editor.hasAdjustments ? editor.resetAdjustments : null,
          prefix: const Icon(FLucideIcons.rotateCcw),
          child: const Flexible(
            child: Text(Strings.resetAdjustments, overflow: .ellipsis),
          ),
        ),
      ),
      children: [
        FSidebarGroup(
          label: const Text(Strings.Tools),
          children: [
            toolItem(.pan, FLucideIcons.hand, Strings.pan),
            toolItem(.mark, FLucideIcons.pen, Strings.mark),
            FSidebarItem(
              icon: const Icon(FLucideIcons.spline),
              label: const Text(Strings.Segmentation),
              // Segmentation lives on the backend; not wired up yet.
              onPress: () => showFToast(
                context: context,
                icon: const Icon(FLucideIcons.spline),
                title: const Text(Strings.segmentationComingSoon),
                description: const Text(Strings.segmentationComingSoonDetail),
              ),
            ),
          ],
        ),
        FSidebarGroup(
          label: const Text(Strings.adjust),
          children: [
            toolItem(.brightness, FLucideIcons.flame, Strings.Brightness),
            toolItem(.contrast, FLucideIcons.contrast, Strings.Contrast),
            toolItem(.hue, FLucideIcons.blend, Strings.Hue),
            toolItem(.saturation, FLucideIcons.spotlight, Strings.Saturation),
          ],
        ),
      ],
    );
  }
}
