import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';

/// The app's icon and name, as shown on the login page and at the top of
/// each workspace. The name is cut short when there is no room for it.
class AppBrand extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: .min,
    spacing: AppSizes.gap8,
    children: [
      const Icon(FLucideIcons.scanEye),
      Flexible(
        child: Text(
          Strings.appName,
          overflow: .ellipsis,
          style: context.theme.typography.display.lg,
        ),
      ),
    ],
  );
}
