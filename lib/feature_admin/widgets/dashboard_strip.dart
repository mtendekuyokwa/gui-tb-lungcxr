import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_colors.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/widgets/admin_section.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:provider/provider.dart';

/// The admin's dashboard as a strip of headline numbers: how many cases sit
/// in each state that needs a decision, and how well the model matched the
/// doctors. Tapping a state tile filters the case list to it; tapping the
/// one already filtered shows every case again. [onOpen] moves the admin
/// onward from the dashboard to the page where the filtering happens.
class DashboardStrip extends StatelessWidget {
  const new({this.onOpen, super.key});

  /// Called on every state-tile tap, after the filter is applied. Null
  /// when the tiles are being read on the page that already shows the
  /// case list.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final stats = admin.stats;
    if (stats == null) {
      // The tiles cannot show made-up numbers, and a vanished panel looks
      // like "everything at zero" — say the stats are missing instead.
      return AdminSection(
        title: Strings.stats,
        children: [
          const Icon(FLucideIcons.chartColumn, size: AppSizes.icon32),
          Text(
            Strings.statsDeferred,
            style: context.theme.typography.body.xs2.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ],
      );
    }
    final theme = context.theme;
    final colors = theme.colors;

    int count(CaseStatus status) => stats.byStatus[status.code] ?? 0;

    /// One tile per state the admin acts on. [filter] marks the state the
    /// case list currently shows.
    final List<_StatTile> tiles = [
      _StatTile(
        label: Strings.statusUnassigned,
        value: count(CaseStatus.unassigned),
        icon: FLucideIcons.inbox,
        accent: colors.primary,
        active: admin.statusFilter == CaseStatus.unassigned,
        onTap: _filter(context, CaseStatus.unassigned),
      ),
      _StatTile(
        label: Strings.statusSubmitted,
        value: stats.submitted,
        icon: FLucideIcons.sendHorizontal,
        accent: AppColors.statWarning,
        active: admin.statusFilter == CaseStatus.submitted,
        onTap: _filter(context, CaseStatus.submitted),
      ),
      _StatTile(
        label: Strings.statusReturned,
        value: count(CaseStatus.returned),
        icon: FLucideIcons.undo2,
        accent: colors.destructive,
        active: admin.statusFilter == CaseStatus.returned,
        onTap: _filter(context, CaseStatus.returned),
      ),
      _StatTile(
        label: Strings.statusAccepted,
        value: count(CaseStatus.accepted),
        icon: FLucideIcons.checkCheck,
        accent: AppColors.statDone,
        active: admin.statusFilter == CaseStatus.accepted,
        onTap: _filter(context, CaseStatus.accepted),
      ),
      _StatTile(
        label: Strings.statsAgreement,
        value: stats.rate == null
            ? null
            : (stats.rate! * 100).toStringAsFixed(0),
        caption: stats.compared == 0
            ? null
            : '${stats.agreed}/${stats.compared}',
        icon: FLucideIcons.scale,
        accent: colors.mutedForeground,
      ),
    ];

    final health = _HealthCard(waiting: admin.waitingOnModel);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppSizes.narrowBreakpoint;
        if (wide) {
          return Row(
            spacing: AppSizes.gap8,
            children: [
              for (final t in tiles) Expanded(child: t),
              SizedBox(width: AppSizes.adminHealthCardWidth, child: health),
            ],
          );
        }
        // Narrow screens wrap the tiles to fixed widths instead of
        // squeezing five columns; the health card hides behind the case
        // list's own waiting hint.
        return Wrap(
          spacing: AppSizes.gap8,
          runSpacing: AppSizes.gap8,
          children: [
            for (final t in tiles)
              SizedBox(width: AppSizes.adminTileWidth, child: t),
          ],
        );
      },
    );
  }

  /// Filter the case list to [status], or back to every case when it is
  /// already the one filtered, then hand the admin over to where that
  /// filter takes effect.
  VoidCallback _filter(BuildContext context, CaseStatus status) => () {
    final admin = context.read<AdminState>();
    admin.setStatusFilter(admin.statusFilter == status ? null : status);
    onOpen?.call();
  };
}

/// One number the admin reads at a glance: what it counts, its icon in the
/// tile's accent, and when it filters the case list, whether that filter
/// is on.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.caption,
    this.active = false,
    this.onTap,
  });

  final String label;

  /// The headline, either a number or a short value like an agreement
  /// percent.
  final Object? value;

  /// Shown under [value] instead of [label] when the tile needs a bit of
  /// context.
  final String? caption;
  final IconData icon;
  final Color accent;

  /// True when this tile's status filter is on.
  final bool active;

  /// Null on the informational tiles, which just display.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final empty = value == null || value == '0';
    final foreground = active || !empty
        ? colors.foreground
        : colors.mutedForeground;

    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: .opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const .fromLTRB(
            AppSizes.gap12,
            AppSizes.gap10,
            AppSizes.gap12,
            AppSizes.gap10,
          ),
          decoration: BoxDecoration(
            color: active ? accent.withValues(alpha: 0.08) : colors.card,
            border: Border.all(
              color: active ? accent : colors.border,
              width: active ? 1.5 : 1,
            ),
            borderRadius: .circular(AppSizes.radius12),
          ),
          child: Column(
            crossAxisAlignment: .start,
            spacing: AppSizes.gap6,
            children: [
              Row(
                spacing: AppSizes.gap8,
                children: [
                  Container(
                    width: AppSizes.statIconBox,
                    height: AppSizes.statIconBox,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: .circular(AppSizes.radius8),
                    ),
                    child: Icon(icon, size: AppSizes.icon16, color: accent),
                  ),
                  if (active)
                    Expanded(
                      child: Text(
                        Strings.dashboardFilterOn,
                        textAlign: .end,
                        overflow: .ellipsis,
                        style: theme.typography.body.xs3.copyWith(
                          color: accent,
                          fontWeight: .w600,
                        ),
                      ),
                    ),
                ],
              ),
              Text(
                value == null ? '-' : '$value',
                overflow: .ellipsis,
                style: theme.typography.body.lg.copyWith(
                  fontWeight: .w700,
                  color: foreground,
                ),
              ),
              Text(caption ?? label, overflow: .ellipsis, style: muted(theme)),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle muted(FThemeData theme) =>
      theme.typography.body.xs2.copyWith(color: theme.colors.mutedForeground);
}

/// Right end of the strip on wide screens: green when nothing waits, amber
/// while the model worker still has readings to make.
class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.waiting});

  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final accent = waiting ? AppColors.statWarning : AppColors.statDone;
    final text = waiting ? Strings.statsWaiting : Strings.dashboardClear;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        borderRadius: .circular(AppSizes.radius12),
      ),
      child: Padding(
        padding: const .fromLTRB(
          AppSizes.gap10,
          AppSizes.gap8,
          AppSizes.gap10,
          AppSizes.gap8,
        ),
        child: Row(
          children: [
            Icon(
              waiting ? FLucideIcons.bot : FLucideIcons.circleCheck,
              size: AppSizes.icon18,
              color: accent,
            ),
            const SizedBox(width: AppSizes.gap8),
            Expanded(
              child: Text(
                text,
                maxLines: 3,
                overflow: .ellipsis,
                style: theme.typography.body.xs2.copyWith(
                  color: accent,
                  fontWeight: .w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
