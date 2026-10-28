import { Hono } from 'hono';
import type { AppEnv, CategoryType, TxType } from '../types';
import { newId } from '../lib/crypto';
import { badRequest, notFound, now, oneOf, readJson, str } from '../lib/http';
import { requireDevice, requireMember } from '../middleware/auth';

const TX_TYPES = ['income', 'expense'] as const;
const MAX_AMOUNT = 1_000_000_000_000;

type TxRow = {
  id: string;
  ledger_id: string;
  member_id: string;
  type: TxType;
  amount: number;
  category_id: string | null;
  memo: string | null;
  spent_at: string;
};

const SELECT_TX = `
  SELECT t.id, t.type, t.amount, t.category_id, c.name AS category_name, c.type AS category_type,
    t.memo, t.spent_at, t.member_id, m.nickname AS member_nickname,
    t.created_at, t.updated_at, t.deleted_at
  FROM transactions t
  JOIN ledger_members m ON m.id = t.member_id
  LEFT JOIN categories c ON c.id = t.category_id AND c.deleted_at IS NULL`;

function parseAmount(value: unknown): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value <= 0 || value > MAX_AMOUNT) {
    throw badRequest('invalid_field', 'amount 값은 1 이상의 원 단위 정수여야 해요.');
  }
  return value;
}

function parseDate(value: unknown): string {
  if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)) {
    const d = new Date(`${value}T00:00:00Z`);
    if (!Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === value) return value;
  }
  throw badRequest('invalid_field', 'spent_at 값은 YYYY-MM-DD 형식이어야 해요.');
}

/** 카테고리가 이 가계부에 있고 내역 종류와 맞는지 (공통은 둘 다 가능) */
async function checkCategory(db: D1Database, ledgerId: string, categoryId: string, type: TxType) {
  const cat = await db.prepare('SELECT type FROM categories WHERE id = ? AND ledger_id = ? AND deleted_at IS NULL')
    .bind(categoryId, ledgerId)
    .first<{ type: CategoryType }>();
  if (!cat) throw badRequest('invalid_category', '카테고리를 찾을 수 없어요.');
  if (cat.type !== 'common' && cat.type !== type) {
    throw badRequest('invalid_category', `${type === 'income' ? '수입' : '지출'} 내역에 쓸 수 없는 카테고리예요.`);
  }
}

// /ledgers/:ledgerId/transactions
export const transactions = new Hono<AppEnv>();

transactions.use('*', requireDevice, requireMember());

/**
 * 월별 조회: ?month=YYYY-MM [&category_ids=a,b] [&uncategorized=1]
 * 변경분 동기화: ?since=<ISO 시각> (삭제된 내역도 deleted_at과 함께 내려감)
 */
transactions.get('/', async (c) => {
  const ledgerId = c.var.ledger.id;
  const since = c.req.query('since');
  const db = c.env.DB;

  if (since) {
    if (Number.isNaN(Date.parse(since))) throw badRequest('invalid_query', 'since 값이 올바른 시각이 아니에요.');
    const { results } = await db.prepare(`${SELECT_TX} WHERE t.ledger_id = ? AND t.updated_at > ? ORDER BY t.updated_at`)
      .bind(ledgerId, since)
      .all();
    return c.json({ transactions: results, server_time: now() });
  }

  const month = c.req.query('month') ?? '';
  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(month)) throw badRequest('invalid_query', 'month 값은 YYYY-MM 형식이어야 해요.');
  const [y, m] = month.split('-').map(Number);
  const end = m === 12 ? `${y + 1}-01-01` : `${y}-${String(m + 1).padStart(2, '0')}-01`;

  const where = ['t.ledger_id = ?', 't.deleted_at IS NULL', 't.spent_at >= ?', 't.spent_at < ?'];
  const params: unknown[] = [ledgerId, `${month}-01`, end];

  const ids = (c.req.query('category_ids') ?? '').split(',').map((s) => s.trim()).filter(Boolean);
  const uncategorized = c.req.query('uncategorized') === '1';
  if (ids.length > 50) throw badRequest('invalid_query', '카테고리 필터는 50개까지 걸 수 있어요.');
  if (ids.length || uncategorized) {
    const parts: string[] = [];
    if (ids.length) {
      parts.push(`t.category_id IN (${ids.map(() => '?').join(', ')})`);
      params.push(...ids);
    }
    if (uncategorized) parts.push('t.category_id IS NULL');
    where.push(`(${parts.join(' OR ')})`);
  }

  const { results } = await db.prepare(`${SELECT_TX} WHERE ${where.join(' AND ')} ORDER BY t.spent_at DESC, t.created_at DESC`)
    .bind(...params)
    .all<{ type: TxType; amount: number }>();

  const summary = results.reduce(
    (acc, t) => {
      acc[t.type] += t.amount;
      return acc;
    },
    { income: 0, expense: 0 },
  );
  return c.json({ month, summary, transactions: results });
});

transactions.post('/', async (c) => {
  const body = await readJson(c);
  const type = oneOf(body.type, TX_TYPES, 'type');
  const amount = parseAmount(body.amount);
  const spentAt = parseDate(body.spent_at);
  const categoryId = str(body, 'category_id', { optional: true }) ?? null;
  const memo = str(body, 'memo', { max: 100, optional: true }) ?? null;
  const { ledger, member } = c.var;

  if (categoryId) await checkCategory(c.env.DB, ledger.id, categoryId, type);

  const id = newId();
  const ts = now();
  await c.env.DB.prepare(
    `INSERT INTO transactions (id, ledger_id, member_id, type, amount, category_id, memo, spent_at, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  )
    .bind(id, ledger.id, member.id, type, amount, categoryId, memo, spentAt, ts, ts)
    .run();

  const created = await c.env.DB.prepare(`${SELECT_TX} WHERE t.id = ?`).bind(id).first();
  return c.json(created, 201);
});

/** 승인된 멤버는 누구나 수정·삭제할 수 있다 (작성자 표시는 그대로) */
transactions.patch('/:txId', async (c) => {
  const body = await readJson(c);
  const db = c.env.DB;
  const ledgerId = c.var.ledger.id;

  const tx = await db.prepare('SELECT * FROM transactions WHERE id = ? AND ledger_id = ? AND deleted_at IS NULL')
    .bind(c.req.param('txId'), ledgerId)
    .first<TxRow>();
  if (!tx) throw notFound('transaction_not_found', '내역을 찾을 수 없어요.');

  const next = {
    type: body.type !== undefined ? oneOf(body.type, TX_TYPES, 'type') : tx.type,
    amount: body.amount !== undefined ? parseAmount(body.amount) : tx.amount,
    spent_at: body.spent_at !== undefined ? parseDate(body.spent_at) : tx.spent_at,
    category_id: 'category_id' in body ? (str(body, 'category_id', { optional: true }) ?? null) : tx.category_id,
    memo: 'memo' in body ? (str(body, 'memo', { max: 100, optional: true }) ?? null) : tx.memo,
  };
  if (next.category_id) await checkCategory(db, ledgerId, next.category_id, next.type);

  await db.prepare(
    'UPDATE transactions SET type = ?, amount = ?, spent_at = ?, category_id = ?, memo = ?, updated_at = ? WHERE id = ?',
  )
    .bind(next.type, next.amount, next.spent_at, next.category_id, next.memo, now(), tx.id)
    .run();

  const updated = await db.prepare(`${SELECT_TX} WHERE t.id = ?`).bind(tx.id).first();
  return c.json(updated);
});

transactions.delete('/:txId', async (c) => {
  const ts = now();
  const res = await c.env.DB.prepare(
    'UPDATE transactions SET deleted_at = ?, updated_at = ? WHERE id = ? AND ledger_id = ? AND deleted_at IS NULL',
  )
    .bind(ts, ts, c.req.param('txId'), c.var.ledger.id)
    .run();
  if (!res.meta.changes) throw notFound('transaction_not_found', '내역을 찾을 수 없어요.');
  return c.json({ ok: true });
});
