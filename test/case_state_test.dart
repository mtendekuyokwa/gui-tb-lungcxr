import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gui_lungcxr/feature_auth/state/session_state.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';
import 'package:gui_lungcxr/feature_home/models/lesion.dart';
import 'package:gui_lungcxr/feature_home/models/mask_edit.dart';
import 'package:gui_lungcxr/feature_home/state/case_state.dart';
import 'package:gui_lungcxr/feature_home/state/review_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backend.dart';

const _delay = Duration(milliseconds: 5);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 40));

void main() {
  late FakeBackend backend;
  late SessionState session;
  late CaseState cases;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
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

  test('the doctor can upload a case and it is selected', () async {
    final ok = await cases.upload(
      patientName: 'New Upload',
      hospitalNumber: 'H-9',
      bytes: Uint8List.fromList([1, 2, 3]),
      filename: 'cxr.png',
    );
    expect(ok, isTrue);
    expect(cases.error, isNull);
    expect(cases.busy, isFalse);
    expect(backend.log, contains('POST /cases'));
    // The new case is in the list and opened.
    expect(cases.cases.any((c) => c.patientName == 'New Upload'), isTrue);
    expect(cases.selected?.patientName, 'New Upload');
  });

  test('an unreachable backend keeps the upload failed and visible', () async {
    backend.failSaves = true;
    // Uploads fail only on reachability or a backend error; fake that by
    // removing the token so the call comes back 401.
    final token = backend.api.token;
    backend.api.token = null;
    final ok = await cases.upload(
      patientName: 'X',
      hospitalNumber: '',
      bytes: Uint8List.fromList([1]),
      filename: 'cxr.png',
    );
    expect(ok, isFalse);
    expect(cases.error, 'Missing bearer token.');
    backend.api.token = token;
  });

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

  test('each case keeps its own editor and review', () {
    expect(cases.editorFor(1), same(cases.editorFor(1)));
    expect(cases.reviewFor(1), same(cases.reviewFor(1)));
    cases.editorFor(1).setAdjustment(.brightness, 0.4);
    expect(cases.editorFor(2).hasAdjustments, isFalse);
  });

  test('opening a case updates its status in the list', () async {
    final review = await openFirst();
    expect(review.loading, isFalse);
    expect(review.editable, isTrue);
    expect(cases.cases.first.status, CaseStatus.inReview);
    expect(backend.saved, isEmpty, reason: 'loading must not trigger a save');
  });

  test('selecting a mark does not save a draft, labelling does', () async {
    backend.cases[1]!['review'] = {
      'state': 'draft',
      'verdict': null,
      'note': '',
      'marks': [
        {
          'finding': 'cavity',
          'points': [
            [0.1, 0.1],
            [0.2, 0.2],
          ],
        },
      ],
      'disease_tags': [],
      'model_feedback': null,
      'further_testing': null,
      'doctor': {'full_name': 'Doc One'},
    };
    final review = await openFirst();
    await _settle();
    expect(backend.saved, isEmpty);

    review.editor.selectMark(0);
    expect(review.editor.activeMark, 0);
    await _settle();
    await _settle();
    expect(backend.saved, isEmpty, reason: 'selection is not a change');
    expect(review.saveStatus, SaveStatus.idle);

    review.editor.labelActiveMark(LesionType.effusion);
    await _settle();
    expect(backend.saved, hasLength(1));
    expect(review.saveStatus, SaveStatus.saved);
  });

  test('edits and marks are autosaved as one draft', () async {
    final review = await openFirst();
    final editor = cases.editorFor(1);
    editor
      ..startStroke(const Offset(0.25, 0.5))
      ..extendStroke(const Offset(0.5, 0.75))
      ..endStroke()
      ..updateActiveMark(lesion: .cavity, note: 'Cavity, right upper zone');
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
          'note': 'Cavity, right upper zone',
          'points': [
            [0.25, 0.5],
            [0.5, 0.75],
          ],
        },
      ],
      'mask_edits': [],
      'disease_tags': <String>[],
      'model_feedback': {'kind': 'false_negative', 'note': ''},
      'further_testing': {
        'tests': ['genexpert'],
        'urgency': 'urgent',
      },
    });
  });

  test('mask corrections are autosaved and restored with the draft', () async {
    final review = await openFirst();
    final editor = cases.editorFor(1);
    editor
      ..startMaskStroke(const Offset(0.4, 0.4))
      ..extendMaskStroke(const Offset(0.45, 0.5))
      ..endMaskStroke();
    review.setVerdict('no_tb');
    await _settle();

    expect(review.saveStatus, SaveStatus.saved);
    expect(backend.saved.single['mask_edits'], [
      {
        'kind': 'add',
        'tool': 'brush',
        'width': editor.maskWidth,
        'points': [
          [0.4, 0.4],
          [0.45, 0.5],
        ],
      },
    ]);

    final later = CaseState(api: backend.api, saveDelay: _delay);
    addTearDown(later.dispose);
    await later.load();
    final restored = later.reviewFor(1);
    await _settle();
    final edit = later.editorFor(1).maskEdits.single;
    expect(edit.kind, MaskEditKind.add);
    expect(edit.points, const [Offset(0.4, 0.4), Offset(0.45, 0.5)]);
    expect(restored.verdict, 'no_tb');
  });

  test('search filters the client list by name or ID', () {
    expect(cases.visibleCases.map((c) => c.id), [1, 2]);
    cases.setSearchQuery('john');
    expect(cases.visibleCases.map((c) => c.id), [2]);
    expect(cases.selected?.id, 1, reason: 'filtering keeps the open case');
    cases.setSearchQuery('H-1');
    expect(cases.visibleCases.map((c) => c.id), [1]);
    cases.setSearchQuery('zzz');
    expect(cases.visibleCases, isEmpty);
    cases.setSearchQuery('');
    expect(cases.visibleCases.map((c) => c.id), [1, 2]);
  });

  test('a saved draft is restored when the case is opened again', () async {
    final review = await openFirst();
    cases.editorFor(1)
      ..startStroke(const Offset(0.1, 0.2))
      ..endStroke()
      ..updateActiveMark(lesion: .effusion, note: 'Blunting of the angle');
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
    expect(mark.note, 'Blunting of the angle');
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

  test('a queued model reading is rechecked until it lands', () async {
    backend.cases[1] = caseJson(1, predictionState: 'queued');
    final polling = CaseState(
      api: backend.api,
      saveDelay: _delay,
      pollInterval: const Duration(milliseconds: 5),
    );
    addTearDown(polling.dispose);
    await polling.load();
    expect(polling.selected?.prediction?.state, 'queued');
    int loads() => backend.log.where((e) => e == 'GET /cases').length;
    final first = loads();

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(
      loads(),
      greaterThan(first),
      reason: 'the list reloads while the reading is queued',
    );

    // Once the worker answers, polling stops on its own.
    backend.cases[1] = caseJson(1);
    await polling.load();
    final settled = loads();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(loads(), settled, reason: 'no more polls once the reading is done');
    expect(polling.selected?.prediction?.state, 'done');
  });

  test('the upload sends the chosen hospital and selects the case', () async {
    final hospital = await cases.createHospital('Queen Elizabeth');
    expect((await cases.hospitals('queen')).single.id, hospital.id);
    await cases.upload(
      patientName: 'New Upload',
      hospitalNumber: '',
      hospitalId: hospital.id,
      bytes: Uint8List.fromList([1, 2, 3]),
      filename: 'cxr.png',
    );
    expect(backend.lastUploadBody, contains('name="hospital_id"'));
    expect(backend.lastUploadBody, contains('${hospital.id}'));
    expect(cases.selected?.id, 3);
  });

  test(
    'hiding a case drops it from the list and undo brings it back',
    () async {
      expect(cases.selected?.id, 1);
      expect(await cases.hide(1), isTrue);
      expect(backend.log, contains('POST /cases/1/hide'));
      expect(cases.cases.map((c) => c.id), [2]);
      expect(cases.selected?.id, 2, reason: 'the next case opens');
      expect(cases.hiding, isNull);

      await cases.unhide(1);
      expect(cases.cases.map((c) => c.id), containsAll([1, 2]));
      expect(cases.selected?.id, 1);
    },
  );

  test('re-evaluating sends the saved mask corrections to the model', () async {
    final review = await openFirst();
    final editor = cases.editorFor(1);
    expect(review.canReevaluate, isFalse, reason: 'nothing corrected yet');
    editor
      ..startMaskStroke(const Offset(0.3, 0.3))
      ..endMaskStroke();
    expect(review.canReevaluate, isTrue);

    expect(await review.reevaluate(), isTrue);
    expect(backend.saved.last['mask_edits'], hasLength(1));
    expect(backend.log, contains('POST /cases/1/reevaluate'));
    // The corrections are now part of the new mask.
    expect(editor.maskEdits, isEmpty);
    expect(review.reevaluating, isFalse);
    final prediction = cases.selected!.prediction!;
    expect(prediction.state, 'queued');
    expect(prediction.editedMask, isTrue);
    // A new reading means new image URLs, so no stale overlay is shown.
    expect(cases.maskUrl(cases.selected!), endsWith('?v=101'));
    await _settle();
    expect(review.saveStatus, isNot(SaveStatus.unsaved));
  });
}
