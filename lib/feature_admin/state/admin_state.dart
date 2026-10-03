import 'package:flutter/foundation.dart';
import 'package:gui_lungcxr/api/api_client.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/endpoints.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';

/// Everything the hospital admin sees: all cases, the doctors, the cases
/// ticked for assignment and the case opened for review.
class AdminState extends ChangeNotifier {
  new({required this.api});

  final ApiClient api;

  List<CxrCase> _cases = const [];
  List<AppUser> _doctors = const [];
  CaseStatus? _statusFilter;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final Set<int> _ticked = {};
  CxrCase? _open;
  bool _disposed = false;

  List<CxrCase> get cases => _cases;

  /// Active doctors, the only users a case can be assigned to.
  List<AppUser> get doctors => _doctors;
  CaseStatus? get statusFilter => _statusFilter;
  bool get loading => _loading;

  /// True while an action is in flight; buttons disable themselves.
  bool get busy => _busy;
  String? get error => _error;
  Set<int> get ticked => _ticked;

  /// The case whose review is shown in the side panel.
  CxrCase? get open => _open;

  Future<void> load() => _guard(_reload);

  Future<void> _reload() async {
    final users = await api.get(Endpoints.adminUsers) as List;
    _doctors = [
      for (final json in users)
        if (AppUser.fromJson(json) case final user
            when user.isDoctor && user.active)
          user,
    ];
    final json = await api.get(
      Endpoints.adminCases,
      query: {if (_statusFilter case final status?) 'status': status.code},
    ) as List;
    _cases = [for (final item in json) CxrCase.fromJson(item)];
    // Only cases still in the list, and still assignable, stay ticked.
    final assignable = {
      for (final c in _cases)
        if (c.status.assignable) c.id,
    };
    _ticked.retainAll(assignable);
    if (_open case final open?) await _fetchOpen(open.id);
    _loading = false;
  }

  Future<void> _fetchOpen(int id) async {
    _open = CxrCase.fromJson(await api.get(Endpoints.adminCase(id)));
  }

  void setStatusFilter(CaseStatus? status) {
    if (status == _statusFilter) return;
    _statusFilter = status;
    load();
  }

  void toggleTicked(int id) {
    if (!_ticked.remove(id)) _ticked.add(id);
    notifyListeners();
  }

  Future<void> openCase(int id) => _guard(() => _fetchOpen(id));

  String imageUrl(int id) => api.url(Endpoints.caseImage(id));

  Future<bool> assign(int doctorId) => _guard(() async {
    await api.post(Endpoints.adminAssign, {
      'case_ids': _ticked.toList(),
      'doctor_id': doctorId,
    });
    _ticked.clear();
    await _reload();
  });

  Future<bool> accept(int id) => _guard(() async {
    await api.post(Endpoints.adminAccept(id));
    await _reload();
  });

  Future<bool> returnToDoctor(int id, String note) => _guard(() async {
    await api.post(Endpoints.adminReturn(id), {'note': note});
    await _reload();
  });

  Future<bool> upload({
    required String patientName,
    required String hospitalNumber,
    required Uint8List bytes,
    required String filename,
  }) => _guard(() async {
    await api.upload(
      Endpoints.adminCases,
      fields: {
        'patient_name': patientName.trim(),
        if (hospitalNumber.trim().isNotEmpty)
          'hospital_number': hospitalNumber.trim(),
      },
      fileField: 'image',
      bytes: bytes,
      filename: filename,
    );
    await _reload();
  });

  /// Runs [action], reporting whether it succeeded and keeping any error.
  Future<bool> _guard(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    _notify();
    var ok = true;
    try {
      await action();
    } on ApiException catch (e) {
      _error = e.message;
      _loading = false;
      ok = false;
    }
    _busy = false;
    _notify();
    return ok;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
