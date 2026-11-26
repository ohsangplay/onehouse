import { Hono } from 'hono';
import type { AppEnv } from '../types';
import { newId } from '../lib/crypto';
import { badRequest, forbidden, notFound, now, oneOf, readJson, str } from '../lib/http';
import { generateDue, nextOccurrence, occurrenceAmount, todayKst, type RuleKind, type RuleRow } from '../lib/recurring';
import { MANAGERS, requireDevice, requireMember } from '../middleware/auth';
import { BUDGET } from '../kinds';
import { checkCategory, parseAmount, parseDate, TX_TYPES } from './transactions';

const KINDS = ['fixed', 'installment'] as const;
const MAX_RULES = 100;

const SELECT_RULE = `
  SELECT r.*, c.name AS category_name, c.type AS category_type, m.nickname AS member_nickname,
    (SELECT COUNT(*) FROM transactions t WHERE t.rule_id = r.id) AS done
  FROM recurring_rules r
  JOIN ledger_members m ON m.id = r.member_id
  LEFT JOIN categories c ON c.id = r.category_id AND c.deleted_at IS NULL`;

type RuleOut = RuleRow & { done: number; category_name: string | null; member_nickname: string };

/** 앱에 내려줄 모양: 다음 회차·남은 금액을 붙인다 */
function present(rule: RuleOut, today = todayKst()) {
  const next = rule.deleted_at ? null : nextOccurrence(rule, today);
  let remaining: number | null = null;
  if (rule.kind === 'installment' && rule.months) {
    remaining = 0;
    for (let seq = rule.done + 1; seq <= rule.months; seq++) remaining += occurrenceAmount(rule, seq);
  }
  return {
    id: rule.id,
    kind: rule.kind,
    type: rule.type,
    amount: rule.amount,
    months: rule.months,
    monthly_amount: occurrenceAmount(rule, 2),
    first_amount: occurrenceAmount(rule, 1),
    category_id: rule.category_id,
    category_name: rule.category_name,
    memo: rule.memo,
    day: rule.day,
    start_date: rule.start_date,
    member_id: rule.member_id,
    member_nickname: rule.member_nickname,
    done: rule.done,
    remaining_amount: remaining,
    next_date: next?.date ?? null,
    next_seq: next?.seq ?? null,
    finished: !rule.deleted_at && next === null,
  };
}

// /ledgers/:ledgerId/recurring
export const recurring = new Hono<AppEnv>();

recurring.use('*', requireDevice, requireMember(BUDGET));

recurring.get('/', async (c) => {
  const db = c.env.DB;
  await generateDue(db, c.var.ledger.id);
  const { results } = await db.prepare(`${SELECT_RULE} WHERE r.ledger_id = ? AND r.deleted_at IS NULL ORDER BY r.created_at`)
    .bind(c.var.ledger.id)
    .all<RuleOut>();
  return c.json({ rules: results.map((r) => present(r)) });
});

/**
 * 만들기. start_date가 첫 회차이고, 그 날짜의 '일'이 매월 기록되는 날이 된다.
 * 오늘이나 지난 날짜면 밀린 회차까지 바로 내역으로 만든다.
 */
recurring.post('/', async (c) => {
  const body = await readJson(c);
  const db = c.env.DB;
  const { ledger, member } = c.var;
  const kind = oneOf(body.kind, KINDS, 'kind') as RuleKind;
  const type = oneOf(body.type, TX_TYPES, 'type');
  const amount = parseAmount(body.amount);
  const startDate = parseDate(body.start_date);
  const categoryId = str(body, 'category_id', { optional: true }) ?? null;
  const memo = str(body, 'memo', { max: 100, optional: true }) ?? null;

  let months: number | null = null;
  if (kind === 'installment') {
    if (type !== 'expense') throw badRequest('invalid_field', '할부는 지출에만 쓸 수 있어요.');
    if (typeof body.months !== 'number' || !Number.isInteger(body.months) || body.months < 2 || body.months > 60) {
      throw badRequest('invalid_field', '할부 개월 수는 2~60개월이어야 해요.');
    }
    months = body.months;
    if (amount < months) throw badRequest('invalid_field', '할부 금액이 너무 적어요.');
  }
  if (categoryId) await checkCategory(db, ledger.id, categoryId, type);

  const count = await db.prepare('SELECT COUNT(*) AS n FROM recurring_rules WHERE ledger_id = ? AND deleted_at IS NULL')
    .bind(ledger.id)
    .first<{ n: number }>();
  if ((count?.n ?? 0) >= MAX_RULES) throw badRequest('too_many_rules', `고정·할부는 ${MAX_RULES}개까지 만들 수 있어요.`);

  const id = newId();
  const ts = now();
  await db.prepare(
    `INSERT INTO recurring_rules (id, ledger_id, member_id, kind, type, amount, months, category_id, memo, day, start_date, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  )
    .bind(id, ledger.id, member.id, kind, type, amount, months, categoryId, memo, Number(startDate.slice(8, 10)), startDate, ts, ts)
    .run();
  const created = await generateDue(db, ledger.id);

  const rule = await db.prepare(`${SELECT_RULE} WHERE r.id = ?`).bind(id).first<RuleOut>();
  return c.json({ rule: present(rule!), created }, 201);
});

async function findRule(c: { env: AppEnv['Bindings']; var: AppEnv['Variables'] }, ruleId: string) {
  const rule = await c.env.DB.prepare('SELECT * FROM recurring_rules WHERE id = ? AND ledger_id = ? AND deleted_at IS NULL')
    .bind(ruleId, c.var.ledger.id)
    .first<RuleRow>();
  if (!rule) throw notFound('rule_not_found', '고정·할부 항목을 찾을 수 없어요.');
  // 만든 사람이나 방장·부방장만 바꿀 수 있다
  if (rule.member_id !== c.var.member.id && !MANAGERS.includes(c.var.member.role)) {
    throw forbidden('not_allowed', '만든 사람이나 방장·부방장만 바꿀 수 있어요.');
  }
  return rule;
}

/**
 * 수정: 이미 만든 내역은 그대로 두고 다음 회차부터 바뀐다.
 * 고정: amount, day, category_id, memo / 할부: category_id, memo (금액·개월 수는 바꿀 수 없음)
 */
recurring.patch('/:ruleId', async (c) => {
  const body = await readJson(c);
  const db = c.env.DB;
  const rule = await findRule(c, c.req.param('ruleId'));

  const next = {
    amount: rule.amount,
    day: rule.day,
    category_id: 'category_id' in body ? (str(body, 'category_id', { optional: true }) ?? null) : rule.category_id,
    memo: 'memo' in body ? (str(body, 'memo', { max: 100, optional: true }) ?? null) : rule.memo,
  };
  if (rule.kind === 'fixed') {
    if (body.amount !== undefined) next.amount = parseAmount(body.amount);
    if (body.day !== undefined) {
      if (typeof body.day !== 'number' || !Number.isInteger(body.day) || body.day < 1 || body.day > 31) {
        throw badRequest('invalid_field', 'day 값은 1~31이어야 해요.');
      }
      next.day = body.day;
    }
  } else if (body.amount !== undefined || body.day !== undefined) {
    throw badRequest('installment_locked', '할부는 금액·날짜를 바꿀 수 없어요. 지우고 다시 만들어 주세요.');
  }
  if (next.category_id) await checkCategory(db, rule.ledger_id, next.category_id, rule.type);

  await db.prepare('UPDATE recurring_rules SET amount = ?, day = ?, category_id = ?, memo = ?, updated_at = ? WHERE id = ?')
    .bind(next.amount, next.day, next.category_id, next.memo, now(), rule.id)
    .run();
  const updated = await db.prepare(`${SELECT_RULE} WHERE r.id = ?`).bind(rule.id).first<RuleOut>();
  return c.json({ rule: present(updated!) });
});

/** 그만하기: 앞으로 만들지 않는다. 이미 만든 내역(오늘까지)은 남는다 */
recurring.delete('/:ruleId', async (c) => {
  const db = c.env.DB;
  const rule = await findRule(c, c.req.param('ruleId'));
  const ts = now();
  await db.prepare('UPDATE recurring_rules SET deleted_at = ?, updated_at = ? WHERE id = ?').bind(ts, ts, rule.id).run();
  return c.json({ ok: true });
});
