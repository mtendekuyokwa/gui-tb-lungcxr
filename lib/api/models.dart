import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';

/// Signed-in user, or a doctor in the admin's list.
class AppUser {
  const new({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.active,
  });

  final int id;
  final String email;
  final String fullName;
  final String role;
  final bool active;

  bool get isAdmin => role == 'admin';
  bool get isDoctor => role == 'doctor';

  static AppUser fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as int,
    email: json['email'] as String,
    fullName: json['full_name'] as String,
    role: json['role'] as String,
    active: json['active'] as bool,
  );
}

/// A code the backend stores and the label shown for it.
class Option {
  const new(this.code, this.label);

  final String code;
  final String label;

  static List<Option> listFromJson(Object? json) => [
    for (final item in json as List? ?? const [])
      Option(item['code'] as String, item['label'] as String),
  ];
}

/// Choice lists served by the backend, so they can change without an app
/// release. Lesion findings are not here: they are the `LesionType` enum.
class Catalog {
  const new({
    this.verdicts = const [],
    this.diseases = const [],
    this.tests = const [],
    this.urgencies = const [],
    this.feedbackKinds = const [],
  });

  final List<Option> verdicts;
  final List<Option> diseases;
  final List<Option> tests;
  final List<Option> urgencies;
  final List<Option> feedbackKinds;

  String label(List<Option> options, String? code) {
    for (final option in options) {
      if (option.code == code) return option.label;
    }
    return code ?? Strings.none;
  }

  static Catalog fromJson(Map<String, dynamic> json) => Catalog(
    verdicts: Option.listFromJson(json['verdicts']),
    diseases: Option.listFromJson(json['diseases']),
    tests: Option.listFromJson(json['tests']),
    urgencies: Option.listFromJson(json['urgencies']),
    feedbackKinds: Option.listFromJson(json['feedback_kinds']),
  );
}

/// A reusable patient record from `GET /patients`.
class AppPatient {
  const AppPatient({
    required this.id,
    required this.name,
    this.hospitalNumber,
    this.sex,
    this.birthYear,
  });

  final int id;
  final String name;
  final String? hospitalNumber;
  final String? sex;
  final int? birthYear;

  /// One-line detail for a suggestion row: "HU-42 · Male · born 1987".
  String get detail => [
    if (hospitalNumber case final number?) number,
    if (sex case final value? when value.isNotEmpty)
      '${value[0].toUpperCase()}${value.substring(1)}',
    if (birthYear case final year?) 'born $year',
  ].join(' · ');

  static AppPatient fromJson(Map<String, dynamic> json) => AppPatient(
    id: json['id'] as int,
    name: json['name'] as String,
    hospitalNumber: json['hospital_number'] as String?,
    sex: json['sex'] as String?,
    birthYear: (json['birth_year'] as num?)?.toInt(),
  );
}

/// Where an X-ray was taken, from `GET /hospitals`.
class AppHospital {
  const AppHospital({required this.id, required this.name});

  final int id;
  final String name;

  static AppHospital fromJson(Map<String, dynamic> json) =>
      AppHospital(id: json['id'] as int, name: json['name'] as String);
}

/// One doctor's cases from `GET /admin/stats`, for the dashboard: what they
/// are still working on ([open], which includes returned cases), what
/// waits for sign-off and what is done.
class DoctorWorkload {
  const DoctorWorkload({
    required this.doctorId,
    required this.fullName,
    required this.open,
    required this.submitted,
    required this.accepted,
    this.oldestOpenSince,
  });

  final int doctorId;
  final String fullName;
  final int open;
  final int submitted;
  final int accepted;

  /// When the doctor's longest-waiting open case was assigned; null when
  /// they have none.
  final DateTime? oldestOpenSince;

  int get total => open + submitted + accepted;

  static DoctorWorkload fromJson(Map<String, dynamic> json) {
    final doctor = json['doctor'] as Map<String, dynamic>;
    return DoctorWorkload(
      doctorId: (doctor['id'] as num).toInt(),
      fullName: doctor['full_name'] as String,
      open: ((json['open'] as num?) ?? 0).toInt(),
      submitted: ((json['submitted'] as num?) ?? 0).toInt(),
      accepted: ((json['accepted'] as num?) ?? 0).toInt(),
      oldestOpenSince: switch (json['oldest_open_since']) {
        final String at => DateTime.parse(at),
        _ => null,
      },
    );
  }
}

/// One dashboard queue from `GET /admin/stats`: how many cases wait there
/// and the longest-waiting few.
class AdminQueue {
  const AdminQueue({this.count = 0, this.cases = const []});

  final int count;
  final List<CxrCase> cases;

  static AdminQueue fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return const AdminQueue();
    return AdminQueue(
      count: ((json['count'] as num?) ?? 0).toInt(),
      cases: [
        for (final row in json['cases'] as List? ?? const [])
          CxrCase.fromJson(row as Map<String, dynamic>),
      ],
    );
  }
}

/// Counts the admin's dashboard shows, from `GET /admin/stats`.
class AdminStats {
  const AdminStats({
    this.byStatus = const {},
    this.workload = const [],
    this.compared = 0,
    this.agreed = 0,
    this.rate,
    this.verdicts = const {},
    this.feedback = const {},
    this.signOff = const AdminQueue(),
    this.overdue = const AdminQueue(),
    this.unassigned = const AdminQueue(),
  });

  /// Cases per [CaseStatus] code.
  final Map<String, int> byStatus;

  /// Per-doctor rows behind the totals.
  final List<DoctorWorkload> workload;

  /// Submitted reviews where both the model and the doctor gave a TB /
  /// not-TB answer, and how many of those agreed.
  final int compared;
  final int agreed;
  final double? rate;

  /// Submitted reviews per verdict code.
  final Map<String, int> verdicts;

  /// Submitted model-wrong flags per feedback kind code.
  final Map<String, int> feedback;

  /// What waits for the admin, oldest first.
  final AdminQueue signOff;
  final AdminQueue overdue;
  final AdminQueue unassigned;

  static AdminStats fromJson(Map<String, dynamic> json) {
    final agreement = json['model_agreement'] as Map<String, dynamic>? ?? {};
    final queues = json['queues'] as Map<String, dynamic>? ?? const {};
    return AdminStats(
      byStatus: _counts(json['by_status']),
      workload: [
        for (final row in json['doctors'] as List? ?? const [])
          DoctorWorkload.fromJson(row as Map<String, dynamic>),
      ],
      compared: ((agreement['compared'] as num?) ?? 0).toInt(),
      agreed: ((agreement['agreed'] as num?) ?? 0).toInt(),
      rate: (agreement['rate'] as num?)?.toDouble(),
      // Absent on an older backend; the dashboard then shows zeros.
      verdicts: _counts(json['verdicts']),
      feedback: _counts(json['model_feedback']),
      signOff: AdminQueue.fromJson(queues['sign_off']),
      overdue: AdminQueue.fromJson(queues['overdue']),
      unassigned: AdminQueue.fromJson(queues['unassigned']),
    );
  }

  static Map<String, int> _counts(Object? json) => {
    for (final entry in (json as Map<String, dynamic>? ?? const {}).entries)
      entry.key: (entry.value as num).toInt(),
  };
}
