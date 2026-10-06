import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:gui_lungcxr/widgets/app_brand.dart';
import 'package:provider/provider.dart';

/// Top bar of the admin workspace: app name, who is signed in, refresh and
/// sign-out.
class AdminHeader extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final admin = context.read<AdminState>();
    final theme = context.theme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.background,
        border: Border(bottom: BorderSide(color: theme.colors.border)),
      ),
      child: Padding(
        padding: const .symmetric(
          horizontal: AppSizes.gap16,
          vertical: AppSizes.gap10,
        ),
        child: Row(
          spacing: AppSizes.gap8,
          children: [
            const AppBrand(),
            const Spacer(),
            Text(
              session.user?.fullName ?? '',
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            FTooltip(
              tipBuilder: (_, _) => const Text(Strings.refresh),
              child: FButton.icon(
                variant: .ghost,
                size: .sm,
                onPress: admin.load,
                child: const Icon(FLucideIcons.refreshCw),
              ),
            ),
            FTooltip(
              tipBuilder: (_, _) => const Text(Strings.signOut),
              child: FButton.icon(
                variant: .ghost,
                size: .sm,
                onPress: session.logout,
                child: const Icon(FLucideIcons.logOut),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
