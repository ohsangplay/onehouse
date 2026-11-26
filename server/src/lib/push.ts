// 푸시 알림: Firebase Cloud Messaging(HTTP v1). Android·iOS 모두 FCM 토큰으로 보낸다 (iOS는 Firebase가 APNs로 전달).
// 앱마다 Firebase 프로젝트가 따로라서 서비스 계정도 따로 둔다 (서버 비밀값, 서비스 계정 JSON):
//   한지붕 가계부 BUDGET_FCM_SERVICE_ACCOUNT, 한지붕 메모 MEMO_FCM_SERVICE_ACCOUNT. 없으면 그 앱은 알림을 보내지 않는다.
import type { Env, SpaceKind } from '../types';

/** 공간 종류 → 그 앱의 Firebase 서비스 계정 JSON */
function accountJson(env: Env, kind: SpaceKind): string | undefined {
  return kind === 'memo' ? env.MEMO_FCM_SERVICE_ACCOUNT : env.BUDGET_FCM_SERVICE_ACCOUNT;
}

function anyAccount(env: Env): boolean {
  return Boolean(env.BUDGET_FCM_SERVICE_ACCOUNT || env.MEMO_FCM_SERVICE_ACCOUNT);
}

type ServiceAccount = { project_id: string; client_email: string; private_key: string };

export type PushMessage = {
  title: string;
  body: string;
  /** 앱에서 화면 이동 등에 쓰는 값 (문자열만) */
  data?: Record<string, string>;
};

const cached = new Map<string, { token: string; expires: number }>();

function b64url(data: ArrayBuffer | Uint8Array | string): string {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : new Uint8Array(data);
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function parseAccount(env: Env, kind: SpaceKind): ServiceAccount | null {
  const raw = accountJson(env, kind);
  if (!raw) return null;
  try {
    const sa = JSON.parse(raw) as ServiceAccount;
    return sa.project_id && sa.client_email && sa.private_key ? sa : null;
  } catch {
    console.error(`${kind} FCM 서비스 계정 JSON을 읽을 수 없어요`);
    return null;
  }
}

/** 서비스 계정으로 OAuth 액세스 토큰 (1시간, 캐시) */
async function accessToken(sa: ServiceAccount): Promise<string> {
  const nowSec = Math.floor(Date.now() / 1000);
  const hit = cached.get(sa.client_email);
  if (hit && hit.expires > nowSec + 60) return hit.token;

  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: nowSec,
      exp: nowSec + 3600,
    }),
  );
  const pem = sa.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const der = Uint8Array.from(atob(pem), (ch) => ch.charCodeAt(0));
  const key = await crypto.subtle.importKey('pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${header}.${claims}`));
  const jwt = `${header}.${claims}.${b64url(sig)}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=${encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}&assertion=${jwt}`,
  });
  if (!res.ok) throw new Error(`FCM 토큰 발급 실패 ${res.status} ${await res.text()}`);
  const json = (await res.json()) as { access_token: string; expires_in: number };
  cached.set(sa.client_email, { token: json.access_token, expires: nowSec + json.expires_in });
  return json.access_token;
}

/** 토큰 목록에 보낸다. 더 이상 쓸 수 없는 토큰은 지운다 */
export async function sendPush(env: Env, kind: SpaceKind, tokens: string[], msg: PushMessage): Promise<void> {
  const sa = parseAccount(env, kind);
  if (!sa || tokens.length === 0) return;
  let auth: string;
  try {
    auth = await accessToken(sa);
  } catch (e) {
    console.error(String(e));
    return;
  }
  const dead: string[] = [];
  await Promise.all(
    [...new Set(tokens)].map(async (token) => {
      const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${auth}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: msg.title, body: msg.body },
            data: msg.data ?? {},
            android: { priority: 'high', notification: { sound: 'default' } },
            apns: { payload: { aps: { sound: 'default' } } },
          },
        }),
      });
      if (res.ok) return;
      const text = await res.text();
      if (res.status === 404 || text.includes('UNREGISTERED') || text.includes('registration token is not a valid')) {
        dead.push(token);
      } else {
        console.error('FCM 전송 실패', res.status, text.slice(0, 300));
      }
    }),
  );
  if (dead.length) {
    await env.DB.prepare(`DELETE FROM push_tokens WHERE token IN (${dead.map(() => '?').join(', ')})`)
      .bind(...dead)
      .run();
  }
}

/**
 * 공간 멤버들의 토큰을 골라 보낸다.
 *   who: 'managers' (방장·부방장) | { exceptMemberId } (그 사람 빼고 내역 알림을 켠 멤버) | { memberId } (한 명)
 */
export async function notifySpace(
  env: Env,
  ledgerId: string,
  who: 'managers' | { exceptMemberId: string } | { memberId: string },
  msg: PushMessage,
): Promise<void> {
  const space = await env.DB.prepare('SELECT kind FROM ledgers WHERE id = ?').bind(ledgerId).first<{ kind: SpaceKind }>();
  if (!space || !accountJson(env, space.kind)) return;
  let where = "m.ledger_id = ? AND m.status = 'approved'";
  const binds: unknown[] = [ledgerId];
  if (who === 'managers') {
    where += " AND m.role IN ('owner', 'co_owner')";
  } else if ('exceptMemberId' in who) {
    where += ' AND m.id != ? AND m.notify_records = 1';
    binds.push(who.exceptMemberId);
  } else {
    // 승인 직후에도 받도록 상태와 관계없이 그 멤버의 기기로
    where = 'm.ledger_id = ? AND m.id = ?';
    binds.push(who.memberId);
  }
  const { results } = await env.DB.prepare(
    `SELECT p.token FROM push_tokens p JOIN ledger_members m ON m.device_id = p.device_id WHERE ${where}`,
  )
    .bind(...binds)
    .all<{ token: string }>();
  await sendPush(
    env,
    space.kind,
    results.map((r) => r.token),
    { ...msg, data: { space_id: ledgerId, ...(msg.data ?? {}) } },
  );
}

/** 응답을 늦추지 않게 뒤에서 보낸다 */
export function pushLater(
  c: { executionCtx: { waitUntil(p: Promise<unknown>): void }; env: Env },
  task: (env: Env) => Promise<void>,
): void {
  if (!anyAccount(c.env)) return;
  c.executionCtx.waitUntil(task(c.env).catch((e) => console.error('push', String(e))));
}
