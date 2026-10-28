import { Hono } from 'hono';
import type { AppEnv, MemberRow } from '../types';
import { eventStmt } from '../lib/events';
import { badRequest, conflict, forbidden, notFound, now, oneOf, readJson, str } from '../lib/http';
import { MANAGERS, OWNER, requireDevice, requireMember } from '../middleware/auth';

const MAX_CO_OWNERS = 3;

// /ledgers/:ledgerId/members
export const members = new Hono<AppEnv>();

members.use('*', requireDevice);

async function findMember(db: D1Database, ledgerId: string, memberId: string): Promise<MemberRow> {
  const row = await db.prepare('SELECT * FROM ledger_members WHERE id = ? AND ledger_id = ?')
    .bind(memberId, ledgerId)
    .first<MemberRow>();
  if (!row) throw notFound('member_not_found', '멤버를 찾을 수 없어요.');
  return row;
}

/** 멤버 + 승인 대기 목록 (방장·부방장) */
members.get('/', requireMember(MANAGERS), async (c) => {
  const { results } = await c.env.DB.prepare(
    `SELECT id, nickname, role, status, was_revoked, requested_at, decided_at
     FROM ledger_members
     WHERE ledger_id = ? AND status IN ('approved', 'pending')
     ORDER BY CASE role WHEN 'owner' THEN 0 WHEN 'co_owner' THEN 1 ELSE 2 END, requested_at`,
  )
    .bind(c.var.ledger.id)
    .all<{ id: string; nickname: string; role: string; status: string; was_revoked: number }>();

  const toItem = (r: (typeof results)[number]) => ({ ...r, was_revoked: r.was_revoked === 1 });
  return c.json({
    members: results.filter((r) => r.status === 'approved').map(toItem),
    pending: results.filter((r) => r.status === 'pending').map(toItem),
  });
});

/** 멤버 상세 (방장·부방장): 참여일, 승인한 사람, 이번 달 작성 내역 */
members.get('/:memberId', requireMember(MANAGERS), async (c) => {
  const target = await findMember(c.env.DB, c.var.ledger.id, c.req.param('memberId'));
  const month = new Date(Date.now() + 9 * 3600_000).toISOString().slice(0, 7);
  const stats = await c.env.DB.prepare(
    `SELECT COUNT(*) AS count,
       COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS expense
     FROM transactions
     WHERE member_id = ? AND deleted_at IS NULL AND substr(spent_at, 1, 7) = ?`,
  )
    .bind(target.id, month)
    .first<{ count: number; expense: number }>();
  const decidedBy = target.decided_by_member_id
    ? await c.env.DB.prepare('SELECT id, nickname, role FROM ledger_members WHERE id = ?')
        .bind(target.decided_by_member_id)
        .first()
    : null;

  return c.json({
    id: target.id,
    nickname: target.nickname,
    role: target.role,
    status: target.status,
    was_revoked: target.was_revoked === 1,
    joined_at: target.decided_at,
    decided_by: decidedBy,
    month,
    month_count: stats?.count ?? 0,
    month_expense: stats?.expense ?? 0,
  });
});

/**
 * 승인. link_to_member_id를 주면 "기존 멤버로 연결":
 * 기존 멤버 행이 새 기기를 가리키게 되고 대기 요청 행은 지운다. 내역은 같은 사람으로 이어진다.
 */
members.post('/:memberId/approve', requireMember(MANAGERS), async (c) => {
  const body = await readJson(c).catch(() => ({}) as Record<string, unknown>);
  const linkToId = str(body, 'link_to_member_id', { optional: true });
  const { ledger, member: actor } = c.var;
  const db = c.env.DB;

  const target = await findMember(db, ledger.id, c.req.param('memberId'));
  if (target.status !== 'pending') throw conflict('not_pending', '승인 대기 중인 요청이 아니에요.');
  const ts = now();

  if (!linkToId) {
    await db.batch([
      db
        .prepare(
          "UPDATE ledger_members SET status = 'approved', decided_at = ?, decided_by_member_id = ? WHERE id = ?",
        )
        .bind(ts, actor.id, target.id),
      eventStmt(db, ledger.id, 'approve', actor.id, target.id),
    ]);
    return c.json({ member_id: target.id, linked: false });
  }

  const linkTo = await findMember(db, ledger.id, linkToId);
  if (linkTo.status !== 'approved') throw badRequest('invalid_link', '승인된 멤버에게만 연결할 수 있어요.');
  if (linkTo.id === actor.id) throw badRequest('invalid_link', '자기 자신에게는 연결할 수 없어요.');

  await db.batch([
    // UNIQUE(ledger_id, device_id) 때문에 대기 행을 먼저 지운다
    db.prepare('DELETE FROM ledger_members WHERE id = ?').bind(target.id),
    db
      .prepare('UPDATE ledger_members SET device_id = ?, decided_at = ?, decided_by_member_id = ? WHERE id = ?')
      .bind(target.device_id, ts, actor.id, linkTo.id),
    eventStmt(db, ledger.id, 'link', actor.id, linkTo.id),
  ]);
  return c.json({ member_id: linkTo.id, linked: true });
});

members.post('/:memberId/reject', requireMember(MANAGERS), async (c) => {
  const { ledger, member: actor } = c.var;
  const db = c.env.DB;
  const target = await findMember(db, ledger.id, c.req.param('memberId'));
  if (target.status !== 'pending') throw conflict('not_pending', '승인 대기 중인 요청이 아니에요.');

  await db.batch([
    db
      .prepare("UPDATE ledger_members SET status = 'rejected', decided_at = ?, decided_by_member_id = ? WHERE id = ?")
      .bind(now(), actor.id, target.id),
    eventStmt(db, ledger.id, 'reject', actor.id, target.id),
  ]);
  return c.json({ ok: true });
});

/** 차단: 방장은 누구든(자신 제외), 부방장은 일반 멤버만 */
members.post('/:memberId/revoke', requireMember(MANAGERS), async (c) => {
  const { ledger, member: actor } = c.var;
  const db = c.env.DB;
  const target = await findMember(db, ledger.id, c.req.param('memberId'));

  if (target.status !== 'approved') throw conflict('not_approved', '승인된 멤버만 차단할 수 있어요.');
  if (target.id === actor.id || target.role === 'owner') {
    throw forbidden('cannot_revoke', '이 멤버는 차단할 수 없어요.');
  }
  if (actor.role === 'co_owner' && target.role !== 'member') {
    throw forbidden('cannot_revoke', '부방장은 일반 멤버만 차단할 수 있어요.');
  }

  await db.batch([
    db
      .prepare(
        `UPDATE ledger_members SET status = 'revoked', role = 'member', was_revoked = 1,
           decided_at = ?, decided_by_member_id = ? WHERE id = ?`,
      )
      .bind(now(), actor.id, target.id),
    eventStmt(db, ledger.id, 'revoke', actor.id, target.id),
  ]);
  return c.json({ ok: true });
});

/** 부방장 지정·해제 (방장만, 최대 3명) */
members.patch('/:memberId/role', requireMember(OWNER), async (c) => {
  const body = await readJson(c);
  const role = oneOf(body.role, ['co_owner', 'member'] as const, 'role');
  const { ledger, member: actor } = c.var;
  const db = c.env.DB;
  const target = await findMember(db, ledger.id, c.req.param('memberId'));

  if (target.status !== 'approved') throw conflict('not_approved', '승인된 멤버만 바꿀 수 있어요.');
  if (target.role === 'owner') throw badRequest('invalid_target', '방장 역할은 방장 넘기기로만 바꿀 수 있어요.');

  if (role === 'co_owner' && target.role !== 'co_owner') {
    const count = await db.prepare(
      "SELECT COUNT(*) AS n FROM ledger_members WHERE ledger_id = ? AND role = 'co_owner' AND status = 'approved'",
    )
      .bind(ledger.id)
      .first<{ n: number }>();
    if ((count?.n ?? 0) >= MAX_CO_OWNERS) {
      throw conflict('co_owner_limit', `부방장은 최대 ${MAX_CO_OWNERS}명까지 지정할 수 있어요.`);
    }
  }

  await db.batch([
    db.prepare('UPDATE ledger_members SET role = ? WHERE id = ?').bind(role, target.id),
    eventStmt(db, ledger.id, 'role', actor.id, target.id),
  ]);
  return c.json({ member_id: target.id, role });
});
