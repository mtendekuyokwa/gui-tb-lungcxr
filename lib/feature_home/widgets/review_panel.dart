import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/review_state.dart';
import 'package:gui_lungcxr/feature_home/widgets/review_form.dart';
import 'package:provider/provider.dart';

/// The doctor's review of the selected case: verdict, disease tags, whether
/// the model was wrong, and further testing. Saved as a draft as it changes.
class ReviewPanel extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final review = context.watch<ReviewState>();
    final theme = context.theme;

    final Widget body;
    if (review.loading) {
      body = const Center(child: FCircularProgress());
    } else if (review.detail == null) {
      body = Center(
        child: Column(
          mainAxisSize: .min,
          spacing: AppSizes.gap8,
          children: [
            Text(
              review.error ?? Strings.somethingWentWrong,
              textAlign: .center,
              style: theme.typography.body.sm,
            ),
            FButton(
              variant: .outline,
              size: .sm,
              mainAxisSize: .min,
              onPress: review.load,
              child: const Text(Strings.retry),
            ),
          ],
        ),
      );
    } else {
      body = const ReviewForm();
    }

    return Padding(
      padding: const .fromLTRB(AppSizes.gap8, 0, AppSizes.gap8, AppSizes.gap8),
      child: FCard(clipBehavior: .antiAlias, child: body),
    );
  }
}
