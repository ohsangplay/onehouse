import { Hono } from 'hono';
import type { AppEnv, LedgerRow, MemberRow } from '../types';
import { newId, normalizeCode, randomCode, sha256 } from '../lib/crypto';
import { eventStmt } from '../lib/events';
import { badRequest, conflict, forbidden, notFound, now, readJson, reqStr } from '../lib/http';
import { rateLimit } from '../lib/rateLimit';
import { MANAGERS, OWNER, requireDevice, requireMember } from '../middleware/auth';
import { type KindConfig, at, obj } from '../kinds';

const MAX_PENDING_REQUESTS = 20;
const MAX_CO_OWNERS = 3;

async function uniqueInviteCode(db: D1Database): Promise<string> {
  for (let i = 0; i < 5; i++) {
    const code = randomCode(2);
    const taken = await db.prepare('SELECT 1 FROM ledgers WHERE invite_code = ?').bind(code).first();
    if (!taken) return code;
  }
  throw new Error('초대코드 생성 실패');
}

/**
 * 공간(가계부·메모집) 공통 API. /ledgers 와 /notebooks 에 같은 코드를 붙인다.
 * 초대코드·참여 요청·방장 복구·양도·나가기·이름 수정·삭제가 여기 있다.
 */
export function spaceRoutes(kind: KindConfig) {
  const ledgers = new Hono<AppEnv>();
  const noun = kind.noun;

  ledgers.use('*', requireDevice);

  /** 내 목록 (승인 대기 포함) */
  ledgers.get('/', async (c) => {
    const extra = kind.listExtra();
    const { results } = await c.env.DB.prepare(
      `SELECT l.id, l.name, m.id AS member_id, m.nickname, m.role, m.status,
         (SELECT COUNT(*) FROM ledger_members x WHERE x.ledger_id = l.id AND x.status = 'approved') AS member_count,
         (SELECT COUNT(*) FROM ledger_members x WHERE x.ledger_id = l.id AND x.status = 'pending') AS pending_count,
         ${extra.sql}
       FROM ledger_members m
       JOIN ledgers l ON l.id = m.ledger_id
       WHERE m.device_id = ?1 AND m.status IN ('pending', 'approved') AND l.kind = '${kind.kind}' AND l.deleted_at IS NULL
       ORDER BY l.created_at`,
    )
      .bind(c.var.device.id, ...extra.binds)
      .all<Record<string, unknown>>();

    // 승인 대기 중인 곳에서는 내부 정보를 숨긴다
    const items = results.map((r) => {
      const approved = r.status === 'approved';
      const manager = approved && (r.role === 'owner' || r.role === 'co_owner');
      const extras = extra.pick(r);
      return {
        id: r.id,
        name: r.name,
        member_id: r.member_id,
        nickname: r.nickname,
        role: approved ? r.role : null,
        status: r.status,
        member_count: approved ? r.member_count : null,
        pending_count: manager ? r.pending_count : null,
        ...Object.fromEntries(Object.entries(extras).map(([k, v]) => [k, approved || k === 'month' ? v : null])),
      };
    });
    return c.json({ [kind.listKey]: items });
  });

  /** 만들기 → 초대코드 + 복구코드(이때 한 번만 보여줌) */
  ledgers.post('/', async (c) => {
    const body = await readJson(c);
    const name = reqStr(body, 'name', { min: 1, max: 30 });
    const nickname = reqStr(body, 'nickname', { min: 1, max: 20 });

    const ledgerId = newId();
    const memberId = newId();
    const inviteCode = await uniqueInviteCode(c.env.DB);
    const recoveryCode = randomCode(3);
    const ts = now();
    const db = c.env.DB;

    await db.batch([
      db
        .prepare(
          `INSERT INTO ledgers (id, kind, name, owner_member_id, invite_code, invite_code_updated_at,
             recovery_code_hash, recovery_code_updated_at, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        )
        .bind(ledgerId, kind.kind, name, memberId, inviteCode, ts, await sha256(recoveryCode), ts, ts),
      db
        .prepare(
          `INSERT INTO ledger_members (id, ledger_id, device_id, nickname, role, status, requested_at, decided_at)
           VALUES (?, ?, ?, ?, 'owner', 'approved', ?, ?)`,
        )
        .bind(memberId, ledgerId, c.var.device.id, nickname, ts, ts),
      ...kind.onCreate(db, ledgerId, ts),
    ]);

    return c.json(
      {
        ledger: { id: ledgerId, name, invite_code: inviteCode },
        member: { id: memberId, nickname, role: 'owner' },
        recovery_code: recoveryCode,
      },
      201,
    );
  });

  /** 초대코드로 참여 요청 → 승인 대기 */
  ledgers.post('/join', async (c) => {
    await rateLimit(c, 'join', 10, 600);
    const body = await readJson(c);
    const code = normalizeCode(reqStr(body, 'code', { max: 20 }));
    const nickname = reqStr(body, 'nickname', { min: 1, max: 20 });
    const db = c.env.DB;

    // 초대코드는 종류와 상관없이 하나뿐이지만, 가계부 코드를 메모 앱에 넣으면 "맞지 않아요"로 처리한다
    const ledger = await db.prepare('SELECT * FROM ledgers WHERE invite_code = ? AND kind = ? AND deleted_at IS NULL')
      .bind(code, kind.kind)
      .first<LedgerRow>();
    if (!ledger) throw notFound('invalid_invite_code', '초대코드가 맞지 않아요.');

    const existing = await db.prepare('SELECT * FROM ledger_members WHERE ledger_id = ? AND device_id = ?')
      .bind(ledger.id, c.var.device.id)
      .first<MemberRow>();

    const result = (status: string) => c.json({ ledger_id: ledger.id, ledger_name: ledger.name, status });

    if (existing?.status === 'approved') return result('approved');
    if (existing?.status === 'pending') return result('pending');

    const pending = await db.prepare(
      "SELECT COUNT(*) AS n FROM ledger_members WHERE ledger_id = ? AND status = 'pending'",
    )
      .bind(ledger.id)
      .first<{ n: number }>();
    if ((pending?.n ?? 0) >= MAX_PENDING_REQUESTS) {
      throw conflict('too_many_requests', `이 ${at(kind)} 대기 중인 요청이 너무 많아요. 방장에게 알려주세요.`);
    }

    const ts = now();
    if (existing) {
      // 거절·차단·나감 이후 재요청: 같은 행을 승인 대기로 되돌린다 (was_revoked는 유지)
      await db.prepare(
        `UPDATE ledger_members SET status = 'pending', role = 'member', nickname = ?,
           requested_at = ?, decided_at = NULL, decided_by_member_id = NULL
         WHERE id = ?`,
      )
        .bind(nickname, ts, existing.id)
        .run();
    } else {
      await db.prepare(
        `INSERT INTO ledger_members (id, ledger_id, device_id, nickname, role, status, requested_at)
         VALUES (?, ?, ?, ?, 'member', 'pending', ?)`,
      )
        .bind(newId(), ledger.id, c.var.device.id, nickname, ts)
        .run();
    }
    return result('pending');
  });

  /** 복구코드로 방장 권한을 이 기기로 가져오기 */
  ledgers.post('/recover', async (c) => {
    await rateLimit(c, 'recover', 10, 3600);
    const body = await readJson(c);
    const code = normalizeCode(reqStr(body, 'code', { max: 20 }));
    const db = c.env.DB;
    const deviceId = c.var.device.id;

    const ledger = await db.prepare(
      'SELECT * FROM ledgers WHERE recovery_code_hash = ? AND kind = ? AND deleted_at IS NULL',
    )
      .bind(await sha256(code), kind.kind)
      .first<LedgerRow>();
    if (!ledger || !ledger.owner_member_id) throw notFound('invalid_recovery_code', '복구코드가 맞지 않아요.');

    const owner = await db.prepare('SELECT * FROM ledger_members WHERE id = ?')
      .bind(ledger.owner_member_id)
      .first<MemberRow>();
    if (!owner) throw notFound('invalid_recovery_code', '복구코드가 맞지 않아요.');

    const newRecoveryCode = randomCode(3);
    const ts = now();
    const stmts: D1PreparedStatement[] = [];

    if (owner.device_id !== deviceId) {
      const mine = await db.prepare('SELECT * FROM ledger_members WHERE ledger_id = ? AND device_id = ?')
        .bind(ledger.id, deviceId)
        .first<MemberRow>();
      if (mine) {
        // 이 기기가 이미 다른 멤버로 있었다면 그 기록을 방장 쪽으로 합치고 행을 정리
        stmts.push(...kind.mergeMember(db, mine.id, owner.id));
        stmts.push(db.prepare('DELETE FROM ledger_members WHERE id = ?').bind(mine.id));
      }
      stmts.push(
        db.prepare("UPDATE ledger_members SET device_id = ?, status = 'approved' WHERE id = ?").bind(deviceId, owner.id),
      );
    }
    stmts.push(
      db
        .prepare('UPDATE ledgers SET recovery_code_hash = ?, recovery_code_updated_at = ? WHERE id = ?')
        .bind(await sha256(newRecoveryCode), ts, ledger.id),
      eventStmt(db, ledger.id, 'recover', owner.id, owner.id),
    );
    await db.batch(stmts);

    return c.json({ ledger_id: ledger.id, ledger_name: ledger.name, recovery_code: newRecoveryCode });
  });

  /** 승인 대기 중인 요청 취소 (요청자 본인) */
  ledgers.post('/:ledgerId/cancel-request', async (c) => {
    const res = await c.env.DB.prepare(
      `UPDATE ledger_members SET status = 'left'
       WHERE ledger_id = ? AND device_id = ? AND status = 'pending'
         AND ledger_id IN (SELECT id FROM ledgers WHERE kind = ?)`,
    )
      .bind(c.req.param('ledgerId'), c.var.device.id, kind.kind)
      .run();
    if (!res.meta.changes) throw notFound('no_pending_request', '대기 중인 요청이 없어요.');
    return c.json({ ok: true });
  });

  /** 상세 (역할별로 보이는 값이 다름) */
  ledgers.get('/:ledgerId', requireMember(kind), async (c) => {
    const { ledger, member } = c.var;
    const manager = MANAGERS.includes(member.role);
    return c.json({
      id: ledger.id,
      name: ledger.name,
      member: { id: member.id, nickname: member.nickname, role: member.role },
      invite_code: manager ? ledger.invite_code : null,
      // 방장 양도 직후에는 복구코드가 없다 → 앱에서 새 방장에게 발급을 안내
      needs_recovery_code: member.role === 'owner' ? ledger.recovery_code_hash === null : null,
    });
  });

  /** 이름 수정 (방장만) */
  ledgers.patch('/:ledgerId', requireMember(kind, OWNER), async (c) => {
    const body = await readJson(c);
    const name = reqStr(body, 'name', { min: 1, max: 30 });
    const { ledger, member } = c.var;
    await c.env.DB.batch([
      c.env.DB.prepare('UPDATE ledgers SET name = ? WHERE id = ?').bind(name, ledger.id),
      eventStmt(c.env.DB, ledger.id, 'rename', member.id),
    ]);
    return c.json({ id: ledger.id, name });
  });

  /** 삭제 (방장만, 이름을 다시 입력해야 함) */
  ledgers.delete('/:ledgerId', requireMember(kind, OWNER), async (c) => {
    const body = await readJson(c);
    const confirmName = reqStr(body, 'confirm_name');
    if (confirmName !== c.var.ledger.name) throw badRequest('name_mismatch', `${noun} 이름이 일치하지 않아요.`);
    await c.env.DB.prepare('UPDATE ledgers SET deleted_at = ? WHERE id = ?').bind(now(), c.var.ledger.id).run();
    return c.json({ ok: true });
  });

  /** 초대코드 재발급 (방장만) */
  ledgers.post('/:ledgerId/invite-code', requireMember(kind, OWNER), async (c) => {
    const code = await uniqueInviteCode(c.env.DB);
    const { ledger, member } = c.var;
    await c.env.DB.batch([
      c.env.DB.prepare('UPDATE ledgers SET invite_code = ?, invite_code_updated_at = ? WHERE id = ?').bind(
        code,
        now(),
        ledger.id,
      ),
      eventStmt(c.env.DB, ledger.id, 'invite_code', member.id),
    ]);
    return c.json({ invite_code: code });
  });

  /** 복구코드 재발급 (방장만, 이전 코드는 무효) */
  ledgers.post('/:ledgerId/recovery-code', requireMember(kind, OWNER), async (c) => {
    const code = randomCode(3);
    const { ledger, member } = c.var;
    await c.env.DB.batch([
      c.env.DB.prepare('UPDATE ledgers SET recovery_code_hash = ?, recovery_code_updated_at = ? WHERE id = ?').bind(
        await sha256(code),
        now(),
        ledger.id,
      ),
      eventStmt(c.env.DB, ledger.id, 'recovery_code', member.id),
    ]);
    return c.json({ recovery_code: code });
  });

  /** 방장 양도: 기존 방장은 부방장(자리가 없으면 멤버)이 되고, 복구코드는 새 방장이 다시 발급 */
  ledgers.post('/:ledgerId/transfer-owner', requireMember(kind, OWNER), async (c) => {
    const body = await readJson(c);
    const targetId = reqStr(body, 'member_id');
    const { ledger, member } = c.var;
    const db = c.env.DB;

    if (targetId === member.id) throw badRequest('invalid_target', '자기 자신에게는 넘길 수 없어요.');
    const target = await db.prepare(
      "SELECT * FROM ledger_members WHERE id = ? AND ledger_id = ? AND status = 'approved'",
    )
      .bind(targetId, ledger.id)
      .first<MemberRow>();
    if (!target) throw notFound('member_not_found', '멤버를 찾을 수 없어요.');

    const coOwners = await db.prepare(
      "SELECT COUNT(*) AS n FROM ledger_members WHERE ledger_id = ? AND role = 'co_owner' AND status = 'approved' AND id != ?",
    )
      .bind(ledger.id, target.id)
      .first<{ n: number }>();
    const myNewRole = (coOwners?.n ?? 0) < MAX_CO_OWNERS ? 'co_owner' : 'member';

    await db.batch([
      db.prepare("UPDATE ledger_members SET role = 'owner' WHERE id = ?").bind(target.id),
      db.prepare('UPDATE ledger_members SET role = ? WHERE id = ?').bind(myNewRole, member.id),
      db
        .prepare(
          'UPDATE ledgers SET owner_member_id = ?, recovery_code_hash = NULL, recovery_code_updated_at = NULL WHERE id = ?',
        )
        .bind(target.id, ledger.id),
      eventStmt(db, ledger.id, 'transfer_owner', member.id, target.id),
    ]);
    return c.json({ owner_member_id: target.id, my_role: myNewRole });
  });

  /** 나가기 (방장은 불가: 양도하거나 삭제) */
  ledgers.post('/:ledgerId/leave', requireMember(kind), async (c) => {
    const { member } = c.var;
    if (member.role === 'owner') {
      throw forbidden('owner_cannot_leave', `방장은 나갈 수 없어요. 방장을 넘기거나 ${obj(kind)} 삭제해 주세요.`);
    }
    await c.env.DB.prepare("UPDATE ledger_members SET status = 'left', role = 'member' WHERE id = ?")
      .bind(member.id)
      .run();
    return c.json({ ok: true });
  });

  /** 내 닉네임 수정 */
  ledgers.patch('/:ledgerId/me', requireMember(kind), async (c) => {
    const body = await readJson(c);
    const nickname = reqStr(body, 'nickname', { min: 1, max: 20 });
    await c.env.DB.prepare('UPDATE ledger_members SET nickname = ? WHERE id = ?').bind(nickname, c.var.member.id).run();
    return c.json({ nickname });
  });

  /** 관리 이력 (방장만) */
  ledgers.get('/:ledgerId/events', requireMember(kind, OWNER), async (c) => {
    const { results } = await c.env.DB.prepare(
      `SELECT e.id, e.type, e.created_at,
         e.actor_member_id, a.nickname AS actor_nickname,
         e.target_member_id, t.nickname AS target_nickname
       FROM ledger_events e
       LEFT JOIN ledger_members a ON a.id = e.actor_member_id
       LEFT JOIN ledger_members t ON t.id = e.target_member_id
       WHERE e.ledger_id = ?
       ORDER BY e.created_at DESC
       LIMIT 100`,
    )
      .bind(c.var.ledger.id)
      .all();
    return c.json({ events: results });
  });

  return ledgers;
}
