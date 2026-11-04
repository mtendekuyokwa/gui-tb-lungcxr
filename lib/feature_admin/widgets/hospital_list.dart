import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/widgets/admin_section.dart';
import 'package:gui_lungcxr/widgets/busy_icon.dart';
import 'package:provider/provider.dart';

/// The hospitals cases can come from: a filter box that doubles as the
/// name of a new one, and the matching list.
class HospitalList extends StatefulWidget {
  const new({super.key});

  @override
  State<HospitalList> createState() => _HospitalListState();
}

class _HospitalListState extends State<HospitalList> {
  final _name = TextEditingController();
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add(AdminState admin) async {
    setState(() => _adding = true);
    final ok = await admin.addHospital(_name.text);
    if (!mounted) return;
    setState(() => _adding = false);
    if (ok) _name.clear();
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final theme = context.theme;
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    final typed = _name.text.trim();
    final query = typed.toLowerCase();
    final shown = [
      for (final hospital in admin.hospitalList)
        if (hospital.name.toLowerCase().contains(query)) hospital,
    ];
    final exists = admin.hospitalList.any((h) => h.name.toLowerCase() == query);

    return AdminSection(
      title: Strings.hospitals,
      subtitle: Strings.hospitalsSubtitle,
      children: [
        Row(
          spacing: AppSizes.gap8,
          children: [
            Expanded(
              child: FTextField(
                control: .managed(controller: _name),
                hint: Strings.hospitalSearchOrAdd,
                clearable: (value) => value.text.isNotEmpty,
              ),
            ),
            FButton(
              size: .sm,
              mainAxisSize: .min,
              onPress: typed.isEmpty || exists || admin.busy
                  ? null
                  : () => _add(admin),
              prefix: BusyIcon(busy: _adding, icon: FLucideIcons.plus),
              child: const Text(Strings.addHospital),
            ),
          ],
        ),
        if (shown.isEmpty)
          Text(
            admin.hospitalList.isEmpty
                ? Strings.noHospitals
                : Strings.noHospitalMatch,
            style: muted,
          )
        else
          for (final hospital in shown)
            Row(
              spacing: AppSizes.gap8,
              children: [
                Icon(
                  FLucideIcons.building2,
                  size: AppSizes.icon16,
                  color: theme.colors.mutedForeground,
                ),
                Expanded(
                  child: Text(
                    hospital.name,
                    overflow: .ellipsis,
                    style: theme.typography.body.sm,
                  ),
                ),
              ],
            ),
      ],
    );
  }
}
