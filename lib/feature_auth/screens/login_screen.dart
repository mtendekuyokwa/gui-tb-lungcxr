import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() =>
      context.read<SessionState>().login(_email.text, _password.text);

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final theme = context.theme;

    return Center(
      child: SingleChildScrollView(
        padding: const .all(24),
        child: SizedBox(
          width: 360,
          child: FCard(
            child: Padding(
              padding: const .all(24),
              child: Column(
                crossAxisAlignment: .stretch,
                mainAxisSize: .min,
                spacing: 12,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      const Icon(FLucideIcons.scanEye),
                      Text(Strings.appName, style: theme.typography.display.lg),
                    ],
                  ),
                  Text(
                    Strings.signInPrompt,
                    style: theme.typography.body.sm.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                  FTextField(
                    control: .managed(controller: _email),
                    label: const Text(Strings.email),
                    keyboardType: .emailAddress,
                    textInputAction: .next,
                    autofocus: true,
                  ),
                  FTextField(
                    control: .managed(controller: _password),
                    label: const Text(Strings.password),
                    obscureText: true,
                    textInputAction: .done,
                    onSubmit: (_) => _submit(),
                  ),
                  if (session.error case final error?)
                    Text(
                      error,
                      style: theme.typography.body.sm.copyWith(
                        color: theme.colors.destructive,
                      ),
                    ),
                  FButton(
                    onPress: session.busy ? null : _submit,
                    child: const Text(Strings.signIn),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
