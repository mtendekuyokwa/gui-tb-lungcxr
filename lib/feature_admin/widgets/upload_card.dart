import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/utils/pick_xray.dart';
import 'package:gui_lungcxr/feature_admin/widgets/admin_section.dart';
import 'package:gui_lungcxr/widgets/patient_fields.dart';
import 'package:provider/provider.dart';

/// Form for adding a case: patient details (with return-visit suggestions)
/// and the X-ray image.
class UploadCard extends StatefulWidget {
  const UploadCard({super.key});

  @override
  State<UploadCard> createState() => _UploadCardState();
}

class _UploadCardState extends State<UploadCard> {
  String _name = '';
  String _number = '';
  PlatformFile? _file;
  int _attempt = 0; // re-keys the form to clear it after a successful upload

  Future<void> _choose() async {
    final file = await pickXray();
    if (file != null && mounted) setState(() => _file = file);
  }

  Future<void> _upload(AdminState admin) async {
    final file = _file;
    if (file == null) return;
    final ok = await admin.upload(
      patientName: _name,
      hospitalNumber: _number,
      bytes: await file.readAsBytes(),
      filename: file.name,
    );
    if (!ok || !mounted) return;
    setState(() {
      _name = '';
      _number = '';
      _file = null;
      _attempt++;
    });
    showFToast(
      context: context,
      icon: const Icon(FLucideIcons.circleCheck),
      title: const Text(Strings.caseUploaded),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final ready = _file != null && _name.trim().isNotEmpty && !admin.busy;

    return AdminSection(
      title: Strings.uploadCase,
      children: [
        PatientFields(
          key: ValueKey(_attempt),
          search: admin.patients,
          onChanged: (name, number) => setState(() {
            _name = name;
            _number = number;
          }),
        ),
        FButton(
          variant: .outline,
          size: .sm,
          onPress: _choose,
          prefix: const Icon(FLucideIcons.image),
          child: Flexible(
            child: Text(
              _file?.name ?? Strings.chooseImage,
              overflow: .ellipsis,
            ),
          ),
        ),
        FButton(
          size: .sm,
          onPress: ready ? () => _upload(admin) : null,
          prefix: const Icon(FLucideIcons.upload),
          child: const Text(Strings.upload),
        ),
        if (admin.error case final error?)
          Text(
            error,
            style: context.theme.typography.body.sm.copyWith(
              color: context.theme.colors.destructive,
            ),
          ),
      ],
    );
  }
}
