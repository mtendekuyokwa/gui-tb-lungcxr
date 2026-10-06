import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';

/// The patient's initials; cases carry no portrait.
class PatientAvatar extends StatelessWidget {
  const new({required this.initials, this.size = AppSizes.avatarLg, super.key});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) =>
      FAvatar.raw(size: size, child: Text(initials));
}
