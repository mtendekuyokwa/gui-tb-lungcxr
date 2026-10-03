import 'package:flutter/foundation.dart';
import 'package:gui_lungcxr/api/api_client.dart';
import 'package:gui_lungcxr/constants/endpoints.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:gui_lungcxr/feature_home/state/chat_state.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';
import 'package:gui_lungcxr/feature_home/state/review_state.dart';

/// The signed-in doctor's assigned cases and the selection. Each case keeps
/// its own editor, review and chat state so work survives switching cases.
class CaseState extends ChangeNotifier {
  new({required this.api, this.saveDelay});

  final ApiClient api;

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
      final json = await api.get(Endpoints.cases) as List;
      _cases = [for (final item in json) CxrCase.fromJson(item)];
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

  String imageUrl(int id) => api.url(Endpoints.caseImage(id));
  String overlayUrl(int id) => api.url(Endpoints.caseOverlay(id));

  ImageEditorState editorFor(int id) =>
      _editors.putIfAbsent(id, ImageEditorState.new);

  ChatState chatFor(int id) => _chats.putIfAbsent(id, ChatState.new);

  /// Created on first use, which also loads the case from the backend.
  ReviewState reviewFor(int id) => _reviews.putIfAbsent(id, () {
    final delay = saveDelay;
    final editor = editorFor(id);
    final review = delay == null
        ? ReviewState(
            api: api,
            caseId: id,
            editor: editor,
            onCaseChanged: _replace,
          )
        : ReviewState(
            api: api,
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
