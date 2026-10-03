# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter GUI for a tuberculosis (TB) chest X-ray model, backed by a Flask API in `server/` (see `server/CLAUDE.md`). A hospital admin uploads X-rays and assigns them to doctors; a doctor views the CXR on a canvas, marks and labels findings, adjusts brightness/contrast/hue/saturation, sees the model's reading, records a verdict, flags the model as wrong or the case for further testing, and submits the review back. `DOCUMENTATION.md` is the full design; `FEATURES.md` (frontend) and `server/FEATURES.md` (backend) are the ordered build lists — tick items there as they land. **Web is the current target**; mobile/desktop come later, so avoid web-only APIs (`dart:html`, `package:web`) outside of platform-guarded code. The model reading and XAI heatmap come from the backend's worker (`flask worker`); until it has processed a case the badge shows "Awaiting model".

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
flutter run -d chrome          # primary dev target; needs the backend running (see server/CLAUDE.md)
flutter run -d chrome --dart-define=API_BASE_URL=http://host:5000/api/v1   # non-default backend
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
- **Feature folders**: `lib/feature_<name>/{screens,widgets,state,models,utils}`. `feature_auth` (login, `SessionState`), `feature_home` (the doctor's workspace), `feature_admin` (the admin's workspace). `main.dart`'s `AppGate` picks between `LoginScreen`, `Home` and `AdminHome` from the signed-in user's role.
- **API layer** (`lib/api/`): `ApiClient` sends JSON with the bearer token, throws `ApiException` carrying the backend's `error` message, and calls `onUnauthorized` (sign-out) on a 401. Paths live in `Endpoints`; the base URL is the `API_BASE_URL` dart-define. Choice lists (verdicts, diseases, tests, feedback kinds) come from the backend `GET /catalog` as `Catalog`; lesion findings are the Dart `LesionType` enum, whose names are the backend's finding codes — keep the two in sync.
- **State** (`provider` + `ChangeNotifier`): `SessionState` is provided at the root. For a doctor, `CaseState` holds the assigned cases, the selection, and a lazily created `ImageEditorState` + `ReviewState` + `ChatState` **per case** (so work survives switching). `Home` re-provides the selected case's three via `ChangeNotifierProvider.value`. `ReviewState` owns the verdict/flags, listens to the editor's `markRevision`, and debounces a `PUT /cases/{id}/review` of the whole draft; after submit it sets `ImageEditorState.locked`. For an admin, `AdminState` holds all cases, doctors, the ticked set and the opened case.
- **Doctor screen**: `feature_home/screens/home.dart` is a `Row` of `SidebarWid` (tools + adjustments) | column of `CanvasHeader` (patient, status, sign-out) + `CanvasWid` + `CanvasFooter` (model reading + XAI switch) | column of `ClientBoard` (case list) + a Review / Assistant tab switch over `ReviewPanel` and `ChatWid`.
- **Canvas**: `CanvasWid` wraps an `InteractiveViewer` (zoom via `ImageEditorState.transform`; pan disabled in mark mode). `XrayImage` loads the image from the backend (with auth headers) at native aspect ratio and applies brightness/contrast/hue/saturation with a `ColorFilter.matrix` built by `utils/color_matrix.dart`. `_MarkLayer` captures strokes with a raw `Listener`, paints them via `PaintboardWid` and overlays a tappable tag per mark. Each stroke is a `Mark` (`models/mark.dart`) with image-relative (0..1) points and an optional `LesionType` (`models/lesion.dart`, grouped by `LesionCategory`); finishing a stroke sets `activeMark`, which shows `LesionLabelPanel` to pick category → type. Mark colour is per category (`markColor`). Marks + labels are the future segmentation hints. Adjustments are -1..1 with 0 = unchanged; `AdjustmentPanel` shows the slider for the active adjustment tool.
- **Not yet wired**: segmentation (sidebar item shows a toast), chat replies (canned offline message). The session token is in memory only, so a page reload signs out.
- **Constants** (`lib/constants/`): all UI strings go in `Strings` (including lesion names), API paths in `Endpoints`. `AppImages` and the portraits in `assets/images/patients/` are leftovers from the hard-coded demo and are unused.
- **Tests**: `test/support/fake_backend.dart` is an in-memory stand-in for the Flask API (an `http` `MockClient`); `case_state_test.dart` drives state against it and `screens_test.dart` pumps each role's screen. The widget-test font is much wider than the real one, so button labels that can be long are wrapped in `Flexible` with ellipsis.
- `imosys_flutter_package` is a dependency but currently unused.
