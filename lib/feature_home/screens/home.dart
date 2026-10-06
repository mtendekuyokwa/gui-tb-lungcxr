import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/feature_home/state/case_state.dart';
import 'package:gui_lungcxr/feature_home/widgets/canvas_footer.dart';
import 'package:gui_lungcxr/feature_home/widgets/canvas_header.dart';
import 'package:gui_lungcxr/feature_home/widgets/canvas_wid.dart';
import 'package:gui_lungcxr/feature_home/widgets/client_board.dart';
import 'package:gui_lungcxr/feature_home/widgets/no_cases.dart';
import 'package:gui_lungcxr/feature_home/widgets/side_panel.dart';
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
    if (id == null) return NoCases(error: cases.error);

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
            width: AppSizes.sidePanelWidth,
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: AppSizes.caseListMaxHeight,
                  ),
                  child: const SingleChildScrollView(child: ClientBoard()),
                ),
                // Panel state belongs to one case; reset it on switch.
                Expanded(child: SidePanel(key: ValueKey(id))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
