import 'package:flutter/widgets.dart';

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

  /// Strokes in image-relative coordinates (0..1 on both axes), so they stay
  /// attached to the image regardless of zoom or window size. These are the
  /// hints that will be sent to the segmentation backend.
  final List<List<Offset>> _strokes = [];
  bool _drawing = false;
  int _strokeRevision = 0;
  int _resetCount = 0;
  bool _xaiEnabled = false;

  EditorTool get tool => _tool;
  List<List<Offset>> get strokes => _strokes;
  bool get hasMarks => _strokes.isNotEmpty;
  int get strokeRevision => _strokeRevision;
  bool get xaiEnabled => _xaiEnabled;

  /// Changes whenever adjustments are reset, so sliders can be rebuilt.
  int get resetCount => _resetCount;

  bool get hasAdjustments => _adjustments.values.any((v) => v != 0);

  /// Adjustment value in the range -1..1, where 0 leaves the image unchanged.
  double adjustment(EditorTool tool) => _adjustments[tool] ?? 0;

  /// Selecting the active tool again returns to [EditorTool.pan].
  void selectTool(EditorTool tool) {
    _tool = _tool == tool ? .pan : tool;
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

  void startStroke(Offset point) {
    _strokes.add([point]);
    _drawing = true;
    _strokeRevision++;
    notifyListeners();
  }

  void extendStroke(Offset point) {
    if (!_drawing) return;
    _strokes.last.add(point);
    _strokeRevision++;
    notifyListeners();
  }

  void endStroke() => _drawing = false;

  void undoStroke() {
    if (_strokes.isEmpty) return;
    _strokes.removeLast();
    _drawing = false;
    _strokeRevision++;
    notifyListeners();
  }

  void clearMarks() {
    _strokes.clear();
    _drawing = false;
    _strokeRevision++;
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
