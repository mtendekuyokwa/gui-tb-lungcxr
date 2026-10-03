import 'package:flutter/widgets.dart';
import 'package:gui_lungcxr/feature_home/models/lesion.dart';
import 'package:gui_lungcxr/feature_home/models/mark.dart';

enum EditorTool {
  pan,
  mark,
  brightness,
  contrast,
  hue,
  saturation;

  bool get isAdjustment => switch (this) {
    brightness || contrast || hue || saturation => true,
    pan || mark => false,
  };
}

/// View and edit state for one patient's X-ray: active tool, image
/// adjustments, hand-drawn marks and zoom.
class ImageEditorState extends ChangeNotifier {
  static const double minScale = 0.5;
  static const double maxScale = 8;

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
  bool _locked = false;

  /// True once the review is submitted: marks can be seen but not changed.
  bool get locked => _locked;
  set locked(bool value) {
    if (value == _locked) return;
    _locked = value;
    _drawing = false;
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

  /// Changes whenever adjustments are reset, so sliders can be rebuilt.
  int get resetCount => _resetCount;

  bool get hasAdjustments => _adjustments.values.any((v) => v != 0);

  /// Adjustment value in the range -1..1, where 0 leaves the image unchanged.
  double adjustment(EditorTool tool) => _adjustments[tool] ?? 0;

  /// Selecting the active tool again returns to [EditorTool.pan].
  void selectTool(EditorTool tool) {
    _tool = _tool == tool ? .pan : tool;
    _activeMark = null;
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

  void resetAdjustments() {
    _adjustments.updateAll((_, _) => 0);
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
  void selectMark(int? index) {
    if (_locked) return;
    _activeMark = index;
    _markRevision++;
    notifyListeners();
  }

  /// Labels the active mark and closes the label panel.
  void labelActiveMark(LesionType lesion) {
    final index = _activeMark;
    if (index == null) return;
    _marks[index].lesion = lesion;
    _activeMark = null;
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

  void resetZoom() => transform.value = Matrix4.identity();

  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }
}
