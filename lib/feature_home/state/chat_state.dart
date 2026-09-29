import 'package:flutter/foundation.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/models/chat_message.dart';

/// Chat history for one patient. Replies are placeholders until the model
/// backend is connected.
class ChatState extends ChangeNotifier {
  final List<ChatMessage> _messages = [];

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  void send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _messages
      ..add(ChatMessage(author: .user, text: trimmed, sentAt: DateTime.now()))
      ..add(
        ChatMessage(
          author: .assistant,
          text: Strings.chatModelOffline,
          sentAt: DateTime.now(),
        ),
      );
    notifyListeners();
  }
}
