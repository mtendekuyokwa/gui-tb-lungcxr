import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/api/api_client.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';

/// The patient part of an upload form: name and hospital number.
///
/// Typing at least two characters suggests existing patients (name or
/// hospital number); picking one fills both fields, so a return visit never
/// needs retyping. Reports the current values through [onChanged] whenever
/// either field changes.
class PatientFields extends StatefulWidget {
  const PatientFields({
    required this.search,
    required this.onChanged,
    this.initialName = '',
    this.initialNumber = '',
    super.key,
  });

  /// Backend patient search, e.g. `admin.patients`.
  final Future<List<AppPatient>> Function(String query) search;
  final void Function(String name, String number) onChanged;
  final String initialName;
  final String initialNumber;

  @override
  State<PatientFields> createState() => _PatientFieldsState();
}

class _PatientFieldsState extends State<PatientFields> {
  late final FAutocompleteController _name;
  late final TextEditingController _number;

  @override
  void initState() {
    super.initState();
    _name = FAutocompleteController(text: widget.initialName);
    _number = TextEditingController(text: widget.initialNumber);
    _name.addListener(_fire);
    _number.addListener(_fire);
  }

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  void _fire() => widget.onChanged(_name.text, _number.text);

  Future<List<AppPatient>> _filter(String query) async {
    final typed = query.trim();
    if (typed.length < 2) return const [];
    try {
      return await widget.search(typed);
    } on ApiException {
      return const []; // suggestions are optional; the fields still work
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      spacing: AppSizes.gap8,
      children: [
        FAutocomplete<AppPatient>.builder(
          control: .managed(controller: _name),
          hint: Strings.patientNameOrNumber,
          filter: _filter,
          format: (patient) => patient.name,
          parse: (_) => null, // free text stays free text
          contentBuilder: (context, query, patients) => [
            for (final patient in patients)
              FAutocompleteItem<AppPatient>(
                value: patient,
                title: Text(patient.name),
                subtitle: patient.detail.isEmpty
                    ? null
                    : Text(patient.detail, overflow: .ellipsis),
              ),
          ],
          onItemPress: (patient) {
            setState(() => _number.text = patient.hospitalNumber ?? '');
            widget.onChanged(patient.name, _number.text);
          },
        ),
        FTextField(
          control: .managed(controller: _number),
          hint: Strings.hospitalNumber,
          description: Text(Strings.patientReuse),
        ),
      ],
    );
  }
}
