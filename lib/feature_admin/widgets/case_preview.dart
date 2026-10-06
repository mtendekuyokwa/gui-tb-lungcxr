import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_colors.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:provider/provider.dart';

/// The case's X-ray, scaled down to fit the detail card.
class CasePreview extends StatelessWidget {
  const new({required this.caseId, super.key});

  final int caseId;

  @override
  Widget build(BuildContext context) {
    final admin = context.read<AdminState>();

    return ClipRRect(
      borderRadius: .circular(AppSizes.radius6),
      child: ColoredBox(
        color: AppColors.xrayBackdrop,
        child: SizedBox(
          height: AppSizes.casePreviewHeight,
          child: Image.network(
            admin.imageUrl(caseId),
            headers: admin.imageHeaders,
            fit: .contain,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(
                FLucideIcons.imageOff,
                color: AppColors.onXrayBackdrop,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
