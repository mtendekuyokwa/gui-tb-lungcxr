import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';

/// One labelled count with a Forui progress bar of its share, for the
/// dashboard's short breakdowns (verdict mix, how the model was flagged).
class CountRow extends StatelessWidget {
  const new({
    required this.label,
    required this.count,
    required this.of,
    super.key,
  });

  final String label;
  final int count;

  /// The breakdown's total; the bar fills [count] / [of].
  final int of;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final style = theme.typography.body.sm;

    return Column(
      crossAxisAlignment: .stretch,
      spacing: AppSizes.gap6,
      children: [
        Row(
          spacing: AppSizes.gap8,
          children: [
            Expanded(child: Text(label, style: style)),
            Text(
              '$count',
              style: style.copyWith(
                fontWeight: .w500,
                color: count == 0 ? theme.colors.mutedForeground : null,
              ),
            ),
          ],
        ),
        FDeterminateProgress(value: of == 0 ? 0 : count / of),
      ],
    );
  }
}
