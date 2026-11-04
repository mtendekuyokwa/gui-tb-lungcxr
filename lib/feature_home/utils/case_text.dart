import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';

// The one-line texts shown for a case.

/// The model's reading, or why there is none yet.
String modelReading(Prediction? prediction) {
  final percent = ((prediction?.tbProbability ?? 0) * 100).round();
  final reading = switch (prediction?.state) {
    'done' when prediction?.label == 'tb' => '${Strings.modelTb} · $percent%',
    'done' => '${Strings.modelNormal} · TB $percent%',
    'failed' => Strings.modelFailed,
    _ => Strings.awaitingModel,
  };
  // Re-evaluated on the doctor's corrected lung mask.
  final edited = prediction?.editedMask ?? false;
  return edited ? '$reading · ${Strings.correctedMask}' : reading;
}

/// Second line of a row in the doctor's case list.
String caseSubtitle(CxrCase item) =>
    [item.displayId, ?item.hospitalName, item.status.label].join(' · ');
