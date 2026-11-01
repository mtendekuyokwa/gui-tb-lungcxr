import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/app_colors.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/widgets/admin_section.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:provider/provider.dart';

/// The admin's charts, kept actionable: every panel answers a question and
/// tapping it narrows the case list — overview narrows into the queue's
/// drilldown. [onOpen] moves the admin from the dashboard to the page where
/// that filter takes effect. When the stats panel cannot load, the graphs
/// are replaced by a note saying so instead of silently vanishing.
class AdminCharts extends StatelessWidget {
  const AdminCharts({this.onOpen, super.key});

  /// Called after every drilldown tap. Null when the charts sit beside the
  /// case list already.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final stats = context.select<AdminState, AdminStats?>((a) => a.stats);
    if (stats == null) return const _DeferredNote();
    return Column(
      crossAxisAlignment: .stretch,
      spacing: AppSizes.gap12,
      children: [
        WorkloadChart(onOpen: onOpen),
        StatusChart(onOpen: onOpen),
      ],
    );
  }
}

/// The graphs' substitute when the stats endpoint fails: the same slot,
/// but honestly saying what is missing instead of hiding the panel.
class _DeferredNote extends StatelessWidget {
  const _DeferredNote();

  @override
  Widget build(BuildContext context) => AdminSection(
    title: Strings.stats,
    children: [
      Icon(
        FLucideIcons.chartColumn,
        size: AppSizes.icon32,
        color: context.theme.colors.mutedForeground,
      ),
      Text(
        Strings.statsDeferred,
        style: context.theme.typography.body.xs2.copyWith(
          color: context.theme.colors.mutedForeground,
        ),
      ),
    ],
  );
}

/// Closed work per doctor as a stacked bar: open work in the theme
/// primary, what already moved through it in amber and green. Tapping a
/// bar filters the case list to that doctor; tapping it again clears.
/// Bars are capped to the 8 busiest doctors — an unbounded axis shows
/// nothing readable.
class WorkloadChart extends StatelessWidget {
  const WorkloadChart({this.onOpen, super.key});

  /// Called after a bar tap drills the case list down, so the dashboard
  /// can hand the admin over to the filtered queue.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final filteredDoctors = admin.stats?.workload ?? const <DoctorWorkload>[];
    final theme = context.theme;
    final colors = theme.colors;
    final muted = theme.typography.body.xs2.copyWith(
      color: colors.mutedForeground,
    );
    if (filteredDoctors.isEmpty) {
      return AdminSection(
        title: Strings.workloadQuestion,
        children: [Text(Strings.noDoctors, style: muted)],
      );
    }

    // Most open first: the chart answers "who needs help now?", and the
    // axis stays readable no matter how many doctors the hospital has.
    final sorted = [...filteredDoctors]..sort((a, b) => b.open - a.open);
    final doctors = sorted.take(AppSizes.chartMaxDoctors).toList();
    final truncated = sorted.length > doctors.length;

    final maxTotal = [
      for (final d in doctors) d.open + d.submitted + d.accepted,
    ].reduce((a, b) => a > b ? a : b);
    final filterId = admin.doctorFilter;

    return AdminSection(
      title: Strings.workloadQuestion,
      children: [
        Text(Strings.chartTapDoctor, style: muted),
        Column(
          crossAxisAlignment: .stretch,
          spacing: AppSizes.gap8,
          children: [
            _Legend(
              entries: [
                (colors.primary, Strings.statsOpen),
                (AppColors.statWarning, Strings.statsSubmitted),
                (AppColors.statDone, Strings.statsAccepted),
              ],
            ),
            SizedBox(
              height: AppSizes.chartBarHeight,
              child: BarChart(
                // Instant: the rail remounts its content per tab, so an
                // animation would replay on every visit.
                duration: .zero,
                BarChartData(
                  alignment: .spaceAround,
                  maxY: (maxTotal == 0 ? 1.0 : maxTotal.toDouble() * 1.15),
                  // A tap on a bar narrows the case list to that doctor;
                  // built-in touches still give the per-rod tooltip.
                  barTouchData: BarTouchData(
                    touchCallback: (event, response) {
                      if (event is! FlTapUpEvent) return;
                      final group = response?.spot?.touchedBarGroupIndex;
                      if (group == null || group >= doctors.length) return;
                      final id = admin.doctorIdOf(doctors[group].fullName);
                      if (id == null) return;
                      admin.setDoctorFilter(filterId == id ? null : id);
                      onOpen?.call();
                    },
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (value, _) =>
                            Text(value.toInt().toString(), style: muted),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, _) => Text(
                          _short(doctors[value.toInt()].fullName),
                          overflow: .ellipsis,
                          style: muted,
                        ),
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      strokeWidth: 1,
                      color: colors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (final (i, doctor) in doctors.indexed)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY:
                                (doctor.open +
                                        doctor.submitted +
                                        doctor.accepted)
                                    .toDouble(),
                            width: 16,
                            borderRadius: const .vertical(
                              top: .circular(AppSizes.radius4),
                            ),
                            // The filtered doctor's bar stays lit; the
                            // others dim so the choice is visible.
                            rodStackItems: [
                              for (final (color, from, to) in _stack(
                                colors,
                                doctor,
                              ))
                                BarChartRodStackItem(
                                  from,
                                  to,
                                  admin.doctorIdOf(doctor.fullName) ==
                                              filterId ||
                                          filterId == null
                                      ? color
                                      : color.withValues(alpha: 0.35),
                                ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (truncated) Text(Strings.chartsTopDoctors, style: muted),
            if (doctors.any((d) => d.fullName.trim().split(' ').length > 1))
              for (final doctor in doctors)
                Text(_counts(doctor), overflow: .ellipsis, style: muted),
          ],
        ),
      ],
    );
  }

  /// The rod's stacked bands, in order, with their full spans.
  List<(Color, double, double)> _stack(FColors colors, DoctorWorkload doctor) {
    final open = doctor.open.toDouble();
    final submitted = open + doctor.submitted;
    final accepted = submitted + doctor.accepted;
    return [
      (colors.primary, 0.0, open),
      (AppColors.statWarning, open, submitted),
      (AppColors.statDone, submitted, accepted),
    ];
  }

  String _counts(DoctorWorkload doctor) =>
      '${_short(doctor.fullName)}: '
      '${doctor.open} ${Strings.statsOpen} · '
      '${doctor.submitted} ${Strings.statsSubmitted} · '
      '${doctor.accepted} ${Strings.statsAccepted}';

  /// Enough of the name to tell the bars apart; the tooltip and the items
  /// below the chart give the full form.
  String _short(String name) => name.trim().split(' ').first;
}

/// The pipeline as a donut: one slice per status, at most six — crowded
/// slices carry no meaning. Each slice, and its legend row, filters the
/// case list to that status; the filtered slice swells to mark itself.
class StatusChart extends StatelessWidget {
  const StatusChart({this.onOpen, super.key});

  /// Called after a slice or legend tap drills the case list down, so the
  /// dashboard can hand the admin over to the filtered queue.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final stats = admin.stats;
    final theme = context.theme;
    final colors = theme.colors;
    if (stats == null) return const SizedBox.shrink();

    int count(CaseStatus status) => stats.byStatus[status.code] ?? 0;

    final entries = [
      (
        CaseStatus.unassigned,
        Strings.statusUnassigned,
        count(CaseStatus.unassigned),
        colors.primary,
      ),
      (
        CaseStatus.assigned,
        Strings.statusAssigned,
        count(CaseStatus.assigned),
        AppColors.statHeld,
      ),
      (
        CaseStatus.inReview,
        Strings.statusInReview,
        count(CaseStatus.inReview),
        AppColors.statReviewing,
      ),
      (
        CaseStatus.submitted,
        Strings.statusSubmitted,
        count(CaseStatus.submitted),
        AppColors.statWarning,
      ),
      (
        CaseStatus.returned,
        Strings.statusReturned,
        count(CaseStatus.returned),
        colors.destructive,
      ),
      (
        CaseStatus.accepted,
        Strings.statusAccepted,
        count(CaseStatus.accepted),
        AppColors.statDone,
      ),
    ]..removeWhere((entry) => entry.$3 == 0);
    var total = 0;
    for (final (_, _, value, _) in entries) {
      total += value;
    }

    return AdminSection(
      title: Strings.queueQuestion,
      children: [
        Text(Strings.chartTapStatus, style: muted(context)),
        if (total == 0)
          Text(Strings.noCasesAdmin, style: muted(context))
        else
          Column(
            crossAxisAlignment: .stretch,
            spacing: AppSizes.gap12,
            children: [
              SizedBox(
                height: AppSizes.chartDonutHeight,
                child: PieChart(
                  duration: .zero,
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: AppSizes.chartDonutHole,
                    sections: [
                      for (final (status, _, value, color) in entries)
                        PieChartSectionData(
                          value: value.toDouble(),
                          color: color,
                          // The filtered status's slice pops out; the
                          // rest keep a flat circle.
                          radius: admin.statusFilter == status
                              ? AppSizes.chartDonutRadius + 4
                              : AppSizes.chartDonutRadius,
                          showTitle: false,
                        ),
                    ],
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (event is! FlTapUpEvent) return;
                        final index =
                            response?.touchedSection?.touchedSectionIndex;
                        if (index == null || index >= entries.length) return;
                        final status = entries[index].$1;
                        admin.setStatusFilter(
                          admin.statusFilter == status ? null : status,
                        );
                        onOpen?.call();
                      },
                    ),
                  ),
                ),
              ),
              Wrap(
                spacing: AppSizes.gap8,
                runSpacing: AppSizes.gap4,
                children: [
                  for (final (status, label, value, color) in entries)
                    _LegendDot(
                      label: label,
                      value: value,
                      color: color,
                      active: admin.statusFilter == status,
                      onTap: () {
                        admin.setStatusFilter(
                          admin.statusFilter == status ? null : status,
                        );
                        onOpen?.call();
                      },
                    ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  TextStyle muted(BuildContext context) => context.theme.typography.body.xs2
      .copyWith(color: context.theme.colors.mutedForeground);
}

/// A donut legend row: dot, name, count. Clickable, and highlighted when
/// its status is the one the case list is filtered to.
class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.label,
    required this.value,
    required this.color,
    required this.active,
    this.onTap,
  });

  final String label;
  final int value;
  final Color color;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final activeStyle = theme.typography.body.xs2.copyWith(fontWeight: .w600);
    final normal = theme.typography.body.xs2.copyWith(
      color: theme.colors.mutedForeground,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: .opaque,
        onTap: onTap,
        child: Padding(
          padding: const .symmetric(vertical: AppSizes.gap2),
          child: Row(
            mainAxisSize: .min,
            spacing: AppSizes.gap6,
            children: [
              Container(
                width: AppSizes.gap8,
                height: AppSizes.gap8,
                decoration: BoxDecoration(
                  color: color,
                  shape: .circle,
                  border: active
                      ? Border.all(color: theme.colors.foreground, width: 1.5)
                      : null,
                ),
              ),
              Text(
                '$label $value',
                overflow: .ellipsis,
                style: active ? activeStyle : normal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline legend for stacked bars.
class _Legend extends StatelessWidget {
  const _Legend({required this.entries});

  final List<(Color, String)> entries;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSizes.gap10,
    runSpacing: AppSizes.gap4,
    children: [
      for (final (color, label) in entries)
        Row(
          mainAxisSize: .min,
          spacing: AppSizes.gap6,
          children: [
            Container(
              width: AppSizes.gap8,
              height: AppSizes.gap8,
              decoration: BoxDecoration(color: color, shape: .circle),
            ),
            Text(
              label,
              style: context.theme.typography.body.xs2.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
    ],
  );
}
