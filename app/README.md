# 한지붕 앱 (Flutter)

패키지명·번들 ID: `com.ohsang.util.onehouse`

## 처음 한 번: 플랫폼 폴더 생성

저장소에는 `lib/`, `test/`, `pubspec.yaml`만 들어 있어요. `android/`, `ios/` 폴더는 아래 명령으로 만들어 주세요.
기존 `lib/` 코드는 덮어쓰지 않아요.

```bash
cd app
flutter create --org com.ohsang.util --project-name onehouse --platforms android,ios .
flutter pub get
```

생성된 `test/widget_test.dart`(카운터 예제)는 지워도 돼요.

## 실행

```bash
# 배포한 API에 붙기 (권장)
flutter run --dart-define=API_BASE_URL=https://onehouse-api.<계정>.workers.dev

# 로컬 wrangler dev(8787)에 붙기: Android 에뮬레이터 기본값 http://10.0.2.2:8787
flutter run
```

Android는 기본적으로 http(평문) 통신을 막아요. 로컬 서버로 테스트하려면 `android/app/src/debug/AndroidManifest.xml`의
`<application>`에 `android:usesCleartextTraffic="true"`를 넣어 주세요. 배포한 https 주소를 쓰면 필요 없어요.

## 확인

```bash
flutter analyze
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=https://...
```

## 구조

```
lib/
  main.dart                 앱 시작
  config.dart               API 주소 (--dart-define=API_BASE_URL)
  theme.dart                시안 색상·버튼·입력창 테마
  api/api_client.dart       HTTP + 기기 토큰 + 오류 처리
  services/device_session.dart  설치 키·기기 토큰 (Keychain/Keystore), 재설치 복구, 기기 이전
  models/ledger_summary.dart
  utils/format.dart         원 단위 표시, 한국 시간 기준 월
  screens/
    bootstrap_screen.dart   기기 등록 후 목록으로
    start_view.dart         가계부가 없을 때 시작 화면
    ledger_list_screen.dart 내 가계부 목록 (승인 대기 카드 포함)
    create_ledger_screen.dart
    recovery_code_screen.dart  복구코드 1회 표시, "저장했어요" 전에는 못 나감
    join_screen.dart
    transfer_in_screen.dart    새 폰에서 기기 이전 코드 입력
    ledger_home_screen.dart    월별 내역 (목록)
```

## 다음 단계

- 내역 작성·수정, 달력 보기, 카테고리 필터(전체화면 + 라벨, +N)
- 가계부 관리(방장): 초대코드, 참여 요청 처리, 멤버 상세, 카테고리 관리
- 설정: 기기 이전 코드 발급, 방장 복구
- Android 재설치 복구: 지금은 iOS Keychain만 재설치 후에도 남아요. Android는 Block Store 연동이 필요해요.
