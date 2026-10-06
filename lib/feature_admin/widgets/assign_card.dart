import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/widgets/admin_section.dart';
import 'package:gui_lungcxr/feature_home/widgets/choice_chips.dart';
import 'package:provider/provider.dart';

/// Picks a doctor and hands them the ticked cases.
class AssignCard extends StatefulWidget {
  const new({super.key});

  @override
  State<AssignCard> createState() => _AssignCardState();
}

class _AssignCardState extends State<AssignCard> {
  int? _doctorId;

  Future<void> _assign(AdminState admin, int doctorId) async {
    if (!await admin.assign(doctorId) || !mounted) return;
    showFToast(
      context: context,
      icon: const Icon(FLucideIcons.circleCheck),
      title: const Text(Strings.casesAssigned),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final theme = context.theme;
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    // A doctor deactivated since being picked is no longer a valid choice.
    final doctorId = admin.doctors.any((d) => d.id == _doctorId)
        ? _doctorId
        : null;
    final count = admin.ticked.length;

    return AdminSection(
      title: Strings.assignTo,
      children: [
        if (admin.doctors.isEmpty)
          Text(Strings.noDoctors, style: muted)
        else
          ChoiceChips(
            options: [
              for (final doctor in admin.doctors)
                Option('${doctor.id}', doctor.fullName),
            ],
            selected: {'$doctorId'},
            onTap: (code) => setState(() => _doctorId = int.parse(code)),
          ),
        if (count == 0) Text(Strings.selectCasesToAssign, style: muted),
        FButton(
          size: .sm,
          onPress: count > 0 && doctorId != null && !admin.busy
              ? () => _assign(admin, doctorId)
              : null,
          child: Text('${Strings.assign} ($count)'),
        ),
      ],
    );
  }
}
