import 'package:flutter/material.dart';
import 'package:gui_lungcxr/constants/app_images.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';

/// The picture filling the left side of the login card.
class LoginArtwork extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: .circular(AppSizes.radius12),
    child: Image.asset(
      AppImages.doctorHoldingTb,
      width: AppSizes.loginArtworkWidth,
      height: AppSizes.loginCardHeight,
      fit: .cover,
    ),
  );
}
