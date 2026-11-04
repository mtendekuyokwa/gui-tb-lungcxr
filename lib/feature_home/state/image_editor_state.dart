import 'package:flutter/widgets.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/feature_home/models/lesion.dart';
import 'package:gui_lungcxr/feature_home/models/mark.dart';
import 'package:gui_lungcxr/feature_home/models/mask_edit.dart';

enum EditorTool {
  pan,
  mark,
  segment,
  brightness,
  contrast,
  hue,
  saturation;

  bool get isAdjustment => switch (this) {
    brightness || contrast || hue || saturation => true,
    pan || mark || segment => false,
  };
}

/// The correction brush inside the segment tool.
enum SegmentSubtool { brush, pen, eraser }

/// View and edit state for one patient's X-ray: active tool, image
/// adjustments, hand-drawn marks and zoom.
class ImageEditorState extends ChangeNotifier {
  static const double minScale = 0.5;
  static const double maxScale = 8;

  /// Scale change of one press of the zoom buttons.
  static const double zoomStep = 1.25;

  final TransformationController transform = TransformationController();

  EditorTool _tool = .pan;
  final Map<EditorTool, double> _adjustments = {
    .brightness: 0,
    .contrast: 0,
    .hue: 0,
    .saturation: 0,
  };

  /// Labelled marks; these are the hints that will be sent to the
  /// segmentation backend.
  final List<Mark> _marks = [];
  bool _drawing = false;
  int _markRevision = 0;
  int? _activeMark;
  int _resetCount = 0;
  bool _xaiEnabled = false;
  bool _segmentationEnabled = false;
  bool _locked = false;

  /// Corrections to the model's lung mask, painted in the segment tool.
  final List<MaskEdit> _maskEdits = [];
  bool _editingMask = false;
  int _maskRevision = 0;
  SegmentSubtool _segmentSubtool = .brush;
  final Map<SegmentSubtool, double> _maskWidths = {
    .brush: AppSizes.maskBrushDefaultWidth,
    .pen: AppSizes.maskPenDefaultWidth,
    .eraser: AppSizes.maskBrushDefaultWidth,
  };

  /// True once the review is submitted: marks can be seen but not changed.
  bool get locked => _locked;
  set locked(bool value) {
    if (value == _locked) return;
    _locked = value;
    _drawing = false;
    _editingMask = false;
    _activeMark = null;
    notifyListeners();
  }

  EditorTool get tool => _tool;
  List<Mark> get marks => _marks;
  bool get hasMarks => _marks.isNotEmpty;

  /// Bumped whenever [marks] or a mark's label changes, since both are
  /// mutated in place.
  int get markRevision => _markRevision;

  /// Index of the mark being labelled, if any.
  int? get activeMark => _activeMark;
  bool get xaiEnabled => _xaiEnabled;
  bool get segmentationEnabled => _segmentationEnabled;

  /// The doctor's corrections to the model's lung mask.
  List<MaskEdit> get maskEdits => _maskEdits;
  bool get hasMaskEdits => _maskEdits.isNotEmpty;
  bool get hasEraseEdits => _maskEdits.any((e) => e.kind == MaskEditKind.erase);

  /// Bumped whenever [maskEdits] changes, mirroring [markRevision].
  int get maskRevision => _maskRevision;

  SegmentSubtool get segmentSubtool => _segmentSubtool;

  /// Correction stroke width as a fraction of the image width.
  double get maskWidth => _maskWidths[_segmentSubtool]!;

  /// Changes whenever adjustments are reset, so sliders can be rebuilt.
  int get resetCount => _resetCount;

  bool get hasAdjustments => _adjustments.values.any((v) => v != 0);

  /// Adjustment value in the range -1..1, where 0 leaves the image unchanged.
  double adjustment(EditorTool tool) => _adjustments[tool] ?? 0;

  /// Selecting the active tool again returns to [EditorTool.pan].
  /// Entering the segment tool shows the model mask with it.
  void selectTool(EditorTool tool) {
    _tool = _tool == tool ? .pan : tool;
    _activeMark = null;
    if (_tool == .segment) _segmentationEnabled = true;
    notifyListeners();
  }

  void setAdjustment(EditorTool tool, double value) {
    assert(tool.isAdjustment, '$tool is not an adjustment');
    _adjustments[tool] = value.clamp(-1, 1);
    notifyListeners();
  }

  void resetAdjustment(EditorTool tool) {
    _adjustments[tool] = 0;
    _resetCount++;
    notifyListeners();
  }

  /// Replaces all marks, e.g. with the ones saved on the backend.
  void replaceMarks(Iterable<Mark> marks) {
    _marks
      ..clear()
      ..addAll(marks);
    _drawing = false;
    _activeMark = null;
    _markRevision++;
    notifyListeners();
  }

  void startStroke(Offset point) {
    if (_locked) return;
    _marks.add(Mark([point]));
    _drawing = true;
    _activeMark = null;
    _markRevision++;
    notifyListeners();
  }

  void extendStroke(Offset point) {
    if (!_drawing) return;
    _marks.last.points.add(point);
    _markRevision++;
    notifyListeners();
  }

  /// Finishes the stroke and opens it for labelling.
  void endStroke() {
    if (!_drawing) return;
    _drawing = false;
    _activeMark = _marks.length - 1;
    notifyListeners();
  }

  /// Opens an existing mark for (re)labelling; null closes the label panel.
  /// Selection is UI state only and never marks the draft as changed, so
  /// merely opening the panel cannot flip a returned case to "in review".
  void selectMark(int? index) {
    if (_locked) return;
    _activeMark = index;
    notifyListeners();
  }

  /// Labels the active mark and closes the label panel.
  void labelActiveMark(LesionType lesion) => updateActiveMark(lesion: lesion);

  /// Saves the active mark's finding and comment, then closes the label
  /// panel. Either may be left unchanged by passing null.
  void updateActiveMark({LesionType? lesion, String? note}) {
    final index = _activeMark;
    if (index == null || _locked) return;
    if (lesion != null) _marks[index].lesion = lesion;
    if (note != null) _marks[index].note = note;
    _activeMark = null;
    _markRevision++;
    notifyListeners();
  }

  /// Rewrites the active mark's comment without closing the label panel.
  void setActiveMarkNote(String note) {
    final index = _activeMark;
    if (index == null || _locked) return;
    if (_marks[index].note == note) return;
    _marks[index].note = note;
    _markRevision++;
    notifyListeners();
  }

  void deleteMark(int index) {
    if (_locked) return;
    _marks.removeAt(index);
    _activeMark = null;
    _drawing = false;
    _markRevision++;
    notifyListeners();
  }

  void undoStroke() {
    if (_marks.isEmpty) return;
    deleteMark(_marks.length - 1);
  }

  void clearMarks() {
    if (_locked) return;
    _marks.clear();
    _activeMark = null;
    _drawing = false;
    _markRevision++;
    notifyListeners();
  }

  void setXai(bool enabled) {
    _xaiEnabled = enabled;
    notifyListeners();
  }

  void setSegmentation(bool enabled) {
    _segmentationEnabled = enabled;
    notifyListeners();
  }

  /// Picks the correction brush; each subtool remembers its own width.
  void selectSegmentSubtool(SegmentSubtool subtool) {
    _segmentSubtool = subtool;
    notifyListeners();
  }

  void setMaskWidth(double width) {
    _maskWidths[_segmentSubtool] = width.clamp(
      AppSizes.maskEditMinWidth,
      AppSizes.maskEditMaxWidth,
    );
    notifyListeners();
  }

  /// Replaces all mask corrections, e.g. with the ones saved on the backend.
  void replaceMaskEdits(Iterable<MaskEdit> edits) {
    _maskEdits
      ..clear()
      ..addAll(edits);
    _editingMask = false;
    _maskRevision++;
    notifyListeners();
  }

  void startMaskStroke(Offset point) {
    if (_locked) return;
    _maskEdits.add(
      MaskEdit(
        [point],
        kind: _segmentSubtool == .eraser ? .erase : .add,
        tool: _segmentSubtool == .pen ? .pen : .brush,
        width: maskWidth,
      ),
    );
    _editingMask = true;
    _maskRevision++;
    notifyListeners();
  }

  void extendMaskStroke(Offset point) {
    if (!_editingMask) return;
    _maskEdits.last.points.add(point);
    _maskRevision++;
    notifyListeners();
  }

  void endMaskStroke() {
    if (!_editingMask) return;
    _editingMask = false;
    notifyListeners();
  }

  void undoMaskEdit() {
    if (_locked || _maskEdits.isEmpty) return;
    _maskEdits.removeLast();
    _editingMask = false;
    _maskRevision++;
    notifyListeners();
  }

  /// Drops every correction, showing the model mask as it was made.
  void clearMaskEdits() {
    if (_locked || _maskEdits.isEmpty) return;
    _maskEdits.clear();
    _editingMask = false;
    _maskRevision++;
    notifyListeners();
  }

  /// Zooms by [factor] around [focalPoint] (viewport coordinates).
  void zoom(double factor, Offset focalPoint) {
    final current = transform.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(minScale, maxScale);
    final f = target / current;
    transform.value = Matrix4.translationValues(focalPoint.dx, focalPoint.dy, 0)
      ..multiply(Matrix4.diagonal3Values(f, f, 1))
      ..multiply(Matrix4.translationValues(-focalPoint.dx, -focalPoint.dy, 0))
      ..multiply(transform.value);
  }

  void zoomIn(Offset focalPoint) => zoom(zoomStep, focalPoint);
  void zoomOut(Offset focalPoint) => zoom(1 / zoomStep, focalPoint);

  void resetZoom() => transform.value = Matrix4.identity();

  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }
}
