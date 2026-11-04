import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gui_lungcxr/api/api_client.dart';
import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/feature_auth/api/auth_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Who is signed in. Each account keeps its own token in local storage under
/// a per-email key, so two users can be signed in at once (e.g. two tabs or
/// two accounts in one browser) and signing out one never deletes another
/// account's token. The most recent sign-in is restored on a page reload.
class SessionState extends ChangeNotifier {
  new({ApiClient? api}) : api = api ?? ApiClient() {
    _auth.onUnauthorized = logout;
  }

  /// Prefix of every per-account token key: `$_tokenPrefix<email>`.
  @visibleForTesting
  static const tokenPrefix = 'lungcxr.token.';

  /// Local-storage key of the most recently signed-in account's email.
  @visibleForTesting
  static const lastUserKey = 'lungcxr.last-user';

  /// Legacy single-token key from before per-account storage. Found tokens
  /// are validated on restore and migrated to their per-account key.
  @visibleForTesting
  static const legacyTokenKey = 'lungcxr.token';

  /// Local-storage key for an account's bearer token. Only the token is
  /// stored: the user and catalog are reloaded from the backend on restore.
  static String tokenKeyFor(String email) =>
      '$tokenPrefix${email.toLowerCase()}';

  /// The signed-in client, handed to the role's own state once logged in.
  final ApiClient api;
  late final AuthApi _auth = AuthApi(api);

  AppUser? _user;
  Catalog _catalog = const Catalog();
  bool _busy = false;
  bool _restoring = false;
  String? _error;

  AppUser? get user => _user;
  Catalog get catalog => _catalog;
  bool get busy => _busy;

  /// True while a stored token is being checked on startup.
  bool get restoring => _restoring;
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(tokenKeyFor(user.email), _auth.token!);
      await prefs.setString(lastUserKey, user.email.toLowerCase());
    } on ApiException catch (e) {
      _auth.clearToken();
      _error = e.message;
    }
    _busy = false;
    notifyListeners();
  }

  /// Checks a stored token on startup. A rejected or missing token leaves
  /// the user signed out; the app shows a loading state until this returns.
  Future<void> restore() async {
    _restoring = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(lastUserKey);
    if (last != null && await _try(prefs, prefs.getString(tokenKeyFor(last)))) {
      _restoring = false;
      _notify();
      return;
    }
    // That account is gone: drop its token and the pointer, but never the
    // other accounts' tokens. Migration: an old single-token session is
    // adopted for its account.
    if (last != null) {
      await prefs.remove(tokenKeyFor(last));
      if (prefs.getString(lastUserKey) == last) {
        await prefs.remove(lastUserKey);
      }
      _done();
      return;
    }
    final legacy = prefs.getString(legacyTokenKey);
    if (legacy != null) {
      if (await _try(prefs, legacy, migrateLegacy: true)) {
        _done();
        return;
      }
    }
    _done();
  }

  void _done() {
    _restoring = false;
    _notify();
  }

  /// Puts [token] on the client and checks it against the backend. Restored
  /// sessions stay signed in; a rejected token is not kept on the client.
  /// With [migrateLegacy] the validated token moves to its per-account key.
  Future<bool> _try(
    SharedPreferences prefs,
    String? token, {
    bool migrateLegacy = false,
  }) async {
    if (token == null) return false;
    _auth.token = token;
    try {
      _user = await _auth.me();
      _catalog = await _auth.catalog();
      if (migrateLegacy) {
        await prefs.setString(tokenKeyFor(_user!.email), token);
        await prefs.setString(lastUserKey, _user!.email.toLowerCase());
        await prefs.remove(legacyTokenKey);
      }
      return true;
    } on ApiException {
      _auth.clearToken();
      return false;
    }
  }

  void logout() {
    if (_user == null && !_auth.hasToken) return;
    final email = _user?.email;
    _auth.clearToken();
    _user = null;
    _catalog = const Catalog();
    unawaited(_forget(email));
    notifyListeners();
  }

  /// Removes only this account's stored token. Another account's token stays,
  /// and the most-recent pointer moves to a remaining signed-in account.
  Future<void> _forget(String? email) async {
    final prefs = await SharedPreferences.getInstance();
    if (email case final email?) {
      final key = tokenKeyFor(email);
      await prefs.remove(key);
      if (prefs.getString(lastUserKey) == email.toLowerCase()) {
        final others = prefs
            .getKeys()
            .where((stored) => stored.startsWith(tokenPrefix) && stored != key)
            .toList();
        if (others.isEmpty) {
          await prefs.remove(lastUserKey);
        } else {
          final next = others.first;
          await prefs.setString(
            lastUserKey,
            next.substring(tokenPrefix.length),
          );
        }
      }
    } else {
      // Unknown account (e.g. a 401 before the user loaded): the pointer can
      // not be trusted, but other accounts' tokens are still left alone.
      await prefs.remove(lastUserKey);
      await prefs.remove(legacyTokenKey);
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
