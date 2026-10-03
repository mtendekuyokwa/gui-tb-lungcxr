import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/api/models.dart';

/// A wrapping row of options; the selected ones are filled.
class ChoiceChips extends StatelessWidget {
  const new({
    required this.options,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final List<Option> options;
  final Set<String?> selected;
  final ValueChanged<String> onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final option in options)
        FButton(
          variant: selected.contains(option.code) ? .primary : .outline,
          size: .xs,
          mainAxisSize: .min,
          onPress: enabled ? () => onTap(option.code) : null,
          child: Flexible(child: Text(option.label, overflow: .ellipsis)),
        ),
    ],
  );
}
