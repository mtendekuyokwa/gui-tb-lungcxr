import 'package:flutter/foundation.dart';
import 'package:gui_lungcxr/api/api_client.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/feature_auth/api/auth_api.dart';

/// Who is signed in. The token lives in memory only, so a reload signs out.
class SessionState extends ChangeNotifier {
  new({ApiClient? api}) : api = api ?? ApiClient() {
    _auth.onUnauthorized = logout;
  }

  /// The signed-in client, handed to the role's own state once logged in.
  final ApiClient api;
  late final AuthApi _auth = AuthApi(api);

  AppUser? _user;
  Catalog _catalog = const Catalog();
  bool _busy = false;
  String? _error;

  AppUser? get user => _user;
  Catalog get catalog => _catalog;
  bool get busy => _busy;
  String? get error => _error;

  Future<void> login(String email, String password) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final user = await _auth.login(email.trim(), password);
      _catalog = await _auth.catalog();
      _user = user;
    } on ApiException catch (e) {
      _auth.clearToken();
      _error = e.message;
    }
    _busy = false;
    notifyListeners();
  }

  void logout() {
    if (_user == null && !_auth.hasToken) return;
    _auth.clearToken();
    _user = null;
    notifyListeners();
  }
}
