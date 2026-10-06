import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:gui_lungcxr/feature_home/state/case_state.dart';
import 'package:provider/provider.dart';

/// Shown instead of the workspace when the doctor has no cases, or when
/// loading them failed with [error].
class NoCases extends StatelessWidget {
  const new({required this.error, super.key});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Center(
      child: Column(
        mainAxisSize: .min,
        spacing: AppSizes.gap8,
        children: [
          const Icon(FLucideIcons.inbox, size: AppSizes.icon32),
          Text(
            error ?? Strings.noCases,
            style: theme.typography.body.md.copyWith(fontWeight: .w600),
          ),
          if (error == null)
            Text(
              Strings.noCasesDetail,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          const SizedBox(height: AppSizes.gap4),
          Row(
            mainAxisSize: .min,
            spacing: AppSizes.gap8,
            children: [
              FButton(
                variant: .outline,
                size: .sm,
                mainAxisSize: .min,
                onPress: context.read<CaseState>().load,
                prefix: const Icon(FLucideIcons.refreshCw),
                child: const Text(Strings.refresh),
              ),
              FButton(
                variant: .ghost,
                size: .sm,
                mainAxisSize: .min,
                onPress: context.read<SessionState>().logout,
                prefix: const Icon(FLucideIcons.logOut),
                child: const Text(Strings.signOut),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
