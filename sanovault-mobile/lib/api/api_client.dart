import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sanovault/api/api_config.dart';
import 'package:sanovault/api/api_exception.dart';

typedef TokenReader = Future<String?> Function();

class ApiClient {
  ApiClient({required this.readToken, this.baseUrl = apiBaseUrl});

  final String baseUrl;
  final TokenReader readToken;

  Future<dynamic> get(String path) => _send('GET', path);

  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);

  Future<dynamic> patch(String path, [Object? body]) => _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, {Object? body}) async {
    final token = await readToken();
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers['Accept'] = 'application/json';
    request.headers['User-Agent'] = 'SanoVault-iOS/1.0';
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    late http.Response response;
    try {
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      response = await http.Response.fromStream(streamed);
    } catch (_) {
      throw const ApiException('Could not reach SanoVault. Check your connection.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    var message = 'Something went wrong';
    String? code;
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          message = (decoded['error'] as String?) ??
              (decoded['message'] as String?) ??
              message;
          code = decoded['code'] as String?;
        }
      } catch (_) {}
    }
    throw ApiException(message, statusCode: response.statusCode, code: code);
  }
}
