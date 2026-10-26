import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/widgets/admin_section.dart';
import 'package:provider/provider.dart';

/// Copies a CSV export to the clipboard (the Read half of export CRUD).
/// A direct file download needs platform download APIs; copying the text
/// pastes straight into a spreadsheet on every platform the app runs on.
class ExportCard extends StatefulWidget {
  const new({super.key});

  @override
  State<ExportCard> createState() => _ExportCardState();
}

class _ExportCardState extends State<ExportCard> {
  String? _kind;
  String? _csv;

  Future<void> _fetch(AdminState admin, String kind) async {
    final csv = await admin.exportCsv(kind);
    if (!mounted) return;
    setState(() {
      _kind = kind;
      _csv = csv;
    });
    if (csv == null) return;
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    showFToast(
      context: context,
      icon: const Icon(FLucideIcons.clipboardCheck),
      title: Text('${_rows(csv)} ${Strings.exportCopied}'),
    );
  }

  static int _rows(String csv) {
    final lines = csv.trim().split('\n');
    return lines.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final theme = context.theme;
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );

    return AdminSection(
      title: Strings.export,
      children: [
        Row(
          spacing: AppSizes.gap8,
          children: [
            Expanded(
              child: FButton(
                size: .sm,
                variant: .outline,
                onPress: admin.busy ? null : () => _fetch(admin, 'reviews'),
                prefix: const Icon(FLucideIcons.table),
                child: const Flexible(
                  child: Text(Strings.exportReviews, overflow: .ellipsis),
                ),
              ),
            ),
            Expanded(
              child: FButton(
                size: .sm,
                variant: .outline,
                onPress: admin.busy
                    ? null
                    : () => _fetch(admin, 'model_feedback'),
                prefix: const Icon(FLucideIcons.bot),
                child: const Flexible(
                  child: Text(Strings.exportFeedback, overflow: .ellipsis),
                ),
              ),
            ),
          ],
        ),
        if (_csv case final csv?)
          Text(
            '${_kind ?? ''}: ${_rows(csv)} ${Strings.exportRows}',
            style: muted,
            overflow: .ellipsis,
          ),
      ],
    );
  }
}
