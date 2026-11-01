import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/utils/pick_xray.dart';
import 'package:gui_lungcxr/feature_home/state/case_state.dart';
import 'package:gui_lungcxr/widgets/patient_fields.dart';
import 'package:provider/provider.dart';

/// The doctor's own upload: patient details (with return-visit suggestions)
/// and the X-ray image. Hidden behind a button so the case list stays small;
/// collapses after success.
class DoctorUpload extends StatefulWidget {
  const DoctorUpload({
    required this.open,
    required this.onToggle,
    super.key,
  });

  final bool open;
  final VoidCallback onToggle;

  @override
  State<DoctorUpload> createState() => _DoctorUploadState();
}

class _DoctorUploadState extends State<DoctorUpload> {
  String _name = '';
  String _number = '';
  PlatformFile? _file;
  int _attempt = 0; // re-keys the form to clear it after a successful upload

  Future<void> _choose() async {
    final file = await pickXray();
    if (file != null && mounted) setState(() => _file = file);
  }

  Future<void> _upload(CaseState state) async {
    final file = _file;
    if (file == null) return;
    final ok = await state.upload(
      patientName: _name,
      hospitalNumber: _number,
      bytes: await file.readAsBytes(),
      filename: file.name,
    );
    if (!ok) return;
    _name = '';
    _number = '';
    widget.onToggle(); // collapse the form again
    if (mounted) {
      setState(() {
        _file = null;
        _attempt++;
      });
      showFToast(
        context: context,
        icon: const Icon(FLucideIcons.circleCheck),
        title: const Text(Strings.caseUploaded),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CaseState>();
    final ready = _file != null && _name.trim().isNotEmpty && !state.busy;

    if (!widget.open) {
      return FButton(
        variant: .outline,
        size: .sm,
        onPress: widget.onToggle,
        prefix: const Icon(FLucideIcons.upload, size: AppSizes.icon16),
        child: Text(Strings.uploadCase),
      );
    }

    return Column(
      crossAxisAlignment: .stretch,
      spacing: AppSizes.gap8,
      children: [
        PatientFields(
          key: ValueKey(_attempt),
          search: state.patients,
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
          onPress: ready ? () => _upload(state) : null,
          prefix: const Icon(FLucideIcons.upload),
          child: const Text(Strings.upload),
        ),
        if (state.error != null)
          Text(
            state.error!,
            style: context.theme.typography.body.sm.copyWith(
              color: context.theme.colors.destructive,
            ),
          ),
      ],
    );
  }
}
