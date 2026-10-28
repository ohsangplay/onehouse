import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';

/// 로그인 대신 쓰는 기기 계정.
///
/// - 설치 키: 최초 실행 때 만든 랜덤 값. iOS Keychain에 남아서 재설치 후에도 기존 계정에 다시 붙는다.
/// - 기기 토큰: 서버가 발급. 모든 API 호출에 Bearer로 붙는다.
class DeviceSession {
  DeviceSession(this._api, {FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _installKeyKey = 'install_key';
  static const _tokenKey = 'device_token';

  final ApiClient _api;
  final FlutterSecureStorage _storage;

  /// 토큰을 준비한다. 없으면 설치 키로 복구하거나 새로 등록한다.
  Future<void> ensure() async {
    final token = await _storage.read(key: _tokenKey);
    if (token != null) {
      _api.token = token;
      return;
    }

    final installKey = await _storage.read(key: _installKeyKey);
    if (installKey != null) {
      try {
        await _restore(installKey);
        return;
      } on ApiException catch (e) {
        if (e.status != 404) rethrow;
      }
    }
    await _register(installKey ?? _newInstallKey());
  }

  /// 서버가 401을 주면(다른 기기로 이전됨) 토큰을 지우고 다시 준비한다.
  Future<void> reset() async {
    await _storage.delete(key: _tokenKey);
    _api.token = null;
    await ensure();
  }

  /// 새 폰에서 기기 이전 코드를 입력했을 때
  Future<void> transferFrom(String code) async {
    final installKey = await _storage.read(key: _installKeyKey) ?? _newInstallKey();
    await _storage.write(key: _installKeyKey, value: installKey);
    final res = await _api.post('/devices/transfer', {
      'code': code,
      'install_key': installKey,
    });
    await _saveToken(res['token'] as String);
  }

  /// 이전 폰에서 기기 이전 코드 발급
  Future<({String code, DateTime expiresAt})> createTransferCode() async {
    final res = await _api.post('/devices/transfer-codes');
    return (
      code: res['code'] as String,
      expiresAt: DateTime.parse(res['expires_at'] as String),
    );
  }

  Future<void> _register(String installKey) async {
    await _storage.write(key: _installKeyKey, value: installKey);
    try {
      final res = await _api.post('/devices', {'install_key': installKey});
      await _saveToken(res['token'] as String);
    } on ApiException catch (e) {
      if (e.status != 409) rethrow;
      await _restore(installKey);
    }
  }

  Future<void> _restore(String installKey) async {
    final res = await _api.post('/devices/restore', {'install_key': installKey});
    await _saveToken(res['token'] as String);
  }

  Future<void> _saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    _api.token = token;
  }

  static String _newInstallKey() {
    final random = Random.secure();
    return List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
