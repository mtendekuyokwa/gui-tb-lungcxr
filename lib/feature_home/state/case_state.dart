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
  new({required ApiClient api, this.saveDelay}) : _api = CaseApi(api);

  final CaseApi _api;

  /// Overrides the review autosave delay; tests use a short one.
  final Duration? saveDelay;

  List<CxrCase> _cases = const [];
  bool _loading = true;
  String? _error;
  int? _selectedId;
  bool _disposed = false;

  final Map<int, ImageEditorState> _editors = {};
  final Map<int, ChatState> _chats = {};
  final Map<int, ReviewState> _reviews = {};

  List<CxrCase> get cases => _cases;
  bool get loading => _loading;
  String? get error => _error;

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
  }

  void select(int id) {
    if (id == _selectedId) return;
    _selectedId = id;
    notifyListeners();
  }

  String imageUrl(int id) => _api.imageUrl(id);
  String overlayUrl(int id) => _api.overlayUrl(id);

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
