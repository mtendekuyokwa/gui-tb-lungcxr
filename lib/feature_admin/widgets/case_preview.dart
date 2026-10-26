import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_colors.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:gui_lungcxr/feature_home/models/mask_edit.dart';
import 'package:gui_lungcxr/feature_home/utils/segmentation.dart';
import 'package:provider/provider.dart';

/// The case's X-ray with the model's lung mask and the doctor's corrections,
/// scaled down to fit the detail card.
class CasePreview extends StatelessWidget {
  const new({required this.caseId, super.key});

  final int caseId;

  @override
  Widget build(BuildContext context) {
    final admin = context.read<AdminState>();
    final item = context.select<AdminState, CxrCase?>((a) => a.open);

    return ClipRRect(
      borderRadius: .circular(AppSizes.radius6),
      child: ColoredBox(
        color: AppColors.xrayBackdrop,
        child: SizedBox(
          height: AppSizes.casePreviewHeight,
          child: _PreviewLayers(
            xrayUrl: admin.imageUrl(caseId),
            maskUrl: (item?.prediction?.hasMask ?? false)
                ? admin.maskUrl(caseId)
                : null,
            headers: admin.imageHeaders,
            edits: item?.review?.maskEdits ?? const <MaskEdit>[],
          ),
        ),
      ),
    );
  }
}

/// Fitted rect of an [aspect]-ratio image shown `contain`ed in [box].
Rect _fitRect(Size box, double aspect) {
  var width = box.width;
  var height = width / aspect;
  if (height > box.height) {
    height = box.height;
    width = height * aspect;
  }
  return Rect.fromLTWH(
    (box.width - width) / 2,
    (box.height - height) / 2,
    width,
    height,
  );
}

/// X-ray with the mask wash and correction strokes composited exactly over
/// the fitted image rect, so strokes sit on the anatomy they correct.
class _PreviewLayers extends StatefulWidget {
  const new({
    required this.xrayUrl,
    required this.maskUrl,
    required this.headers,
    required this.edits,
  });

  final String xrayUrl;
  final String? maskUrl;
  final Map<String, String> headers;
  final List<MaskEdit> edits;

  @override
  State<_PreviewLayers> createState() => _PreviewLayersState();
}

class _PreviewLayersState extends State<_PreviewLayers> {
  ImageStream? _stream;
  late final _listener = ImageStreamListener(_onXray, onError: _onXrayError);
  double? _xrayAspect;
  bool _maskOk = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveXray();
  }

  @override
  void didUpdateWidget(_PreviewLayers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.xrayUrl != widget.xrayUrl) {
      _xrayAspect = null;
      _resolveXray();
    }
    if (oldWidget.maskUrl != widget.maskUrl) _maskOk = true;
  }

  void _resolveXray() {
    final provider = NetworkImage(widget.xrayUrl, headers: widget.headers);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _onXray(ImageInfo info, bool _) {
    final aspect = info.image.width / info.image.height;
    info.dispose();
    if (mounted) setState(() => _xrayAspect = aspect);
  }

  void _onXrayError(Object _, StackTrace? _) {
    // The base image's own errorBuilder covers this.
  }

  void _onMaskError() {
    // setState during layout is unsafe; defer a frame. With no mask the
    // edits would float over a plain X-ray, so hide them too.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _maskOk = false);
    });
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maskUrl = widget.maskUrl;
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = constraints.biggest;
        final aspect = _xrayAspect;
        return Stack(
          fit: .expand,
          children: [
            Image.network(
              widget.xrayUrl,
              headers: widget.headers,
              fit: .contain,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(
                  FLucideIcons.imageOff,
                  color: AppColors.onXrayBackdrop,
                ),
              ),
            ),
            // Same fitted rect as the X-ray above, so every layer aligns.
            if (maskUrl != null && aspect != null && _maskOk)
              Positioned.fromRect(
                rect: _fitRect(box, aspect),
                child: Stack(
                  fit: .expand,
                  children: [
                    ColorFiltered(
                      colorFilter: ColorFilter.matrix(
                        maskTintMatrix(
                          AppColors.maskTint,
                          AppSizes.maskFillOpacity,
                        ),
                      ),
                      child: Image.network(
                        maskUrl,
                        headers: widget.headers,
                        fit: .fill,
                        errorBuilder: (_, _, _) {
                          _onMaskError();
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    if (widget.edits.isNotEmpty)
                      CustomPaint(
                        painter: _PreviewEditsPainter(edits: widget.edits),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Correction strokes at preview scale: added regions in the mask tint,
/// erased regions as an outline (the exact punch-through lives on the
/// doctor's canvas).
class _PreviewEditsPainter extends CustomPainter {
  _PreviewEditsPainter({required this.edits});

  final List<MaskEdit> edits;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edit in edits) {
      final points = [
        for (final p in edit.points)
          Offset(p.dx * size.width, p.dy * size.height),
      ];
      final paint = Paint()
        ..strokeCap = .round
        ..strokeJoin = .round;
      if (edit.kind == .erase) {
        paint
          ..style = .stroke
          ..strokeWidth = AppSizes.gap2
          ..color = AppColors.xrayBackdrop;
      } else {
        paint
          ..style = .stroke
          ..strokeWidth = edit.width * size.width
          ..color = AppColors.maskTint.withValues(
            alpha: AppSizes.maskFillOpacity,
          );
      }
      if (points.length == 1) {
        final radius = edit.kind == .erase
            ? AppSizes.gap2
            : paint.strokeWidth / 2;
        canvas.drawCircle(points.first, radius, paint..style = .fill);
        continue;
      }
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_PreviewEditsPainter oldDelegate) =>
      !identical(oldDelegate.edits, edits);
}
