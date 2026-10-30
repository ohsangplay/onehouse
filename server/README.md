# 한지붕 API (Cloudflare Workers + D1)

## 로컬 실행

```bash
cd server
npm install
npm run db:migrate:local   # 로컬 D1에 스키마 적용
npm run dev                # http://127.0.0.1:8787
npm run test:smoke         # 다른 터미널에서: 전체 흐름 50단계 스모크 테스트
```

## 확인

```bash
npm run typecheck   # tsc
npm run build       # wrangler 번들 (dist/, 배포는 하지 않음)
```

## 웹 접근

한지붕은 앱 전용이에요.

- 브라우저로 서버 주소에 들어오면 **앱 설치 안내 페이지**가 나와요 (`src/pages/landing.ts`). API 주소로 들어와도 안내 페이지로 보내요.
- 운영 서버는 CORS 헤더를 내지 않아서, 다른 웹 페이지에서 API를 부를 수 없어요. 네이티브 앱은 영향 없어요.
- 로컬에서 Flutter 웹으로 확인할 때만 `npx wrangler dev --var "ALLOW_WEB_ORIGINS:*"` 로 허용하세요.
- 스토어에 올라가면 `wrangler.toml`의 `APP_STORE_URL`, `PLAY_STORE_URL`을 채우고 배포하면 안내 페이지 버튼이 링크로 바뀌어요.

## 배포

`main`에 `server/` 변경이 올라오면 GitHub Actions(`.github/workflows/deploy.yml`)가 자동으로 배포해요.
처음 한 번 저장소 **Settings → Secrets and variables → Actions**에 아래 두 값을 넣어주세요.

| Secret | 값 |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API 토큰 ("Edit Cloudflare Workers" 템플릿 + Account › D1 › Edit 추가) |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare 대시보드 Workers & Pages 화면 오른쪽의 Account ID |

워크플로가 하는 일: `onehouse` D1을 찾거나 만들고 → 원격 마이그레이션 → `wrangler deploy` → 헬스체크·안내 페이지·CORS 차단 확인.
결과는 `deploy-results` 브랜치의 `summary.md`에 남아요.

직접 배포하려면:

```bash
npx wrangler login
npx wrangler d1 create onehouse          # 나온 database_id를 wrangler.toml에 넣기
npm run db:migrate:remote
npm run deploy                           # https://onehouse-api.<계정>.workers.dev
```

커스텀 도메인을 쓰려면 Cloudflare 대시보드에서 Worker에 `onehouse.ohsangplay.com` 같은 도메인을 연결하세요.

## 구조

```
src/
  index.ts              라우팅, 오류 응답
  types.ts
  lib/crypto.ts         해시, 토큰, 코드 생성(0/O, 1/I/L 제외)
  lib/http.ts           ApiError, 입력 검증
  lib/rateLimit.ts      코드 입력 시도 횟수 제한
  lib/events.ts         관리 이력
  middleware/auth.ts    기기 토큰 인증, 가계부 멤버·역할 검사
  routes/devices.ts     기기 등록·재설치 복구·기기 이전
  routes/ledgers.ts     가계부, 참여 요청, 방장 복구·양도, 나가기
  routes/members.ts     승인·연결·거절·차단·부방장
  routes/categories.ts  공통/지출/수입 카테고리
  routes/transactions.ts 내역 + 월별 합계 + 카테고리 필터
migrations/0001_init.sql
test/smoke.mjs
```

API 목록은 [`../docs/api.md`](../docs/api.md)에 있어요.
