import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gui_lungcxr/api/api_client.dart';
import 'package:gui_lungcxr/constants/endpoints.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
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

  final ApiClient api;
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
  int _seenMarkRevision = 0;

  CxrCase? get detail => _detail;
  bool get loading => _loading;
  String? get error => _error;
  SaveStatus get saveStatus => _saveStatus;
  bool get editable => _detail?.status.editable ?? false;

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
      _apply(await api.get(Endpoints.caseDetail(caseId)), loadDraft: true);
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    }
    _loading = false;
    _notify();
  }

  void setVerdict(String? value) => _edit(() => _verdict = value);
  void setNote(String value) {
    if (value != _note) _edit(() => _note = value);
  }

  void toggleDisease(String code) => _edit(() => _toggle(_diseases, code));
  void setFeedbackKind(String? value) => _edit(() => _feedbackKind = value);
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
    if (editor.markRevision == _seenMarkRevision) return;
    _seenMarkRevision = editor.markRevision;
    if (!_applying && editable) _changed();
  }

  void _changed() {
    _dirty = true;
    _saveStatus = .unsaved;
    _timer?.cancel();
    _timer = Timer(saveDelay, save);
    _notify();
  }

  Map<String, dynamic> toJson() => {
    'verdict': _verdict,
    'note': _note,
    'marks': [for (final mark in editor.marks) markToJson(mark)],
    'disease_tags': _verdict == otherDisease ? _diseases.toList() : const [],
    'model_feedback': _feedbackKind == null
        ? null
        : {'kind': _feedbackKind, 'note': _feedbackNote},
    'further_testing': _tests.isEmpty
        ? null
        : {'tests': _tests.toList(), 'urgency': _urgency},
  };

  /// Saves the draft now if anything changed since the last save.
  Future<void> save() async {
    _timer?.cancel();
    if (!_dirty || !editable || _saving) return;
    _saving = true;
    _dirty = false;
    _saveStatus = .saving;
    _notify();
    try {
      _apply(await api.put(Endpoints.review(caseId), toJson()));
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
    if (!canSubmit) return false;
    _dirty = true; // always send the latest state before locking
    await save();
    if (_saveStatus == .failed || _dirty) return false;
    try {
      _apply(await api.post(Endpoints.submitReview(caseId)));
      _error = null;
      _saveStatus = .idle;
      _notify();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _notify();
      return false;
    }
  }

  void _apply(dynamic json, {bool loadDraft = false}) {
    // A response can arrive after sign-out has disposed this and the editor.
    if (_disposed) return;
    final detail = CxrCase.fromJson(json as Map<String, dynamic>);
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
    }
    _seenMarkRevision = editor.markRevision;
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
