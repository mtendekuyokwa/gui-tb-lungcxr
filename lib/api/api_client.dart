import 'dart:convert';
import 'dart:typed_data';

import 'package:gui_lungcxr/constants/endpoints.dart';
import 'package:gui_lungcxr/constants/strings.dart';
import 'package:http/http.dart' as http;

/// An error response from the backend, or a failure to reach it (status 0).
class ApiException implements Exception {
  const new(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => message;
}

/// JSON client for the Flask backend. Holds the bearer token once signed in.
class ApiClient {
  new({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? Endpoints.baseUrl,
      _http = client ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  String? token;

  /// Called when the backend rejects the token, so the session can sign out.
  void Function()? onUnauthorized;

  /// Headers for requests the app does not send itself, e.g. image loading.
  Map<String, String> get authHeaders => {
    if (token case final token?) 'Authorization': 'Bearer $token',
  };

  String url(String path) => '$baseUrl$path';

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body: body);

  Future<dynamic> put(String path, Object body) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, Object body) =>
      _send('PATCH', path, body: body);

  /// Multipart POST with one file under [fileField].
  Future<dynamic> upload(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required Uint8List bytes,
    required String filename,
  }) {
    final request = http.MultipartRequest('POST', Uri.parse(url(path)))
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes(fileField, bytes, filename: filename),
      );
    return _run(request);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) {
    var uri = Uri.parse(url(path));
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    final request = http.Request(method, uri);
    if (body != null) {
      request
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body);
    }
    return _run(request);
  }

  Future<dynamic> _run(http.BaseRequest request) async {
    final hadToken = token != null;
    request.headers.addAll(authHeaders);
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request));
    } on http.ClientException {
      throw const ApiException(0, Strings.serverUnreachable);
    }

    final isJson =
        response.headers['content-type']?.contains('application/json') ?? false;
    final decoded = isJson && response.bodyBytes.isNotEmpty
        ? jsonDecode(utf8.decode(response.bodyBytes))
        : response.body;
    if (response.statusCode >= 400) {
      if (response.statusCode == 401 && hadToken) onUnauthorized?.call();
      final message = decoded is Map && decoded['error'] is String
          ? decoded['error'] as String
          : Strings.somethingWentWrong;
      throw ApiException(response.statusCode, message);
    }
    return decoded;
  }
}
