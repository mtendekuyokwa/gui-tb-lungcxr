import 'package:flutter_test/flutter_test.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backend.dart';

const doctorTokenKey =
    '${SessionState.tokenPrefix}doc@test';
const adminTokenKey =
    '${SessionState.tokenPrefix}admin@test';

Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

void main() {
  late FakeBackend backend;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = FakeBackend();
  });

  test('login persists the token for the next launch', () async {
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await session.login('doc@test', 'secret');
    expect(session.user?.isDoctor, isTrue);
    expect((await prefs()).getString(doctorTokenKey), 'token-1');
    expect(
      (await prefs()).getString(SessionState.lastUserKey),
      'doc@test',
    );
  });

  test('a wrong password persists nothing', () async {
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await session.login('doc@test', 'nope');
    expect(session.user, isNull);
    expect((await prefs()).getKeys(), isEmpty);
  });

  test('restore hydrates the user from a stored token', () async {
    SharedPreferences.setMockInitialValues({
      SessionState.lastUserKey: 'doc@test',
      doctorTokenKey: 'token-1',
    });
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    expect(session.restoring, isFalse);
    await session.restore();
    expect(session.restoring, isFalse);
    expect(session.user?.fullName, 'Doc One');
    expect(session.catalog.verdicts, hasLength(3));
    expect(
      backend.log,
      containsAll(['GET /auth/me', 'GET /catalog']),
    );
  });

  test('restore with a rejected token stays signed out', () async {
    SharedPreferences.setMockInitialValues({
      SessionState.lastUserKey: 'doc@test',
      doctorTokenKey: 'stale',
    });
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await session.restore();
    expect(session.user, isNull);
    expect(backend.api.token, isNull);
    final stored = await prefs();
    expect(stored.getString(doctorTokenKey), isNull);
    expect(stored.getString(SessionState.lastUserKey), isNull);
  });

  test('restore without a token stays signed out quietly', () async {
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await session.restore();
    expect(session.user, isNull);
    expect(backend.log, isNot(contains('GET /auth/me')));
  });

  test('restore migrates a legacy single-token session', () async {
    SharedPreferences.setMockInitialValues({
      SessionState.legacyTokenKey: 'token-1',
    });
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await session.restore();
    expect(session.user?.fullName, 'Doc One');
    final stored = await prefs();
    expect(stored.getString(doctorTokenKey), 'token-1');
    expect(stored.getString(SessionState.legacyTokenKey), isNull);
    expect(stored.getString(SessionState.lastUserKey), 'doc@test');
  });

  test('logout clears only the signed-in account token', () async {
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await session.login('doc@test', 'secret');
    expect((await prefs()).getString(doctorTokenKey), 'token-1');
    session.logout();
    // The removal is fire-and-forget; let it run.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect((await prefs()).getString(doctorTokenKey), isNull);
    expect(session.user, isNull);
  });

  test('logout of one account keeps the other account signed in', () async {
    // The doctor is signed in (as in another tab or an earlier visit).
    SharedPreferences.setMockInitialValues({
      SessionState.lastUserKey: 'doc@test',
      doctorTokenKey: 'token-1',
    });
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await session.restore();
    expect(session.user?.fullName, 'Doc One');

    // An admin signs in on top of the existing session.
    final adminBackend = FakeBackend(role: 'admin');
    final adminSession = SessionState(api: adminBackend.api);
    addTearDown(adminSession.dispose);
    await adminSession.login('admin@test', 'secret');

    final stored = await prefs();
    expect(stored.getString(doctorTokenKey), 'token-1');
    expect(stored.getString(adminTokenKey), 'token-1');
    expect(stored.getString(SessionState.lastUserKey), 'admin@test');

    // Signing the admin back out must not delete the doctor's token.
    adminSession.logout();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final after = await prefs();
    expect(after.getString(adminTokenKey), isNull);
    expect(after.getString(doctorTokenKey), 'token-1');
    // The pointer hands over to the remaining account.
    expect(after.getString(SessionState.lastUserKey), 'doc@test');
  });

  test('restore without a last pointer tries other signed-in accounts',
      () async {
    SharedPreferences.setMockInitialValues({
      doctorTokenKey: 'token-1',
    });
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await session.restore();
    expect(session.user, isNull);
    expect(await prefs().then((p) => p.getString(doctorTokenKey)), 'token-1');
  });
}
