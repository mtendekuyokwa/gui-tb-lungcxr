import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/feature_home/models/chat_message.dart';

/// One chat message, on the right when it is the doctor's own.
class ChatBubble extends StatelessWidget {
  const new({required this.message, super.key});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final mine = message.author == .user;
    return Align(
      alignment: mine ? .centerRight : .centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppSizes.chatBubbleMaxWidth,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: mine ? colors.primary : colors.secondary,
            borderRadius: .circular(AppSizes.radius12),
          ),
          child: Padding(
            padding: const .symmetric(
              horizontal: AppSizes.gap12,
              vertical: AppSizes.gap8,
            ),
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
