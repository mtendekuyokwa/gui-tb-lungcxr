import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// A muted label with its value underneath.
class DetailLine extends StatelessWidget {
  const new(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(
          label,
          style: theme.typography.body.xs.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
        Text(value, style: theme.typography.body.sm),
      ],
    );
  }
}
