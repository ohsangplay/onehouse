import { Hono } from 'hono';
import type { Context } from 'hono';
import { cors } from 'hono/cors';
import type { AppEnv, Env } from './types';
import { ApiError } from './lib/http';
import { LANDING_HEADERS, renderLanding } from './pages/landing';
import { renderPrivacy } from './pages/privacy';
import { purge } from './lib/purge';
import { devices } from './routes/devices';
import { spaceRoutes } from './routes/spaces';
import { memberRoutes } from './routes/members';
import { memos } from './routes/memos';
import { BUDGET, MEMO } from './kinds';
import { categories } from './routes/categories';
import { transactions } from './routes/transactions';

const app = new Hono<AppEnv>();

/**
 * 한지붕은 앱 전용이다. 운영 서버는 CORS 헤더를 내지 않아서 브라우저(다른 출처의 웹 페이지)에서는 API를 쓸 수 없다.
 * 네이티브 앱은 CORS의 영향을 받지 않는다.
 * 로컬 개발·CI의 웹 미리보기에서만 ALLOW_WEB_ORIGINS 로 허용한다. 예) --var "ALLOW_WEB_ORIGINS:*"
 */
app.use('*', async (c, next) => {
  const allowed = c.env.ALLOW_WEB_ORIGINS;
  if (!allowed) return next();
  const origin = allowed === '*' ? '*' : allowed.split(',').map((s) => s.trim());
  return cors({ origin, allowHeaders: ['Content-Type', 'Authorization'] })(c, next);
});

const wantsHtml = (c: Context<AppEnv>) => (c.req.header('Accept') ?? '').includes('text/html');

/**
 * 운영 주소는 api.ohsangplay.com 아래 경로로 붙는다 (wrangler.toml routes).
 *   https://api.ohsangplay.com/onehouse/budget/...  → 한지붕 가계부 앱
 *   https://api.ohsangplay.com/onehouse/memo/...    → 한지붕 메모 앱
 * 두 앱이 같은 서버라서, fetch에서 이 접두 경로를 떼고 나머지(/ledgers, /notebooks …)로 처리한다.
 * workers.dev 주소와 로컬 개발은 접두 경로 없이 그대로 동작한다.
 * 뗀 경로는 내부 헤더로 넘겨서 안내 페이지 링크·이동 주소를 만들 때 쓴다 (밖에서 보낸 같은 헤더는 지운다).
 */
const BASE_PATH = /^\/onehouse(?:\/(?:budget|memo))?(?=\/|$)/;
const BASE_HEADER = 'x-onehouse-base';
const basePath = (c: Context<AppEnv>) => c.req.header(BASE_HEADER) ?? '';

function stripBasePath(request: Request): Request {
  const url = new URL(request.url);
  const match = url.pathname.match(BASE_PATH);
  if (match) url.pathname = url.pathname.slice(match[0].length) || '/';
  const next = new Request(url.toString(), request);
  next.headers.delete(BASE_HEADER);
  if (match) next.headers.set(BASE_HEADER, match[0]);
  return next;
}

// 브라우저 주소창으로 API 주소에 들어와도 안내 페이지로 보낸다 (앱 요청은 Accept: text/html 을 보내지 않음)
app.use('*', async (c, next) => {
  const path = c.req.path;
  const pages = ['/', '/robots.txt', '/privacy'];
  if (c.req.method === 'GET' && wantsHtml(c) && !c.req.header('Authorization') && !pages.includes(path)) {
    return c.redirect(`${basePath(c)}/`, 302);
  }
  return next();
});

const landing = (c: Context<AppEnv>) => {
  for (const [key, value] of Object.entries(LANDING_HEADERS)) c.header(key, value);
  return c.html(
    renderLanding({
      appStoreUrl: c.env.APP_STORE_URL,
      playStoreUrl: c.env.PLAY_STORE_URL,
      memoAppStoreUrl: c.env.MEMO_APP_STORE_URL,
      memoPlayStoreUrl: c.env.MEMO_PLAY_STORE_URL,
      base: basePath(c),
    }),
  );
};

// 브라우저로 들어오면 앱 설치 안내, 그 외(앱·헬스체크)는 JSON
app.get('/', (c) => (wantsHtml(c) ? landing(c) : c.json({ name: 'onehouse-api', ok: true })));
app.get('/health', (c) => c.json({ ok: true }));
app.get('/robots.txt', (c) => c.text('User-agent: *\nAllow: /$\nAllow: /privacy\nDisallow: /\n'));
// 개인정보처리방침 (한지붕 시리즈 공통, 스토어에 등록하는 주소)
app.get('/privacy', (c) => {
  for (const [key, value] of Object.entries(LANDING_HEADERS)) c.header(key, value);
  return c.html(renderPrivacy(basePath(c)));
});

app.route('/devices', devices);
// 하위 경로를 먼저 등록해야 /ledgers/:ledgerId 와 겹치지 않는다
// 한지붕 가계부
app.route('/ledgers/:ledgerId/members', memberRoutes(BUDGET));
app.route('/ledgers/:ledgerId/categories', categories);
app.route('/ledgers/:ledgerId/transactions', transactions);
app.route('/ledgers', spaceRoutes(BUDGET));
// 한지붕 메모
app.route('/notebooks/:ledgerId/members', memberRoutes(MEMO));
app.route('/notebooks/:ledgerId/memos', memos);
app.route('/notebooks', spaceRoutes(MEMO));

app.notFound((c) => {
  // 브라우저로 없는 주소에 들어오면 안내 페이지로
  if (c.req.method === 'GET' && wantsHtml(c)) return c.redirect(`${basePath(c)}/`, 302);
  return c.json({ error: { code: 'not_found', message: '없는 경로예요.' } }, 404);
});

app.onError((err, c) => {
  if (err instanceof ApiError) {
    return c.json({ error: { code: err.code, message: err.message }, ...err.extra }, err.status);
  }
  console.error(err);
  return c.json({ error: { code: 'internal', message: '서버 오류가 발생했어요.' } }, 500);
});

export default {
  fetch: (request: Request, env: Env, ctx: ExecutionContext) => app.fetch(stripBasePath(request), env, ctx),
  /** 하루 한 번: 지운 지 30일 지난 데이터 완전 삭제 */
  async scheduled(_event: ScheduledController, env: Env, ctx: ExecutionContext) {
    ctx.waitUntil(purge(env.DB).then((r) => console.log('purge', JSON.stringify(r))));
  },
} satisfies ExportedHandler<Env>;
