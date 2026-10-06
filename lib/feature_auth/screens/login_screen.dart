import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_images.dart';
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

    return SizedBox(
      width: 900,
      height: 800,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 0),
        child: FCard(
          child: Row(
            mainAxisAlignment: .spaceBetween,
            spacing: 12,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                height: 800,
                child: Image.asset(
                  AppImages.doctorHoldingTb,
                  width: 400,
                  fit: BoxFit.cover,
                ),
              ),
              Spacer(),
              SizedBox(
                width: 450,
                child: Column(
                  crossAxisAlignment: .stretch,
                  mainAxisSize: .min,
                  spacing: 12,
                  mainAxisAlignment: .center,
                  children: [
                    Row(
                      spacing: 8,
                      children: [
                        const Icon(FLucideIcons.scanEye),
                        Text(
                          Strings.appName,
                          style: theme.typography.display.lg,
                        ),
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
                      width: 100,
                      child: FButton(
                        onPress: session.busy ? null : _submit,
                        child: const Text(Strings.signIn),
                      ),
                    ),
                  ],
                ),
              ),
              Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
