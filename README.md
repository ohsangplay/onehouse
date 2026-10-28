# 한지붕 - 우리가족 공유 가계부

로그인 없이 초대코드와 방장 승인으로 가족이 함께 쓰는 가계부 앱.

| 항목 | 값 |
| --- | --- |
| 스토어 이름 | 한지붕 - 우리가족 공유 가계부 |
| 패키지명 / 번들 ID | `com.ohsang.util.onehouse` |
| 앱 | Flutter (iOS·Android) |
| 서버 | Cloudflare Workers + D1 (TypeScript, Hono) |

## 폴더

```
app/      Flutter 앱          → app/README.md
server/   API + D1 스키마      → server/README.md
docs/     설계 요약, API 명세
```

## 빠른 시작

```bash
# 서버
cd server && npm install && npm run db:migrate:local && npm run dev

# 앱 (처음 한 번 플랫폼 폴더 생성)
cd app
flutter create --org com.ohsang.util --project-name onehouse --platforms android,ios .
flutter pub get
flutter run
```

- 설계 요약: [docs/design.md](docs/design.md)
- API 명세: [docs/api.md](docs/api.md)
