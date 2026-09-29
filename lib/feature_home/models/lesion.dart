import 'package:gui_lungcxr/constants/strings.dart';

/// Anatomical grouping of chest X-ray findings.
enum LesionCategory {
  parenchymal,
  pleural,
  mediastinal,
  other;

  String get label => switch (this) {
    parenchymal => Strings.lesionParenchymal,
    pleural => Strings.lesionPleural,
    mediastinal => Strings.lesionMediastinal,
    other => Strings.lesionOther,
  };

  List<LesionType> get types => [
    for (final type in LesionType.values)
      if (type.category == this) type,
  ];
}

/// Findings a clinician can attach to a mark, grouped by [LesionCategory].
enum LesionType {
  consolidation(.parenchymal),
  cavity(.parenchymal),
  nodule(.parenchymal),
  miliary(.parenchymal),
  fibrosis(.parenchymal),
  calcification(.parenchymal),
  effusion(.pleural),
  pleuralThickening(.pleural),
  pneumothorax(.pleural),
  hilarLymphadenopathy(.mediastinal),
  mediastinalWidening(.mediastinal),
  other(.other);

  const LesionType(this.category);

  final LesionCategory category;

  String get label => switch (this) {
    consolidation => Strings.lesionConsolidation,
    cavity => Strings.lesionCavity,
    nodule => Strings.lesionNodule,
    miliary => Strings.lesionMiliary,
    fibrosis => Strings.lesionFibrosis,
    calcification => Strings.lesionCalcification,
    effusion => Strings.lesionEffusion,
    pleuralThickening => Strings.lesionPleuralThickening,
    pneumothorax => Strings.lesionPneumothorax,
    hilarLymphadenopathy => Strings.lesionHilarLymphadenopathy,
    mediastinalWidening => Strings.lesionMediastinalWidening,
    other => Strings.lesionOtherFinding,
  };
}
