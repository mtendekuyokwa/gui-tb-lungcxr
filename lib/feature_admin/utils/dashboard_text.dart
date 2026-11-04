import 'package:gui_lungcxr/api/models.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:gui_lungcxr/feature_home/models/cxr_case.dart';

/// The statuses of a case a doctor holds: returned cases go back to them.
const List<CaseStatus> withDoctorStatuses = [
  CaseStatus.inReview,
  CaseStatus.assigned,
  CaseStatus.returned,
];

/// Below this many compared reviews an agreement rate says more about luck
/// than about the model, so the dashboard shows the raw count instead.
const int agreementMinimum = 20;

/// Agreement from which the dashboard calls the model healthy.
const double agreementHealthy = 0.8;

int statusCount(AdminStats stats, CaseStatus status) =>
    stats.byStatus[status.code] ?? 0;

int stageCount(AdminStats stats, List<CaseStatus> statuses) =>
    statuses.fold(0, (sum, s) => sum + statusCount(stats, s));

/// Submitted reviews whose doctor flagged the model as wrong.
int flaggedTotal(AdminStats stats) =>
    stats.feedback.values.fold(0, (sum, n) => sum + n);

/// Whether enough reviews were compared for the rate to mean something.
bool agreementIsMeaningful(AdminStats stats) =>
    stats.rate != null && stats.compared >= agreementMinimum;

bool agreementIsHealthy(AdminStats stats) =>
    (stats.rate ?? 0) >= agreementHealthy;

String agreementPercent(AdminStats stats) =>
    '${((stats.rate ?? 0) * 100).round()}%';

/// "41 of 50 agreed with the model".
String agreementCount(AdminStats stats) =>
    '${stats.agreed} ${Strings.agreeOf} ${stats.compared} ${Strings.agreed}';

String tooFewToJudge() =>
    '${Strings.tooFewToJudge} $agreementMinimum ${Strings.reviews}.';

/// The one sentence at the top: what waits for the admin and where the
/// rest of the work is, e.g. "1 review waits for your sign-off. 2 cases
/// are past due. 13 cases are with doctors."
String dashboardSummary(AdminStats stats) {
  final withDoctors = stageCount(stats, withDoctorStatuses);
  final parts = [
    if (stats.signOff.count > 0)
      _count(
        stats.signOff.count,
        Strings.summarySignOffOne,
        Strings.summarySignOffMany,
      ),
    if (stats.overdue.count > 0)
      _count(
        stats.overdue.count,
        Strings.summaryOverdueOne,
        Strings.summaryOverdueMany,
      ),
    if (stats.unassigned.count > 0)
      _count(
        stats.unassigned.count,
        Strings.summaryUnassignedOne,
        Strings.summaryUnassignedMany,
      ),
  ];
  if (parts.isEmpty) parts.add(Strings.nothingWaits);
  if (withDoctors > 0) {
    parts.add(
      _count(
        withDoctors,
        Strings.summaryWithDoctorsOne,
        Strings.summaryWithDoctorsMany,
      ),
    );
  }
  return parts.join(' ');
}

String _count(int n, String one, String many) => '$n ${n == 1 ? one : many}';

/// How long ago [since] was, in the largest whole unit: "3 days".
String elapsed(DateTime since, DateTime now) {
  final d = now.difference(since);
  if (d.inDays > 0) return _count(d.inDays, Strings.dayOne, Strings.dayMany);
  if (d.inHours > 0) {
    return _count(d.inHours, Strings.hourOne, Strings.hourMany);
  }
  if (d.inMinutes > 0) {
    return _count(d.inMinutes, Strings.minuteOne, Strings.minuteMany);
  }
  return Strings.justNow;
}

/// A queue row's subtitle: who has the case and how long it has waited.
String queueLine(CxrCase c, AdminQueueKind kind, DateTime now) {
  final since = c.waitingSince;
  final time = since == null ? null : elapsed(since, now);
  final when = switch (kind) {
    _ when time == null => null,
    _ when time == Strings.justNow => time,
    AdminQueueKind.signOff => '${Strings.waiting} $time',
    AdminQueueKind.overdue => '$time ${Strings.late}',
    AdminQueueKind.unassigned => '${Strings.uploaded} $time ${Strings.ago}',
  };
  return [?c.doctorName, ?when].join(', ');
}

enum AdminQueueKind { signOff, overdue, unassigned }

/// Doctors with the fewest open cases first: the top of the list is who
/// should get the next case.
List<DoctorWorkload> leastLoadedFirst(List<DoctorWorkload> workload) =>
    [...workload]..sort((a, b) {
      final byOpen = a.open.compareTo(b.open);
      return byOpen != 0 ? byOpen : a.total.compareTo(b.total);
    });

/// A team row's subtitle: "7 open, oldest 4 days".
String doctorLine(DoctorWorkload w, DateTime now) {
  if (w.open == 0) return Strings.noOpenCases;
  final since = w.oldestOpenSince;
  return [
    '${w.open} ${Strings.open}',
    if (since != null) '${Strings.oldest} ${elapsed(since, now)}',
  ].join(', ');
}

/// One doctor's counts in a line, for the assign card.
String workloadLine(DoctorWorkload w) =>
    '${w.open} ${Strings.statsOpen.toLowerCase()}, '
    '${w.submitted} ${Strings.statsSubmitted.toLowerCase()}, '
    '${w.accepted} ${Strings.statsAccepted.toLowerCase()}';
