import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:gui_lungcxr/main.dart';
import 'package:gui_lungcxr/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backend.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('debug narrow admin', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend(role: 'admin');
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await tester.runAsync(() => session.login('admin@test', 'secret'));
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
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.tap(find.text(Strings.casesTab));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText())
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toSet()
        .toList();
    debugPrint('TEXTS: $texts');

    debugPrint(
      'intake matches: ${find.text(Strings.intakeTab).evaluate().length}',
    );
  });
}
