import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/api/api_client.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';

/// Picks the hospital an X-ray came from: typing suggests existing
/// hospitals, and a name that is not on the list can be created on the
/// spot. Reports the chosen hospital (or null once the text no longer
/// matches it) through [onChanged].
class HospitalField extends StatefulWidget {
  const HospitalField({
    required this.search,
    required this.create,
    required this.onChanged,
    super.key,
  });

  /// Backend hospital search, e.g. `cases.hospitals`.
  final Future<List<AppHospital>> Function(String query) search;

  /// Backend hospital creation, e.g. `cases.createHospital`.
  final Future<AppHospital> Function(String name) create;

  final ValueChanged<AppHospital?> onChanged;

  @override
  State<HospitalField> createState() => _HospitalFieldState();
}

/// Marks the "create" suggestion; real hospitals have positive ids.
const int _newHospitalId = -1;

class _HospitalFieldState extends State<HospitalField> {
  final _name = FAutocompleteController();
  AppHospital? _chosen;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onText);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Editing the text after a pick un-picks the hospital.
  void _onText() {
    final chosen = _chosen;
    if (chosen != null && _name.text.trim() != chosen.name) _choose(null);
  }

  void _choose(AppHospital? hospital) {
    setState(() {
      _chosen = hospital;
      _error = null;
    });
    widget.onChanged(hospital);
  }

  Future<List<AppHospital>> _filter(String query) async {
    final typed = query.trim();
    if (typed.isEmpty) return const [];
    List<AppHospital> found;
    try {
      found = await widget.search(typed);
    } on ApiException {
      found = const []; // suggestions are optional; creating still works
    }
    final exact = found.any((h) => h.name.toLowerCase() == typed.toLowerCase());
    return [...found, if (!exact) AppHospital(id: _newHospitalId, name: typed)];
  }

  Future<void> _pick(AppHospital hospital) async {
    if (hospital.id != _newHospitalId) {
      _choose(hospital);
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final created = await widget.create(hospital.name);
      if (!mounted) return;
      _name.text = created.name;
      _choose(created);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    final chosen = _chosen;

    return Column(
      crossAxisAlignment: .stretch,
      spacing: AppSizes.gap4,
      children: [
        FAutocomplete<AppHospital>.builder(
          control: .managed(controller: _name),
          hint: Strings.hospitalHint,
          enabled: !_creating,
          filter: _filter,
          format: (hospital) => hospital.name,
          parse: (_) => null, // a typed name is only a query until picked
          contentBuilder: (context, query, hospitals) => [
            for (final hospital in hospitals)
              FAutocompleteItem<AppHospital>(
                value: hospital,
                prefix: Icon(
                  hospital.id == _newHospitalId
                      ? FLucideIcons.plus
                      : FLucideIcons.building2,
                ),
                title: Text(
                  hospital.id == _newHospitalId
                      ? Strings.createHospitalNamed(hospital.name)
                      : hospital.name,
                  overflow: .ellipsis,
                ),
              ),
          ],
          onItemPress: _pick,
        ),
        Row(
          spacing: AppSizes.gap6,
          children: [
            if (_creating) const FCircularProgress(size: .xs),
            Expanded(
              child: Text(
                _error ??
                    (_creating
                        ? Strings.creatingHospital
                        : chosen != null
                        ? Strings.hospitalChosen
                        : Strings.hospitalHelp),
                style: _error == null
                    ? muted
                    : muted.copyWith(color: theme.colors.destructive),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
