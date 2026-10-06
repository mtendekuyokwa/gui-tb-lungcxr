import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';

/// Floating zoom and mark-editing buttons in the canvas's top-right corner.
class ViewerToolbar extends StatelessWidget {
  const new({required this.editor, required this.viewportCenter, super.key});

  final ImageEditorState editor;

  /// The point the zoom buttons zoom around.
  final Offset viewportCenter;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String tip, VoidCallback? onPress) => FTooltip(
      tipBuilder: (_, _) => Text(tip),
      child: FButton.icon(
        variant: .secondary,
        onPress: onPress,
        child: Icon(icon),
      ),
    );
    final canEditMarks = editor.hasMarks && !editor.locked;

    return Wrap(
      spacing: AppSizes.gap6,
      children: [
        button(
          FLucideIcons.zoomOut,
          Strings.Zoomout,
          () => editor.zoomOut(viewportCenter),
        ),
        button(
          FLucideIcons.zoomIn,
          Strings.ZoomIn,
          () => editor.zoomIn(viewportCenter),
        ),
        button(FLucideIcons.maximize, Strings.fitToScreen, editor.resetZoom),
        button(
          FLucideIcons.undo2,
          Strings.undo,
          canEditMarks ? editor.undoStroke : null,
        ),
        button(
          FLucideIcons.eraser,
          Strings.clearMarks,
          canEditMarks ? editor.clearMarks : null,
        ),
      ],
    );
  }
}
