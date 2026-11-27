import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onehouse_core/onehouse_core.dart';

/// 푸시 알림 (Firebase Cloud Messaging, Android·iOS).
/// Firebase 설정값은 빌드할 때 넣는다 (없으면 알림 기능을 끈 채로 동작):
///   --dart-define=FIREBASE_PROJECT_ID=… FIREBASE_SENDER_ID=…
///   FIREBASE_API_KEY=… FIREBASE_APP_ID=… (빌드하는 플랫폼(Android/iOS)의 값)
/// 서버가 보내는 알림: 메모집 참여 요청(방장·부방장), 참여 승인(요청한 사람)
class Push {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _bundleId = 'com.ohsang.util.onehouse.memo';

  /// 앱 안에 띄우는 알림 (앱을 보고 있을 때)
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static final _events = StreamController<Map<String, dynamic>>.broadcast();

  /// 알림이 오거나 알림을 눌러 들어왔을 때 (data: space_id, type …). 화면을 새로 고치는 데 쓴다
  static Stream<Map<String, dynamic>> get events => _events.stream;

  static bool _ready = false;
  static StreamSubscription<String>? _refreshSub;

  static bool get _configured {
    if (kIsWeb || const bool.fromEnvironment('E2E')) return false;
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    return _apiKey.isNotEmpty && _projectId.isNotEmpty && _senderId.isNotEmpty && _appId.isNotEmpty;
  }

  static Future<void> init() async {
    if (!_configured) return;
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: _apiKey,
          appId: _appId,
          messagingSenderId: _senderId,
          projectId: _projectId,
          iosBundleId: _bundleId,
        ),
      );
      _ready = true;
      // 앱을 보고 있을 때는 시스템 알림 대신 화면 아래에 잠깐 보여 준다
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: false, badge: false, sound: false);
      FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        if (n != null) {
          messengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text([n.title, n.body].whereType<String>().join('\n')),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        _events.add(message.data);
      });
      FirebaseMessaging.onMessageOpenedApp.listen((message) => _events.add(message.data));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _events.add(initial.data);
    } catch (e) {
      debugPrint('알림 초기화 실패: $e');
    }
  }

  /// 알림 권한을 묻고(처음 한 번) 이 기기의 알림 토큰을 서버에 등록한다.
  /// 메모집을 만들거나 참여를 요청한 뒤 목록 화면에서 부른다 (처음 켜자마자 묻지 않게).
  static Future<void> register(ApiClient api) async {
    if (!_ready) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      if (Platform.isIOS) {
        // iOS는 APNs 토큰이 먼저 준비돼야 FCM 토큰이 나온다
        for (var i = 0; i < 10 && await messaging.getAPNSToken() == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      final token = await messaging.getToken();
      if (token != null) await _send(api, token);
      _refreshSub ??= messaging.onTokenRefresh.listen((t) => _send(api, t));
    } catch (e) {
      debugPrint('알림 등록 실패: $e');
    }
  }

  static Future<void> _send(ApiClient api, String token) async {
    try {
      await api.put('/devices/push-token', {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'});
    } catch (e) {
      debugPrint('알림 토큰 저장 실패: $e');
    }
  }
}
