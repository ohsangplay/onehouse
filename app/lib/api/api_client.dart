import 'dart:convert';

import 'package:http/http.dart' as http;

/// 서버가 돌려주는 오류: {"error": {"code": "...", "message": "..."}}
class ApiException implements Exception {
  ApiException(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;

  /// 다른 기기로 이전됐거나 토큰이 사라진 경우
  bool get isUnauthorized => status == 401;

  /// 승인 전이거나 차단된 가계부
  bool get isForbidden => status == 403;

  @override
  String toString() => 'ApiException($status, $code): $message';
}

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  /// 기기 토큰. DeviceSession이 설정한다.
  String? token;

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) =>
      _send('POST', path, body);

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _send('PATCH', path, body);

  Future<Map<String, dynamic>> delete(String path, [Map<String, dynamic>? body]) =>
      _send('DELETE', path, body);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers['Content-Type'] = 'application/json';
    final currentToken = token;
    if (currentToken != null) {
      request.headers['Authorization'] = 'Bearer $currentToken';
    }
    if (body != null) request.body = jsonEncode(body);

    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    final text = utf8.decode(response.bodyBytes);
    final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
    final json = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    if (response.statusCode >= 400) {
      final error = json['error'];
      if (error is Map<String, dynamic>) {
        throw ApiException(
          response.statusCode,
          error['code'] as String? ?? 'unknown',
          error['message'] as String? ?? '알 수 없는 오류가 발생했어요.',
        );
      }
      throw ApiException(response.statusCode, 'unknown', '알 수 없는 오류가 발생했어요.');
    }
    return json;
  }
}
