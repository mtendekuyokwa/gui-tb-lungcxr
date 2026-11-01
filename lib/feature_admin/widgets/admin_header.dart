import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:gui_lungcxr/widgets/app_brand.dart';
import 'package:provider/provider.dart';

/// Top bar of the admin workspace: the current page's name, who is signed
/// in, refresh and sign-out. The brand lives in the sidebar on wide
/// screens; on narrow ones there is no sidebar, so the brand leads.
class AdminHeader extends StatelessWidget {
  const new({required this.title, super.key});

  final String title;

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The signed-in name is decoration; on narrow screens the
            // brand and the action buttons need the room more.
            final wide = constraints.maxWidth >= AppSizes.narrowBreakpoint;
            return Row(
              spacing: AppSizes.gap8,
              children: [
                // Bounded so a long page name ellipsizes instead of
                // pushing the buttons out.
                Expanded(
                  child:
                      (wide)
                          ? Text(
                            title,
                            maxLines: 1,
                            overflow: .ellipsis,
                            style: theme.typography.body.md.copyWith(
                              fontWeight: .w600,
                            ),
                          )
                          : const Align(
                            alignment: .centerLeft,
                            child: AppBrand(),
                          ),
                ),
                if (wide)
                  Flexible(
                    child: Text(
                      session.user?.fullName ?? '',
                      style: theme.typography.body.xs.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                      overflow: .ellipsis,
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
            );
          },
        ),
      ),
    );
  }
}
