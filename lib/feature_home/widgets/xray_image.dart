import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';
import 'package:gui_lungcxr/feature_home/utils/color_matrix.dart';
import 'package:provider/provider.dart';

/// Shows the X-ray at its native aspect ratio with the editor's colour
/// adjustments applied, and stacks the XAI heatmap (if any) and [overlay]
/// exactly over the image bounds.
class XrayImage extends StatefulWidget {
  const new({
    required this.url,
    required this.overlay,
    this.headers = const {},
    this.heatmapUrl,
    super.key,
  });

  final String url;

  /// Sent with the image request; the backend serves images only to the
  /// signed-in user.
  final Map<String, String> headers;

  /// Grad-CAM overlay drawn over the X-ray while XAI is on.
  final String? heatmapUrl;
  final Widget overlay;

  @override
  State<XrayImage> createState() => _XrayImageState();
}

class _XrayImageState extends State<XrayImage> {
  ImageStream? _stream;
  late final _listener = ImageStreamListener(_onImage, onError: _onError);
  double? _aspectRatio;
  bool _failed = false;

  ImageProvider get _provider =>
      NetworkImage(widget.url, headers: widget.headers);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(XrayImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _aspectRatio = null;
      _failed = false;
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
    final ratio = info.image.width / info.image.height;
    info.dispose();
    if (mounted) setState(() => _aspectRatio = ratio);
  }

  void _onError(Object _, StackTrace? _) {
    if (mounted) setState(() => _failed = true);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Column(
        mainAxisSize: .min,
        spacing: 8,
        children: [
          const Icon(FLucideIcons.imageOff, color: Colors.white70, size: 32),
          Text(
            Strings.imageLoadFailed,
            style: context.theme.typography.body.sm.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      );
    }
    final aspectRatio = _aspectRatio;
    if (aspectRatio == null) {
      return const FCircularProgress();
    }

    final editor = context.watch<ImageEditorState>();
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: .expand,
        children: [
          ColorFiltered(
            colorFilter: ColorFilter.matrix(
              adjustmentMatrix(
                brightness: editor.adjustment(.brightness),
                contrast: editor.adjustment(.contrast),
                hue: editor.adjustment(.hue),
                saturation: editor.adjustment(.saturation),
              ),
            ),
            child: Image(
              image: _provider,
              fit: .fill,
              filterQuality: .medium,
              gaplessPlayback: true,
            ),
          ),
          if (widget.heatmapUrl case final heatmap?)
            Opacity(
              opacity: 0.6,
              child: Image.network(
                heatmap,
                headers: widget.headers,
                fit: .fill,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          widget.overlay,
        ],
      ),
    );
  }
}
