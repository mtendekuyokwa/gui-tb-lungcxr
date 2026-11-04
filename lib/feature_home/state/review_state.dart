import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gui_lungcxr/api/api_client.dart';
import 'package:gui_lungcxr/feature_home/api/case_api.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:gui_lungcxr/feature_home/models/review_draft.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';

enum SaveStatus { idle, unsaved, saving, saved, failed }

/// One doctor's review of one case: verdict, flags and the editor's marks.
/// Changes are saved to the backend as a draft shortly after they stop.
class ReviewState extends ChangeNotifier {
  new({
    required this.api,
    required this.caseId,
    required this.editor,
    required this.onCaseChanged,
    this.saveDelay = const Duration(milliseconds: 900),
  }) {
    editor.addListener(_onEditorChanged);
  }

  static const otherDisease = 'other_disease';
  static const defaultUrgency = 'routine';

  final CaseApi api;
  final int caseId;
  final ImageEditorState editor;
  final ValueChanged<CxrCase> onCaseChanged;
  final Duration saveDelay;

  CxrCase? _detail;
  bool _loading = true;
  String? _error;
  SaveStatus _saveStatus = .idle;

  String? _verdict;
  String _note = '';
  final Set<String> _diseases = {};
  String? _feedbackKind;
  String _feedbackNote = '';
  final Set<String> _tests = {};
  String _urgency = defaultUrgency;

  Timer? _timer;
  bool _dirty = false;
  bool _saving = false;
  bool _applying = false;
  bool _disposed = false;
  bool _submitting = false;
  bool _reevaluating = false;
  int _seenMarkRevision = 0;
  int _seenMaskRevision = 0;

  CxrCase? get detail => _detail;
  bool get loading => _loading;
  String? get error => _error;
  SaveStatus get saveStatus => _saveStatus;
  bool get editable => _detail?.status.editable ?? false;

  /// True while [submit] runs.
  bool get submitting => _submitting;

  /// True while [reevaluate] runs.
  bool get reevaluating => _reevaluating;

  String? get verdict => _verdict;
  String get note => _note;
  Set<String> get diseases => _diseases;
  String? get feedbackKind => _feedbackKind;
  String get feedbackNote => _feedbackNote;
  Set<String> get tests => _tests;
  String get urgency => _urgency;

  /// The backend refuses a submission that fails this.
  bool get canSubmit =>
      editable &&
      _verdict != null &&
      (_verdict != otherDisease || _diseases.isNotEmpty);

  /// Fetches the case, which also marks it as opened on the backend.
  Future<void> load() async {
    try {
      _apply(await api.caseDetail(caseId), loadDraft: true);
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    }
    _loading = false;
    _notify();
  }

  void setVerdict(String? value) => _edit(() => _verdict = value);

  /// Picks [code], or clears the verdict when it is already picked.
  void toggleVerdict(String code) => setVerdict(code == _verdict ? null : code);
  void setNote(String value) {
    if (value != _note) _edit(() => _note = value);
  }

  void toggleDisease(String code) => _edit(() => _toggle(_diseases, code));
  void setFeedbackKind(String? value) => _edit(() => _feedbackKind = value);

  /// Picks [code], or withdraws the flag when it is already picked.
  void toggleFeedbackKind(String code) =>
      setFeedbackKind(code == _feedbackKind ? null : code);
  void setFeedbackNote(String value) {
    if (value != _feedbackNote) _edit(() => _feedbackNote = value);
  }

  void toggleTest(String code) => _edit(() => _toggle(_tests, code));
  void setUrgency(String value) => _edit(() => _urgency = value);

  void _toggle(Set<String> set, String code) {
    if (!set.remove(code)) set.add(code);
  }

  void _edit(VoidCallback change) {
    if (!editable) return;
    change();
    _changed();
  }

  void _onEditorChanged() {
    var changed = false;
    if (editor.markRevision != _seenMarkRevision) {
      _seenMarkRevision = editor.markRevision;
      changed = true;
    }
    if (editor.maskRevision != _seenMaskRevision) {
      _seenMaskRevision = editor.maskRevision;
      changed = true;
    }
    if (changed && !_applying && editable) _changed();
  }

  void _changed() {
    _dirty = true;
    _saveStatus = .unsaved;
    _timer?.cancel();
    _timer = Timer(saveDelay, save);
    _notify();
  }

  ReviewDraft get draft => ReviewDraft(
    verdict: _verdict,
    note: _note,
    marks: editor.marks,
    maskEdits: editor.maskEdits,
    // Disease tags only mean something under the "other disease" verdict.
    diseases: _verdict == otherDisease ? _diseases.toList() : const [],
    feedbackKind: _feedbackKind,
    feedbackNote: _feedbackNote,
    tests: _tests.toList(),
    urgency: _urgency,
  );

  /// Saves the draft now if anything changed since the last save.
  Future<void> save() async {
    _timer?.cancel();
    if (!_dirty || !editable || _saving) return;
    _saving = true;
    _dirty = false;
    _saveStatus = .saving;
    _notify();
    try {
      _apply(await api.saveReview(caseId, draft));
      _error = null;
      _saveStatus = _dirty ? .unsaved : .saved;
    } on ApiException catch (e) {
      _dirty = true;
      _error = e.message;
      _saveStatus = .failed;
    }
    _saving = false;
    _notify();
    // Edits made while the request was in flight.
    if (_dirty && _saveStatus != .failed && !_disposed) {
      _timer = Timer(saveDelay, save);
    }
  }

  /// Saves, then locks the review and hands the case back to the admin.
  Future<bool> submit() async {
    if (!canSubmit || _submitting) return false;
    _submitting = true;
    _notify();
    try {
      _dirty = true; // always send the latest state before locking
      await save();
      if (_saveStatus == .failed || _dirty) return false;
      _apply(await api.submitReview(caseId));
      _error = null;
      _saveStatus = .idle;
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _submitting = false;
      _notify();
    }
  }

  /// Whether the mask corrections can be sent back to the model. The
  /// backend also needs a finished model mask; the caller checks that.
  bool get canReevaluate =>
      editable && editor.hasMaskEdits && !_reevaluating && !_submitting;

  /// Saves the mask corrections, then has the model classify the X-ray
  /// again with them baked into the lung mask. The corrections are cleared
  /// afterwards: the new mask already contains them.
  Future<bool> reevaluate() async {
    if (!canReevaluate) return false;
    _reevaluating = true;
    _notify();
    try {
      _dirty = true; // the backend reads the saved draft's corrections
      await save();
      if (_saveStatus == .failed || _dirty) return false;
      _apply(await api.reevaluate(caseId), reloadMaskEdits: true);
      _error = null;
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _reevaluating = false;
      _notify();
    }
  }

  void _apply(
    CxrCase detail, {
    bool loadDraft = false,
    bool reloadMaskEdits = false,
  }) {
    // A response can arrive after sign-out has disposed this and the editor.
    if (_disposed) return;
    _detail = detail;
    _applying = true;
    editor.locked = !detail.status.editable;
    if (loadDraft) {
      final review = detail.review;
      _verdict = review?.verdict;
      _note = review?.note ?? '';
      _diseases
        ..clear()
        ..addAll(review?.diseases ?? const []);
      // A derived flag is the server's, not the doctor's; it is recomputed on
      // submit, so it is not loaded as if the doctor had chosen it.
      final derived = review?.feedbackDerived ?? false;
      _feedbackKind = derived ? null : review?.feedbackKind;
      _feedbackNote = derived ? '' : review?.feedbackNote ?? '';
      _tests
        ..clear()
        ..addAll(review?.tests ?? const []);
      _urgency = review?.urgency ?? defaultUrgency;
      editor.replaceMarks(review?.marks ?? const []);
      editor.replaceMaskEdits(review?.maskEdits ?? const []);
    } else if (reloadMaskEdits) {
      editor.replaceMaskEdits(detail.review?.maskEdits ?? const []);
    }
    _seenMarkRevision = editor.markRevision;
    _seenMaskRevision = editor.maskRevision;
    _applying = false;
    onCaseChanged(detail);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    editor.removeListener(_onEditorChanged);
    super.dispose();
  }
}
