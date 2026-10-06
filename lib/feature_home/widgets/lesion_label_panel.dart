import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/models/lesion.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';
import 'package:gui_lungcxr/feature_home/utils/mark_style.dart';
import 'package:gui_lungcxr/feature_home/widgets/color_swatch.dart';

/// Floating card for labelling the active mark: pick a category, then the
/// lesion type within it.
class LesionLabelPanel extends StatefulWidget {
  const new({required this.editor, super.key});

  final ImageEditorState editor;

  @override
  State<LesionLabelPanel> createState() => _LesionLabelPanelState();
}

class _LesionLabelPanelState extends State<LesionLabelPanel> {
  late final int _index = widget.editor.activeMark!;
  late LesionType? _current = widget.editor.marks[_index].lesion;
  late LesionCategory _category = _current?.category ?? .parenchymal;

  @override
  Widget build(BuildContext context) {
    final editor = widget.editor;
    final theme = context.theme;
    final heading = theme.typography.body.sm.copyWith(fontWeight: .w600);
    final caption = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );

    return SizedBox(
      width: AppSizes.lesionPanelWidth,
      child: FCard(
        child: Padding(
          padding: const .fromLTRB(
            AppSizes.gap16,
            AppSizes.gap8,
            AppSizes.gap8,
            AppSizes.gap16,
          ),
          child: Column(
            crossAxisAlignment: .stretch,
            spacing: AppSizes.gap8,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _current == null ? Strings.labelMark : Strings.editLabel,
                      style: heading,
                    ),
                  ),
                  FTooltip(
                    tipBuilder: (_, _) => const Text(Strings.deleteMark),
                    child: FButton.icon(
                      variant: .ghost,
                      size: .sm,
                      onPress: () => editor.deleteMark(_index),
                      child: const Icon(FLucideIcons.trash2),
                    ),
                  ),
                  FTooltip(
                    tipBuilder: (_, _) => const Text(Strings.close),
                    child: FButton.icon(
                      variant: .ghost,
                      size: .sm,
                      onPress: () => editor.selectMark(null),
                      child: const Icon(FLucideIcons.x),
                    ),
                  ),
                ],
              ),
              Text(Strings.lesionCategory, style: caption),
              Wrap(
                spacing: AppSizes.gap6,
                runSpacing: AppSizes.gap6,
                children: [
                  for (final category in LesionCategory.values)
                    FButton(
                      variant: category == _category ? .primary : .outline,
                      size: .xs,
                      mainAxisSize: .min,
                      onPress: () => setState(() => _category = category),
                      prefix: ColorSwatchDot(
                        color: markColor(category.types.first),
                      ),
                      child: Text(category.label),
                    ),
                ],
              ),
              const SizedBox(height: AppSizes.gap2),
              Text(Strings.lesionType, style: caption),
              Wrap(
                spacing: AppSizes.gap6,
                runSpacing: AppSizes.gap6,
                children: [
                  for (final type in _category.types)
                    FButton(
                      variant: type == _current ? .primary : .secondary,
                      size: .xs,
                      mainAxisSize: .min,
                      onPress: () {
                        setState(() => _current = type);
                        editor.labelActiveMark(type);
                      },
                      child: Text(type.label),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
