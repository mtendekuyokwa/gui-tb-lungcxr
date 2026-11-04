import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/utils/save_csv.dart';
import 'package:gui_lungcxr/feature_admin/widgets/admin_section.dart';
import 'package:gui_lungcxr/widgets/busy_icon.dart';
import 'package:provider/provider.dart';

/// The CSV exports: each one downloads as a `.csv` file (a browser download
/// on web, a save dialog elsewhere) or copies to the clipboard for pasting
/// straight into a spreadsheet.
class ExportCard extends StatefulWidget {
  const new({super.key});

  @override
  State<ExportCard> createState() => _ExportCardState();
}

/// What the doctor's work can be exported as: backend kind, label, icon.
const _exports = [
  ('reviews', Strings.exportReviews, FLucideIcons.table),
  ('model_feedback', Strings.exportFeedback, FLucideIcons.bot),
];

class _ExportCardState extends State<ExportCard> {
  /// The export being fetched, and whether it is being downloaded (not
  /// copied), so only that button spins.
  (String, bool)? _working;
  String? _lastLine;

  Future<void> _export(
    AdminState admin,
    String kind, {
    required bool download,
  }) async {
    setState(() => _working = (kind, download));
    final csv = await admin.exportCsv(kind);
    if (csv == null || !mounted) {
      if (mounted) setState(() => _working = null);
      return;
    }
    final rows = _rows(csv);
    String? message;
    if (download) {
      final name = exportFileName(kind, DateTime.now());
      if (await saveCsv(csv, name))
        message = '$rows ${Strings.exportSaved} $name';
    } else {
      await Clipboard.setData(ClipboardData(text: csv));
      message = '$rows ${Strings.exportCopied}';
    }
    if (!mounted) return;
    setState(() {
      _working = null;
      if (message != null) _lastLine = message;
    });
    if (message == null) return; // save dialog cancelled
    showFToast(
      context: context,
      icon: Icon(
        download ? FLucideIcons.download : FLucideIcons.clipboardCheck,
      ),
      title: Text(message),
    );
  }

  static int _rows(String csv) => csv.trim().split('\n').length - 1;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final theme = context.theme;
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    final idle = !admin.busy && _working == null;

    return AdminSection(
      title: Strings.export,
      subtitle: Strings.exportHint,
      children: [
        for (final (kind, label, icon) in _exports)
          Row(
            spacing: AppSizes.gap8,
            children: [
              Icon(
                icon,
                size: AppSizes.icon16,
                color: theme.colors.mutedForeground,
              ),
              Expanded(
                child: Text(
                  label,
                  overflow: .ellipsis,
                  style: theme.typography.body.sm,
                ),
              ),
              FButton(
                size: .sm,
                mainAxisSize: .min,
                onPress: idle
                    ? () => _export(admin, kind, download: true)
                    : null,
                prefix: BusyIcon(
                  busy: _working == (kind, true),
                  icon: FLucideIcons.download,
                ),
                child: const Text(Strings.exportDownload),
              ),
              FTooltip(
                tipBuilder: (_, _) => const Text(Strings.exportCopy),
                child: FButton.icon(
                  variant: .outline,
                  size: .sm,
                  onPress: idle
                      ? () => _export(admin, kind, download: false)
                      : null,
                  child: _working == (kind, false)
                      ? const FCircularProgress(size: .sm)
                      : const Icon(FLucideIcons.copy),
                ),
              ),
            ],
          ),
        if (_lastLine case final line?)
          Text(line, style: muted, overflow: .ellipsis),
      ],
    );
  }
}
