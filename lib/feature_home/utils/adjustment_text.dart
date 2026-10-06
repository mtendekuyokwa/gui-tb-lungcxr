import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';

String adjustmentLabel(EditorTool tool) => switch (tool) {
  .brightness => Strings.Brightness,
  .contrast => Strings.Contrast,
  .hue => Strings.Hue,
  .saturation => Strings.Saturation,
  .pan || .mark => '',
};

/// Displays a -1..1 value as -100..100 (hue as degrees).
String formatAdjustment(EditorTool tool, double value) {
  final shown = tool == .hue ? value * 180 : value * 100;
  final rounded = shown.round();
  final suffix = tool == .hue ? '°' : '';
  return '${rounded > 0 ? '+' : ''}$rounded$suffix';
}

/// Sliders run 0..1; adjustments run -1..1.
double adjustmentToSlider(double value) => (value + 1) / 2;
double sliderToAdjustment(double position) => position * 2 - 1;
