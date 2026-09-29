import 'package:flutter/foundation.dart';
import 'package:gui_lungcxr/constants/app_images.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/models/patient.dart';
import 'package:gui_lungcxr/feature_home/state/chat_state.dart';
import 'package:gui_lungcxr/feature_home/state/image_editor_state.dart';

/// Patient list and selection. Each patient keeps its own editor and chat
/// state so marks and adjustments survive switching between patients.
class PatientState extends ChangeNotifier {
  // TODO: load from the backend once it exists.
  final List<Patient> patients = const [
    Patient(
      id: 'TB-0001',
      name: Strings.fakeName,
      imageUrl: AppImages.demoTBImage,
    ),
    Patient(
      id: 'TB-0002',
      name: Strings.fakeName1,
      imageUrl: AppImages.demoTBImage,
    ),
  ];

  late String _selectedId = patients.first.id;
  final Map<String, ImageEditorState> _editors = {};
  final Map<String, ChatState> _chats = {};

  Patient get selected => patients.firstWhere((p) => p.id == _selectedId);

  void select(String id) {
    if (id == _selectedId) return;
    _selectedId = id;
    notifyListeners();
  }

  ImageEditorState editorFor(String id) =>
      _editors.putIfAbsent(id, ImageEditorState.new);

  ChatState chatFor(String id) => _chats.putIfAbsent(id, ChatState.new);

  @override
  void dispose() {
    for (final editor in _editors.values) {
      editor.dispose();
    }
    for (final chat in _chats.values) {
      chat.dispose();
    }
    super.dispose();
  }
}
