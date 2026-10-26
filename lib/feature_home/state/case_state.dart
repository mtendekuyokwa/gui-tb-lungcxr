import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gui_lungcxr/api/api_client.dart';
import 'package:gui_lungcxr/feature_home/api/case_api.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:gui_lungcxr/feature_home/state/chat_state.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';
import 'package:gui_lungcxr/feature_home/state/review_state.dart';

/// The signed-in doctor's assigned cases and the selection. Each case keeps
/// its own editor, review and chat state so work survives switching cases.
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
  String? _error;
  int? _selectedId;
  bool _disposed = false;
  String _search = '';
  Timer? _poll;

  final Map<int, ImageEditorState> _editors = {};
  final Map<int, ChatState> _chats = {};
  final Map<int, ReviewState> _reviews = {};

  List<CxrCase> get cases => _cases;
  bool get loading => _loading;
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
    try {
      _cases = await _api.cases();
      _error = null;
      if (selected == null) _selectedId = _cases.firstOrNull?.id;
    } on ApiException catch (e) {
      _error = e.message;
    }
    _loading = false;
    _notify();
    _schedulePoll();
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
  String overlayUrl(int id) => _api.overlayUrl(id);
  String maskUrl(int id) => _api.maskUrl(id);

  /// Headers the image widgets need to load [imageUrl] and [overlayUrl].
  Map<String, String> get imageHeaders => _api.imageHeaders;

  ImageEditorState editorFor(int id) =>
      _editors.putIfAbsent(id, ImageEditorState.new);

  ChatState chatFor(int id) => _chats.putIfAbsent(id, ChatState.new);

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

  /// Keeps the list row in step with a case the review just reloaded.
  void _replace(CxrCase updated) {
    _cases = [
      for (final c in _cases)
        if (c.id == updated.id) updated else c,
    ];
    _notify();
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
    for (final chat in _chats.values) {
      chat.dispose();
    }
    super.dispose();
  }
}
