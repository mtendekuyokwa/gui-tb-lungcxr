import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/feature_home/models/patient.dart';

/// Patient portrait, or their initials when there is no photo or it fails to
/// load.
class PatientAvatar extends StatelessWidget {
  const new({required this.patient, this.size = 40, super.key});

  final Patient patient;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = Text(patient.initials);
    return switch (patient.photo) {
      final photo? => FAvatar(
        size: size,
        image: AssetImage(photo),
        semanticsLabel: patient.name,
        fallback: initials,
      ),
      null => FAvatar.raw(size: size, child: initials),
    };
  }
}
