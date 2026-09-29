import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/models/mark.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';
import 'package:gui_lungcxr/feature_home/state/patient_state.dart';
import 'package:gui_lungcxr/feature_home/widgets/PaintBoard_wid.dart';
import 'package:gui_lungcxr/feature_home/widgets/adjustment_panel.dart';
import 'package:gui_lungcxr/feature_home/widgets/lesion_label_panel.dart';
import 'package:gui_lungcxr/feature_home/widgets/xray_image.dart';
import 'package:provider/provider.dart';

/// X-ray viewer: zoomable image with colour adjustments and a mark layer.
class CanvasWid extends StatelessWidget {
  const new({super.key});

  // Radiology viewers use a dark surround regardless of app theme.
  static const _background = Color(0xFF0B0D0E);

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<ImageEditorState>();
    final patient = context.select<PatientState, String>(
      (s) => s.selected.imageUrl,
    );

    return ClipRect(
      child: ColoredBox(
        color: _background,
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
                    boundaryMargin: const .all(200),
                    // Dragging draws in mark mode; wheel/pinch zoom still work.
                    panEnabled: editor.tool != .mark,
                    child: Center(
                      child: Padding(
                        padding: const .all(24),
                        child: XrayImage(
                          url: patient,
                          overlay: _MarkLayer(editor: editor),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
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
                          child: const Text(Strings.markHint),
                        ),
                      const Spacer(),
                      _ViewerToolbar(
                        editor: editor,
                        viewportCenter: viewportCenter,
                      ),
                    ],
                  ),
                ),
                if (editor.xaiEnabled)
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: FBadge(
                      variant: .secondary,
                      child: const Text(Strings.xaiPending),
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

class _ViewerToolbar extends StatelessWidget {
  const new({required this.editor, required this.viewportCenter});

  final ImageEditorState editor;
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

    return Wrap(
      spacing: 6,
      children: [
        button(
          FLucideIcons.zoomOut,
          Strings.Zoomout,
          () => editor.zoom(1 / 1.25, viewportCenter),
        ),
        button(
          FLucideIcons.zoomIn,
          Strings.ZoomIn,
          () => editor.zoom(1.25, viewportCenter),
        ),
        button(FLucideIcons.maximize, Strings.fitToScreen, editor.resetZoom),
        button(
          FLucideIcons.undo2,
          Strings.undo,
          editor.hasMarks ? editor.undoStroke : null,
        ),
        button(
          FLucideIcons.eraser,
          Strings.clearMarks,
          editor.hasMarks ? editor.clearMarks : null,
        ),
      ],
    );
  }
}

/// Captures pointer input in mark mode, paints existing marks and shows a
/// tappable label tag on each one.
///
/// Uses a raw [Listener] rather than a gesture detector so drawing never
/// competes with [InteractiveViewer]'s gesture recognisers.
class _MarkLayer extends StatefulWidget {
  const new({required this.editor});

  final ImageEditorState editor;

  @override
  State<_MarkLayer> createState() => _MarkLayerState();
}

class _MarkLayerState extends State<_MarkLayer> {
  int? _pointer;

  Offset _normalize(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0, 1),
    (local.dy / size.height).clamp(0, 1),
  );

  @override
  Widget build(BuildContext context) {
    final editor = widget.editor;
    final marking = editor.tool == .mark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Stack(
          clipBehavior: .none,
          children: [
            Positioned.fill(
              child: MouseRegion(
                cursor: marking
                    ? SystemMouseCursors.precise
                    : MouseCursor.defer,
                child: Listener(
                  behavior: .opaque,
                  onPointerDown: (e) {
                    if (!marking || _pointer != null) return;
                    _pointer = e.pointer;
                    editor.startStroke(_normalize(e.localPosition, size));
                  },
                  onPointerMove: (e) {
                    if (e.pointer != _pointer) return;
                    editor.extendStroke(_normalize(e.localPosition, size));
                  },
                  onPointerUp: (e) => _end(e.pointer),
                  onPointerCancel: (e) => _end(e.pointer),
                  child: CustomPaint(
                    size: size,
                    painter: PaintboardWid(
                      marks: editor.marks,
                      revision: editor.markRevision,
                      activeMark: editor.activeMark,
                      colorOf: (mark) => markColor(mark.lesion),
                    ),
                  ),
                ),
              ),
            ),
            // Tags only once a stroke is finished, so they don't jump around
            // under the pointer while drawing.
            if (_pointer == null)
              for (final (i, mark) in editor.marks.indexed)
                Positioned(
                  left: mark.anchor.dx * size.width,
                  top: mark.anchor.dy * size.height,
                  child: FractionalTranslation(
                    // Centred horizontally, sitting just above the mark.
                    translation: const Offset(-0.5, -1.25),
                    child: _MarkTag(
                      mark: mark,
                      active: i == editor.activeMark,
                      onTap: () => editor.selectMark(i),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  void _end(int pointer) {
    if (pointer != _pointer) return;
    setState(() => _pointer = null);
    widget.editor.endStroke();
  }
}

class _MarkTag extends StatelessWidget {
  const new({required this.mark, required this.active, required this.onTap});

  final Mark mark;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = markColor(mark.lesion);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: active ? color : Colors.black.withValues(alpha: 0.7),
            border: .all(color: color),
            borderRadius: .circular(4),
          ),
          child: Padding(
            padding: const .symmetric(horizontal: 6, vertical: 2),
            child: Text(
              mark.lesion?.label ?? Strings.unlabelled,
              style: context.theme.typography.body.xs.copyWith(
                color: active ? Colors.black : color,
                fontWeight: .w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
