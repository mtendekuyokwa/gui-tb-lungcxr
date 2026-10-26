import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gui_lungcxr/constants/app_colors.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/feature_home/models/mask_edit.dart';
import 'package:gui_lungcxr/feature_home/utils/segmentation.dart';

/// See-through strength of the XAI heatmap, shared with [XrayImage].
const double heatmapOverlayOpacity = 0.6;

/// Resolves [url] (with [headers]) to a decoded image for custom painting,
/// rebuilding [builder] once it arrives. Builds with a null image while
/// loading, so callers show nothing until the layer is ready.
///
/// The provider is recreated only when [url] changes, so painting strokes
/// over the layer never refetches it.
class DecodedImage extends StatefulWidget {
  const new({
    required this.url,
    required this.headers,
    required this.builder,
    super.key,
  });

  final String url;
  final Map<String, String> headers;
  final Widget Function(BuildContext context, ui.Image? image) builder;

  @override
  State<DecodedImage> createState() => _DecodedImageState();
}

class _DecodedImageState extends State<DecodedImage> {
  ImageStream? _stream;
  late final _listener = ImageStreamListener(_onImage, onError: _onError);
  ui.Image? _image;

  ImageProvider get _provider =>
      NetworkImage(widget.url, headers: widget.headers);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(DecodedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _image?.dispose();
      _image = null;
      _resolve();
    }
  }

  void _resolve() {
    final stream = _provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _onImage(ImageInfo info, bool _) {
    _image?.dispose();
    if (mounted) {
      setState(() => _image = info.image);
    } else {
      info.dispose();
    }
  }

  void _onError(Object _, StackTrace? _) {
    // Leave _image null; the layer stays hidden.
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _image);
}

List<Offset> _toPixels(List<Offset> relative, Size size) => [
  for (final p in relative) Offset(p.dx * size.width, p.dy * size.height),
];

void _paintRibbon(Canvas canvas, List<Offset> points, Paint paint) {
  if (points.length == 1) {
    canvas.drawCircle(
      points.first,
      paint.strokeWidth / 2,
      paint..style = .fill,
    );
    return;
  }
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final p in points.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  canvas.drawPath(path, paint);
}

Paint _editPaint(MaskEdit edit, Size size) {
  final paint = Paint()
    ..style = .stroke
    ..strokeCap = .round
    ..strokeJoin = .round
    ..strokeWidth = edit.width * size.width;
  if (edit.kind == .erase) {
    paint.blendMode = .clear;
  } else {
    paint.color = AppColors.maskTint.withValues(
      alpha: AppSizes.maskFillOpacity,
    );
  }
  return paint;
}

/// The model mask with the doctor's corrections painted in: added regions in
/// the mask tint, erased regions punched through to the X-ray below. Used
/// only while corrections exist; the plain mask is a tinted [Image] instead.
class MaskCompositeView extends StatelessWidget {
  const new({
    required this.maskUrl,
    required this.headers,
    required this.edits,
    required this.revision,
    super.key,
  });

  final String maskUrl;
  final Map<String, String> headers;
  final List<MaskEdit> edits;

  /// Bumped by the editor on every change, since [edits] mutates in place.
  final int revision;

  @override
  Widget build(BuildContext context) => DecodedImage(
    url: maskUrl,
    headers: headers,
    builder: (_, image) {
      if (image == null) return const SizedBox.expand();
      return CustomPaint(
        painter: _MaskCompositePainter(
          image: image,
          edits: edits,
          revision: revision,
        ),
      );
    },
  );
}

class _MaskCompositePainter extends CustomPainter {
  _MaskCompositePainter({
    required this.image,
    required this.edits,
    required this.revision,
  });

  final ui.Image image;
  final List<MaskEdit> edits;
  final int revision;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      bounds,
      Paint()
        ..colorFilter = ColorFilter.matrix(
          maskTintMatrix(AppColors.maskTint, AppSizes.maskFillOpacity),
        ),
    );
    for (final edit in edits) {
      _paintRibbon(
        canvas,
        _toPixels(edit.points, size),
        _editPaint(edit, size),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MaskCompositePainter oldDelegate) =>
      oldDelegate.revision != revision || oldDelegate.image != image;
}

/// The Grad-CAM heatmap with erased lung regions cut out, so the XAI only
/// shows inside the (possibly edited) segmentation. Wrap in [Opacity];
/// used only while erase corrections exist.
class ClippedHeatmapView extends StatelessWidget {
  const new({
    required this.heatmapUrl,
    required this.headers,
    required this.edits,
    required this.revision,
    super.key,
  });

  final String heatmapUrl;
  final Map<String, String> headers;
  final List<MaskEdit> edits;
  final int revision;

  @override
  Widget build(BuildContext context) => DecodedImage(
    url: heatmapUrl,
    headers: headers,
    builder: (_, image) {
      if (image == null) return const SizedBox.expand();
      return CustomPaint(
        painter: _HeatClipPainter(
          image: image,
          edits: edits,
          revision: revision,
        ),
      );
    },
  );
}

class _HeatClipPainter extends CustomPainter {
  _HeatClipPainter({
    required this.image,
    required this.edits,
    required this.revision,
  });

  final ui.Image image;
  final List<MaskEdit> edits;
  final int revision;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      bounds,
      Paint(),
    );
    for (final edit in edits.where((e) => e.kind == .erase)) {
      _paintRibbon(
        canvas,
        _toPixels(edit.points, size),
        _editPaint(edit, size),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeatClipPainter oldDelegate) =>
      oldDelegate.revision != revision || oldDelegate.image != image;
}
