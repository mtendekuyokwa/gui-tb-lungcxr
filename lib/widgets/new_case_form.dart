import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/utils/pick_xray.dart';
import 'package:gui_lungcxr/widgets/busy_icon.dart';
import 'package:gui_lungcxr/widgets/hospital_field.dart';
import 'package:gui_lungcxr/widgets/patient_fields.dart';

/// A new case form: patient details (with return-visit suggestions), the
/// hospital (looked up or created) and the X-ray image. It lives inside a create pop-up, so it has no card chrome
/// of its own — the pop-up panel owns the title.
class NewCaseForm extends StatefulWidget {
  const NewCaseForm({
    required this.upload,
    required this.search,
    required this.searchHospitals,
    required this.createHospital,
    required this.busy,
    this.error,
    this.onDone,
    super.key,
  });

  /// Files the case with these details and reports whether it went through.
  final Future<bool> Function({
    required String patientName,
    required String hospitalNumber,
    int? hospitalId,
    required Uint8List bytes,
    required String filename,
  })
  upload;

  /// Backend patient search, e.g. `admin.patients` or `cases.patients`,
  /// for the return-visit suggestions.
  final Future<List<AppPatient>> Function(String query) search;

  /// Backend hospital lookup and creation for the hospital field.
  final Future<List<AppHospital>> Function(String query) searchHospitals;
  final Future<AppHospital> Function(String name) createHospital;

  /// The uploading state's busy flag, so the submit button disables.
  final bool busy;

  /// The uploading state's last error, if any.
  final String? error;

  /// Called after a successful upload, so the pop-up can close itself.
  final VoidCallback? onDone;

  @override
  State<NewCaseForm> createState() => _NewCaseFormState();
}

class _NewCaseFormState extends State<NewCaseForm> {
  String _name = '';
  String _number = '';
  PlatformFile? _file;
  AppHospital? _hospital;

  /// Covers reading the file as well as the upload itself, so the spinner
  /// shows from the first press.
  bool _sending = false;
  int _attempt = 0; // re-keys the form to clear it after a successful upload

  Future<void> _choose() async {
    final file = await pickXray();
    if (file != null && mounted) setState(() => _file = file);
  }

  Future<void> _submit() async {
    final file = _file;
    if (file == null || _sending) return;
    setState(() => _sending = true);
    final bool ok;
    try {
      ok = await widget.upload(
        patientName: _name,
        hospitalNumber: _number,
        hospitalId: _hospital?.id,
        bytes: await file.readAsBytes(),
        filename: file.name,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    if (!ok || !mounted) return;
    setState(() {
      _name = '';
      _number = '';
      _file = null;
      _hospital = null;
      _attempt++;
    });
    widget.onDone?.call();
    showFToast(
      context: context,
      icon: const Icon(FLucideIcons.circleCheck),
      title: const Text(Strings.caseUploaded),
    );
  }

  @override
  Widget build(BuildContext context) {
    final working = _sending || widget.busy;
    final ready = _file != null && _name.trim().isNotEmpty && !working;

    return Column(
      crossAxisAlignment: .stretch,
      spacing: AppSizes.gap8,
      children: [
        PatientFields(
          key: ValueKey(_attempt),
          search: widget.search,
          onChanged: (name, number) => setState(() {
            _name = name;
            _number = number;
          }),
        ),
        HospitalField(
          key: ValueKey(('hospital', _attempt)),
          search: widget.searchHospitals,
          create: widget.createHospital,
          onChanged: (hospital) => setState(() => _hospital = hospital),
        ),
        FButton(
          variant: .outline,
          size: .sm,
          onPress: working ? null : _choose,
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
          onPress: ready ? _submit : null,
          prefix: BusyIcon(busy: working, icon: FLucideIcons.upload),
          child: Text(working ? Strings.uploading : Strings.upload),
        ),
        if (widget.error case final error?)
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
