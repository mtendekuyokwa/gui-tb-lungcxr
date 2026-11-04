import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gui_lungcxr/api/api_client.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/feature_home/api/case_api.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';
import 'package:gui_lungcxr/feature_home/state/review_state.dart';

/// The signed-in doctor's assigned cases and the selection. Each case keeps
/// its own editor and review state so work survives switching cases.
class CaseState extends ChangeNotifier {
  new({
    required ApiClient api,
    this.saveDelay,
    this.pollInterval = _pollInterval,
  }) : _api = CaseApi(api);

  final CaseApi _api;

  /// Overrides the review autosave delay; tests use a short one.
  final Duration? saveDelay;

  /// How long after a load to check again while the open case's model
  /// reading is still queued. Tests use a short one.
  final Duration pollInterval;

  /// The worker usually answers within seconds; polling much faster just
  /// hammers the list endpoint.
  static const Duration _pollInterval = Duration(seconds: 5);

  List<CxrCase> _cases = const [];
  bool _loading = true;
  bool _busy = false;
  bool _refreshing = false;
  int? _hiding;
  String? _error;
  int? _selectedId;
  bool _disposed = false;
  String _search = '';
  Timer? _poll;

  final Map<int, ImageEditorState> _editors = {};
  final Map<int, ReviewState> _reviews = {};

  List<CxrCase> get cases => _cases;
  bool get loading => _loading;

  /// True while the doctor's own upload is under way.
  bool get busy => _busy;

  /// True while the list is being fetched again after the first load.
  bool get refreshing => _refreshing;

  /// The case being taken off the list, while that request runs.
  int? get hiding => _hiding;

  String? get error => _error;

  /// The client's search text; the list shows only matching cases.
  String get searchQuery => _search;

  void setSearchQuery(String value) {
    if (value == _search) return;
    _search = value;
    _notify();
  }

  /// Cases matching [_search] by patient name or client ID. The selection
  /// is kept even while filtered out, so typing never loses the open case.
  List<CxrCase> get visibleCases {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return _cases;
    return [
      for (final c in _cases)
        if (c.patientName.toLowerCase().contains(query) ||
            c.displayId.toLowerCase().contains(query))
          c,
    ];
  }

  CxrCase? get selected {
    for (final c in _cases) {
      if (c.id == _selectedId) return c;
    }
    return null;
  }

  Future<void> load() async {
    if (!_loading) {
      _refreshing = true;
      _notify();
    }
    try {
      _cases = await _api.cases();
      _error = null;
      if (selected == null) _selectedId = _cases.firstOrNull?.id;
    } on ApiException catch (e) {
      _error = e.message;
    }
    _loading = false;
    _refreshing = false;
    _notify();
    _schedulePoll();
  }

  /// The doctor's own upload: creates a case owned by them and selects it.
  Future<bool> upload({
    required String patientName,
    required String hospitalNumber,
    int? hospitalId,
    required Uint8List bytes,
    required String filename,
  }) async {
    if (_busy) return false;
    _busy = true;
    _error = null;
    _notify();
    var ok = true;
    try {
      final created = await _api.uploadCase(
        patientName: patientName.trim(),
        hospitalNumber: hospitalNumber.trim().isEmpty
            ? null
            : hospitalNumber.trim(),
        hospitalId: hospitalId,
        bytes: bytes,
        filename: filename,
      );
      // Open the new case straight away: the canvas shows its spinner
      // while the image and review load, instead of the old selection.
      _cases = [created, ..._cases.where((c) => c.id != created.id)];
      _selectedId = created.id;
      _notify();
      await load();
      _selectedId = created.id;
    } on ApiException catch (e) {
      _error = e.message;
      ok = false;
    }
    _busy = false;
    _notify();
    _schedulePoll();
    return ok;
  }

  /// Takes a case off this doctor's list (the admin still sees it). The
  /// next case is opened if it was the selected one. Returns whether it
  /// went through, so the caller can offer [unhide] as an undo.
  Future<bool> hide(int id) async {
    if (_hiding != null) return false;
    _hiding = id;
    _error = null;
    _notify();
    var ok = true;
    try {
      await _api.hideCase(id);
      final index = _cases.indexWhere((c) => c.id == id);
      _cases = [
        for (final c in _cases)
          if (c.id != id) c,
      ];
      if (_selectedId == id) {
        _selectedId = _cases.isEmpty
            ? null
            : _cases[index.clamp(0, _cases.length - 1)].id;
      }
      _forget(id);
    } on ApiException catch (e) {
      _error = e.message;
      ok = false;
    }
    _hiding = null;
    _notify();
    _schedulePoll();
    return ok;
  }

  /// Puts a hidden case back on the list and opens it.
  Future<void> unhide(int id) async {
    try {
      await _api.unhideCase(id);
      await load();
      select(id);
    } on ApiException catch (e) {
      _error = e.message;
      _notify();
    }
  }

  /// Drops the per-case state of a case that left the list.
  void _forget(int id) {
    _reviews.remove(id)?.dispose();
    _editors.remove(id)?.dispose();
  }

  void select(int id) {
    if (id == _selectedId) return;
    _selectedId = id;
    notifyListeners();
    _schedulePoll();
  }

  /// Rechecks the list once the worker has had time to answer, but only
  /// while the open case is still waiting — so "Awaiting model" resolves
  /// on its own instead of needing the refresh button.
  void _schedulePoll() {
    _poll?.cancel();
    _poll = null;
    if (_disposed || _loading) return;
    if (selected?.prediction?.state != 'queued') return;
    _poll = Timer(pollInterval, () {
      if (!_disposed) load();
    });
  }

  String imageUrl(int id) => _api.imageUrl(id);
  String overlayUrl(CxrCase c) =>
      _api.overlayUrl(c.id, version: c.prediction?.id);
  String maskUrl(CxrCase c) => _api.maskUrl(c.id, version: c.prediction?.id);

  /// Runs the patient search behind the upload form's suggestions.
  Future<List<AppPatient>> patients(String query) => _api.patients(query);

  /// Hospital lookup behind the upload form.
  Future<List<AppHospital>> hospitals(String query) => _api.hospitals(query);

  /// Adds a hospital from the upload form.
  Future<AppHospital> createHospital(String name) => _api.createHospital(name);

  /// Headers the image widgets need to load [imageUrl] and [overlayUrl].
  Map<String, String> get imageHeaders => _api.imageHeaders;

  ImageEditorState editorFor(int id) =>
      _editors.putIfAbsent(id, ImageEditorState.new);

  /// Created on first use, which also loads the case from the backend.
  ReviewState reviewFor(int id) => _reviews.putIfAbsent(id, () {
    final delay = saveDelay;
    final editor = editorFor(id);
    final review = delay == null
        ? ReviewState(
            api: _api,
            caseId: id,
            editor: editor,
            onCaseChanged: _replace,
          )
        : ReviewState(
            api: _api,
            caseId: id,
            editor: editor,
            onCaseChanged: _replace,
            saveDelay: delay,
          );
    return review..load();
  });

  /// Keeps the list row in step with a case the review just reloaded, and
  /// polls again if it now waits on the model (e.g. after a re-evaluation).
  void _replace(CxrCase updated) {
    _cases = [
      for (final c in _cases)
        if (c.id == updated.id) updated else c,
    ];
    _notify();
    _schedulePoll();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    for (final review in _reviews.values) {
      review.dispose();
    }
    for (final editor in _editors.values) {
      editor.dispose();
    }
    super.dispose();
  }
}
