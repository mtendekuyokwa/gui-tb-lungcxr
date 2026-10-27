import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/state/case_state.dart';
import 'package:gui_lungcxr/feature_home/widgets/canvas_footer.dart';
import 'package:gui_lungcxr/feature_home/widgets/canvas_header.dart';
import 'package:gui_lungcxr/feature_home/widgets/canvas_wid.dart';
import 'package:gui_lungcxr/feature_home/widgets/client_board.dart';
import 'package:gui_lungcxr/feature_home/widgets/no_cases.dart';
import 'package:gui_lungcxr/feature_home/widgets/side_panel.dart';
import 'package:gui_lungcxr/feature_home/widgets/sidebar_wid.dart';
import 'package:gui_lungcxr/feature_home/widgets/tool_strip.dart';
import 'package:gui_lungcxr/widgets/narrow_tabs.dart';
import 'package:provider/provider.dart';

/// The doctor's workspace: assigned cases, the X-ray canvas and the review.
/// Under [AppSizes.narrowBreakpoint] the three columns become bottom tabs.
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
      child: LayoutBuilder(
        builder: (context, constraints) =>
            constraints.maxWidth < AppSizes.narrowBreakpoint
            ? _NarrowHome(key: ValueKey(id))
            : const Row(
                crossAxisAlignment: .stretch,
                children: [
                  SidebarWid(),
                  Expanded(child: DoctorCanvas()),
                  SizedBox(
                    width: AppSizes.sidePanelWidth,
                    child: DoctorPanels(),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The X-ray with its header, tool strip on narrow screens, and footer.
class DoctorCanvas extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: .stretch,
    children: [CanvasHeader(), Expanded(child: CanvasWid()), CanvasFooter()],
  );
}

/// The case list over the review / assistant panel.
class DoctorPanels extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final id = context.select<CaseState, int?>((s) => s.selected?.id);
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        // The board shrink-wraps; its case list is capped inside ClientBoard.
        const ClientBoard(),
        // Panel state belongs to one case; reset it on switch.
        Expanded(child: SidePanel(key: ValueKey(id))),
      ],
    );
  }
}

class _NarrowHome extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => NarrowTabs(
    tabs: [
      NarrowTab(
        label: Strings.xrayTab,
        icon: FLucideIcons.scan,
        page: const Column(
          crossAxisAlignment: .stretch,
          children: [
            CanvasHeader(),
            ToolStrip(),
            Expanded(child: CanvasWid()),
            CanvasFooter(),
          ],
        ),
      ),
      NarrowTab(
        label: Strings.casesTab,
        icon: FLucideIcons.users,
        page: const SingleChildScrollView(child: ClientBoard()),
      ),
      NarrowTab(
        label: Strings.reviewTab,
        icon: FLucideIcons.clipboardCheck,
        page: const SidePanel(),
      ),
    ],
  );
}
