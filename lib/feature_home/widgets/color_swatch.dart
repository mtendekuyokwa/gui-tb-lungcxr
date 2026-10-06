import 'package:flutter/material.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';

/// A small dot of [color], e.g. a lesion category's mark colour.
class ColorSwatchDot extends StatelessWidget {
  const new({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color, shape: .circle),
    child: const SizedBox.square(dimension: AppSizes.swatch),
  );
}
