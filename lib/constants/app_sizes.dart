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
  static const double gap24 = 24;

  // Corner radii
  static const double radius4 = 4;
  static const double radius6 = 6;
  static const double radius8 = 8;
  static const double radius12 = 12;

  // Icons
  static const double icon16 = 16;
  static const double icon18 = 18;
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
  /// Width of the case list / review / chat column.
  static const double sidePanelWidth = 340;

  /// The case list scrolls once it is taller than this.
  static const double caseListMaxHeight = 260;
  static const double chatBubbleMaxWidth = 260;

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

  // Admin workspace
  /// Width of the upload / assign / case detail column.
  static const double adminPanelWidth = 380;

  /// Height of the X-ray preview in the case detail card.
  static const double casePreviewHeight = 200;
}
