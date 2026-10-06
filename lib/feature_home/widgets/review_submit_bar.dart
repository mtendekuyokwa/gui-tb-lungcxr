import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/review_state.dart';
import 'package:gui_lungcxr/feature_home/utils/review_text.dart';
import 'package:provider/provider.dart';

/// Autosave status and the submit button under the review form.
class ReviewSubmitBar extends StatelessWidget {
  const new({required this.onSubmit, super.key});

  /// Runs when the doctor presses submit. The bar itself is gone once the
  /// review locks, so the caller owns what happens afterwards.
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final review = context.watch<ReviewState>();
    final theme = context.theme;

    return Padding(
      padding: const .all(AppSizes.gap12),
      child: Row(
        spacing: AppSizes.gap8,
        children: [
          Expanded(
            child: Text(
              reviewStatusLine(review),
              maxLines: 2,
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ),
          FButton(
            size: .sm,
            mainAxisSize: .min,
            onPress: review.canSubmit && review.saveStatus != .saving
                ? onSubmit
                : null,
            child: const Text(Strings.submitReview),
          ),
        ],
      ),
    );
  }
}
