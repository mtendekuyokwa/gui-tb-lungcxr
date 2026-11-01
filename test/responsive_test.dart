import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_auth/screens/login_screen.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:gui_lungcxr/feature_auth/widgets/login_artwork.dart';
import 'package:gui_lungcxr/feature_home/screens/home.dart';
import 'package:gui_lungcxr/feature_home/widgets/sidebar_wid.dart';
import 'package:gui_lungcxr/feature_home/widgets/tool_strip.dart';
import 'package:gui_lungcxr/main.dart';
import 'package:gui_lungcxr/theme/theme.dart';
import 'package:gui_lungcxr/widgets/narrow_tabs.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backend.dart';

Future<void> _pumpApp(
  WidgetTester tester,
  SessionState session,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: session,
      child: MaterialApp(
        localizationsDelegates: FLocalizations.localizationsDelegates,
        builder: (context, child) => FTheme(
          data: lightTheme,
          child: FToaster(child: FTooltipGroup(child: child!)),
        ),
        home: const FScaffold(child: AppGate()),
      ),
    ),
  );
}

/// Lets the fake backend's futures and the app's short timers run.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder _tab(String label) => find.descendant(
  of: find.byType(NarrowTabs),
  matching: find.text(label),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a narrow doctor screen uses bottom tabs', (tester) async {
    final backend = FakeBackend();
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await tester.runAsync(() => session.login('doc@test', 'secret'));
    await _pumpApp(tester, session, const Size(400, 900));
    await _settle(tester);

    expect(find.byType(Home), findsOneWidget);
    expect(find.byType(SidebarWid), findsNothing);
    expect(find.byType(ToolStrip), findsOneWidget);
    expect(_tab(Strings.xrayTab), findsOneWidget);
    expect(_tab(Strings.casesTab), findsOneWidget);
    expect(_tab(Strings.reviewTab), findsOneWidget);

    // The X-ray page is up first; the tool strip leaves with it.
    await tester.tap(_tab(Strings.casesTab));
    await tester.pump();
    expect(find.text(Strings.pan), findsNothing);
    expect(find.text('John Phiri'), findsOneWidget);

    await tester.tap(_tab(Strings.reviewTab));
    await tester.pump();
    expect(find.text(Strings.verdict), findsOneWidget);

    await tester.tap(_tab(Strings.xrayTab));
    await tester.pump();
    expect(find.byType(ToolStrip), findsOneWidget);
    await tester.pump(const Duration(seconds: 10)); // let toasts expire
  });

  testWidgets('a wide doctor screen keeps the three columns', (tester) async {
    final backend = FakeBackend();
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await tester.runAsync(() => session.login('doc@test', 'secret'));
    await _pumpApp(tester, session, const Size(1600, 1000));
    await _settle(tester);

    expect(find.byType(SidebarWid), findsOneWidget);
    expect(find.byType(ToolStrip), findsNothing);
    expect(find.byType(NarrowTabs), findsNothing);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('a narrow admin screen tabs cases and manage', (tester) async {
    final backend = FakeBackend(role: 'admin');
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await tester.runAsync(() => session.login('admin@test', 'secret'));
    await _pumpApp(tester, session, const Size(400, 900));
    await _settle(tester);

    expect(_tab(Strings.casesTab), findsOneWidget);
    expect(_tab(Strings.manageTab), findsOneWidget);

    await tester.tap(_tab(Strings.manageTab));
    await tester.pump();
    // The work rail opens on the case detail; intake is a tab over.
    expect(find.text(Strings.detailTab), findsWidgets);
    await tester.tap(find.text(Strings.intakeTab));
    await tester.pump();
    expect(find.text(Strings.uploadCase), findsOneWidget);
    expect(find.text(Strings.assignTo), findsOneWidget);

    await tester.tap(_tab(Strings.casesTab));
    await tester.pump();
    expect(find.text(Strings.uploadCase), findsNothing);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('a narrow login screen hides the artwork', (tester) async {
    final session = SessionState(api: FakeBackend().api);
    addTearDown(session.dispose);
    await _pumpApp(tester, session, const Size(400, 900));
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text(Strings.signInPrompt), findsOneWidget);
    expect(find.byType(LoginArtwork), findsNothing);
  });

  testWidgets('a wide login screen shows the artwork', (tester) async {
    final session = SessionState(api: FakeBackend().api);
    addTearDown(session.dispose);
    await _pumpApp(tester, session, const Size(1600, 1000));
    await tester.pump();

    expect(find.byType(LoginArtwork), findsOneWidget);
  });
}
