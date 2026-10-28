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

## 배포 (처음 한 번)

```bash
npx wrangler login
npx wrangler d1 create onehouse          # 나온 database_id를 wrangler.toml에 넣기
npm run db:migrate:remote
npm run deploy                           # https://onehouse-api.<계정>.workers.dev
```

커스텀 도메인을 쓰려면 Cloudflare 대시보드에서 Worker에 `api.onehouse.ohsangplay.com` 같은 도메인을 연결하세요.

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
