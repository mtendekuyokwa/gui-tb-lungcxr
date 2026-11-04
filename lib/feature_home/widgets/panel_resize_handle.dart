import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';

/// A vertical drag handle between two columns: dragging reports the
/// horizontal movement, double-clicking asks to toggle a preset width.
class PanelResizeHandle extends StatefulWidget {
  const new({required this.onDrag, required this.onToggle, super.key});

  final ValueChanged<double> onDrag;
  final VoidCallback onToggle;

  @override
  State<PanelResizeHandle> createState() => _PanelResizeHandleState();
}

class _PanelResizeHandleState extends State<PanelResizeHandle> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Semantics(
      label: Strings.resizeReview,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() => _active = true),
        onExit: (_) => setState(() => _active = false),
        child: GestureDetector(
          behavior: .opaque,
          onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
          onDoubleTap: widget.onToggle,
          child: SizedBox(
            width: AppSizes.resizeHandleWidth,
            child: Center(
              child: Container(
                width: _active
                    ? AppSizes.resizeHandleLineActive
                    : AppSizes.resizeHandleLine,
                color: _active ? colors.primary : colors.border,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
