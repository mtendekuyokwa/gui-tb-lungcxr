import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:gui_lungcxr/feature_home/state/review_state.dart';
import 'package:gui_lungcxr/feature_home/widgets/choice_chips.dart';
import 'package:provider/provider.dart';

/// The doctor's review of the selected case: verdict, disease tags, whether
/// the model was wrong, and further testing. Saved as a draft as it changes.
class ReviewPanel extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final review = context.watch<ReviewState>();
    final theme = context.theme;

    final Widget body;
    if (review.loading) {
      body = const Center(child: FCircularProgress());
    } else if (review.detail == null) {
      body = Center(
        child: Column(
          mainAxisSize: .min,
          spacing: 8,
          children: [
            Text(
              review.error ?? Strings.somethingWentWrong,
              textAlign: .center,
              style: theme.typography.body.sm,
            ),
            FButton(
              variant: .outline,
              size: .sm,
              mainAxisSize: .min,
              onPress: review.load,
              child: const Text(Strings.retry),
            ),
          ],
        ),
      );
    } else {
      body = const _ReviewForm();
    }

    return Padding(
      padding: const .fromLTRB(8, 0, 8, 8),
      child: FCard(clipBehavior: .antiAlias, child: body),
    );
  }
}

class _ReviewForm extends StatefulWidget {
  const new();

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
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
            padding: const .all(12),
            child: Column(
              crossAxisAlignment: .stretch,
              spacing: 8,
              children: [
                if (returnNote != null && editable)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: .all(color: theme.colors.destructive),
                      borderRadius: .circular(6),
                    ),
                    child: Padding(
                      padding: const .all(8),
                      child: Column(
                        crossAxisAlignment: .start,
                        spacing: 2,
                        children: [
                          Text(Strings.returnedByAdmin, style: heading),
                          Text(returnNote, style: theme.typography.body.sm),
                        ],
                      ),
                    ),
                  ),
                if (!editable) Text(Strings.readOnly, style: muted),
                Text(Strings.verdict, style: heading),
                ChoiceChips(
                  options: catalog.verdicts,
                  selected: {review.verdict},
                  enabled: editable,
                  onTap: (code) =>
                      review.setVerdict(code == review.verdict ? null : code),
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
                  onTap: (code) => review.setFeedbackKind(
                    code == review.feedbackKind ? null : code,
                  ),
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
          Padding(
            padding: const .all(12),
            child: Row(
              spacing: 8,
              children: [
                Expanded(
                  child: Text(_statusLine(review), style: muted, maxLines: 2),
                ),
                FButton(
                  size: .sm,
                  mainAxisSize: .min,
                  onPress: review.canSubmit && review.saveStatus != .saving
                      ? _submit
                      : null,
                  child: const Text(Strings.submitReview),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _statusLine(ReviewState review) {
    if (review.saveStatus == .failed) {
      return '${Strings.saveFailed}: ${review.error ?? ''}';
    }
    if (review.error case final error?) return error;
    if (review.verdict == null) return Strings.verdictRequired;
    if (!review.canSubmit) return Strings.diseaseRequired;
    return switch (review.saveStatus) {
      .unsaved => Strings.saveUnsaved,
      .saving => Strings.saveSaving,
      .saved => Strings.saveSaved,
      .idle || .failed => '',
    };
  }
}
