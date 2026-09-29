enum ChatAuthor { user, assistant }

class ChatMessage {
  const new({required this.author, required this.text, required this.sentAt});

  final ChatAuthor author;
  final String text;
  final DateTime sentAt;
}
