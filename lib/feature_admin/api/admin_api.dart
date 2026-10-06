import 'dart:typed_data';

import 'package:gui_lungcxr/api/api_client.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/endpoints.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';

/// The admin's backend calls, decoded into models. Throws [ApiException].
class AdminApi {
  const new(this._client);

  final ApiClient _client;

  Future<List<AppUser>> users() async {
    final json = await _client.get(Endpoints.adminUsers) as List;
    return [for (final item in json) AppUser.fromJson(item)];
  }

  /// Every case, or only those in [status].
  Future<List<CxrCase>> cases({CaseStatus? status}) async {
    final json = await _client.get(
      Endpoints.adminCases,
      query: {if (status != null) 'status': status.code},
    ) as List;
    return [for (final item in json) CxrCase.fromJson(item)];
  }

  /// One case with its review attached.
  Future<CxrCase> caseDetail(int id) async =>
      CxrCase.fromJson(await _client.get(Endpoints.adminCase(id)));

  Future<void> assign({required List<int> caseIds, required int doctorId}) =>
      _client.post(Endpoints.adminAssign, {
        'case_ids': caseIds,
        'doctor_id': doctorId,
      });

  Future<void> accept(int id) => _client.post(Endpoints.adminAccept(id));

  Future<void> returnToDoctor(int id, String note) =>
      _client.post(Endpoints.adminReturn(id), {'note': note});

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

  /// Headers the image widget needs to load [imageUrl].
  Map<String, String> get imageHeaders => _client.authHeaders;
}
