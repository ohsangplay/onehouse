/// 빌드할 때 API 주소를 바꿀 수 있다.
/// flutter run --dart-define=API_BASE_URL=https://onehouse-api.<계정>.workers.dev
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // Android 에뮬레이터에서 PC의 wrangler dev(8787)에 붙는 주소
    defaultValue: 'http://10.0.2.2:8787',
  );
}
