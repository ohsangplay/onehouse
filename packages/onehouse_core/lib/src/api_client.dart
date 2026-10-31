import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 서버가 돌려주는 오류: {"error": {"code": "...", "message": "..."}, ...추가 값}
class ApiException implements Exception {
  ApiException(this.status, this.code, this.message, [this.body = const {}]);

  final int status;
  final String code;
  final String message;

  /// 오류 응답 전체 (예: 충돌 시 `current`에 지금 저장된 내용)
  final Map<String, dynamic> body;

  /// 다른 기기로 이전됐거나 토큰이 사라진 경우
  bool get isUnauthorized => status == 401;

  /// 승인 전이거나 차단된 공간
  bool get isForbidden => status == 403;

  bool get isConflict => status == 409;

  @override
  String toString() => 'ApiException($status, $code): $message';
}

/// 서버에 닿지 못함 (인터넷 끊김, 시간 초과, 와이파이 로그인 전 등)
class OfflineException implements Exception {
  const OfflineException();

  String get message => '인터넷에 연결되어 있지 않아요.';

  @override
  String toString() => 'OfflineException';
}

/// 온라인·오프라인 상태.
///
/// 와이파이·데이터 연결 여부가 아니라 **실제로 서버에 닿았는지**로 판단한다.
/// 요청이 실패하면 오프라인이 되고, 5초마다 /health 로 확인해서 다시 닿으면 온라인으로 돌아온다.
class NetworkStatus extends ChangeNotifier {
  NetworkStatus(this._ping);

  final Future<bool> Function() _ping;
  bool _online = true;
  Timer? _retry;

  bool get online => _online;

  void markOnline() {
    _retry?.cancel();
    _retry = null;
    if (_online) return;
    _online = true;
    notifyListeners();
  }

  void markOffline() {
    _retry ??= Timer.periodic(const Duration(seconds: 5), (_) => check());
    if (!_online) return;
    _online = false;
    notifyListeners();
  }

  /// 앱이 다시 앞으로 왔을 때 등 바로 확인하고 싶을 때
  Future<bool> check() async {
    final ok = await _ping();
    ok ? markOnline() : markOffline();
    return ok;
  }

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }
}

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient}) : _http = httpClient ?? http.Client() {
    network = NetworkStatus(ping);
  }

  static const _timeout = Duration(seconds: 12);

  final String baseUrl;
  final http.Client _http;
  late final NetworkStatus network;

  /// 기기 토큰. DeviceSession이 설정한다.
  String? token;

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) => _send('POST', path, body);

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) => _send('PATCH', path, body);

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) => _send('PUT', path, body);

  Future<Map<String, dynamic>> delete(String path, [Map<String, dynamic>? body]) => _send('DELETE', path, body);

  /// 서버에 닿는지만 확인
  Future<bool> ping() async {
    try {
      final res = await _http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

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

    final http.Response response;
    final Map<String, dynamic> json;
    try {
      final streamed = await _http.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed).timeout(_timeout);
      final text = utf8.decode(response.bodyBytes);
      final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
      json = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      // 연결 실패, 시간 초과, 서버가 아닌 곳(와이파이 로그인 화면 등)의 응답
      network.markOffline();
      throw const OfflineException();
    }
    network.markOnline();

    if (response.statusCode >= 400) {
      final error = json['error'];
      if (error is Map<String, dynamic>) {
        throw ApiException(
          response.statusCode,
          error['code'] as String? ?? 'unknown',
          error['message'] as String? ?? '알 수 없는 오류가 발생했어요.',
          json,
        );
      }
      throw ApiException(response.statusCode, 'unknown', '알 수 없는 오류가 발생했어요.', json);
    }
    return json;
  }
}

/// 화면에 보여줄 오류 문구
String errorMessage(Object error) {
  if (error is ApiException) return error.message;
  if (error is OfflineException) return error.message;
  return '알 수 없는 오류가 발생했어요.';
}
