# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter GUI for a tuberculosis (TB) chest X-ray model. Clinicians pick a patient, view their CXR on a canvas, segment/mark the lungs, adjust brightness/contrast/hue/saturation, see the model's result, toggle explainability (XAI) overlays, and use a chat panel. **Web is the current target**; mobile/desktop come later, so avoid web-only APIs (`dart:html`, `package:web`) outside of platform-guarded code. The TB model is not integrated yet; it will be added later (`lib/constants/endpoints.dart` holds endpoint names for a future backend).

### Target layout (from the design mockup)

```
┌──────┬──────────────────────────────┬──────────────────┐
│ tool │                              │ patient/client   │
│ side │   CXR canvas (image +        │ list             │
│ bar  │   lung segmentation overlay) ├──────────────────┤
│      │                              │ chat panel       │
│      │                              │ (messages +      │
│      │                              │  input at bottom)│
├──────┼─────────┬─────────┬──────────┤                  │
│      │ ClientID│ Result  │ Activate │                  │
│      │         │(Positive)│   XAI   │                  │
└──────┴─────────┴─────────┴──────────┴──────────────────┘
```

## Commands

```bash
flutter pub get
flutter run -d chrome          # primary dev target
flutter build web
flutter analyze                # lints: package:flutter_lints/flutter.yaml
dart format lib
flutter test
flutter test test/foo_test.dart --plain-name "name"   # single test
```

Forui CLI (config in `forui.yaml`):
```bash
dart run forui style create <widget>   # generates into lib/theme/styles/
dart forui theme create --preset fagbab # regenerates lib/theme/theme.dart
```

## Toolchain / language quirks

- Runs on the Flutter **main channel** (3.49 pre) with Dart SDK `^3.14.0-dev`. The code uses new Dart syntax that older SDKs reject:
  - Primary-constructor shorthand: `const new({super.key});` instead of `const ClassName({super.key});`
  - Dot shorthands: `style: const .delta(...)`, `.tile(...)`, `mainAxisSize: .min`, `Theme.brightnessOf(context) == .light`.
  Follow these idioms in new code.
- Some files import `package:material_ui/material_ui.dart` / `package:cupertino_ui/cupertino_ui.dart` (the split-out Material/Cupertino libraries) which resolve transitively but are not declared in `pubspec.yaml` (analyzer `depend_on_referenced_packages` info).

## Architecture

- **UI kit is Forui** (`forui`, `forui_lucide`), not plain Material. `main.dart` wraps `MaterialApp` with `FTheme` (light/dark chosen from platform brightness) + `FToaster` + `FTooltipGroup`, and hosts `Home` inside an `FScaffold`. Prefer `F*` widgets (`FSidebar`, `FTileGroup`, `FButton`, …) and `FLucideIcons`; `hugeicons` is also available.
- **Theme** (`lib/theme/`): `theme.dart` is Forui-CLI generated and uses `part` files (`colors.dart`, `typography.dart`, `style.dart`, `icons.dart`). `touch = true` selects the touch variant. Custom tokens go in the `AppStyle` `ThemeExtension` in `style.dart`, accessed via `context.theme.style.app`. Per-widget generated styles live in `lib/theme/styles/`.
- **Feature folders**: `lib/feature_<name>/{screens,widgets,state,models,utils}`. `feature_home/screens/home.dart` is the single screen, a `Row` of `SidebarWid` (tools + adjustments) | column of `CanvasWid` + `CanvasFooter` (client ID, name, result badge, XAI switch) | column of `ClientBoard` (patient list) + `ChatWid`.
- **State** (`provider` + `ChangeNotifier`, in `feature_home/state/`): `PatientState` is provided at the root in `main.dart` and holds the patient list, the selection, and a lazily created `ImageEditorState` + `ChatState` **per patient** (so marks/adjustments/chat survive switching). `Home` re-provides the selected patient's editor and chat via `ChangeNotifierProvider.value`; widgets `context.watch<ImageEditorState>()` / `<ChatState>()`.
- **Canvas**: `CanvasWid` wraps an `InteractiveViewer` (zoom via `ImageEditorState.transform`; pan disabled in mark mode). `XrayImage` loads the image at native aspect ratio and applies brightness/contrast/hue/saturation with a `ColorFilter.matrix` built by `utils/color_matrix.dart`. `_MarkLayer` captures strokes with a raw `Listener` and paints them via `PaintboardWid`; stroke points are stored image-relative (0..1) as future segmentation hints. Adjustments are -1..1 with 0 = unchanged; `AdjustmentPanel` shows the slider for the active adjustment tool.
- **Not yet wired to a backend**: segmentation (sidebar item shows a toast), `Patient.result` (always null → "Awaiting model"), XAI overlay (switch only shows a placeholder badge), chat replies (canned offline message).
- **Constants** (`lib/constants/`): all UI strings go in `Strings`, image paths/URLs in `AppImages`, API paths in `Endpoints`. Patient names in `Strings` are fake placeholder data.
- `imosys_flutter_package` is a dependency but currently unused.
