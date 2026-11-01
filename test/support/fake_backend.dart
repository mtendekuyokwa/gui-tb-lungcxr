import 'dart:convert';

import 'package:gui_lungcxr/api/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _catalog = {
  'verdicts': [
    {'code': 'tb_suspected', 'label': 'TB suspected'},
    {'code': 'no_tb', 'label': 'No TB'},
    {'code': 'other_disease', 'label': 'Other disease suspected'},
  ],
  'diseases': [
    {'code': 'pneumonia', 'label': 'Pneumonia'},
  ],
  'tests': [
    {'code': 'genexpert', 'label': 'Sputum GeneXpert'},
  ],
  'urgencies': [
    {'code': 'routine', 'label': 'Routine'},
    {'code': 'urgent', 'label': 'Urgent'},
  ],
  'feedback_kinds': [
    {'code': 'false_negative', 'label': 'Model said Normal'},
  ],
};

Map<String, dynamic> caseJson(
  int id, {
  String status = 'assigned',
  Map<String, dynamic>? review,
  String name = 'Jane Banda',
  String predictionState = 'done',
}) => {
  'id': id,
  'status': status,
  'patient': {'id': id, 'name': name, 'hospital_number': 'H-$id'},
  'assigned_to': {
    'id': 2,
    'email': 'doc@test',
    'full_name': 'Doc One',
    'role': 'doctor',
    'active': true,
  },
  'prediction': {
    'id': id,
    'state': predictionState,
    'label': 'tb',
    'tb_probability': 0.97,
    'has_overlay': false,
    'has_mask': true,
  },
  'review': review,
  'return_note': null,
  'verdict': review?['verdict'],
  'model_wrong': false,
  'needs_testing': false,
};

/// In-memory stand-in for the Flask backend, just enough for the app's calls.
class FakeBackend {
  FakeBackend({this.role = 'doctor'});

  final String role;
  final Map<int, Map<String, dynamic>> cases = {
    1: caseJson(1),
    2: caseJson(2, name: 'John Phiri'),
  };

  /// Every request as "METHOD /path".
  final List<String> log = [];

  /// Bodies of review saves, in order.
  final List<Map<String, dynamic>> saved = [];
  bool failSaves = false;

  /// In-memory users table, so user CRUD can be tested.
  final Map<int, Map<String, dynamic>> users = {
    2: {
      'id': 2,
      'email': 'doc@test',
      'full_name': 'Doc One',
      'role': 'doctor',
      'active': true,
    },
  };

  /// Body of the last assign call, so tests can assert the due date.
  Map<String, dynamic>? lastAssign;

  late final ApiClient api = ApiClient(
    baseUrl: 'http://test',
    client: MockClient(_handle),
  );

  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    final method = request.method;
    // Keep the query so tests can assert which filter was requested.
    log.add(
      request.url.query.isEmpty
          ? '$method $path'
          : '$method $path?${request.url.query}',
    );

    if (path == '/auth/login') {
      final body = jsonDecode(request.body);
      if (body['password'] != 'secret') {
        return _json({'error': 'Wrong email or password.'}, 401);
      }
      return _json({
        'token': 'token-1',
        'user': {
          'id': role == 'admin' ? 1 : 2,
          'email': body['email'],
          'full_name': role == 'admin' ? 'Admin' : 'Doc One',
          'role': role,
          'active': true,
        },
      });
    }
    if (request.headers['Authorization'] != 'Bearer token-1') {
      return _json({'error': 'Missing bearer token.'}, 401);
    }
    if (path == '/cases' && method == 'POST') {
      cases[3] = caseJson(3, name: 'New Upload');
      return _json(cases[3]!, 201);
    }
    if (path == '/auth/me') {
      return _json({
        'id': role == 'admin' ? 1 : 2,
        'email': role == 'admin' ? 'admin@test' : 'doc@test',
        'full_name': role == 'admin' ? 'Admin' : 'Doc One',
        'role': role,
        'active': true,
      });
    }
    if (path == '/catalog') return _json(_catalog);
    if (path == '/patients') {
      final query = request.url.queryParameters['q'] ?? '';
      return _json([
        if ('jane banda'.contains(query.toLowerCase()))
          {
            'id': 7,
            'name': 'Jane Banda',
            'hospital_number': 'HU-42',
            'sex': 'female',
            'birth_year': 1987,
          },
      ]);
    }
    if (path == '/cases') return _json(cases.values.toList());
    if (path == '/admin/stats') {
      return _json({
        'by_status': {'assigned': cases.length},
        'doctors': [
          {
            'doctor': {
              'id': 2,
              'email': 'doc@test',
              'full_name': 'Doc One',
              'role': 'doctor',
              'active': true,
            },
            'open': cases.length,
            'submitted': 0,
            'accepted': 0,
          },
        ],
        'model_agreement': {'compared': 0, 'agreed': 0, 'rate': null},
      });
    }
    if (path == '/admin/export') {
      final kind = request.url.queryParameters['kind'] ?? 'reviews';
      return http.Response(
        kind == 'model_feedback'
            ? 'case_id,doctor_id,feedback_kind\n1,2,false_negative\n'
            : 'case_id,doctor_id,verdict\n1,2,tb_suspected\n',
        200,
        headers: {'content-type': 'text/csv'},
      );
    }
    if (path == '/admin/cases') {
      final status = request.url.queryParameters['status'];
      final doctor = request.url.queryParameters['doctor'];
      final flag = request.url.queryParameters['flag'];
      return _json([
        for (final c in cases.values)
          if ((status == null || c['status'] == status) &&
              (doctor == null ||
                  (c['assigned_to'] as Map)['id'].toString() == doctor) &&
              (flag == null ||
                  (flag == 'model_wrong' && c['model_wrong'] == true) ||
                  (flag == 'needs_testing' && c['needs_testing'] == true)))
            c,
      ]);
    }
    if (path == '/admin/users' && method == 'POST') {
      final body = jsonDecode(request.body);
      users[3] = {
        'id': 3,
        'email': body['email'],
        'full_name': body['full_name'],
        'role': body['role'],
        'active': true,
      };
      return _json(users[3]!, 201);
    }
    if (path == '/admin/users') {
      return _json(users.values.toList());
    }
    final userMatch = RegExp(r'^/admin/users/(\d+)$').firstMatch(path);
    if (userMatch != null) {
      if (method != 'PATCH') return _json({'error': 'Not found.'}, 404);
      final user = users[int.parse(userMatch.group(1)!)];
      if (user == null) return _json({'error': 'User not found.'}, 404);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (body.containsKey('active')) user['active'] = body['active'];
      if (body.containsKey('full_name')) {
        user['full_name'] = body['full_name'];
      }
      return _json(user);
    }
    if (path == '/admin/cases/assign') {
      final body = jsonDecode(request.body);
      for (final id in body['case_ids'] as List) {
        cases[id]!['status'] = 'assigned';
      }
      lastAssign = body as Map<String, dynamic>;
      return _json([]);
    }

    final match = RegExp(r'^(?:/admin)?/cases/(\d+)(/[a-z/]+)?$')
        .firstMatch(path);
    if (match == null) return _json({'error': 'Not found.'}, 404);
    final item = cases[int.parse(match.group(1)!)];
    if (item == null) return _json({'error': 'Case not found.'}, 404);
    switch ((method, match.group(2))) {
      case ('GET', null):
        if (item['status'] == 'assigned' && !path.startsWith('/admin')) {
          item['status'] = 'in_review';
        }
      case ('PUT', '/review'):
        if (failSaves) return _json({'error': 'Database is down.'}, 500);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        saved.add(body);
        item['status'] = 'in_review';
        item['review'] = {
          'state': 'draft',
          'verdict': body['verdict'],
          'note': body['note'],
          'marks': body['marks'],
          'mask_edits': body['mask_edits'] ?? [],
          'disease_tags': [
            for (final code in body['disease_tags'] as List) {'code': code},
          ],
          'model_feedback': body['model_feedback'],
          'further_testing': body['further_testing'],
          'doctor': {'full_name': 'Doc One'},
        };
      case ('POST', '/review/submit'):
        item['status'] = 'submitted';
        (item['review'] as Map)['state'] = 'submitted';
      case ('POST', '/accept'):
        item['status'] = 'accepted';
      case ('POST', '/return'):
        item['status'] = 'returned';
      default:
        return _json({'error': 'Not found.'}, 404);
    }
    return _json(item);
  }
}
