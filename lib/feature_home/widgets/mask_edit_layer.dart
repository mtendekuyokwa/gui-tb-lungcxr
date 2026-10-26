import 'package:flutter/material.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';
import 'package:gui_lungcxr/feature_home/utils/mark_style.dart';

/// Captures pointer input in segment mode and forwards strokes to the
/// editor's mask corrections. Painted output lives in the mask layer itself;
/// this widget only listens.
///
/// Uses a raw [Listener] like [MarkLayer] so drawing never competes with
/// [InteractiveViewer]'s gesture recognisers.
class MaskEditLayer extends StatefulWidget {
  const new({required this.editor, required this.maskAvailable, super.key});

  final ImageEditorState editor;

  /// False while the model hasn't made a mask: strokes would have nothing
  /// to correct, so input is ignored.
  final bool maskAvailable;

  @override
  State<MaskEditLayer> createState() => _MaskEditLayerState();
}

class _MaskEditLayerState extends State<MaskEditLayer> {
  int? _pointer;

  @override
  Widget build(BuildContext context) {
    final editor = widget.editor;
    final editing =
        editor.tool == .segment &&
        !editor.locked &&
        editor.segmentationEnabled &&
        widget.maskAvailable;
    // While another tool is active this layer must not intercept pointer
    // input: it sits above the mark layer, and even an idle listener up
    // there stops strokes from reaching the marks below.
    if (!editing) return const SizedBox.expand();
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return MouseRegion(
          cursor: SystemMouseCursors.precise,
          child: Listener(
            behavior: .translucent,
            onPointerDown: (e) {
              if (_pointer != null) return;
              _pointer = e.pointer;
              editor.startMaskStroke(toImageRelative(e.localPosition, size));
            },
            onPointerMove: (e) {
              if (e.pointer != _pointer) return;
              editor.extendMaskStroke(toImageRelative(e.localPosition, size));
            },
            onPointerUp: (e) => _end(e.pointer),
            onPointerCancel: (e) => _end(e.pointer),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }

  void _end(int pointer) {
    if (pointer != _pointer) return;
    setState(() => _pointer = null);
    widget.editor.endMaskStroke();
  }
}
