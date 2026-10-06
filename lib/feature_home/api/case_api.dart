import 'package:gui_lungcxr/api/api_client.dart';
import 'package:gui_lungcxr/constants/endpoints.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:gui_lungcxr/feature_home/models/review_draft.dart';

/// The doctor's backend calls, decoded into models. Throws [ApiException].
class CaseApi {
  const new(this._client);

  final ApiClient _client;

  /// The cases assigned to the signed-in doctor.
  Future<List<CxrCase>> cases() async {
    final json = await _client.get(Endpoints.cases) as List;
    return [for (final item in json) CxrCase.fromJson(item)];
  }

  /// One case with its review; fetching it marks it as opened.
  Future<CxrCase> caseDetail(int id) async =>
      CxrCase.fromJson(await _client.get(Endpoints.caseDetail(id)));

  /// Replaces the saved draft and returns the case as it now stands.
  Future<CxrCase> saveReview(int id, ReviewDraft draft) async =>
      CxrCase.fromJson(await _client.put(Endpoints.review(id), draft.toJson()));

  /// Locks the review and hands the case back to the admin.
  Future<CxrCase> submitReview(int id) async =>
      CxrCase.fromJson(await _client.post(Endpoints.submitReview(id)));

  String imageUrl(int id) => _client.url(Endpoints.caseImage(id));
  String overlayUrl(int id) => _client.url(Endpoints.caseOverlay(id));

  /// Headers the image widgets need to load [imageUrl] and [overlayUrl].
  Map<String, String> get imageHeaders => _client.authHeaders;
}
