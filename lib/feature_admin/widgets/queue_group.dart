import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/utils/dashboard_text.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:provider/provider.dart';

/// One queue of cases waiting on the admin, longest-waiting first: who has
/// each case and for how long, with the next step one press away. When the
/// queue holds more than it shows, the last row lists them all.
class QueueGroup extends StatelessWidget {
  const new({required this.kind, required this.queue, this.onOpen, super.key});

  final AdminQueueKind kind;
  final AdminQueue queue;

  /// Called after a row prepares the Cases page, to move there.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final admin = context.read<AdminState>();
    final now = DateTime.now();
    final (title, empty, action) = switch (kind) {
      AdminQueueKind.signOff => (
        Strings.queueSignOff,
        Strings.queueEmptySignOff,
        Strings.actionReview,
      ),
      AdminQueueKind.overdue => (
        Strings.queueOverdue,
        Strings.queueEmptyOverdue,
        Strings.actionOpen,
      ),
      AdminQueueKind.unassigned => (
        Strings.queueUnassigned,
        Strings.queueEmptyUnassigned,
        Strings.actionAssign,
      ),
    };

    Future<void> act(CxrCase c) => kind == AdminQueueKind.unassigned
        ? admin.pickForAssignment(c.id)
        : admin.openFromQueue(c);

    // The case list has no past-due filter, so that queue's heading count
    // stands alone rather than linking to a list that would not match.
    final CaseStatus? listStatus = switch (kind) {
      AdminQueueKind.signOff => CaseStatus.submitted,
      AdminQueueKind.unassigned => CaseStatus.unassigned,
      AdminQueueKind.overdue => null,
    };

    return FTileGroup(
      label: Text(queue.count == 0 ? title : '$title (${queue.count})'),
      children: [
        if (queue.cases.isEmpty)
          FTile(prefix: const Icon(FLucideIcons.check), title: Text(empty)),
        for (final c in queue.cases)
          FTile(
            title: Text(c.patientName),
            subtitle: Text(queueLine(c, kind, now)),
            details: Text(action),
            suffix: const Icon(FLucideIcons.chevronRight),
            onPress: () {
              act(c);
              onOpen?.call();
            },
          ),
        if (listStatus != null && queue.count > queue.cases.length)
          FTile(
            title: Text('${Strings.showAll} ${queue.count}'),
            suffix: const Icon(FLucideIcons.chevronRight),
            onPress: () {
              admin.showOnly(status: listStatus);
              onOpen?.call();
            },
          ),
      ],
    );
  }
}
