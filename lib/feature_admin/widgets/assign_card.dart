import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/utils/case_summary.dart';
import 'package:gui_lungcxr/feature_admin/widgets/admin_section.dart';
import 'package:provider/provider.dart';

/// Picks a doctor and hands them the ticked cases, with an optional due
/// date. Doctors show their open work so load stays visible where the
/// assignment happens.
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
    final muted = theme.typography.body.xs2.copyWith(
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
          for (final doctor in admin.doctors)
            _DoctorTile(
              name: doctor.fullName,
              workload: admin.workloadOf(doctor),
              selected: doctor.id == doctorId,
              enabled: !admin.busy,
              onTap: () => setState(() => _doctorId = doctor.id),
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
          prefix: const Icon(FLucideIcons.sendHorizontal),
          child: Text('${Strings.assign} ($count)'),
        ),
      ],
    );
  }
}

/// One selectable doctor row: name, how much they hold, and a tick when
/// they are the target.
class _DoctorTile extends StatelessWidget {
  const _DoctorTile({
    required this.name,
    required this.workload,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  final String name;

  /// Shown as "3 open · 1 submitted · 2 accepted", or a fallback when the
  /// stats panel failed to load.
  final String workload;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final accent = selected ? colors.primary : colors.mutedForeground;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: .opaque,
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const .fromLTRB(
            AppSizes.gap10,
            AppSizes.gap8,
            AppSizes.gap10,
            AppSizes.gap8,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.primary.withValues(alpha: 0.08) : null,
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: .circular(AppSizes.radius8),
          ),
          child: Row(
            spacing: AppSizes.gap8,
            children: [
              Icon(FLucideIcons.bookUser, size: AppSizes.icon18, color: accent),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: AppSizes.gap2,
                  children: [
                    Text(
                      name,
                      overflow: .ellipsis,
                      style: theme.typography.body.sm.copyWith(
                        fontWeight: .w600,
                      ),
                    ),
                    Text(
                      workload,
                      overflow: .ellipsis,
                      style: theme.typography.body.xs3.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  FLucideIcons.circleCheck,
                  size: AppSizes.icon18,
                  color: colors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
