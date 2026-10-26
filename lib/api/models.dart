import 'package:gui_lungcxr/constants/strings.dart';

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

/// Counts the admin's statistics screen shows, from `GET /admin/stats`.
class AdminStats {
  const new({
    this.byStatus = const {},
    this.open = 0,
    this.submitted = 0,
    this.accepted = 0,
    this.compared = 0,
    this.agreed = 0,
    this.rate,
  });

  final Map<String, int> byStatus;
  final int open;
  final int submitted;
  final int accepted;
  final int compared;
  final int agreed;
  final double? rate;

  static AdminStats fromJson(Map<String, dynamic> json) {
    final byStatus = <String, int>{};
    for (final entry in (json['by_status'] as Map<String, dynamic>).entries) {
      byStatus[entry.key] = (entry.value as num).toInt();
    }
    var open = 0;
    var submitted = 0;
    var accepted = 0;
    // Per-doctor workload rows are not shown yet; only the totals matter.
    for (final row in json['doctors'] as List? ?? const []) {
      final map = row as Map<String, dynamic>;
      open += ((map['open'] as num?) ?? 0).toInt();
      submitted += ((map['submitted'] as num?) ?? 0).toInt();
      accepted += ((map['accepted'] as num?) ?? 0).toInt();
    }
    final agreement = json['model_agreement'] as Map<String, dynamic>;
    return AdminStats(
      byStatus: byStatus,
      open: open,
      submitted: submitted,
      accepted: accepted,
      compared: ((agreement['compared'] as num?) ?? 0).toInt(),
      agreed: ((agreement['agreed'] as num?) ?? 0).toInt(),
      rate: (agreement['rate'] as num?)?.toDouble(),
    );
  }
}
