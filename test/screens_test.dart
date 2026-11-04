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
import 'package:gui_lungcxr/feature_home/widgets/segment_bar.dart';
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

  testWidgets('segment tool opens the mask correction bar', (tester) async {
    final backend = FakeBackend();
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await tester.runAsync(() => session.login('doc@test', 'secret'));
    await _pumpApp(tester, session);
    await _settle(tester);

    await tester.tap(find.byIcon(FLucideIcons.spline));
    await tester.pump();
    final panel = find.byType(SegmentBar);
    expect(panel, findsOneWidget);
    expect(
      find.descendant(of: panel, matching: find.byIcon(FLucideIcons.brush)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: panel, matching: find.byIcon(FLucideIcons.eraser)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: panel, matching: find.byIcon(FLucideIcons.rotateCcw)),
      findsOneWidget,
    );
    // Nothing corrected yet, so there is nothing to re-evaluate.
    expect(find.text(Strings.reevaluate), findsOneWidget);

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
    await tester.tap(
      find.descendant(of: panel, matching: find.byIcon(FLucideIcons.x)),
    );
    await tester.pump();
    expect(find.byIcon(FLucideIcons.brush), findsNothing);
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

    // The create FAB floats over the workspace; its pop-up holds the form.
    await tester.tap(find.byIcon(FLucideIcons.plus));
    await _settle(tester);

    // Typing suggests existing patients; picking one fills both fields.
    await tester.enterText(
      find.byWidgetPredicate((w) => w is FAutocomplete).first,
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

    // A hospital not on the list can be created from the same form.
    await tester.enterText(
      find.byWidgetPredicate((w) => w is FAutocomplete).last,
      'Zomba Central',
    );
    await _settle(tester);
    expect(backend.log, contains('GET /hospitals?q=Zomba+Central'));
    await tester.tap(find.text(Strings.createHospitalNamed('Zomba Central')));
    await _settle(tester);
    expect(backend.log, contains('POST /hospitals'));
    expect(find.text(Strings.hospitalChosen), findsOneWidget);
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

    // Case management is its own page, reached from the sidebar.
    await tester.tap(find.textContaining(Strings.cases).first);
    await tester.pump();
    expect(find.text(Strings.selectCase), findsOneWidget);

    // Intake is where ticks are handed over to a doctor.
    await tester.tap(find.text(Strings.intakeTab));
    await tester.pump();
    expect(find.text('${Strings.assign} (0)'), findsOneWidget);

    final admin = tester
        .element(find.text('${Strings.assign} (0)'))
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

  testWidgets('an admin opens a waiting review from the dashboard', (
    tester,
  ) async {
    final backend = FakeBackend(role: 'admin');
    backend.cases[1] = caseJson(1, status: 'submitted');
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await tester.runAsync(() => session.login('admin@test', 'secret'));
    await _pumpApp(tester, session);
    await _settle(tester);

    // The opening line says what waits, and the queue lists the case.
    expect(find.textContaining(Strings.summarySignOffOne), findsOneWidget);
    final admin = tester
        .element(find.text(Strings.teamTitle))
        .read<AdminState>();
    expect(admin.statusFilter, isNull);

    await tester.ensureVisible(find.text(Strings.actionReview));
    await tester.tap(find.text(Strings.actionReview));
    await _settle(tester);
    expect(admin.statusFilter, CaseStatus.submitted);
    expect(admin.open?.id, 1);
    expect(find.byType(CaseList), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('an admin opens what to create from the fab pop-ups', (
    tester,
  ) async {
    final backend = FakeBackend(role: 'admin');
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await tester.runAsync(() => session.login('admin@test', 'secret'));
    await _pumpApp(tester, session);
    await _settle(tester);

    // The create button first asks what to make.
    await tester.tap(find.byIcon(FLucideIcons.plus));
    await _settle(tester);
    expect(find.text(Strings.uploadCase), findsOneWidget);
    expect(find.text(Strings.createUser), findsOneWidget);

    // Picking one floats the form in as a pop-up panel.
    await tester.tap(find.text(Strings.createUser));
    await _settle(tester);
    expect(find.text(Strings.fullName), findsOneWidget);
    expect(find.text(Strings.email), findsOneWidget);

    // Close the panel, then file a case the same way.
    await tester.tap(find.byIcon(FLucideIcons.x));
    await _settle(tester);
    await tester.tap(find.byIcon(FLucideIcons.plus));
    await _settle(tester);
    await tester.tap(find.text(Strings.uploadCase));
    await _settle(tester);
    expect(find.text(Strings.chooseImage), findsOneWidget);
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
