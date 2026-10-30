/// 빌드할 때 API 주소를 바꿀 수 있다.
/// 로컬 서버로 테스트: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8787
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // 운영 서버 (Cloudflare Workers)
    defaultValue: 'https://onehouse-api.shark-keeper.workers.dev',
  );
}
