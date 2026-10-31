# 한지붕 시리즈

로그인 없이 초대코드와 방장 승인으로 가족이 함께 쓰는 앱 모음.
초대코드·승인·부방장·차단·복구코드·기기 이전은 모든 앱이 같은 코드와 같은 서버를 쓴다.

| 앱 | 스토어 이름 | 패키지명 / 번들 ID | 폴더 |
| --- | --- | --- | --- |
| 한지붕 가계부 | 한지붕 가계부 - 함께 쓰는 공유 가계부 | `com.ohsang.util.onehouse.budget` | `apps/budget` |
| 한지붕 메모 | 한지붕 메모 - 함께 쓰는 공유 메모장 | `com.ohsang.util.onehouse.memo` | `apps/memo` |

- 앱: Flutter (iOS·Android)
- 서버: Cloudflare Workers + D1 (TypeScript, Hono), 두 앱 공용

## 폴더

```
apps/budget/              한지붕 가계부 (Flutter)        → apps/budget/README.md
apps/memo/                한지붕 메모 (Flutter)          → apps/memo/README.md
packages/onehouse_core/   두 앱이 같이 쓰는 Dart 코드
                          (서버 통신·오프라인 감지, 기기 계정, 테마,
                           시작·만들기·참여·복구코드·기기 이전·설정·멤버 관리 화면)
server/                   API + D1 스키마 (공용)       → server/README.md
scripts/flutter_platforms.sh  플랫폼 폴더 생성 + 번들 ID·앱 이름 설정
e2e/                      CI 스크린샷 (budget.mjs, memo.mjs)
docs/                     설계 요약, API 명세
```

## 빠른 시작

```bash
# 서버
cd server && npm install && npm run db:migrate:local && npm run dev

# 앱 (처음 한 번 플랫폼 폴더 생성)
scripts/flutter_platforms.sh apps/memo memo "한지붕 메모"
cd apps/memo && flutter pub get && flutter run

scripts/flutter_platforms.sh apps/budget budget "한지붕 가계부"
cd apps/budget && flutter pub get && flutter run
```

## CI

모든 브랜치에 푸시하면 `.github/workflows/ci.yml`이 **바뀐 곳만** 확인한다.

| 바뀐 곳 | 확인하는 것 |
| --- | --- |
| `server/` | 타입체크·빌드·병합 단위 테스트·스모크 테스트(가계부 + 메모) |
| `apps/budget/`, `packages/` | 공통 패키지 + 가계부 analyze·test·웹 빌드·스크린샷·디버그 APK |
| `apps/memo/`, `packages/` | 공통 패키지 + 메모 analyze·test·웹 빌드·스크린샷·디버그 APK |
| `e2e/`, `scripts/`, 워크플로 | 전부 |

결과(로그·스크린샷)는 `ci-results` 브랜치, APK는 실행 화면의 Artifacts에 있다.
`main`에 `server/` 변경이 올라오면 `deploy.yml`이 운영 서버에 배포한다(마이그레이션 포함).

- 설계 요약: [docs/design.md](docs/design.md)
- API 명세: [docs/api.md](docs/api.md)
