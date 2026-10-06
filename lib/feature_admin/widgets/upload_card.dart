import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/utils/pick_xray.dart';
import 'package:gui_lungcxr/feature_admin/widgets/admin_section.dart';
import 'package:provider/provider.dart';

/// Form for adding a case: patient details and the X-ray image.
class UploadCard extends StatefulWidget {
  const new({super.key});

  @override
  State<UploadCard> createState() => _UploadCardState();
}

class _UploadCardState extends State<UploadCard> {
  final _name = TextEditingController();
  final _number = TextEditingController();
  PlatformFile? _file;

  @override
  void initState() {
    super.initState();
    // The upload button depends on whether a name has been typed.
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    final file = await pickXray();
    if (file != null && mounted) setState(() => _file = file);
  }

  Future<void> _upload(AdminState admin) async {
    final file = _file;
    if (file == null) return;
    final ok = await admin.upload(
      patientName: _name.text,
      hospitalNumber: _number.text,
      bytes: await file.readAsBytes(),
      filename: file.name,
    );
    if (!ok || !mounted) return;
    _name.clear();
    _number.clear();
    setState(() => _file = null);
    showFToast(
      context: context,
      icon: const Icon(FLucideIcons.circleCheck),
      title: const Text(Strings.caseUploaded),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final ready = _file != null && _name.text.trim().isNotEmpty && !admin.busy;

    return AdminSection(
      title: Strings.uploadCase,
      children: [
        FTextField(
          control: .managed(controller: _name),
          hint: Strings.patientName,
        ),
        FTextField(
          control: .managed(controller: _number),
          hint: Strings.hospitalNumber,
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
      ],
    );
  }
}
