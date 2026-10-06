import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:gui_lungcxr/feature_home/state/review_state.dart';
import 'package:gui_lungcxr/feature_home/widgets/choice_chips.dart';
import 'package:gui_lungcxr/feature_home/widgets/return_note.dart';
import 'package:gui_lungcxr/feature_home/widgets/review_submit_bar.dart';
import 'package:provider/provider.dart';

/// The fields of a loaded review, with the submit bar pinned underneath.
class ReviewForm extends StatefulWidget {
  const new({super.key});

  @override
  State<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<ReviewForm> {
  late final ReviewState _review = context.read<ReviewState>();
  late final _note = TextEditingController(text: _review.note);
  late final _feedbackNote = TextEditingController(text: _review.feedbackNote);

  @override
  void initState() {
    super.initState();
    _note.addListener(() => _review.setNote(_note.text));
    _feedbackNote.addListener(
      () => _review.setFeedbackNote(_feedbackNote.text),
    );
  }

  @override
  void dispose() {
    _note.dispose();
    _feedbackNote.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final submitted = await _review.submit();
    if (!submitted || !mounted) return;
    showFToast(
      context: context,
      icon: const Icon(FLucideIcons.circleCheck),
      title: const Text(Strings.reviewSubmitted),
      description: const Text(Strings.reviewSubmittedDetail),
    );
  }

  @override
  Widget build(BuildContext context) {
    final review = context.watch<ReviewState>();
    final catalog = context.watch<SessionState>().catalog;
    final theme = context.theme;
    final editable = review.editable;
    final heading = theme.typography.body.sm.copyWith(fontWeight: .w600);
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    final returnNote = review.detail?.returnNote;

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const .all(AppSizes.gap12),
            child: Column(
              crossAxisAlignment: .stretch,
              spacing: AppSizes.gap8,
              children: [
                if (returnNote != null && editable)
                  ReturnNote(note: returnNote),
                if (!editable) Text(Strings.readOnly, style: muted),
                Text(Strings.verdict, style: heading),
                ChoiceChips(
                  options: catalog.verdicts,
                  selected: {review.verdict},
                  enabled: editable,
                  onTap: review.toggleVerdict,
                ),
                if (review.verdict == ReviewState.otherDisease) ...[
                  Text(Strings.diseases, style: heading),
                  ChoiceChips(
                    options: catalog.diseases,
                    selected: review.diseases,
                    enabled: editable,
                    onTap: review.toggleDisease,
                  ),
                ],
                Text(Strings.notes, style: heading),
                FTextField.multiline(
                  control: .managed(controller: _note),
                  hint: Strings.notesHint,
                  minLines: 2,
                  maxLines: 4,
                  enabled: editable,
                ),
                Text(Strings.modelWrong, style: heading),
                ChoiceChips(
                  options: catalog.feedbackKinds,
                  selected: {review.feedbackKind},
                  enabled: editable,
                  onTap: review.toggleFeedbackKind,
                ),
                if (review.feedbackKind != null)
                  FTextField(
                    control: .managed(controller: _feedbackNote),
                    hint: Strings.modelWrongHint,
                    enabled: editable,
                  ),
                Text(Strings.furtherTesting, style: heading),
                ChoiceChips(
                  options: catalog.tests,
                  selected: review.tests,
                  enabled: editable,
                  onTap: review.toggleTest,
                ),
                if (review.tests.isNotEmpty) ...[
                  Text(Strings.urgency, style: muted),
                  ChoiceChips(
                    options: catalog.urgencies,
                    selected: {review.urgency},
                    enabled: editable,
                    onTap: review.setUrgency,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (editable) ...[
          const FDivider(style: .delta(padding: .value(.zero))),
          ReviewSubmitBar(onSubmit: _submit),
        ],
      ],
    );
  }
}
