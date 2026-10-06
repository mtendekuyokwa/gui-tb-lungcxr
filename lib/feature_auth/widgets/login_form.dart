import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:gui_lungcxr/widgets/app_brand.dart';
import 'package:provider/provider.dart';

/// Email and password fields, the sign-in error and the submit button.
class LoginForm extends StatefulWidget {
  const new({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
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

    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      spacing: AppSizes.gap12,
      mainAxisAlignment: .center,
      children: [
        const AppBrand(),
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
          hint: Strings.tamaraBandaemail,
          autofocus: true,
        ),
        FTextField.password(
          control: .managed(controller: _password),
          label: const Text(Strings.password),
          hint: Strings.enterPassword,
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
        SizedBox(
          width: AppSizes.loginButtonWidth,
          child: FButton(
            onPress: session.busy ? null : _submit,
            child: const Text(Strings.signIn),
          ),
        ),
      ],
    );
  }
}
