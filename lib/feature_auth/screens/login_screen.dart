import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/feature_auth/widgets/login_artwork.dart';
import 'package:gui_lungcxr/feature_auth/widgets/login_form.dart';

/// Sign-in page: the artwork on the left, the form on the right.
class LoginScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: AppSizes.loginCardWidth,
    height: AppSizes.loginCardHeight,
    child: Padding(
      padding: .symmetric(vertical: AppSizes.gap18),
      child: FCard(
        child: Row(
          mainAxisAlignment: .spaceBetween,
          spacing: AppSizes.gap12,
          children: [
            LoginArtwork(),
            Spacer(),
            SizedBox(width: AppSizes.loginFormWidth, child: LoginForm()),
            Spacer(),
          ],
        ),
      ),
    ),
  );
}
