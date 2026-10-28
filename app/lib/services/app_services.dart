import '../api/api_client.dart';
import 'device_session.dart';

/// 화면들이 함께 쓰는 서비스 묶음
class AppServices {
  const AppServices({required this.api, required this.session});

  final ApiClient api;
  final DeviceSession session;
}
