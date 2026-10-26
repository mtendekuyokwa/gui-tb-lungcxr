import 'dart:typed_data';

import 'package:gui_lungcxr/api/api_client.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/endpoints.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';

/// Case flags the admin can filter by. Codes match the backend's `flag` query.
enum CaseFlag {
  modelWrong('model_wrong'),
  needsTesting('needs_testing');

  const CaseFlag(this.code);

  final String code;
}

/// The admin's backend calls, decoded into models. Throws [ApiException].
class AdminApi {
  const new(this._client);

  final ApiClient _client;

  Future<List<AppUser>> users() async {
    final json = await _client.get(Endpoints.adminUsers) as List;
    return [for (final item in json) AppUser.fromJson(item)];
  }

  /// Every case, or only those matching the given filters.
  Future<List<CxrCase>> cases({
    CaseStatus? status,
    int? doctorId,
    CaseFlag? flag,
  }) async {
    final json = await _client.get(
      Endpoints.adminCases,
      query: {
        if (status != null) 'status': status.code,
        if (doctorId != null) 'doctor': '$doctorId',
        if (flag != null) 'flag': flag.code,
      },
    ) as List;
    return [for (final item in json) CxrCase.fromJson(item)];
  }

  /// One case with its review attached.
  Future<CxrCase> caseDetail(int id) async =>
      CxrCase.fromJson(await _client.get(Endpoints.adminCase(id)));

  Future<void> createUser({
    required String email,
    required String fullName,
    required String password,
    required String role,
  }) => _client.post(Endpoints.adminUsers, {
    'email': email,
    'full_name': fullName,
    'password': password,
    'role': role,
  });

  /// Activate or deactivate a user, rename them, or reset their password.
  /// Only non-null fields are sent.
  Future<AppUser> updateUser(
    int id, {
    bool? active,
    String? fullName,
    String? password,
  }) async {
    final json = await _client.patch(Endpoints.adminUser(id), {
      if (active != null) 'active': active,
      if (fullName != null) 'full_name': fullName,
      if (password != null) 'password': password,
    });
    return AppUser.fromJson(json as Map<String, dynamic>);
  }

  Future<void> assign({
    required List<int> caseIds,
    required int doctorId,
    DateTime? dueAt,
  }) => _client.post(Endpoints.adminAssign, {
    'case_ids': caseIds,
    'doctor_id': doctorId,
    'due_at': ?dueAt?.toUtc().toIso8601String(),
  });

  Future<void> accept(int id) => _client.post(Endpoints.adminAccept(id));

  Future<void> returnToDoctor(int id, String note) =>
      _client.post(Endpoints.adminReturn(id), {'note': note});

  Future<AdminStats> stats() async =>
      AdminStats.fromJson(await _client.get(Endpoints.adminStats));

  /// The CSV text of an export, without patient name or hospital number.
  Future<String> exportCsv(String kind) async =>
      (await _client.get(
            Endpoints.adminExport,
            query: {'kind': kind},
          ))
          as String;

  /// Download URL for a CSV export. Fetched with [imageHeaders].
  String exportUrl(String kind) =>
      _client.url('${Endpoints.adminExport}?kind=$kind');

  Future<void> upload({
    required String patientName,
    String? hospitalNumber,
    required Uint8List bytes,
    required String filename,
  }) => _client.upload(
    Endpoints.adminCases,
    fields: {'patient_name': patientName, 'hospital_number': ?hospitalNumber},
    fileField: 'image',
    bytes: bytes,
    filename: filename,
  );

  String imageUrl(int id) => _client.url(Endpoints.caseImage(id));
  String maskUrl(int id) => _client.url(Endpoints.caseMask(id));

  /// Headers the image widget needs to load [imageUrl].
  Map<String, String> get imageHeaders => _client.authHeaders;
}
