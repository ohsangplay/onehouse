import { newId } from './crypto';
import { now } from './http';

export type EventType =
  | 'approve'
  | 'reject'
  | 'link'
  | 'revoke'
  | 'role'
  | 'transfer_owner'
  | 'recover'
  | 'invite_code'
  | 'recovery_code'
  | 'rename';

export function eventStmt(
  db: D1Database,
  ledgerId: string,
  type: EventType,
  actorMemberId: string | null,
  targetMemberId: string | null = null,
): D1PreparedStatement {
  return db
    .prepare(
      `INSERT INTO ledger_events (id, ledger_id, actor_member_id, type, target_member_id, created_at)
       VALUES (?, ?, ?, ?, ?, ?)`,
    )
    .bind(newId(), ledgerId, actorMemberId, type, targetMemberId, now());
}
