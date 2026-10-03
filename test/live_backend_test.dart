// Drives the app's real state classes against a running Flask backend.
// Skipped unless the three variables below are set, e.g.
//
//   LUNGCXR_LIVE_URL=http://127.0.0.1:5000/api/v1 \
//   LUNGCXR_LIVE_ADMIN=admin@lungcxr.local:<password> \
//   LUNGCXR_LIVE_DOCTOR=doctor1@lungcxr.local:<password> \
//   flutter test test/live_backend_test.dart
//
// It creates one case on that backend and takes it through the whole
// workflow, so point it at a development database.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gui_lungcxr/api/api_client.dart';
import 'package:gui_lungcxr/feature_admin/state/admin_state.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:gui_lungcxr/feature_home/models/lesion.dart';
import 'package:gui_lungcxr/feature_home/state/case_state.dart';

// A 1x1 grey PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNoAAAAggCBd81ytgAAAABJRU5ErkJggg==',
);

void main() {
  final url = Platform.environment['LUNGCXR_LIVE_URL'];
  final adminLogin = Platform.environment['LUNGCXR_LIVE_ADMIN']?.split(':');
  final doctorLogin = Platform.environment['LUNGCXR_LIVE_DOCTOR']?.split(':');
  final configured = url != null && adminLogin != null && doctorLogin != null;

  test(
    'upload → assign → review → return → resubmit → accept',
    skip: configured ? false : 'LUNGCXR_LIVE_* not set',
    () async {
      Future<SessionState> signIn(List<String> login) async {
        final session = SessionState(api: ApiClient(baseUrl: url));
        addTearDown(session.dispose);
        await session.login(login[0], login[1]);
        expect(session.user, isNotNull, reason: session.error);
        return session;
      }

      // Admin uploads a case and assigns it.
      final adminSession = await signIn(adminLogin!);
      expect(adminSession.user!.isAdmin, isTrue);
      expect(adminSession.catalog.verdicts, isNotEmpty);
      final admin = AdminState(api: adminSession.api);
      addTearDown(admin.dispose);
      await admin.load();
      expect(admin.error, isNull);

      final name = 'Live Test ${DateTime.now().millisecondsSinceEpoch}';
      final uploaded = await admin.upload(
        patientName: name,
        hospitalNumber: '',
        bytes: _png,
        filename: 'cxr.png',
      );
      expect(uploaded, isTrue, reason: admin.error);
      final created = admin.cases.firstWhere((c) => c.patientName == name);
      expect(created.status, CaseStatus.unassigned);
      expect(created.prediction?.state, 'queued');

      final doctorSession = await signIn(doctorLogin!);
      final doctor = admin.doctors.firstWhere(
        (d) => d.id == doctorSession.user!.id,
      );
      admin.toggleTicked(created.id);
      expect(await admin.assign(doctor.id), isTrue, reason: admin.error);
      expect(admin.ticked, isEmpty);
      expect(
        admin.cases.firstWhere((c) => c.id == created.id).status,
        CaseStatus.assigned,
      );

      // Doctor opens it, marks, reviews and submits.
      Future<void> settle() =>
          Future<void>.delayed(const Duration(milliseconds: 400));
      var cases = CaseState(
        api: doctorSession.api,
        saveDelay: const Duration(milliseconds: 20),
      );
      addTearDown(() => cases.dispose());
      await cases.load();
      expect(cases.cases.map((c) => c.id), contains(created.id));
      var review = cases.reviewFor(created.id);
      await settle();
      expect(review.error, isNull);
      expect(review.editable, isTrue);
      expect(review.detail!.status, CaseStatus.inReview);

      final image = await HttpClient()
          .getUrl(Uri.parse(cases.imageUrl(created.id)))
          .then((request) {
            cases.api.authHeaders.forEach(request.headers.set);
            return request.close();
          });
      expect(image.statusCode, 200);
      expect(image.headers.contentType?.mimeType, 'image/png');
      await image.drain<void>();

      cases.editorFor(created.id)
        ..startStroke(const Offset(0.25, 0.5))
        ..extendStroke(const Offset(0.5, 0.75))
        ..endStroke()
        ..labelActiveMark(.cavity);
      review
        ..setVerdict('tb_suspected')
        ..setNote('Cavity, right upper zone')
        ..setFeedbackKind('wrong_region')
        ..setFeedbackNote('Heatmap on the heart')
        ..toggleTest('genexpert')
        ..setUrgency('urgent');
      await settle();
      expect(review.error, isNull);
      expect(await review.submit(), isTrue, reason: review.error);
      expect(review.editable, isFalse);
      expect(cases.editorFor(created.id).locked, isTrue);

      // Admin sees the review and its flags, and returns it.
      await admin.load();
      final row = admin.cases.firstWhere((c) => c.id == created.id);
      expect(row.status, CaseStatus.submitted);
      expect(row.verdict, 'tb_suspected');
      expect(row.modelWrong, isTrue);
      expect(row.needsTesting, isTrue);
      await admin.openCase(created.id);
      final seen = admin.open!.review!;
      expect(seen.note, 'Cavity, right upper zone');
      expect(seen.marks.single.lesion, LesionType.cavity);
      expect(seen.marks.single.points, const [
        Offset(0.25, 0.5),
        Offset(0.5, 0.75),
      ]);
      expect(seen.feedbackKind, 'wrong_region');
      expect(seen.tests, ['genexpert']);
      expect(seen.urgency, 'urgent');
      expect(
        await admin.returnToDoctor(created.id, 'Please mark the left lung too'),
        isTrue,
        reason: admin.error,
      );

      // Doctor gets it back with the note and the earlier work, and resubmits.
      cases.dispose();
      cases = CaseState(
        api: doctorSession.api,
        saveDelay: const Duration(milliseconds: 20),
      );
      await cases.load();
      review = cases.reviewFor(created.id);
      await settle();
      expect(review.detail!.status, CaseStatus.returned);
      expect(review.detail!.returnNote, 'Please mark the left lung too');
      expect(review.editable, isTrue);
      expect(review.verdict, 'tb_suspected');
      expect(review.feedbackKind, 'wrong_region');
      expect(cases.editorFor(created.id).marks, hasLength(1));
      cases.editorFor(created.id)
        ..startStroke(const Offset(0.7, 0.4))
        ..endStroke()
        ..labelActiveMark(.effusion);
      await settle();
      expect(await review.submit(), isTrue, reason: review.error);

      // Admin accepts; the case is closed for everyone.
      expect(await admin.accept(created.id), isTrue, reason: admin.error);
      expect(admin.open!.status, CaseStatus.accepted);
      expect(admin.open!.review!.marks, hasLength(2));
      admin.toggleTicked(created.id);
      expect(await admin.assign(doctor.id), isFalse);
      expect(admin.error, contains('cannot be reassigned'));

      // A wrong password is refused with the server's message.
      final bad = SessionState(api: ApiClient(baseUrl: url));
      addTearDown(bad.dispose);
      await bad.login(doctorLogin[0], 'definitely-wrong');
      expect(bad.user, isNull);
      expect(bad.error, 'Wrong email or password.');
    },
  );
}
