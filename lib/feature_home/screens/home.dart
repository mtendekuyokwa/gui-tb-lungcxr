import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:gui_lungcxr/feature_home/state/case_state.dart';
import 'package:gui_lungcxr/feature_home/widgets/canvas_footer.dart';
import 'package:gui_lungcxr/feature_home/widgets/canvas_header.dart';
import 'package:gui_lungcxr/feature_home/widgets/canvas_wid.dart';
import 'package:gui_lungcxr/feature_home/widgets/chat_wid.dart';
import 'package:gui_lungcxr/feature_home/widgets/client_board.dart';
import 'package:gui_lungcxr/feature_home/widgets/review_panel.dart';
import 'package:gui_lungcxr/feature_home/widgets/sidebar_wid.dart';
import 'package:provider/provider.dart';

/// The doctor's workspace: assigned cases, the X-ray canvas and the review.
class Home extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final cases = context.watch<CaseState>();
    if (cases.loading) return const Center(child: FCircularProgress());
    final id = cases.selected?.id;
    if (id == null) return _NoCases(error: cases.error);

    // Editor, review and chat state are per case; swap the providers on
    // selection.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: cases.editorFor(id)),
        ChangeNotifierProvider.value(value: cases.reviewFor(id)),
        ChangeNotifierProvider.value(value: cases.chatFor(id)),
      ],
      child: Row(
        crossAxisAlignment: .stretch,
        children: [
          const SidebarWid(),
          const Expanded(
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                CanvasHeader(),
                Expanded(child: CanvasWid()),
                CanvasFooter(),
              ],
            ),
          ),
          SizedBox(
            width: 340,
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: const SingleChildScrollView(child: ClientBoard()),
                ),
                // Panel state belongs to one case; reset it on switch.
                Expanded(child: _SidePanel(key: ValueKey(id))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Review form or assistant chat for the selected case.
class _SidePanel extends StatefulWidget {
  const new({super.key});

  @override
  State<_SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<_SidePanel> {
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
          padding: const .fromLTRB(8, 0, 8, 8),
          child: Row(
            spacing: 6,
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

class _NoCases extends StatelessWidget {
  const new({required this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Center(
      child: Column(
        mainAxisSize: .min,
        spacing: 8,
        children: [
          const Icon(FLucideIcons.inbox, size: 32),
          Text(
            error ?? Strings.noCases,
            style: theme.typography.body.md.copyWith(fontWeight: .w600),
          ),
          if (error == null)
            Text(
              Strings.noCasesDetail,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: .min,
            spacing: 8,
            children: [
              FButton(
                variant: .outline,
                size: .sm,
                mainAxisSize: .min,
                onPress: context.read<CaseState>().load,
                prefix: const Icon(FLucideIcons.refreshCw),
                child: const Text(Strings.refresh),
              ),
              FButton(
                variant: .ghost,
                size: .sm,
                mainAxisSize: .min,
                onPress: context.read<SessionState>().logout,
                prefix: const Icon(FLucideIcons.logOut),
                child: const Text(Strings.signOut),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
