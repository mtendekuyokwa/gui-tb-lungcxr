import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/utils/case_summary.dart';
import 'package:gui_lungcxr/feature_admin/widgets/admin_section.dart';
import 'package:gui_lungcxr/feature_home/widgets/choice_chips.dart';
import 'package:provider/provider.dart';

/// Picks a doctor and hands them the ticked cases, with an optional due date.
class AssignCard extends StatefulWidget {
  const new({super.key});

  @override
  State<AssignCard> createState() => _AssignCardState();
}

class _AssignCardState extends State<AssignCard> {
  int? _doctorId;
  DateTime? _dueAt;

  Future<void> _assign(AdminState admin, int doctorId) async {
    if (!await admin.assign(doctorId, dueAt: _dueAt) || !mounted) return;
    setState(() => _dueAt = null);
    showFToast(
      context: context,
      icon: const Icon(FLucideIcons.circleCheck),
      title: const Text(Strings.casesAssigned),
    );
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null && mounted) setState(() => _dueAt = picked);
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
    final shown = [
      for (final c in admin.cases)
        if (admin.ticked.contains(c.id)) c,
    ];

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
            enabled: !admin.busy,
          ),
        // Always present so the Assign button below never jumps, and
        // explicit about who holds the ticked cases before they move.
        Text(
          count == 0
              ? Strings.selectCasesToAssign
              : assignSummary(shown, count - shown.length),
          style: muted,
          overflow: .ellipsis,
          maxLines: 2,
        ),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: FButton(
                variant: .outline,
                size: .sm,
                onPress: admin.busy ? null : _pickDueDate,
                prefix: const Icon(FLucideIcons.calendar),
                child: Flexible(
                  child: Text(
                    _dueAt == null
                        ? Strings.dueDate
                        : _dueAt!.toIso8601String().split('T').first,
                    overflow: .ellipsis,
                  ),
                ),
              ),
            ),
            if (_dueAt != null)
              FButton.icon(
                variant: .ghost,
                size: .sm,
                onPress: admin.busy
                    ? null
                    : () => setState(() => _dueAt = null),
                child: const Icon(FLucideIcons.x),
              ),
          ],
        ),
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
