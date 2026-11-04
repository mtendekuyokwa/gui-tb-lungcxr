/// Spacing, radii and fixed dimensions. Widgets take their numbers from here
/// instead of hard-coding them.
class AppSizes {
  // Gaps and paddings, named by their value.
  static const double gap2 = 2;
  static const double gap4 = 4;
  static const double gap6 = 6;
  static const double gap8 = 8;
  static const double gap10 = 10;
  static const double gap12 = 12;
  static const double gap16 = 16;
  static const double gap18 = 18;
  static const double gap20 = 20;
  static const double gap24 = 24;

  // Corner radii
  static const double radius4 = 4;
  static const double radius6 = 6;
  static const double radius8 = 8;
  static const double radius12 = 12;

  // Icons
  static const double icon16 = 16;
  static const double icon18 = 18;
  static const double icon24 = 24;
  static const double icon32 = 32;

  // Patient avatars
  static const double avatarSm = 32;
  static const double avatarMd = 36;
  static const double avatarLg = 40;

  static const double dividerWidth = 1;

  // Login
  static const double loginCardWidth = 900;
  static const double loginCardHeight = 800;
  static const double loginArtworkWidth = 400;
  static const double loginFormWidth = 450;
  static const double loginButtonWidth = 100;

  // Doctor workspace
  /// Default width of the case list / review column.
  static const double sidePanelWidth = 400;

  /// Bounds when the doctor drags the review column's edge.
  static const double sidePanelMinWidth = 320;
  static const double sidePanelMaxFraction = 0.5;

  /// Hit area of that drag handle, and the line drawn in it.
  static const double resizeHandleWidth = 8;
  static const double resizeHandleLine = 1;
  static const double resizeHandleLineActive = 3;

  /// Width of the stroke-width slider in the segmentation bar.
  static const double segmentSliderWidth = 160;

  /// The case list scrolls once it is taller than this.
  static const double caseListMaxHeight = 260;

  /// Share of the window height the (expanded) case list may take.
  static const double caseListMaxFraction = 0.28;

  // X-ray canvas
  /// How far the image can be panned past the viewport edge.
  static const double canvasBoundaryMargin = 200;
  static const double adjustmentPanelWidth = 320;
  static const double lesionPanelWidth = 340;

  /// Colour dot on a lesion category button.
  static const double swatch = 8;

  /// Mark stroke width as a fraction of the image's shorter side, kept
  /// between [markStrokeMin] and [markStrokeMax].
  static const double markStrokeFactor = 0.006;
  static const double markStrokeMin = 1.5;
  static const double markStrokeMax = 4;

  /// How much thicker the mark being labelled is drawn.
  static const double activeMarkStrokeScale = 1.8;

  // Lung segmentation mask.
  /// Fill opacity of the mask wash over the X-ray.
  static const double maskFillOpacity = 0.3;

  /// Correction stroke width, as a fraction of the image width.
  static const double maskEditMinWidth = 0.004;
  static const double maskEditMaxWidth = 0.08;
  static const double maskBrushDefaultWidth = 0.03;
  static const double maskPenDefaultWidth = 0.01;

  // Admin workspace
  /// Width of the upload / assign / case detail column.
  static const double adminPanelWidth = 380;
  static const double adminPageMaxWidth = 720;
  static const double fabSize = 56;
  static const double fabNarrowInset = 72;
  static const double panelMaxWidth = 560;

  /// Below this width the workspaces switch to a single-column tab layout.
  static const double narrowBreakpoint = 700;

  /// Width of the activate / deactivate button in the doctors card.
  static const double userActiveButtonWidth = 110;

  /// Height of the X-ray preview in the case detail card.
  static const double casePreviewHeight = 200;

  // Admin dashboard
  /// Height of the icon box in a dashboard stat tile.
  static const double statIconBox = 28;

  /// Width of the strip's health card on a wide screen.
  static const double adminHealthCardWidth = 160;

  /// Widest the dashboard grows; past this the two columns get too long
  /// to read across.
  static const double dashboardMaxWidth = 1200;

  /// Content width from which the dashboard sets the model and workload
  /// cards side by side.
  static const double dashboardTwoColumn = 820;

  /// Doctors the workload chart shows before truncating to keep the axis
  /// readable.
  static const int chartMaxDoctors = 8;
}
