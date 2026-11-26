// 고정 지출·수입과 할부: 매월 정한 날에 내역을 자동으로 만든다.
// 회차 n(1부터)의 날짜 = 시작 달 + (n-1)달의 day일 (그 달에 day일이 없으면 말일).
// 할부 금액은 총액 / 개월 수, 나누어떨어지지 않는 원 단위는 1회차에 더한다.
// 만든 회차는 transactions(rule_id, rule_seq)로 남고, 사용자가 그 내역을 지워도 다시 만들지 않는다.
import { newId } from './crypto';
import { now } from './http';

export type RuleKind = 'fixed' | 'installment';

export type RuleRow = {
  id: string;
  ledger_id: string;
  member_id: string;
  kind: RuleKind;
  type: 'income' | 'expense';
  amount: number;
  months: number | null;
  category_id: string | null;
  memo: string | null;
  day: number;
  start_date: string;
  deleted_at: string | null;
};

/** 한국 시간 오늘 (YYYY-MM-DD) */
export function todayKst(): string {
  return new Date(Date.now() + 9 * 3600_000).toISOString().slice(0, 10);
}

function daysInMonth(y: number, m: number): number {
  return new Date(Date.UTC(y, m, 0)).getUTCDate();
}

/** 회차 n의 날짜 */
export function occurrenceDate(rule: Pick<RuleRow, 'start_date' | 'day'>, seq: number): string {
  const [y0, m0] = rule.start_date.split('-').map(Number);
  const index = y0 * 12 + (m0 - 1) + (seq - 1);
  const y = Math.floor(index / 12);
  const m = (index % 12) + 1;
  const d = Math.min(rule.day, daysInMonth(y, m));
  return `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}

/** 회차 n의 금액 */
export function occurrenceAmount(rule: Pick<RuleRow, 'kind' | 'amount' | 'months'>, seq: number): number {
  if (rule.kind !== 'installment' || !rule.months) return rule.amount;
  const base = Math.floor(rule.amount / rule.months);
  return seq === 1 ? base + (rule.amount - base * rule.months) : base;
}

/** 오늘까지 와야 하는 마지막 회차 (없으면 0) */
export function dueCount(rule: RuleRow, today: string): number {
  if (rule.start_date > today) return 0;
  const [y0, m0] = rule.start_date.split('-').map(Number);
  const [y1, m1] = today.split('-').map(Number);
  let n = (y1 * 12 + m1) - (y0 * 12 + m0) + 1;
  if (occurrenceDate(rule, n) > today) n -= 1;
  if (rule.kind === 'installment' && rule.months) n = Math.min(n, rule.months);
  return Math.max(n, 0);
}

/** 다음 회차 날짜 (끝났으면 null) */
export function nextOccurrence(rule: RuleRow, today: string): { seq: number; date: string } | null {
  const seq = dueCount(rule, today) + 1;
  if (rule.kind === 'installment' && rule.months && seq > rule.months) return null;
  return { seq, date: occurrenceDate(rule, seq) };
}

/**
 * 밀린 회차를 만든다. ledgerId를 주면 그 가계부만 (조회할 때), 없으면 전체 (매일 새벽 cron).
 * 이미 만든 회차는 UNIQUE(rule_id, rule_seq)와 INSERT OR IGNORE로 건너뛴다.
 * 반환: 새로 만든 내역 수
 */
export async function generateDue(db: D1Database, ledgerId?: string, today = todayKst()): Promise<number> {
  const where = ['r.deleted_at IS NULL', 'l.deleted_at IS NULL', 'r.start_date <= ?'];
  const binds: unknown[] = [today];
  if (ledgerId) {
    where.push('r.ledger_id = ?');
    binds.push(ledgerId);
  }
  const { results: rules } = await db.prepare(
    `SELECT r.*, (SELECT COALESCE(MAX(t.rule_seq), 0) FROM transactions t WHERE t.rule_id = r.id) AS done
     FROM recurring_rules r JOIN ledgers l ON l.id = r.ledger_id
     WHERE ${where.join(' AND ')}`,
  )
    .bind(...binds)
    .all<RuleRow & { done: number }>();

  const stmts: D1PreparedStatement[] = [];
  const ts = now();
  for (const rule of rules) {
    const due = dueCount(rule, today);
    // 한 번에 너무 많이 만들지 않게 (오래 밀려도 최대 60회차)
    for (let seq = rule.done + 1; seq <= Math.min(due, rule.done + 60); seq++) {
      stmts.push(
        db.prepare(
          `INSERT OR IGNORE INTO transactions
             (id, ledger_id, member_id, type, amount, category_id, memo, spent_at, created_at, updated_at, rule_id, rule_seq)
           VALUES (?, ?, ?, ?, ?, (SELECT id FROM categories WHERE id = ? AND deleted_at IS NULL), ?, ?, ?, ?, ?, ?)`,
        ).bind(
          newId(),
          rule.ledger_id,
          rule.member_id,
          rule.type,
          occurrenceAmount(rule, seq),
          rule.category_id,
          rule.memo,
          occurrenceDate(rule, seq),
          ts,
          ts,
          rule.id,
          seq,
        ),
      );
    }
  }
  let created = 0;
  for (let i = 0; i < stmts.length; i += 50) {
    const res = await db.batch(stmts.slice(i, i + 50));
    created += res.reduce((n, r) => n + (r.meta.changes ?? 0), 0);
  }
  return created;
}
