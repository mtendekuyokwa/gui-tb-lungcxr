/// Backend paths, relative to [baseUrl]. See server/app for the routes.
class Endpoints {
  /// Override with `--dart-define=API_BASE_URL=https://host/api/v1`.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:5000/api/v1',
  );

  // Auth
  static const String login = '/auth/login';
  static const String me = '/auth/me';
  static const String catalog = '/catalog';

  // Doctor
  static const String cases = '/cases';
  static const String patients = '/patients';
  static const String hospitals = '/hospitals';
  static String caseDetail(int id) => '/cases/$id';
  static String caseImage(int id) => '/cases/$id/image';
  static String caseOverlay(int id) => '/cases/$id/overlay';
  static String caseMask(int id) => '/cases/$id/mask';
  static String review(int id) => '/cases/$id/review';
  static String submitReview(int id) => '/cases/$id/review/submit';
  static String hideCase(int id) => '/cases/$id/hide';
  static String unhideCase(int id) => '/cases/$id/unhide';
  static String reevaluate(int id) => '/cases/$id/reevaluate';

  // Admin
  static const String adminUsers = '/admin/users';
  static String adminUser(int id) => '/admin/users/$id';
  static const String adminCases = '/admin/cases';
  static const String adminAssign = '/admin/cases/assign';
  static String adminCase(int id) => '/admin/cases/$id';
  static String adminAccept(int id) => '/admin/cases/$id/accept';
  static String adminReturn(int id) => '/admin/cases/$id/return';
  static const String adminExport = '/admin/export';
  static const String adminStats = '/admin/stats';
}
