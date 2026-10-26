import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gui_lungcxr/api/api_client.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/api/admin_api.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';

export 'package:gui_lungcxr/feature_admin/api/admin_api.dart' show CaseFlag;

/// Everything the hospital admin sees: all cases, the doctors, the cases
/// ticked for assignment and the case opened for review.
class AdminState extends ChangeNotifier {
  new({required ApiClient api, this.pollInterval = _pollInterval})
    : _api = AdminApi(api);

  final AdminApi _api;

  /// How long after a load to check again while any visible reading is
  /// still queued. Tests use a short one.
  final Duration pollInterval;

  /// The worker usually answers within seconds; polling much faster just
  /// hammers the list endpoint.
  static const Duration _pollInterval = Duration(seconds: 5);

  List<CxrCase> _cases = const [];
  List<AppUser> _allUsers = const [];
  CaseStatus? _statusFilter;
  int? _doctorFilter;
  CaseFlag? _flagFilter;
  AdminStats? _stats;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final Set<int> _ticked = {};
  CxrCase? _open;
  bool _disposed = false;
  Timer? _poll;

  /// Counts loads so a slow earlier reload cannot overwrite a newer one
  /// when filters change in quick succession.
  int _loadGen = 0;

  List<CxrCase> get cases => _cases;

  /// Active doctors, the only users a case can be assigned to.
  List<AppUser> get doctors => [
    for (final user in _allUsers)
      if (user.isDoctor && user.active) user,
  ];

  /// Every user including deactivated ones, for the doctors card.
  List<AppUser> get allUsers => _allUsers;
  CaseStatus? get statusFilter => _statusFilter;
  int? get doctorFilter => _doctorFilter;
  CaseFlag? get flagFilter => _flagFilter;
  AdminStats? get stats => _stats;
  bool get loading => _loading;

  /// True while an action is in flight; buttons disable themselves.
  bool get busy => _busy;
  String? get error => _error;
  Set<int> get ticked => _ticked;

  /// The case whose review is shown in the side panel.
  CxrCase? get open => _open;

  /// True while any visible case is still waiting on the model worker,
  /// so the UI can say so instead of showing "awaiting" in silence.
  bool get waitingOnModel =>
      _cases.any((c) => c.prediction?.state == 'queued') ||
      (_open?.prediction?.state == 'queued' ?? false);

  Future<void> load() => _guard(_reload);

  Future<void> _reload() async {
    final gen = ++_loadGen;
    final users = await _api.users();
    final cases = await _api.cases(
      status: _statusFilter,
      doctorId: _doctorFilter,
      flag: _flagFilter,
    );
    AdminStats? stats;
    try {
      stats = await _api.stats();
    } on ApiException {
      // Stats are a bonus panel; a failure must not blank the case list.
      stats = null;
    }
    // A newer reload started while awaiting: its results win.
    if (gen != _loadGen) return;
    _allUsers = users;
    _cases = cases;
    if (stats != null) _stats = stats;
    // Prune only ticks the fresh list disproves: cases under another
    // status filter keep their ticks, so filtering never unticks work.
    _ticked.removeAll([
      for (final c in _cases)
        if (!c.status.assignable) c.id,
    ]);
    if (_open case final open?) await _fetchOpen(open.id);
    _loading = false;
    _notify();
    _schedulePoll();
  }

  /// Rechecks the list once the worker has had time to answer, but only
  /// while a visible reading is still queued — so a fresh upload's model
  /// reading resolves on its own instead of needing a manual reload.
  /// Polls quietly: no busy flicker, and a failed poll keeps the old data.
  void _schedulePoll() {
    _poll?.cancel();
    _poll = null;
    if (_disposed || _loading || !waitingOnModel) return;
    _poll = Timer(pollInterval, () async {
      if (_disposed) return;
      try {
        await _reload();
      } on ApiException {
        // Keep the old data; the next poll or manual reload retries.
        _schedulePoll();
      }
    });
  }

  Future<void> _fetchOpen(int id) async {
    _open = await _api.caseDetail(id);
  }

  Future<void> setStatusFilter(CaseStatus? status) {
    if (status == _statusFilter) return Future.value();
    _statusFilter = status;
    return load();
  }

  Future<void> setDoctorFilter(int? doctorId) {
    if (doctorId == _doctorFilter) return Future.value();
    _doctorFilter = doctorId;
    return load();
  }

  Future<void> setFlagFilter(CaseFlag? flag) {
    if (flag == _flagFilter) return Future.value();
    _flagFilter = flag;
    return load();
  }

  void toggleTicked(int id) {
    if (_busy) return;
    if (!_ticked.remove(id)) _ticked.add(id);
    notifyListeners();
  }

  Future<void> openCase(int id) => _guard(() => _fetchOpen(id));

  String imageUrl(int id) => _api.imageUrl(id);
  String maskUrl(int id) => _api.maskUrl(id);

  /// Headers the image widget needs to load [imageUrl].
  Map<String, String> get imageHeaders => _api.imageHeaders;

  /// Download URLs for the CSV exports, fetched with [imageHeaders].
  String exportUrl(String kind) => _api.exportUrl(kind);

  /// The CSV text of an export, for copy/download panels.
  Future<String?> exportCsv(String kind) async {
    String? csv;
    final ok = await _guard(() async {
      csv = await _api.exportCsv(kind);
    });
    return ok ? csv : null;
  }

  /// Hands every ticked case to [doctorId], optionally with a due date.
  Future<bool> assign(int doctorId, {DateTime? dueAt}) => _guard(() async {
    // Ticks can go stale while hidden under another filter or when a case
    // disappears: re-check against the full list rather than trusting them.
    final known = {
      for (final c in await _api.cases())
        if (c.status.assignable) c.id,
    };
    final stale = _ticked.difference(known);
    _ticked.removeAll(stale);
    if (stale.isNotEmpty) {
      throw ApiException(409, Strings.assignStale);
    }
    if (_ticked.isEmpty) {
      throw ApiException(422, Strings.selectCasesToAssign);
    }
    await _api.assign(
      caseIds: _ticked.toList(),
      doctorId: doctorId,
      dueAt: dueAt,
    );
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

  Future<bool> createUser({
    required String email,
    required String fullName,
    required String password,
    required String role,
  }) => _guard(() async {
    await _api.createUser(
      email: email.trim(),
      fullName: fullName.trim(),
      password: password,
      role: role,
    );
    await _reload();
  });

  /// Deactivate or reactivate a user. The backend refuses self-deactivation.
  Future<bool> setUserActive(int id, bool active) => _guard(() async {
    await _api.updateUser(id, active: active);
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
    _poll?.cancel();
    super.dispose();
  }
}
