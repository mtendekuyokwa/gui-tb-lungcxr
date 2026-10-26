import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/widgets/admin_section.dart';
import 'package:provider/provider.dart';

/// Form for creating a new user (doctor or admin).
enum UserRole { doctor, admin }

class NewUser extends StatefulWidget {
  const NewUser({super.key});

  @override
  State<NewUser> createState() => _NewUserState();
}

class _NewUserState extends State<NewUser> {
  final _email = TextEditingController();
  final _fullName = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.doctor;

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() {}));
    _fullName.addListener(() => setState(() {}));
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    _fullName.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(AdminState admin) async {
    final ok = await admin.createUser(
      email: _email.text,
      fullName: _fullName.text,
      password: _password.text,
      role: _role.name,
    );
    if (!ok || !mounted) return;
    _email.clear();
    _fullName.clear();
    _password.clear();
    setState(() => _role = UserRole.doctor);
    showFToast(
      context: context,
      icon: const Icon(FLucideIcons.circleCheck),
      title: const Text(Strings.userCreated),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final ready =
        _email.text.trim().isNotEmpty &&
        _fullName.text.trim().isNotEmpty &&
        _password.text.length >= 8 &&
        !admin.busy;

    return AdminSection(
      title: Strings.createUser,
      children: [
        FTextField(
          control: .managed(controller: _fullName),
          hint: Strings.fullName,
        ),
        FTextField(
          control: .managed(controller: _email),
          hint: Strings.email,
          keyboardType: .emailAddress,
        ),
        FTextField.password(
          control: .managed(controller: _password),
          hint: Strings.enterPassword,
        ),

        FButton(
          size: .sm,
          onPress: ready ? () => _submit(admin) : null,
          prefix: const Icon(FLucideIcons.user),
          child: const Text(Strings.createUser),
        ),
      ],
    );
  }
}
