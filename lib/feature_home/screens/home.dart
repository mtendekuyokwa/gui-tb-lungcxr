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
import 'package:gui_lungcxr/feature_home/widgets/panel_resize_handle.dart';
import 'package:gui_lungcxr/feature_home/widgets/review_panel.dart';
import 'package:gui_lungcxr/feature_home/widgets/segment_bar.dart';
import 'package:gui_lungcxr/feature_home/widgets/sidebar_wid.dart';
import 'package:gui_lungcxr/feature_home/widgets/tool_strip.dart';
import 'package:gui_lungcxr/widgets/create_fab.dart';
import 'package:gui_lungcxr/widgets/new_case_form.dart';
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
    if (id == null)
      return Stack(
        children: [
          NoCases(error: cases.error),
          // Nothing listed yet, so no case list to hold the button.
          CreateFab(actions: [newCaseAction]),
        ],
      );

    // Editor and review state are per case; swap the providers on
    // selection.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: cases.editorFor(id)),
        ChangeNotifierProvider.value(value: cases.reviewFor(id)),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) =>
            constraints.maxWidth < AppSizes.narrowBreakpoint
            ? _NarrowHome(key: ValueKey(id))
            : _WideHome(maxWidth: constraints.maxWidth),
      ),
    );
  }
}

/// Filing a case: the doctor's one create action. Opened from the case
/// list's header (or the FAB while there are no cases), so nothing floats
/// over the review's submit button.
final newCaseAction = CreateAction(
  label: Strings.uploadCase,
  icon: FLucideIcons.image,
  builder: (origin, onDone) => _provided(
    origin: origin,
    builder: (cases) => NewCaseForm(
      upload:
          ({
            required patientName,
            required hospitalNumber,
            hospitalId,
            required bytes,
            required filename,
          }) => cases.upload(
            patientName: patientName,
            hospitalNumber: hospitalNumber,
            hospitalId: hospitalId,
            bytes: bytes,
            filename: filename,
          ),
      search: cases.patients,
      searchHospitals: cases.hospitals,
      createHospital: cases.createHospital,
      busy: cases.busy,
      error: cases.error,
      onDone: onDone,
    ),
  ),
);

/// The pop-up panel mounts outside the workspace, below the navigator, so
/// re-provide the case state the form needs and keep it reacting to it.
Widget _provided({
  required BuildContext origin,
  required Widget Function(CaseState cases) builder,
}) {
  final cases = origin.read<CaseState>();
  return ChangeNotifierProvider<CaseState>.value(
    value: cases,
    child: Consumer<CaseState>(builder: (_, cases, _) => builder(cases)),
  );
}

/// Tools | canvas | case list + review, with a drag handle that resizes the
/// review column (double-click flips between the default and a wide one).
class _WideHome extends StatefulWidget {
  const _WideHome({required this.maxWidth});

  final double maxWidth;

  @override
  State<_WideHome> createState() => _WideHomeState();
}

class _WideHomeState extends State<_WideHome> {
  double _panelWidth = AppSizes.sidePanelWidth;

  /// The review may take up to half the screen, never less than its minimum.
  double get _maxPanel => (widget.maxWidth * AppSizes.sidePanelMaxFraction)
      .clamp(AppSizes.sidePanelMinWidth, double.infinity);

  double get _width => _panelWidth.clamp(AppSizes.sidePanelMinWidth, _maxPanel);

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: .stretch,
    children: [
      const SidebarWid(),
      const Expanded(child: DoctorCanvas()),
      PanelResizeHandle(
        // Dragging left widens the panel on the right.
        onDrag: (dx) => setState(() => _panelWidth = _width - dx),
        onToggle: () => setState(
          () => _panelWidth = _width > AppSizes.sidePanelWidth
              ? AppSizes.sidePanelWidth
              : _maxPanel,
        ),
      ),
      SizedBox(width: _width, child: const DoctorPanels()),
    ],
  );
}

/// The X-ray with its header, the segmentation bar while that tool is on,
/// and the footer.
class DoctorCanvas extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: .stretch,
    children: [
      CanvasHeader(),
      SegmentBar(),
      Expanded(child: CanvasWid()),
      CanvasFooter(),
    ],
  );
}

/// The (collapsible) case list over the review panel.
class DoctorPanels extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final id = context.select<CaseState, int?>((s) => s.selected?.id);
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        // The board shrink-wraps; its case list is capped inside ClientBoard.
        ClientBoard(onNewCase: () => CreateFab.open(context, newCaseAction)),
        // Panel state belongs to one case; reset it on switch.
        Expanded(child: ReviewPanel(key: ValueKey(id))),
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
            SegmentBar(),
            Expanded(child: CanvasWid()),
            CanvasFooter(),
          ],
        ),
      ),
      NarrowTab(
        label: Strings.casesTab,
        icon: FLucideIcons.users,
        page: SingleChildScrollView(
          child: ClientBoard(
            collapsible: false,
            onNewCase: () => CreateFab.open(context, newCaseAction),
          ),
        ),
      ),
      NarrowTab(
        label: Strings.reviewTab,
        icon: FLucideIcons.clipboardCheck,
        page: const ReviewPanel(),
      ),
    ],
  );
}
