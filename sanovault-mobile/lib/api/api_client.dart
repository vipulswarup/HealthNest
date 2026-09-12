import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sanovault/api/api_config.dart';
import 'package:sanovault/api/api_exception.dart';

typedef TokenReader = Future<String?> Function();

class ApiClient {
  ApiClient({required this.readToken, this.baseUrl = apiBaseUrl});

  final String baseUrl;
  final TokenReader readToken;

  Future<dynamic> get(String path, {Map<String, String?>? query, Duration? timeout}) {
    return _send('GET', path, query: query, timeout: timeout);
  }

  Future<dynamic> post(String path, [Object? body, Duration? timeout]) {
    return _send('POST', path, body: body, timeout: timeout);
  }

  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body);

  Future<dynamic> patch(String path, [Object? body]) => _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<List<int>> getBytes(String path, {Map<String, String?>? query}) async {
    final response = await _raw('GET', path, query: query);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw _decodeError(response);
  }

  Future<dynamic> postMultipart({
    required String path,
    required String field,
    required List<int> bytes,
    required String filename,
    String contentType = 'application/octet-stream',
    Map<String, String>? fields,
    Duration? timeout,
  }) async {
    final token = await readToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    request.headers['Accept'] = 'application/json';
    request.headers['User-Agent'] = 'SanoVault-iOS/1.0';
    request.headers['Origin'] = Uri.parse(baseUrl).origin;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (fields != null) request.fields.addAll(fields);
    request.files.add(http.MultipartFile.fromBytes(
      field,
      bytes,
      filename: filename,
    ));
    try {
      final streamed = await request.send().timeout(timeout ?? const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      return _decodeSuccess(response);
    } catch (caught) {
      if (caught is ApiException) rethrow;
      throw const ApiException('Could not reach SanoVault. Check your connection.');
    }
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String?>? query,
    Duration? timeout,
  }) async {
    try {
      final response = await _raw(method, path, body: body, query: query, timeout: timeout);
      return _decodeSuccess(response);
    } catch (caught) {
      if (caught is ApiException) rethrow;
      throw const ApiException('Could not reach SanoVault. Check your connection.');
    }
  }

  Future<http.Response> _raw(
    String method,
    String path, {
    Object? body,
    Map<String, String?>? query,
    Duration? timeout,
  }) async {
    final token = await readToken();
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query == null
          ? null
          : {
              for (final entry in query.entries)
                if (entry.value != null && entry.value!.isNotEmpty) entry.key: entry.value,
            },
    );
    final request = http.Request(method, uri);
    request.headers['Accept'] = 'application/json';
    request.headers['User-Agent'] = 'SanoVault-iOS/1.0';
    request.headers['Origin'] = Uri.parse(baseUrl).origin;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final streamed = await request.send().timeout(timeout ?? const Duration(seconds: 30));
    return http.Response.fromStream(streamed);
  }

  dynamic _decodeSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('json')) return response.bodyBytes;
      return jsonDecode(response.body);
    }
    throw _decodeError(response);
  }

  ApiException _decodeError(http.Response response) {
    var message = 'Something went wrong';
    String? code;
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          message = (decoded['error'] as String?) ?? (decoded['message'] as String?) ?? message;
          code = decoded['code'] as String?;
        }
      } catch (_) {}
    }
    return ApiException(message, statusCode: response.statusCode, code: code);
  }
}
