// 푸시 알림 진단 (push-diagnose.yml에서 실행). 저장소가 공개라 이름·닉네임·토큰은 출력하지 않는다.
//  1) 가계부 기기의 알림 토큰이 서버에 있는지 (플랫폼별 수, 마지막 등록 시각)
//  2) 최근 24시간 참여 요청과, 그 가계부 방장·부방장의 토큰 수
//  3) 그 방장·부방장 토큰으로 테스트 알림을 보내 FCM 응답을 그대로 보여 준다
import { execFileSync } from 'node:child_process';
import { webcrypto as crypto } from 'node:crypto';

const DB = process.env.DB_NAME;
const SEND = process.env.SEND_TEST === 'true';

function sql(command) {
  const out = execFileSync('npx', ['wrangler', 'd1', 'execute', DB, '--remote', '--json', '--command', command], {
    cwd: 'server',
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'inherit'],
  });
  return JSON.parse(out)[0].results;
}
const note = (title, msg) => console.log(`::notice title=${title}::${String(msg).replace(/\n/g, '%0A')}`);
const warn = (title, msg) => console.log(`::warning title=${title}::${String(msg).replace(/\n/g, '%0A')}`);

// 1) 토큰
const tokens = sql(`
  SELECT p.platform, COUNT(DISTINCT p.token) AS n, MAX(p.updated_at) AS last
  FROM push_tokens p
  WHERE p.device_id IN (SELECT m.device_id FROM ledger_members m JOIN ledgers l ON l.id = m.ledger_id WHERE l.kind = 'budget')
  GROUP BY p.platform`);
note('1. 가계부 알림 토큰', tokens.length ? tokens.map((t) => `${t.platform}: ${t.n}개 (마지막 ${t.last})`).join('\n') : '없음 — 앱이 토큰을 서버에 등록하지 못했어요');
const all = sql('SELECT platform, COUNT(*) AS n FROM push_tokens GROUP BY platform');
note('1-1. 전체 토큰 (메모 포함)', all.map((t) => `${t.platform}: ${t.n}`).join(', ') || '없음');

// 2) 최근 참여 요청
const requests = sql(`
  SELECT m.ledger_id, m.status, m.requested_at,
    (SELECT COUNT(*) FROM push_tokens p JOIN ledger_members o ON o.device_id = p.device_id
      WHERE o.ledger_id = m.ledger_id AND o.status = 'approved' AND o.role IN ('owner','co_owner')) AS manager_tokens
  FROM ledger_members m JOIN ledgers l ON l.id = m.ledger_id
  WHERE l.kind = 'budget' AND m.requested_at > datetime('now', '-1 day') AND m.role = 'member'
  ORDER BY m.requested_at DESC LIMIT 10`);
note('2. 최근 24시간 참여 요청', requests.length
  ? requests.map((r, i) => `#${i + 1} ${r.requested_at} ${r.status} · 방장·부방장 토큰 ${r.manager_tokens}개`).join('\n')
  : '없음');

// 3) 테스트 전송
if (!SEND) process.exit(0);
const raw = process.env.BUDGET_FCM_SERVICE_ACCOUNT;
if (!raw) {
  warn('3. 테스트 전송', 'BUDGET_FCM_SERVICE_ACCOUNT 비밀값이 없어요');
  process.exit(0);
}
const sa = JSON.parse(raw);
note('3-0. 서비스 계정 프로젝트', sa.project_id);

const b64url = (buf) => Buffer.from(buf).toString('base64url');
const now = Math.floor(Date.now() / 1000);
const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
const claims = b64url(JSON.stringify({
  iss: sa.client_email, scope: 'https://www.googleapis.com/auth/firebase.messaging',
  aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600,
}));
const der = Buffer.from(sa.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, ''), 'base64');
const key = await crypto.subtle.importKey('pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${header}.${claims}`));
const tokRes = await fetch('https://oauth2.googleapis.com/token', {
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: `grant_type=${encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}&assertion=${header}.${claims}.${b64url(sig)}`,
});
if (!tokRes.ok) {
  warn('3-1. 구글 인증 실패', `${tokRes.status} ${(await tokRes.text()).slice(0, 300)}`);
  process.exit(0);
}
const access = (await tokRes.json()).access_token;
note('3-1. 구글 인증', '성공');

// 최근 요청이 있는 가계부의 방장·부방장 토큰, 없으면 가계부 토큰 최근 5개
const ledgerIds = [...new Set(requests.map((r) => r.ledger_id))];
const targets = ledgerIds.length
  ? sql(`SELECT DISTINCT p.token, p.platform FROM push_tokens p JOIN ledger_members o ON o.device_id = p.device_id
         WHERE o.ledger_id IN (${ledgerIds.map((id) => `'${id.replace(/'/g, '')}'`).join(',')})
           AND o.status = 'approved' AND o.role IN ('owner','co_owner')`)
  : sql(`SELECT p.token, p.platform FROM push_tokens p
         WHERE p.device_id IN (SELECT m.device_id FROM ledger_members m JOIN ledgers l ON l.id = m.ledger_id WHERE l.kind = 'budget')
         ORDER BY p.updated_at DESC LIMIT 5`);
if (!targets.length) warn('3-2. 테스트 전송', '보낼 토큰이 없어요');
for (const [i, t] of targets.entries()) {
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${access}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      message: {
        token: t.token,
        notification: { title: '한지붕 가계부', body: '알림 테스트예요. 이 알림이 보이면 정상이에요.' },
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default' } } },
      },
    }),
  });
  const body = await res.text();
  const fn = res.ok ? note : warn;
  fn(`3-2. 테스트 #${i + 1} (${t.platform})`, `${res.status} ${res.ok ? '보냄' : body.slice(0, 400)}`);
}
