import 'package:flutter/foundation.dart';
import 'package:gui_lungcxr/api/api_client.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/feature_admin/api/admin_api.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';

/// Everything the hospital admin sees: all cases, the doctors, the cases
/// ticked for assignment and the case opened for review.
class AdminState extends ChangeNotifier {
  new({required ApiClient api}) : _api = AdminApi(api);

  final AdminApi _api;

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
    _doctors = [
      for (final user in await _api.users())
        if (user.isDoctor && user.active) user,
    ];
    _cases = await _api.cases(status: _statusFilter);
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
    _open = await _api.caseDetail(id);
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

  String imageUrl(int id) => _api.imageUrl(id);

  /// Headers the image widget needs to load [imageUrl].
  Map<String, String> get imageHeaders => _api.imageHeaders;

  /// Hands every ticked case to [doctorId].
  Future<bool> assign(int doctorId) => _guard(() async {
    await _api.assign(caseIds: _ticked.toList(), doctorId: doctorId);
    _ticked.clear();
    await _reload();
  });

  Future<bool> accept(int id) => _guard(() async {
    await _api.accept(id);
    await _reload();
  });

  Future<bool> returnToDoctor(int id, String note) => _guard(() async {
    await _api.returnToDoctor(id, note.trim());
    await _reload();
  });

  Future<bool> upload({
    required String patientName,
    required String hospitalNumber,
    required Uint8List bytes,
    required String filename,
  }) => _guard(() async {
    final number = hospitalNumber.trim();
    await _api.upload(
      patientName: patientName.trim(),
      hospitalNumber: number.isEmpty ? null : number,
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
