import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/feature_home/models/lesion.dart';
import 'package:gui_lungcxr/feature_home/models/mask_edit.dart';
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

  test('adjustments clamp and reset one at a time', () {
    editor.setAdjustment(.contrast, 3);
    expect(editor.adjustment(.contrast), 1);
    expect(editor.hasAdjustments, isTrue);

    final resets = editor.resetCount;
    editor.resetAdjustment(.contrast);
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
    expect(editor.marks, hasLength(2));
    expect(editor.marks.first.points, hasLength(2));

    editor.undoStroke();
    expect(editor.marks, hasLength(1));
    editor.clearMarks();
    expect(editor.hasMarks, isFalse);
  });

  test('finishing a stroke opens it for labelling', () {
    editor
      ..startStroke(const Offset(0.3, 0.6))
      ..extendStroke(const Offset(0.4, 0.2))
      ..endStroke();
    expect(editor.activeMark, 0);
    expect(editor.marks.single.anchor, const Offset(0.4, 0.2));

    editor.labelActiveMark(.cavity);
    expect(editor.marks.single.lesion, LesionType.cavity);
    expect(editor.activeMark, isNull);

    editor
      ..selectMark(0)
      ..labelActiveMark(.effusion);
    expect(editor.marks.single.lesion?.category, LesionCategory.pleural);

    editor
      ..selectMark(0)
      ..deleteMark(0);
    expect(editor.hasMarks, isFalse);
    expect(editor.activeMark, isNull);
  });

  test('a mark comment and finding are saved together, then closed', () {
    editor
      ..startStroke(const Offset(0.3, 0.6))
      ..extendStroke(const Offset(0.4, 0.2))
      ..endStroke();
    expect(editor.activeMark, 0);

    final revision = editor.markRevision;
    editor.setActiveMarkNote('Cavity, right upper zone');
    expect(editor.marks.single.note, 'Cavity, right upper zone');
    expect(
      editor.activeMark,
      0,
      reason: 'editing the note keeps the panel open',
    );
    expect(editor.markRevision, greaterThan(revision));

    editor.updateActiveMark(lesion: .cavity, note: 'Cavity RUL');
    expect(editor.marks.single.lesion, LesionType.cavity);
    expect(editor.marks.single.note, 'Cavity RUL');
    expect(editor.activeMark, isNull);

    // With no mark open both are no-ops.
    final settled = editor.markRevision;
    editor.setActiveMarkNote('ignored');
    editor.updateActiveMark(lesion: .nodule, note: 'ignored');
    expect(editor.markRevision, settled);
    expect(editor.marks.single.lesion, LesionType.cavity);
  });

  test('selecting a mark is not a change, labelling it is', () {
    editor
      ..startStroke(const Offset(0.3, 0.6))
      ..endStroke();
    editor.selectMark(null); // close the label panel
    final revision = editor.markRevision;

    editor.selectMark(0);
    expect(editor.activeMark, 0);
    expect(editor.markRevision, revision);
    editor.selectMark(null);
    expect(editor.markRevision, revision);

    editor
      ..selectMark(0)
      ..labelActiveMark(.cavity);
    expect(editor.markRevision, greaterThan(revision));
  });

  test('selecting segment shows the mask with it', () {
    expect(editor.segmentationEnabled, isFalse);
    editor.selectTool(.segment);
    expect(editor.tool, EditorTool.segment);
    expect(editor.segmentationEnabled, isTrue);
    editor.selectTool(.segment);
    expect(editor.tool, EditorTool.pan);
    // Leaving the tool keeps the overlay visible until the switch hides it.
    expect(editor.segmentationEnabled, isTrue);
    editor.setSegmentation(false);
    expect(editor.segmentationEnabled, isFalse);
  });

  test('mask strokes record kind, tool and width, then undo and clear', () {
    final revision = editor.maskRevision;
    editor
      ..startMaskStroke(const Offset(0.4, 0.4))
      ..extendMaskStroke(const Offset(0.45, 0.5))
      ..endMaskStroke();
    expect(editor.maskRevision, greaterThan(revision));
    expect(editor.hasMaskEdits, isTrue);
    expect(editor.hasEraseEdits, isFalse);
    final added = editor.maskEdits.single;
    expect(added.kind, MaskEditKind.add);
    expect(added.tool, MaskEditTool.brush);
    expect(added.width, AppSizes.maskBrushDefaultWidth);
    expect(added.points, hasLength(2));

    editor.selectSegmentSubtool(.eraser);
    editor
      ..startMaskStroke(const Offset(0.6, 0.6))
      ..endMaskStroke();
    expect(editor.maskEdits, hasLength(2));
    expect(editor.hasEraseEdits, isTrue);
    expect(editor.maskEdits.last.kind, MaskEditKind.erase);

    editor.selectSegmentSubtool(.pen);
    expect(editor.maskWidth, AppSizes.maskPenDefaultWidth);

    editor.undoMaskEdit();
    expect(editor.maskEdits, hasLength(1));
    editor.clearMaskEdits();
    expect(editor.hasMaskEdits, isFalse);
  });

  test('mask width clamps to the allowed range', () {
    editor.setMaskWidth(10);
    expect(editor.maskWidth, AppSizes.maskEditMaxWidth);
    editor.setMaskWidth(-10);
    expect(editor.maskWidth, AppSizes.maskEditMinWidth);
  });

  test('each segment subtool remembers its own width', () {
    editor.setMaskWidth(AppSizes.maskEditMaxWidth);
    editor.selectSegmentSubtool(.pen);
    expect(editor.maskWidth, AppSizes.maskPenDefaultWidth);
    editor.selectSegmentSubtool(.brush);
    expect(editor.maskWidth, AppSizes.maskEditMaxWidth);
  });

  test('a locked editor ignores mask strokes and edits', () {
    editor.locked = true;
    editor.startMaskStroke(Offset.zero);
    expect(editor.hasMaskEdits, isFalse);
    editor
      ..locked = false
      ..startMaskStroke(Offset.zero)
      ..endMaskStroke()
      ..locked = true;
    editor.undoMaskEdit();
    editor.clearMaskEdits();
    expect(editor.maskEdits, hasLength(1));
  });

  test('mask edits are replaced when a saved draft loads', () {
    editor
      ..startMaskStroke(const Offset(0.1, 0.1))
      ..endMaskStroke();
    editor.replaceMaskEdits(const []);
    expect(editor.hasMaskEdits, isFalse);
  });

  test('switching tools closes the label panel', () {
    editor
      ..selectTool(.mark)
      ..startStroke(Offset.zero)
      ..endStroke()
      ..selectTool(.contrast);
    expect(editor.activeMark, isNull);
  });

  test('every lesion category has at least one type', () {
    for (final category in LesionCategory.values) {
      expect(category.types, isNotEmpty, reason: category.name);
    }
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
