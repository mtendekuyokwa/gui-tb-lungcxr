import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/widgets/chat_wid.dart';
import 'package:gui_lungcxr/feature_home/widgets/review_panel.dart';

/// Review form or assistant chat for the selected case.
class SidePanel extends StatefulWidget {
  const new({super.key});

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel> {
  bool _chat = false;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, IconData icon, bool chat) => Expanded(
      child: FButton(
        variant: _chat == chat ? .secondary : .ghost,
        size: .sm,
        onPress: () => setState(() => _chat = chat),
        prefix: Icon(icon),
        child: Flexible(child: Text(label, overflow: .ellipsis)),
      ),
    );

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Padding(
          padding: const .fromLTRB(
            AppSizes.gap8,
            0,
            AppSizes.gap8,
            AppSizes.gap8,
          ),
          child: Row(
            spacing: AppSizes.gap6,
            children: [
              tab(Strings.review, FLucideIcons.clipboardCheck, false),
              tab(Strings.chat, FLucideIcons.bot, true),
            ],
          ),
        ),
        Expanded(child: _chat ? const ChatWid() : const ReviewPanel()),
      ],
    );
  }
}
