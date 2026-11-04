import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/feature_auth/widgets/login_artwork.dart';
import 'package:gui_lungcxr/feature_auth/widgets/login_form.dart';

/// Sign-in page: the artwork on the left, the form on the right. Under
/// [AppSizes.narrowBreakpoint] the artwork hides and the form takes the
/// full width.
class LoginScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const .all(AppSizes.gap16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < AppSizes.narrowBreakpoint;
          return SizedBox(
            width: narrow ? null : AppSizes.loginCardWidth,
            height: narrow ? null : AppSizes.loginCardHeight,
            child: Padding(
              padding: const .symmetric(vertical: AppSizes.gap18),
              child: FCard(
                child: narrow
                    ? const LoginForm()
                    : const Row(
                        mainAxisAlignment: .spaceBetween,
                        spacing: AppSizes.gap12,
                        children: [
                          LoginArtwork(),
                          Spacer(),
                          SizedBox(
                            width: AppSizes.loginFormWidth,
                            child: LoginForm(),
                          ),
                          Spacer(),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
