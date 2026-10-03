import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:gui_lungcxr/main.dart';
import 'package:gui_lungcxr/theme/theme.dart';
import 'package:provider/provider.dart';

import 'support/fake_backend.dart';

Future<void> _pumpApp(WidgetTester tester, SessionState session) async {
  tester.view.physicalSize = const Size(1600, 1000);
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

void main() {
  testWidgets('signed out shows the login form', (tester) async {
    final session = SessionState(api: FakeBackend().api);
    addTearDown(session.dispose);
    await _pumpApp(tester, session);
    expect(find.text(Strings.signInPrompt), findsOneWidget);
    expect(find.text(Strings.signIn), findsOneWidget);
  });

  testWidgets(
    'a doctor sees their cases, the model reading and the review form',
    (tester) async {
      final backend = FakeBackend();
      final session = SessionState(api: backend.api);
      addTearDown(session.dispose);
      await tester.runAsync(() => session.login('doc@test', 'secret'));
      await _pumpApp(tester, session);
      await _settle(tester);

      expect(find.text('John Phiri'), findsOneWidget);
      expect(find.text('${Strings.modelTb} · 97%'), findsOneWidget);
      expect(find.text(Strings.verdict), findsOneWidget);
      expect(find.text(Strings.submitReview), findsOneWidget);

      await tester.tap(find.text('TB suspected'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // autosave delay
      await _settle(tester);
      expect(backend.saved.single['verdict'], 'tb_suspected');

      await tester.tap(find.text(Strings.submitReview));
      await _settle(tester);
      expect(backend.cases[1]!['status'], 'submitted');
      expect(find.text(Strings.readOnly), findsOneWidget);
      await tester.pump(const Duration(seconds: 10)); // let the toast expire
    },
  );

  testWidgets('an admin sees all cases and can assign ticked ones', (
    tester,
  ) async {
    final backend = FakeBackend(role: 'admin');
    backend.cases[1]!['status'] = 'unassigned';
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await tester.runAsync(() => session.login('admin@test', 'secret'));
    await _pumpApp(tester, session);
    await _settle(tester);

    expect(find.text(Strings.uploadCase), findsOneWidget);
    expect(find.text(Strings.selectCase), findsOneWidget);
    expect(find.text('${Strings.assign} (0)'), findsOneWidget);

    final admin = tester
        .element(find.text(Strings.uploadCase))
        .read<AdminState>();
    await tester.tap(find.byIcon(FLucideIcons.square).first);
    await tester.pump();
    expect(admin.ticked, {1});
    await tester.tap(find.text('Doc One').last);
    await tester.pump();
    await tester.tap(find.text('${Strings.assign} (1)'));
    await _settle(tester);
    expect(backend.log, contains('POST /admin/cases/assign'));
    expect(admin.ticked, isEmpty);
    await tester.pump(const Duration(seconds: 10));
  });
}
