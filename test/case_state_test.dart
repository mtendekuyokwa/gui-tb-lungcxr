import 'package:flutter_test/flutter_test.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:gui_lungcxr/feature_home/models/lesion.dart';
import 'package:gui_lungcxr/feature_home/state/case_state.dart';
import 'package:gui_lungcxr/feature_home/state/review_state.dart';

import 'support/fake_backend.dart';

const _delay = Duration(milliseconds: 5);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 40));

void main() {
  late FakeBackend backend;
  late SessionState session;
  late CaseState cases;

  setUp(() async {
    backend = FakeBackend();
    session = SessionState(api: backend.api);
    await session.login('doc@test', 'secret');
    cases = CaseState(api: backend.api, saveDelay: _delay);
    await cases.load();
  });
  tearDown(() {
    cases.dispose();
    session.dispose();
  });

  Future<ReviewState> openFirst() async {
    final review = cases.reviewFor(1);
    await _settle();
    return review;
  }

  test(
    'login stores the token, user and catalog; wrong password does not',
    () async {
      expect(session.user?.isDoctor, isTrue);
      expect(backend.api.token, 'token-1');
      expect(session.catalog.verdicts, hasLength(3));

      final other = SessionState(api: FakeBackend().api);
      addTearDown(other.dispose);
      await other.login('doc@test', 'nope');
      expect(other.user, isNull);
      expect(other.error, 'Wrong email or password.');
      expect(other.api.token, isNull);
    },
  );

  test('a rejected token signs the user out', () async {
    backend.api.token = 'stale';
    await cases.load();
    expect(session.user, isNull);
    expect(cases.error, isNotNull);
  });

  test('loads assigned cases and selects the first', () {
    expect(cases.cases.map((c) => c.id), [1, 2]);
    expect(cases.selected?.id, 1);
    expect(cases.selected?.displayId, 'H-1');
    expect(cases.selected?.prediction?.tbProbability, 0.97);
    expect(cases.imageUrl(1), 'http://test/cases/1/image');
  });

  test('each case keeps its own editor, review and chat', () {
    expect(cases.editorFor(1), same(cases.editorFor(1)));
    expect(cases.reviewFor(1), same(cases.reviewFor(1)));
    cases.editorFor(1).setAdjustment(.brightness, 0.4);
    cases.chatFor(1).send('hello');
    expect(cases.editorFor(2).hasAdjustments, isFalse);
    expect(cases.chatFor(2).messages, isEmpty);
  });

  test('opening a case updates its status in the list', () async {
    final review = await openFirst();
    expect(review.loading, isFalse);
    expect(review.editable, isTrue);
    expect(cases.cases.first.status, CaseStatus.inReview);
    expect(backend.saved, isEmpty, reason: 'loading must not trigger a save');
  });

  test('edits and marks are autosaved as one draft', () async {
    final review = await openFirst();
    final editor = cases.editorFor(1);
    editor
      ..startStroke(const Offset(0.25, 0.5))
      ..extendStroke(const Offset(0.5, 0.75))
      ..endStroke()
      ..labelActiveMark(.cavity);
    review
      ..setVerdict('tb_suspected')
      ..setNote('Cavity, right upper zone')
      ..setFeedbackKind('false_negative')
      ..toggleTest('genexpert')
      ..setUrgency('urgent');
    expect(review.saveStatus, SaveStatus.unsaved);
    await _settle();

    expect(review.saveStatus, SaveStatus.saved);
    expect(backend.saved, hasLength(1), reason: 'changes are debounced');
    expect(backend.saved.single, {
      'verdict': 'tb_suspected',
      'note': 'Cavity, right upper zone',
      'marks': [
        {
          'finding': 'cavity',
          'points': [
            [0.25, 0.5],
            [0.5, 0.75],
          ],
        },
      ],
      'disease_tags': <String>[],
      'model_feedback': {'kind': 'false_negative', 'note': ''},
      'further_testing': {
        'tests': ['genexpert'],
        'urgency': 'urgent',
      },
    });
  });

  test('a saved draft is restored when the case is opened again', () async {
    final review = await openFirst();
    cases.editorFor(1)
      ..startStroke(const Offset(0.1, 0.2))
      ..endStroke()
      ..labelActiveMark(.effusion);
    review
      ..setVerdict('other_disease')
      ..toggleDisease('pneumonia');
    await _settle();

    final later = CaseState(api: backend.api, saveDelay: _delay);
    addTearDown(later.dispose);
    await later.load();
    final restored = later.reviewFor(1);
    await _settle();
    expect(restored.verdict, 'other_disease');
    expect(restored.diseases, {'pneumonia'});
    final mark = later.editorFor(1).marks.single;
    expect(mark.lesion, LesionType.effusion);
    expect(mark.points.single, const Offset(0.1, 0.2));
  });

  test(
    'submit needs a verdict, then locks the review and the editor',
    () async {
      final review = await openFirst();
      expect(review.canSubmit, isFalse);
      expect(await review.submit(), isFalse);

      review.setVerdict('other_disease');
      expect(review.canSubmit, isFalse, reason: 'needs a disease tag');
      review.toggleDisease('pneumonia');
      expect(await review.submit(), isTrue);

      expect(backend.log.last, 'POST /cases/1/review/submit');
      expect(backend.saved.last['disease_tags'], ['pneumonia']);
      expect(review.editable, isFalse);
      expect(cases.cases.first.status, CaseStatus.submitted);

      final editor = cases.editorFor(1);
      expect(editor.locked, isTrue);
      editor.startStroke(Offset.zero);
      expect(editor.hasMarks, isFalse);
      review.setVerdict('no_tb');
      expect(review.verdict, 'other_disease');
      await _settle();
      expect(backend.log.last, 'POST /cases/1/review/submit');
    },
  );

  test('a failed save is reported and blocks submit', () async {
    final review = await openFirst();
    backend.failSaves = true;
    review.setVerdict('no_tb');
    await _settle();
    expect(review.saveStatus, SaveStatus.failed);
    expect(review.error, 'Database is down.');
    expect(await review.submit(), isFalse);
    expect(cases.cases.first.status, CaseStatus.inReview);

    backend.failSaves = false;
    expect(await review.submit(), isTrue);
  });
}
