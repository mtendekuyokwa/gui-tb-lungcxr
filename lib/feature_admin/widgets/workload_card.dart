import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/utils/dashboard_text.dart';
import 'package:provider/provider.dart';

/// The team, fewest open cases first so the next assignment is obvious,
/// with how long each doctor's oldest open case has waited. Opening a
/// doctor lists their cases.
class WorkloadCard extends StatelessWidget {
  const new({required this.stats, this.onOpen, super.key});

  final AdminStats stats;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final admin = context.read<AdminState>();
    final now = DateTime.now();
    final doctors = leastLoadedFirst(stats.workload)
        .take(AppSizes.chartMaxDoctors)
        .toList();
    final truncated = stats.workload.length > doctors.length;
    // Only worth pointing out when the first doctor really is lighter.
    final roomy = doctors.length > 1 && doctors.first.open < doctors[1].open;

    return FTileGroup(
      label: const Text(Strings.teamTitle),
      description: Text(
        truncated ? Strings.chartsTopDoctors : Strings.teamHint,
      ),
      children: [
        if (doctors.isEmpty)
          FTile(
            prefix: const Icon(FLucideIcons.userRound),
            title: const Text(Strings.noDoctors),
          ),
        for (final (i, doctor) in doctors.indexed)
          FTile(
            prefix: const Icon(FLucideIcons.userRound),
            title: Text(doctor.fullName),
            subtitle: Text(doctorLine(doctor, now)),
            details: i == 0 && roomy
                ? FBadge(variant: .secondary, child: Text(Strings.hasRoom))
                : null,
            suffix: const Icon(FLucideIcons.chevronRight),
            onPress: () {
              admin.showOnly(doctorId: doctor.doctorId);
              onOpen?.call();
            },
          ),
      ],
    );
  }
}
