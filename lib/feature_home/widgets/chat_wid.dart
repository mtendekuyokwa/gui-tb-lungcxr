import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/chat_state.dart';
import 'package:gui_lungcxr/feature_home/widgets/chat_bubble.dart';
import 'package:provider/provider.dart';

/// Assistant chat for the selected case: the messages and the input.
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
      padding: const .fromLTRB(AppSizes.gap8, 0, AppSizes.gap8, AppSizes.gap8),
      child: FCard(
        clipBehavior: .antiAlias,
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Padding(
              padding: const .all(AppSizes.gap12),
              child: Row(
                spacing: AppSizes.gap8,
                children: [
                  const Icon(FLucideIcons.bot, size: AppSizes.icon18),
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
                      padding: const .all(AppSizes.gap12),
                      itemCount: chat.messages.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSizes.gap8),
                      itemBuilder: (_, i) =>
                          ChatBubble(message: chat.messages[i]),
                    ),
            ),
            Padding(
              padding: const .all(AppSizes.gap12),
              child: Row(
                spacing: AppSizes.gap8,
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
