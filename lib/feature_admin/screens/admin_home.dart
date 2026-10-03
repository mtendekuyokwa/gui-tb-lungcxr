import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:gui_lungcxr/feature_home/widgets/choice_chips.dart';
import 'package:provider/provider.dart';

/// The hospital admin's workspace: every case on the left; upload, assign
/// and the selected case's review on the right.
class AdminHome extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final theme = context.theme;

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const _AdminHeader(),
        if (admin.error case final error?)
          Padding(
            padding: const .fromLTRB(16, 8, 16, 0),
            child: Text(
              error,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.destructive,
              ),
            ),
          ),
        Expanded(
          child: admin.loading
              ? const Center(child: FCircularProgress())
              : Row(
                  crossAxisAlignment: .stretch,
                  children: [
                    const Expanded(child: _CaseList()),
                    SizedBox(
                      width: 380,
                      child: SingleChildScrollView(
                        padding: const .fromLTRB(0, 12, 12, 12),
                        child: Column(
                          crossAxisAlignment: .stretch,
                          spacing: 12,
                          children: [
                            const _UploadCard(),
                            const _AssignCard(),
                            // Fresh form state per opened case.
                            _DetailCard(key: ValueKey(admin.open?.id)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _AdminHeader extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final admin = context.read<AdminState>();
    final theme = context.theme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.background,
        border: Border(bottom: BorderSide(color: theme.colors.border)),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 16, vertical: 10),
        child: Row(
          spacing: 8,
          children: [
            const Icon(FLucideIcons.scanEye),
            Text(Strings.appName, style: theme.typography.display.lg),
            const Spacer(),
            Text(
              session.user?.fullName ?? '',
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            FTooltip(
              tipBuilder: (_, _) => const Text(Strings.refresh),
              child: FButton.icon(
                variant: .ghost,
                size: .sm,
                onPress: admin.load,
                child: const Icon(FLucideIcons.refreshCw),
              ),
            ),
            FTooltip(
              tipBuilder: (_, _) => const Text(Strings.signOut),
              child: FButton.icon(
                variant: .ghost,
                size: .sm,
                onPress: session.logout,
                child: const Icon(FLucideIcons.logOut),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaseList extends StatelessWidget {
  const new();

  static const _all = 'all';

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final theme = context.theme;

    return Padding(
      padding: const .all(12),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 12,
        children: [
          ChoiceChips(
            options: [
              const Option(_all, Strings.all),
              for (final status in CaseStatus.values)
                Option(status.code, status.label),
            ],
            selected: {admin.statusFilter?.code ?? _all},
            onTap: (code) => admin.setStatusFilter(
              code == _all ? null : CaseStatus.fromCode(code),
            ),
          ),
          Expanded(
            child: admin.cases.isEmpty
                ? Center(
                    child: Text(
                      Strings.noCasesAdmin,
                      style: theme.typography.body.sm.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: admin.cases.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _CaseRow(item: admin.cases[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CaseRow extends StatelessWidget {
  const new({required this.item});

  final CxrCase item;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final catalog = context.watch<SessionState>().catalog;
    final theme = context.theme;
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    final ticked = admin.ticked.contains(item.id);
    final isOpen = admin.open?.id == item.id;
    final details = [
      item.doctorName ?? Strings.statusUnassigned,
      if (item.verdict != null) catalog.label(catalog.verdicts, item.verdict),
    ].join(' · ');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: .opaque,
        onTap: () => admin.openCase(item.id),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isOpen ? theme.colors.secondary : theme.colors.background,
            border: .all(color: theme.colors.border),
            borderRadius: .circular(8),
          ),
          child: Padding(
            padding: const .symmetric(horizontal: 8, vertical: 6),
            child: Row(
              spacing: 10,
              children: [
                FButton.icon(
                  variant: .ghost,
                  size: .sm,
                  // Submitted and accepted cases cannot be reassigned.
                  onPress: item.status.assignable
                      ? () => admin.toggleTicked(item.id)
                      : null,
                  child: Icon(
                    ticked ? FLucideIcons.squareCheck : FLucideIcons.square,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: 2,
                    children: [
                      Text(
                        '${item.patientName}  ${item.displayId}',
                        overflow: .ellipsis,
                        style: theme.typography.body.sm.copyWith(
                          fontWeight: .w600,
                        ),
                      ),
                      Text(details, overflow: .ellipsis, style: muted),
                    ],
                  ),
                ),
                if (item.modelWrong)
                  const FTooltip(
                    tipBuilder: _modelWrongTip,
                    child: Icon(FLucideIcons.bot, size: 16),
                  ),
                if (item.needsTesting)
                  const FTooltip(
                    tipBuilder: _needsTestingTip,
                    child: Icon(FLucideIcons.flaskConical, size: 16),
                  ),
                FBadge(
                  variant: switch (item.status) {
                    .submitted => .primary,
                    .returned => .destructive,
                    .accepted => .secondary,
                    _ => .outline,
                  },
                  child: Text(item.status.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _modelWrongTip(BuildContext _, FTooltipController _) =>
      const Text(Strings.flagModelWrong);

  static Widget _needsTestingTip(BuildContext _, FTooltipController _) =>
      const Text(Strings.flagNeedsTesting);
}

class _Section extends StatelessWidget {
  const new({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => FCard(
    child: Padding(
      padding: const .all(16),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 8,
        children: [
          Text(
            title,
            style: context.theme.typography.body.sm.copyWith(fontWeight: .w600),
          ),
          ...children,
        ],
      ),
    ),
  );
}

class _UploadCard extends StatefulWidget {
  const new();

  @override
  State<_UploadCard> createState() => _UploadCardState();
}

class _UploadCardState extends State<_UploadCard> {
  final _name = TextEditingController();
  final _number = TextEditingController();
  PlatformFile? _file;

  @override
  void initState() {
    super.initState();
    // The upload button depends on whether a name has been typed.
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
    );
    if (files.isNotEmpty && mounted) setState(() => _file = files.first);
  }

  Future<void> _upload(AdminState admin) async {
    final file = _file;
    if (file == null) return;
    final ok = await admin.upload(
      patientName: _name.text,
      hospitalNumber: _number.text,
      bytes: await file.readAsBytes(),
      filename: file.name,
    );
    if (!ok || !mounted) return;
    _name.clear();
    _number.clear();
    setState(() => _file = null);
    showFToast(
      context: context,
      icon: const Icon(FLucideIcons.circleCheck),
      title: const Text(Strings.caseUploaded),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final ready = _file != null && _name.text.trim().isNotEmpty && !admin.busy;

    return _Section(
      title: Strings.uploadCase,
      children: [
        FTextField(
          control: .managed(controller: _name),
          hint: Strings.patientName,
        ),
        FTextField(
          control: .managed(controller: _number),
          hint: Strings.hospitalNumber,
        ),
        FButton(
          variant: .outline,
          size: .sm,
          onPress: _choose,
          prefix: const Icon(FLucideIcons.image),
          child: Flexible(
            child: Text(
              _file?.name ?? Strings.chooseImage,
              overflow: .ellipsis,
            ),
          ),
        ),
        FButton(
          size: .sm,
          onPress: ready ? () => _upload(admin) : null,
          prefix: const Icon(FLucideIcons.upload),
          child: const Text(Strings.upload),
        ),
      ],
    );
  }
}

class _AssignCard extends StatefulWidget {
  const new();

  @override
  State<_AssignCard> createState() => _AssignCardState();
}

class _AssignCardState extends State<_AssignCard> {
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

    return _Section(
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

class _DetailCard extends StatefulWidget {
  const new({super.key});

  @override
  State<_DetailCard> createState() => _DetailCardState();
}

class _DetailCardState extends State<_DetailCard> {
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final session = context.watch<SessionState>();
    final catalog = session.catalog;
    final theme = context.theme;
    final body = theme.typography.body.sm;
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    final item = admin.open;
    if (item == null) {
      return _Section(
        title: Strings.caseDetail,
        children: [Text(Strings.selectCase, style: muted)],
      );
    }

    Widget line(String label, String value) => Column(
      crossAxisAlignment: .start,
      children: [
        Text(label, style: muted),
        Text(value, style: body),
      ],
    );

    final prediction = item.prediction;
    final percent = ((prediction?.tbProbability ?? 0) * 100).round();
    final reading = switch (prediction?.state) {
      'done' when prediction?.label == 'tb' => '${Strings.modelTb} · $percent%',
      'done' => '${Strings.modelNormal} · TB $percent%',
      'failed' => Strings.modelFailed,
      _ => Strings.awaitingModel,
    };
    final review = item.review;
    final findings = {
      for (final mark in review?.marks ?? const [])
        mark.lesion?.label ?? Strings.unlabelled,
    };

    return _Section(
      title: '${Strings.caseDetail} ${item.displayId} · ${item.patientName}',
      children: [
        ClipRRect(
          borderRadius: .circular(6),
          child: ColoredBox(
            color: const Color(0xFF0B0D0E),
            child: SizedBox(
              height: 200,
              child: Image.network(
                admin.imageUrl(item.id),
                headers: session.api.authHeaders,
                fit: .contain,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(FLucideIcons.imageOff, color: Colors.white70),
                ),
              ),
            ),
          ),
        ),
        line(Strings.doctor, item.doctorName ?? Strings.statusUnassigned),
        line(Strings.modelReading, reading),
        if (review == null)
          Text(Strings.noReviewYet, style: muted)
        else ...[
          line(
            Strings.verdict,
            catalog.label(catalog.verdicts, review.verdict),
          ),
          if (review.diseases.isNotEmpty)
            line(
              Strings.diseases,
              review.diseases
                  .map((code) => catalog.label(catalog.diseases, code))
                  .join(', '),
            ),
          if (review.note.isNotEmpty) line(Strings.notes, review.note),
          line(
            Strings.marks,
            review.marks.isEmpty
                ? Strings.none
                : '${review.marks.length} · ${findings.join(', ')}',
          ),
          if (review.feedbackKind case final kind?)
            line(
              Strings.flagModelWrong,
              [
                catalog.label(catalog.feedbackKinds, kind),
                if (review.feedbackDerived) '(${Strings.flaggedByServer})',
                if (review.feedbackNote.isNotEmpty) '— ${review.feedbackNote}',
              ].join(' '),
            ),
          if (review.tests.isNotEmpty)
            line(
              Strings.flagNeedsTesting,
              '${review.tests.map((code) => catalog.label(catalog.tests, code)).join(', ')}'
              ' · ${catalog.label(catalog.urgencies, review.urgency)}',
            ),
        ],
        if (item.status == .submitted) ...[
          FButton(
            size: .sm,
            onPress: admin.busy ? null : () => admin.accept(item.id),
            prefix: const Icon(FLucideIcons.check),
            child: const Text(Strings.accept),
          ),
          FTextField(
            control: .managed(controller: _note),
            hint: Strings.returnNoteHint,
          ),
          FButton(
            variant: .outline,
            size: .sm,
            onPress: admin.busy || _note.text.trim().isEmpty
                ? null
                : () => admin.returnToDoctor(item.id, _note.text.trim()),
            prefix: const Icon(FLucideIcons.undo2),
            child: const Text(Strings.returnToDoctor),
          ),
        ],
      ],
    );
  }
}
