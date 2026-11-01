import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/widgets/assign_card.dart';
import 'package:gui_lungcxr/feature_admin/widgets/case_list.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:gui_lungcxr/feature_home/widgets/client_board.dart';
import 'package:gui_lungcxr/feature_home/widgets/segment_panel.dart';
import 'package:gui_lungcxr/main.dart';
import 'package:gui_lungcxr/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

  testWidgets('segment tool opens the mask correction panel', (tester) async {
    final backend = FakeBackend();
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await tester.runAsync(() => session.login('doc@test', 'secret'));
    await _pumpApp(tester, session);
    await _settle(tester);

    await tester.tap(find.byIcon(FLucideIcons.spline));
    await tester.pump();
    final panel = find.byType(SegmentPanel);
    expect(panel, findsOneWidget);
    expect(
      find.descendant(of: panel, matching: find.byIcon(FLucideIcons.brush)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: panel, matching: find.byIcon(FLucideIcons.eraser)),
      findsOneWidget,
    );
    expect(find.text(Strings.resetSegmentEdits), findsOneWidget);

    // Each subtool carries its own default width.
    await tester.tap(
      find.descendant(of: panel, matching: find.byIcon(FLucideIcons.pen)),
    );
    await tester.pump();
    expect(find.text('1%'), findsOneWidget);

    // The footer gains a second switch for the mask overlay.
    expect(
      find.byWidgetPredicate(
        (w) => w is FSwitch && w.semanticsLabel == Strings.Segmentation,
      ),
      findsOneWidget,
    );

    // The panel closes back to pan without hiding the overlay.
    await tester.tap(find.byIcon(FLucideIcons.x));
    await tester.pump();
    expect(find.byType(SegmentPanel), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is FSwitch && w.semanticsLabel == Strings.Segmentation && w.value,
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 10)); // let toasts expire
  });

  testWidgets('a doctor can search the client list', (tester) async {
    final backend = FakeBackend();
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await tester.runAsync(() => session.login('doc@test', 'secret'));
    await _pumpApp(tester, session);
    await _settle(tester);

    final board = find.byType(ClientBoard);
    expect(
      find.descendant(of: board, matching: find.text('Jane Banda')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: board, matching: find.text('John Phiri')),
      findsOneWidget,
    );
    await tester.enterText(
      find.descendant(
        of: find.byType(ClientBoard),
        matching: find.byType(FTextField),
      ),
      'john',
    );
    await tester.pump();
    expect(
      find.descendant(of: board, matching: find.text('Jane Banda')),
      findsNothing,
    );
    expect(
      find.descendant(of: board, matching: find.text('John Phiri')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('the upload form suggests returning patients', (tester) async {
    final backend = FakeBackend();
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await tester.runAsync(() => session.login('doc@test', 'secret'));
    await _pumpApp(tester, session);
    await _settle(tester);

    // The doctor's own upload starts collapsed behind a button.
    await tester.tap(find.text(Strings.uploadCase));
    await _settle(tester);


    // Typing suggests existing patients; picking one fills both fields.
    await tester.enterText(
      find.byWidgetPredicate((w) => w is FAutocomplete),
      'banda',
    );
    await _settle(tester);
    expect(backend.log, contains('GET /patients?q=banda'));
    expect(find.text('HU-42 · Female · born 1987'), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate((w) => w is FAutocompleteItem).first,
    );
    await _settle(tester);

    expect(find.text('HU-42'), findsOneWidget); // number now auto-filled
    expect(find.text(Strings.upload), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('an admin sees the dashboard and can assign ticked ones', (
    tester,
  ) async {
    final backend = FakeBackend(role: 'admin');
    backend.cases[1]!['status'] = 'unassigned';
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await tester.runAsync(() => session.login('admin@test', 'secret'));
    await _pumpApp(tester, session);
    await _settle(tester);

    // The overview leads the workspace; the queue is one page over.
    expect(find.text(Strings.selectCase), findsNothing);
    expect(find.text(Strings.statsAgreement), findsOneWidget);

    // Case management is its own page, reached from the sidebar.
    await tester.tap(find.textContaining(Strings.cases).first);
    await tester.pump();
    expect(find.text(Strings.selectCase), findsOneWidget);

    // Intake is where new cases are added and ticks are handed over.
    await tester.tap(find.text(Strings.intakeTab));
    await tester.pump();
    expect(find.text(Strings.uploadCase), findsOneWidget);
    expect(find.text('${Strings.assign} (0)'), findsOneWidget);

    final admin = tester
        .element(find.text(Strings.uploadCase))
        .read<AdminState>();
    await tester.tap(find.byIcon(FLucideIcons.square).first);
    await tester.pump();
    expect(admin.ticked, {1});
    // Scoped to the assign card: the doctors card lists the same name.
    await tester.tap(
      find.descendant(
        of: find.byType(AssignCard),
        matching: find.text('Doc One'),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('${Strings.assign} (1)'));
    await _settle(tester);
    expect(backend.log, contains('POST /admin/cases/assign'));
    expect(admin.ticked, isEmpty);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('an admin searches the case list and filters cases', (
    tester,
  ) async {
    final backend = FakeBackend(role: 'admin');
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await tester.runAsync(() => session.login('admin@test', 'secret'));
    await _pumpApp(tester, session);
    await _settle(tester);

    // Case management is its own page, reached from the sidebar.
    await tester.tap(find.textContaining(Strings.cases).first);
    await tester.pump();
    expect(find.byType(CaseList), findsOneWidget);
    await tester.enterText(find.byType(FTextField).first, 'nmware');
    await tester.pump();
    expect(find.text(Strings.noCasesMatch), findsOneWidget);
    await tester.enterText(find.byType(FTextField).first, '');
    await tester.pump();
    expect(find.text(Strings.noCasesMatch), findsNothing);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('an admin drills into the case list from the charts', (
    tester,
  ) async {
    final backend = FakeBackend(role: 'admin');
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await tester.runAsync(() => session.login('admin@test', 'secret'));
    await _pumpApp(tester, session);
    await _settle(tester);

    final admin = tester
        .element(find.text(Strings.workloadQuestion))
        .read<AdminState>();
    expect(admin.statusFilter, isNull);

    // The donut's legend rows are the charts' drilldown: tap the slice's
    // label and the overview hands the admin over to the filtered queue.
    await tester.tap(find.text('Assigned 2'));
    await tester.pump();
    expect(admin.statusFilter, CaseStatus.assigned);
    expect(find.byType(CaseList), findsOneWidget);

    // Back on the overview, tap again to show every case.
    await tester.tap(find.text(Strings.dashboard).last);
    await tester.pump();
    await tester.tap(find.text('Assigned 2'));
    await tester.pump();
    expect(admin.statusFilter, isNull);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('an admin sees the worker hint while readings are queued', (
    tester,
  ) async {
    final backend = FakeBackend(role: 'admin');
    backend.cases[1] = caseJson(1, predictionState: 'queued');
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await tester.runAsync(() => session.login('admin@test', 'secret'));
    await _pumpApp(tester, session);
    await _settle(tester);

    // The queue lives on its own page now, reached from the sidebar.
    await tester.tap(find.textContaining(Strings.cases).first);
    await tester.pump();
    expect(find.text(Strings.waitingOnModel), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
  });
}
