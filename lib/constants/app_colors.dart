import 'package:flutter/material.dart';

class AppColors {
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  /// Behind an X-ray, whatever the theme: radiology viewers use a dark
  /// surround.
  static const Color xrayBackdrop = Color(0xFF0B0D0E);

  /// Icons and text drawn on [xrayBackdrop].
  static const Color onXrayBackdrop = Color(0xB3FFFFFF);

  // Marks on the X-ray, by lesion category. Chosen for contrast against
  // [xrayBackdrop], independent of the app theme.
  static const Color markUnlabelled = Color(0xFFE5E7EB);
  static const Color markParenchymal = Color(0xFF22D3EE);
  static const Color markPleural = Color(0xFFFBBF24);
  static const Color markMediastinal = Color(0xFFA78BFA);
  static const Color markOther = Color(0xFFF472B6);

  /// Fill of a mark's tag while it is not the one being labelled.
  static const Color markTagBackground = Color(0xB3000000);

  /// Translucent wash for the lung segmentation mask. Emerald sits apart
  /// from the mark colours and the XAI heatmap.
  static const Color maskTint = Color(0xFF34D399);

  /// Admin dashboard tile accents. The theme has no warning / success
  /// tokens, so the dashboard picks fixed hues that read on both modes.
  static const Color statWarning = Color(0xFFD97706);
  static const Color statDone = Color(0xFF059669);

  /// Chart-only hues completing the six status colours. The theme's own
  /// primary / destructive cover unassigned and returned.
  static const Color statHeld = Color(0xFF94A3B8); // assigned
  static const Color statReviewing = Color(0xFF7C3AED); // in review
}
