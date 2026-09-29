import 'package:flutter_test/flutter_test.dart';
import 'package:gui_lungcxr/feature_home/state/patient_state.dart';

void main() {
  test('each patient keeps its own editor and chat state', () {
    final state = PatientState();
    addTearDown(state.dispose);
    final [a, b] = state.patients.take(2).map((p) => p.id).toList();

    state.editorFor(a).setAdjustment(.brightness, 0.4);
    state.chatFor(a).send('hello');

    expect(state.editorFor(a), same(state.editorFor(a)));
    expect(state.editorFor(b).hasAdjustments, isFalse);
    expect(state.chatFor(b).messages, isEmpty);
    expect(state.chatFor(a).messages, hasLength(2));
  });

  test('select switches patient and notifies once', () {
    final state = PatientState();
    addTearDown(state.dispose);
    var notified = 0;
    state.addListener(() => notified++);

    final other = state.patients[1].id;
    state
      ..select(other)
      ..select(other);
    expect(state.selected.id, other);
    expect(notified, 1);
  });
}
