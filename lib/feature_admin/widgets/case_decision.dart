import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:provider/provider.dart';

/// Accepts a submitted review, or returns it to the doctor with a note.
class CaseDecision extends StatefulWidget {
  const new({required this.caseId, super.key});

  final int caseId;

  @override
  State<CaseDecision> createState() => _CaseDecisionState();
}

class _CaseDecisionState extends State<CaseDecision> {
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Returning needs a note, so the button follows the field.
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
    final id = widget.caseId;

    return Column(
      crossAxisAlignment: .stretch,
      spacing: AppSizes.gap8,
      children: [
        FButton(
          size: .sm,
          onPress: admin.busy ? null : () => admin.accept(id),
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
              : () => admin.returnToDoctor(id, _note.text),
          prefix: const Icon(FLucideIcons.undo2),
          child: const Text(Strings.returnToDoctor),
        ),
      ],
    );
  }
}
