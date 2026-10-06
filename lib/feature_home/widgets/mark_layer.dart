import 'package:flutter/material.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';
import 'package:gui_lungcxr/feature_home/utils/mark_style.dart';
import 'package:gui_lungcxr/feature_home/widgets/PaintBoard_wid.dart';
import 'package:gui_lungcxr/feature_home/widgets/mark_tag.dart';

/// Captures pointer input in mark mode, paints existing marks and shows a
/// tappable label tag on each one.
///
/// Uses a raw [Listener] rather than a gesture detector so drawing never
/// competes with [InteractiveViewer]'s gesture recognisers.
class MarkLayer extends StatefulWidget {
  const new({required this.editor, super.key});

  final ImageEditorState editor;

  @override
  State<MarkLayer> createState() => _MarkLayerState();
}

class _MarkLayerState extends State<MarkLayer> {
  // Centres a tag horizontally on its mark's anchor, sitting just above it.
  static const _tagTranslation = Offset(-0.5, -1.25);

  int? _pointer;

  @override
  Widget build(BuildContext context) {
    final editor = widget.editor;
    final marking = editor.tool == .mark && !editor.locked;
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
                    editor.startStroke(toImageRelative(e.localPosition, size));
                  },
                  onPointerMove: (e) {
                    if (e.pointer != _pointer) return;
                    editor.extendStroke(toImageRelative(e.localPosition, size));
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
                    translation: _tagTranslation,
                    child: MarkTag(
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
