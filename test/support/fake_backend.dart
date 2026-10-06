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
    'state': 'done',
    'label': 'tb',
    'tb_probability': 0.97,
    'has_overlay': false,
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
    log.add('$method $path');

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
    if (path == '/catalog') return _json(_catalog);
    if (path == '/cases' || path == '/admin/cases') {
      return _json(cases.values.toList());
    }
    if (path == '/admin/users') {
      return _json([
        {
          'id': 2,
          'email': 'doc@test',
          'full_name': 'Doc One',
          'role': 'doctor',
          'active': true,
        },
      ]);
    }
    if (path == '/admin/cases/assign') {
      final body = jsonDecode(request.body);
      for (final id in body['case_ids'] as List) {
        cases[id]!['status'] = 'assigned';
      }
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
