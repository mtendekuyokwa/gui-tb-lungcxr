import 'package:gui_lungcxr/api/api_client.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/endpoints.dart';

/// Sign-in calls and the bearer token every other request rides on. Throws
/// [ApiException].
class AuthApi {
  const new(this._client);

  final ApiClient _client;

  bool get hasToken => _client.token != null;

  /// Called when the backend rejects the token.
  set onUnauthorized(void Function() callback) =>
      _client.onUnauthorized = callback;

  /// Signs in and keeps the token for the requests that follow.
  Future<AppUser> login(String email, String password) async {
    final json = await _client.post(Endpoints.login, {
      'email': email,
      'password': password,
    });
    _client.token = json['token'] as String;
    return AppUser.fromJson(json['user']);
  }

  /// The choice lists; needs a signed-in user.
  Future<Catalog> catalog() async =>
      Catalog.fromJson(await _client.get(Endpoints.catalog));

  void clearToken() => _client.token = null;
}
