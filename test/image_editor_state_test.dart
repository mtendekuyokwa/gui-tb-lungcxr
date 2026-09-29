import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';

void main() {
  late ImageEditorState editor;
  setUp(() => editor = ImageEditorState());
  tearDown(() => editor.dispose());

  test('selecting the active tool toggles back to pan', () {
    editor.selectTool(.mark);
    expect(editor.tool, EditorTool.mark);
    editor.selectTool(.mark);
    expect(editor.tool, EditorTool.pan);
  });

  test('adjustments clamp and reset', () {
    editor.setAdjustment(.contrast, 3);
    expect(editor.adjustment(.contrast), 1);
    expect(editor.hasAdjustments, isTrue);

    final resets = editor.resetCount;
    editor.resetAdjustments();
    expect(editor.hasAdjustments, isFalse);
    expect(editor.resetCount, resets + 1);
  });

  test('strokes record, undo and clear', () {
    editor
      ..startStroke(const Offset(0.1, 0.1))
      ..extendStroke(const Offset(0.2, 0.2))
      ..endStroke()
      // Moves after the stroke ended are ignored.
      ..extendStroke(const Offset(0.9, 0.9))
      ..startStroke(const Offset(0.5, 0.5))
      ..endStroke();
    expect(editor.strokes, hasLength(2));
    expect(editor.strokes.first, hasLength(2));

    editor.undoStroke();
    expect(editor.strokes, hasLength(1));
    editor.clearMarks();
    expect(editor.hasMarks, isFalse);
  });

  test('zoom clamps to the allowed scale range', () {
    editor.zoom(100, Offset.zero);
    expect(
      editor.transform.value.getMaxScaleOnAxis(),
      ImageEditorState.maxScale,
    );
    editor.resetZoom();
    expect(editor.transform.value.getMaxScaleOnAxis(), 1);
  });
}
