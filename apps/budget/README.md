# 한지붕 가계부 (Flutter)

패키지명·번들 ID: `com.ohsang.util.onehouse.budget` · 홈 화면 이름: 한지붕 가계부

## 처음 한 번: 플랫폼 폴더 생성

저장소에는 `lib/`, `test/`, `pubspec.yaml`만 들어 있어요. 저장소 맨 위에서:

```bash
scripts/flutter_platforms.sh apps/budget budget "한지붕 가계부"
cd apps/budget && flutter pub get
```

스크립트가 `flutter create`(org `com.ohsang.util.onehouse`)를 돌리고, 홈 화면 이름과 릴리스용 인터넷 권한을 넣어요.
기존 `lib/` 코드는 덮어쓰지 않아요.

## 실행

```bash
flutter run                                                   # 운영 서버
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8787   # 로컬 wrangler dev (Android 에뮬레이터)
```

로컬 http 서버로 테스트하려면 `android/app/src/debug/AndroidManifest.xml`의 `<application>`에
`android:usesCleartextTraffic="true"`를 넣어 주세요.

## 구조

```
lib/
  main.dart                 앱 시작 (공통 BootstrapScreen → 가계부 목록)
  config.dart               API 주소, 공간 설정(budgetSpace: 문구·/ledgers)
  theme.dart                가계부 대표색
  models/ledger_summary.dart
  utils/format.dart         원 단위 표시, 한국 시간 기준 월
  screens/
    ledger_list_screen.dart 내 가계부 목록 (승인 대기 카드 포함)
    ledger_home_screen.dart 월별 내역 + 설정 버튼
```

시작·만들기·참여·복구코드·기기 이전·설정·멤버 관리 화면은 `packages/onehouse_core`에 있어요.

## 다음 단계

- 내역 작성·수정, 달력 보기, 카테고리 필터(전체화면 + 라벨, +N), 카테고리 관리
- Android 재설치 복구: 지금은 iOS Keychain만 재설치 후에도 남아요. Android는 Block Store 연동이 필요해요.
