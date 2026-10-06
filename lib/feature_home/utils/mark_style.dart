import 'dart:ui';

import 'package:gui_lungcxr/constants/app_colors.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/feature_home/models/lesion.dart';

/// Mark colour on the X-ray, by lesion category.
Color markColor(LesionType? lesion) => switch (lesion?.category) {
  null => AppColors.markUnlabelled,
  .parenchymal => AppColors.markParenchymal,
  .pleural => AppColors.markPleural,
  .mediastinal => AppColors.markMediastinal,
  .other => AppColors.markOther,
};

/// Stroke width for marks on an image drawn at [size], so strokes look the
/// same on small and large X-rays.
double markStrokeWidth(Size size) =>
    (size.shortestSide * AppSizes.markStrokeFactor).clamp(
      AppSizes.markStrokeMin,
      AppSizes.markStrokeMax,
    );

/// Converts a pointer position on an image drawn at [size] into the
/// image-relative (0..1) point a mark stores.
Offset toImageRelative(Offset local, Size size) => Offset(
  (local.dx / size.width).clamp(0, 1),
  (local.dy / size.height).clamp(0, 1),
);
