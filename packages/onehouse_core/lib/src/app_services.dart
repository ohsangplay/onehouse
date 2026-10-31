import 'api_client.dart';
import 'device_session.dart';
import 'space_config.dart';

/// 화면들이 함께 쓰는 서비스 묶음
class AppServices {
  const AppServices({required this.api, required this.session, required this.space});

  final ApiClient api;
  final DeviceSession session;

  /// 이 앱이 다루는 공간 종류 (가계부 / 메모집)
  final SpaceConfig space;
}
