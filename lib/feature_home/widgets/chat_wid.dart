import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/models/chat_message.dart';
import 'package:gui_lungcxr/feature_home/state/chat_state.dart';
import 'package:provider/provider.dart';

class ChatWid extends StatefulWidget {
  const new({super.key});

  @override
  State<ChatWid> createState() => _ChatWidState();
}

class _ChatWidState extends State<ChatWid> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  void _send(ChatState chat) {
    chat.send(_controller.text);
    _controller.clear();
    _focus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatState>();
    final theme = context.theme;

    return Padding(
      padding: const .fromLTRB(8, 0, 8, 8),
      child: FCard(
        clipBehavior: .antiAlias,
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Padding(
              padding: const .all(12),
              child: Row(
                spacing: 8,
                children: [
                  const Icon(FLucideIcons.bot, size: 18),
                  Text(
                    Strings.chat,
                    style: theme.typography.body.sm.copyWith(fontWeight: .w600),
                  ),
                ],
              ),
            ),
            const FDivider(style: .delta(padding: .value(.zero))),
            Expanded(
              child: chat.messages.isEmpty
                  ? Center(
                      child: Text(
                        Strings.chatEmpty,
                        style: theme.typography.body.sm.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: _scroll,
                      padding: const .all(12),
                      itemCount: chat.messages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _Bubble(message: chat.messages[i]),
                    ),
            ),
            Padding(
              padding: const .all(12),
              child: Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: FTextField(
                      control: .managed(controller: _controller),
                      focusNode: _focus,
                      hint: Strings.chatHint,
                      textInputAction: .send,
                      onSubmit: (_) => _send(chat),
                    ),
                  ),
                  FTooltip(
                    tipBuilder: (_, _) => const Text(Strings.send),
                    child: FButton.icon(
                      variant: .primary,
                      onPress: () => _send(chat),
                      child: const Icon(FLucideIcons.sendHorizontal),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const new({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final mine = message.author == .user;
    return Align(
      alignment: mine ? .centerRight : .centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: mine ? colors.primary : colors.secondary,
            borderRadius: .circular(12),
          ),
          child: Padding(
            padding: const .symmetric(horizontal: 12, vertical: 8),
            child: Text(
              message.text,
              style: context.theme.typography.body.sm.copyWith(
                color: mine
                    ? colors.primaryForeground
                    : colors.secondaryForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
