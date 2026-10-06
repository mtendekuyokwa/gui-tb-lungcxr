import 'package:gui_lungcxr/feature_home/screens/home.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/feature_admin/screens/admin_home.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_auth/screens/login_screen.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:gui_lungcxr/feature_home/state/case_state.dart';
import 'package:gui_lungcxr/theme/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => SessionState(),
      child: const Application(),
    ),
  );
}

class Application extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    // TODO: replace with your application's supported locales.
    supportedLocales: FLocalizations.supportedLocales,
    // TODO: add your application's localizations delegates.
    localizationsDelegates: const [...FLocalizations.localizationsDelegates],
    // MaterialApp's theme is also animated by default with the same duration and curve.
    // See https://api.flutter.dev/flutter/material/MaterialApp/themeAnimationStyle.html for how to configure this.
    //
    // There is a known issue with implicitly animated widgets where their transition occurs AFTER the theme's.
    // See https://github.com/duobaseio/forui/issues/670.
    theme: lightTheme.toApproximateMaterialTheme(),
    darkTheme: darkTheme.toApproximateMaterialTheme(),
    builder: (context, child) => FTheme(
      data: Theme.brightnessOf(context) == .light ? lightTheme : darkTheme,
      child: FToaster(child: FTooltipGroup(child: child!)),
    ),
    home: const FScaffold(child: AppGate()),
  );
}

/// Shows the login screen, or the workspace for the signed-in user's role.
class AppGate extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select<SessionState, AppUser?>((s) => s.user);
    if (user == null) return const LoginScreen();
    final api = context.read<SessionState>().api;
    // Keyed by user so nothing from one session leaks into the next.
    if (user.isAdmin) {
      return ChangeNotifierProvider(
        key: ValueKey(user.id),
        create: (_) => AdminState(api: api)..load(),
        child: const AdminHome(),
      );
    }
    return ChangeNotifierProvider(
      key: ValueKey(user.id),
      create: (_) => CaseState(api: api)..load(),
      child: const Home(),
    );
  }
}
