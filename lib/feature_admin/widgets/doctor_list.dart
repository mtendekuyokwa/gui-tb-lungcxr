import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/widgets/admin_section.dart';
import 'package:provider/provider.dart';

/// Every user with activate / deactivate controls (the Update half of
/// user CRUD; creation lives in [NewUser]).
class DoctorList extends StatefulWidget {
  const new({super.key});

  @override
  State<DoctorList> createState() => _DoctorListState();
}

class _DoctorListState extends State<DoctorList> {
  var _showInactive = false;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final theme = context.theme;
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    final users = [
      for (final user in admin.allUsers)
        if (user.active || _showInactive) user,
    ];

    return AdminSection(
      title: Strings.doctors,
      children: [
        Row(
          children: [
            FCheckbox(
              value: _showInactive,
              onChange: (_) => setState(() => _showInactive = !_showInactive),
            ),
            const SizedBox(width: AppSizes.gap8),
            Flexible(child: Text(Strings.showInactive, style: muted)),
          ],
        ),
        if (users.isEmpty)
          Text(Strings.noDoctors, style: muted)
        else
          for (final user in users)
            Row(
              spacing: AppSizes.gap8,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        user.fullName,
                        overflow: .ellipsis,
                        style: theme.typography.body.sm.copyWith(
                          fontWeight: .w600,
                          color: user.active
                              ? null
                              : theme.colors.mutedForeground,
                        ),
                      ),
                      Text(
                        '${user.email} · ${user.role}',
                        overflow: .ellipsis,
                        style: muted,
                      ),
                    ],
                  ),
                ),
                // Fixed width: the button's inner row cannot take a flex
                // child under unbounded constraints.
                SizedBox(
                  width: AppSizes.userActiveButtonWidth,
                  child: FButton(
                    size: .sm,
                    variant: user.active ? .outline : .primary,
                    onPress: admin.busy
                        ? null
                        : () => admin.setUserActive(user.id, !user.active),
                    child: Flexible(
                      child: Text(
                        user.active ? Strings.deactivate : Strings.reactivate,
                        overflow: .ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
      ],
    );
  }
}
