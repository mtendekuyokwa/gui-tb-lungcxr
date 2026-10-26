import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/models/lesion.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';
import 'package:gui_lungcxr/feature_home/widgets/lesion_label_panel.dart';
import 'package:gui_lungcxr/feature_home/widgets/mark_layer.dart';
import 'package:gui_lungcxr/feature_home/widgets/mask_edit_layer.dart';
import 'package:gui_lungcxr/theme/theme.dart';

/// The canvas stacks the mask-correction layer above the mark layer. The
/// idle mask layer must not swallow pointer input, or no mark can be drawn.
Widget _layers(ImageEditorState editor, {bool viewer = false}) {
  final stack = Stack(
    children: [
      MarkLayer(editor: editor),
      MaskEditLayer(editor: editor, maskAvailable: true),
    ],
  );
  final body = SizedBox(width: 300, height: 300, child: stack);
  if (!viewer) return MaterialApp(home: Scaffold(body: body));
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 300,
        height: 300,
        child: InteractiveViewer(
          transformationController: editor.transform,
          panEnabled: false,
          child: stack,
        ),
      ),
    ),
  );
}

Future<void> _drag(WidgetTester tester) async {
  final center = tester.getCenter(find.byType(MarkLayer));
  final gesture = await tester.startGesture(center);
  await gesture.moveBy(const Offset(50, 50));
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('mark-mode drag reaches the mark layer under the mask layer', (
    tester,
  ) async {
    final editor = ImageEditorState();
    addTearDown(editor.dispose);
    editor.selectTool(EditorTool.mark);
    await tester.pumpWidget(_layers(editor));
    await _drag(tester);

    expect(editor.marks, hasLength(1));
    expect(editor.marks.single.points, hasLength(2));
    expect(editor.activeMark, 0);
    expect(editor.maskEdits, isEmpty);
  });

  testWidgets('mark-mode drag works inside the zoomable canvas', (
    tester,
  ) async {
    final editor = ImageEditorState();
    addTearDown(editor.dispose);
    editor.selectTool(EditorTool.mark);
    await tester.pumpWidget(_layers(editor, viewer: true));
    await _drag(tester);

    expect(editor.marks, hasLength(1));
    expect(editor.activeMark, 0);
    expect(editor.maskEdits, isEmpty);
  });

  testWidgets('segment-mode drag paints a mask edit, not a mark', (
    tester,
  ) async {
    final editor = ImageEditorState();
    addTearDown(editor.dispose);
    editor.selectTool(EditorTool.segment);
    await tester.pumpWidget(_layers(editor));
    await _drag(tester);

    expect(editor.maskEdits, hasLength(1));
    expect(editor.marks, isEmpty);
  });

  testWidgets('the label panel saves the comment and the finding together', (
    tester,
  ) async {
    final editor = ImageEditorState();
    addTearDown(editor.dispose);
    editor
      ..startStroke(const Offset(0.3, 0.6))
      ..endStroke();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: FLocalizations.localizationsDelegates,
        builder: (context, child) => FTheme(
          data: lightTheme,
          child: FToaster(child: FTooltipGroup(child: child!)),
        ),
        home: Scaffold(body: LesionLabelPanel(editor: editor)),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(FTextField), 'Cavity, right upper zone');
    await tester.pump();
    // Picking a finding only selects it locally; the mark is untouched.
    await tester.tap(find.text(LesionType.cavity.label));
    await tester.pump(const Duration(milliseconds: 200));
    expect(editor.marks.single.lesion, isNull);
    expect(editor.activeMark, 0);

    await tester.ensureVisible(find.text(Strings.saveMark));
    await tester.pump();
    await tester.tap(find.text(Strings.saveMark));
    await tester.pump(const Duration(milliseconds: 200));
    expect(editor.marks.single.lesion, LesionType.cavity);
    expect(editor.marks.single.note, 'Cavity, right upper zone');
    expect(editor.activeMark, isNull);
  });
}
