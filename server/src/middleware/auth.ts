import { createMiddleware } from 'hono/factory';
import type { AppEnv, DeviceRow, LedgerRow, MemberRow, Role } from '../types';
import { sha256 } from '../lib/crypto';
import { ApiError, forbidden, notFound, now } from '../lib/http';

/** Authorization: Bearer <기기 토큰> → c.var.device */
export const requireDevice = createMiddleware<AppEnv>(async (c, next) => {
  const header = c.req.header('Authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  if (!token) throw new ApiError(401, 'no_token', '기기 토큰이 필요해요.');

  const device = await c.env.DB.prepare('SELECT * FROM devices WHERE token_hash = ?')
    .bind(await sha256(token))
    .first<DeviceRow>();
  // 다른 기기로 이전된 경우에도 여기로 온다 → 앱은 "다른 기기로 이전되었어요" 안내
  if (!device) throw new ApiError(401, 'invalid_token', '유효하지 않은 기기 토큰이에요.');

  c.executionCtx.waitUntil(
    c.env.DB.prepare('UPDATE devices SET last_seen_at = ? WHERE id = ?').bind(now(), device.id).run(),
  );
  c.set('device', device);
  await next();
});

/**
 * :ledgerId 가계부의 승인된 멤버만 통과. roles를 주면 해당 역할만 허용.
 * → c.var.ledger, c.var.member
 */
export const requireMember = (roles?: Role[]) =>
  createMiddleware<AppEnv>(async (c, next) => {
    const ledgerId = c.req.param('ledgerId');
    if (!ledgerId) throw notFound('ledger_not_found', '가계부를 찾을 수 없어요.');

    const ledger = await c.env.DB.prepare('SELECT * FROM ledgers WHERE id = ? AND deleted_at IS NULL')
      .bind(ledgerId)
      .first<LedgerRow>();
    if (!ledger) throw notFound('ledger_not_found', '가계부를 찾을 수 없어요.');

    const member = await c.env.DB.prepare('SELECT * FROM ledger_members WHERE ledger_id = ? AND device_id = ?')
      .bind(ledgerId, c.var.device.id)
      .first<MemberRow>();
    if (!member || member.status !== 'approved') {
      throw forbidden('not_member', '이 가계부에 접근할 수 없어요.');
    }
    if (roles && !roles.includes(member.role)) {
      throw forbidden('no_permission', '이 작업을 할 권한이 없어요.');
    }

    c.set('ledger', ledger);
    c.set('member', member);
    await next();
  });

export const MANAGERS: Role[] = ['owner', 'co_owner'];
export const OWNER: Role[] = ['owner'];
