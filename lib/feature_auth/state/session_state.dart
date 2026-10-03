import 'package:flutter/foundation.dart';
import 'package:gui_lungcxr/api/api_client.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/endpoints.dart';

/// Who is signed in. The token lives in memory only, so a reload signs out.
class SessionState extends ChangeNotifier {
  new({ApiClient? api}) : api = api ?? ApiClient() {
    this.api.onUnauthorized = logout;
  }

  final ApiClient api;

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
      final json = await api.post(Endpoints.login, {
        'email': email.trim(),
        'password': password,
      });
      api.token = json['token'] as String;
      _catalog = Catalog.fromJson(await api.get(Endpoints.catalog));
      _user = AppUser.fromJson(json['user']);
    } on ApiException catch (e) {
      api.token = null;
      _error = e.message;
    }
    _busy = false;
    notifyListeners();
  }

  void logout() {
    if (_user == null && api.token == null) return;
    api.token = null;
    _user = null;
    notifyListeners();
  }
}
