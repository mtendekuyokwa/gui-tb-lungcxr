import 'package:flutter_test/flutter_test.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_admin/utils/case_summary.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backend.dart';

void main() {
  late FakeBackend backend;
  late AdminState admin;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backend = FakeBackend(role: 'admin');
    final session = SessionState(api: backend.api);
    addTearDown(session.dispose);
    await session.login('admin@test', 'secret');
    admin = AdminState(api: backend.api);
    await admin.load();
  });
  tearDown(() => admin.dispose());

  test('ticks survive a status filter change', () async {
    admin.toggleTicked(1);
    expect(admin.ticked, {1});

    await admin.setStatusFilter(CaseStatus.submitted);
    expect(admin.cases, isEmpty);
    expect(backend.log, contains('GET /admin/cases?status=submitted'));
    expect(admin.ticked, {
      1,
    }, reason: 'cases under another filter keep their ticks');

    await admin.setStatusFilter(null);
    expect(admin.cases.map((c) => c.id), [1, 2]);
    expect(admin.ticked, {1});
  });

  test('ticks are pruned once a case stops being assignable', () async {
    admin.toggleTicked(1);
    backend.cases[1]!['status'] = 'submitted';
    await admin.load();
    expect(admin.ticked, isEmpty);
  });

  test('assign sends every ticked case and clears the ticks', () async {
    admin.toggleTicked(1);
    admin.toggleTicked(2);
    final doctor = admin.doctors.single;
    expect(await admin.assign(doctor.id), isTrue);
    expect(admin.ticked, isEmpty);
    expect(backend.log, contains('POST /admin/cases/assign'));
    expect(admin.cases.map((c) => c.status), everyElement(CaseStatus.assigned));
  });

  test('assign summary names the current holders', () {
    final shown = admin.cases.where((c) => c.id == 1).toList();
    final summary = assignSummary(shown, 0);
    expect(summary, contains('1 selected'));
    expect(summary, contains('Doc One'));
    expect(assignSummary(shown, 1), contains('under another filter'));
    expect(assignSummary(const [], 2), isNot(contains('now with')));
  });

  test('assign refuses stale ticks instead of sending them', () async {
    admin.toggleTicked(1);
    backend.cases[1]!['status'] = 'submitted';
    final doctor = admin.doctors.single;
    expect(await admin.assign(doctor.id), isFalse);
    expect(admin.error, Strings.assignStale);
    expect(admin.ticked, isEmpty);
    expect(backend.log, isNot(contains('POST /admin/cases/assign')));
  });

  test('assign drops deleted cases from the ticks', () async {
    admin.toggleTicked(2);
    backend.cases.remove(2);
    final doctor = admin.doctors.single;
    expect(await admin.assign(doctor.id), isFalse);
    expect(admin.error, Strings.assignStale);
    expect(admin.ticked, isEmpty);
  });

  test('doctor filter is sent as a query parameter', () async {
    final doctor = admin.doctors.single;
    await admin.setDoctorFilter(doctor.id);
    expect(
      backend.log,
      contains('GET /admin/cases?doctor=${doctor.id}'),
    );
    await admin.setDoctorFilter(null);
    expect(backend.log.last, 'GET /admin/stats');
    expect(backend.log, contains('GET /admin/cases'));
  });

  test('flag filter is sent as a query parameter', () async {
    await admin.setFlagFilter(CaseFlag.modelWrong);
    expect(backend.log, contains('GET /admin/cases?flag=model_wrong'));
    await admin.setFlagFilter(CaseFlag.needsTesting);
    expect(backend.log, contains('GET /admin/cases?flag=needs_testing'));
  });

  test('deactivating a doctor removes them from the assign list', () async {
    final doctor = admin.doctors.single;
    expect(await admin.setUserActive(doctor.id, false), isTrue);
    expect(backend.log, contains('PATCH /admin/users/${doctor.id}'));
    expect(admin.doctors, isEmpty);
    expect(
      admin.allUsers.singleWhere((u) => u.id == doctor.id).active,
      isFalse,
    );
    expect(await admin.setUserActive(doctor.id, true), isTrue);
    expect(admin.doctors.single.id, doctor.id);
  });

  test('assign sends the due date when one is picked', () async {
    admin.toggleTicked(1);
    final doctor = admin.doctors.single;
    final due = DateTime.utc(2026, 11, 1);
    expect(await admin.assign(doctor.id, dueAt: due), isTrue);
    expect(
      backend.lastAssign!['due_at'],
      due.toUtc().toIso8601String(),
    );
  });

  test('stats load with the case list', () async {
    expect(backend.log, contains('GET /admin/stats'));
    expect(admin.stats, isNotNull);
    expect(admin.stats!.open, 2);
  });

  test('export fetches the CSV text', () async {
    final csv = await admin.exportCsv('reviews');
    expect(backend.log, contains('GET /admin/export?kind=reviews'));
    expect(csv, contains('tb_suspected'));
  });

  test('reloads while a reading is queued, then stops', () async {
    backend.cases[1] = caseJson(1, predictionState: 'queued');
    final polling = AdminState(
      api: backend.api,
      pollInterval: const Duration(milliseconds: 5),
    );
    addTearDown(polling.dispose);
    await polling.load();
    expect(polling.waitingOnModel, isTrue);
    int loads() => backend.log.where((e) => e == 'GET /admin/cases').length;
    final first = loads();

    // Deadline loop instead of a fixed sleep: under a loaded test runner
    // the event loop can stall longer than any fixed window.
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (loads() == first && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(
      loads(),
      greaterThan(first),
      reason: 'the list reloads while the reading is queued',
    );

    // Once the worker answers, polling stops on its own. The extra load
    // drains any poll that was already in flight when the reading landed.
    backend.cases[1] = caseJson(1);
    await polling.load();
    expect(polling.waitingOnModel, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await polling.load();
    final settled = loads();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(loads(), settled, reason: 'no more polls once the reading is done');
  });
}
