import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';

/// Why the admin sent the case back, shown above the reopened review.
class ReturnNote extends StatelessWidget {
  const new({required this.note, super.key});

  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final body = theme.typography.body.sm;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: .all(color: theme.colors.destructive),
        borderRadius: .circular(AppSizes.radius6),
      ),
      child: Padding(
        padding: const .all(AppSizes.gap8),
        child: Column(
          crossAxisAlignment: .start,
          spacing: AppSizes.gap2,
          children: [
            Text(
              Strings.returnedByAdmin,
              style: body.copyWith(fontWeight: .w600),
            ),
            Text(note, style: body),
          ],
        ),
      ),
    );
  }
}
