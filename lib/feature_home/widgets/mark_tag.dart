import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_colors.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/models/mark.dart';
import 'package:gui_lungcxr/feature_home/utils/mark_style.dart';

/// The finding a mark is labelled with, shown next to it; tap to relabel.
class MarkTag extends StatelessWidget {
  const new({
    required this.mark,
    required this.active,
    required this.onTap,
    super.key,
  });

  final Mark mark;

  /// Whether this is the mark being labelled, which fills the tag.
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = markColor(mark.lesion);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: active ? color : AppColors.markTagBackground,
            border: .all(color: color),
            borderRadius: .circular(AppSizes.radius4),
          ),
          child: Padding(
            padding: const .symmetric(
              horizontal: AppSizes.gap6,
              vertical: AppSizes.gap2,
            ),
            child: Text(
              mark.lesion?.label ?? Strings.unlabelled,
              style: context.theme.typography.body.xs.copyWith(
                color: active ? AppColors.black : color,
                fontWeight: .w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
