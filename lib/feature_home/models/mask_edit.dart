import 'dart:ui';

/// How a lung-mask correction stroke changes the model's mask.
enum MaskEditKind {
  add('add'),
  erase('erase');

  const MaskEditKind(this.code);

  final String code;

  static MaskEditKind fromCode(String code) =>
      values.firstWhere((k) => k.code == code);
}

/// The tool that painted the stroke: broad brush or fine pen.
enum MaskEditTool {
  brush('brush'),
  pen('pen');

  const MaskEditTool(this.code);

  final String code;

  static MaskEditTool fromCode(String code) =>
      values.firstWhere((t) => t.code == code);
}

/// One hand-painted correction to the model's lung mask, stored in
/// image-relative (0..1) points so it survives zoom and resize like a [Mark].
class MaskEdit {
  MaskEdit(
    this.points, {
    required this.kind,
    required this.tool,
    required this.width,
  });

  final List<Offset> points;
  final MaskEditKind kind;
  final MaskEditTool tool;

  /// Stroke width as a fraction of the image width.
  final double width;
}

MaskEdit maskEditFromJson(dynamic json) => MaskEdit(
  [
    for (final point in json['points'] as List)
      Offset((point[0] as num).toDouble(), (point[1] as num).toDouble()),
  ],
  kind: MaskEditKind.fromCode(json['kind'] as String),
  tool: MaskEditTool.fromCode(json['tool'] as String),
  width: (json['width'] as num).toDouble(),
);

Map<String, dynamic> maskEditToJson(MaskEdit edit) => {
  'kind': edit.kind.code,
  'tool': edit.tool.code,
  'width': edit.width,
  'points': [
    for (final point in edit.points) [point.dx, point.dy],
  ],
};
