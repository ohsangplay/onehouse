import { Hono } from 'hono';
import type { AppEnv, CategoryType } from '../types';
import { newId } from '../lib/crypto';
import { badRequest, conflict, notFound, now, oneOf, readJson, reqStr, str } from '../lib/http';
import { MANAGERS, requireDevice, requireMember } from '../middleware/auth';
import { BUDGET } from '../kinds';

const CATEGORY_TYPES = ['common', 'expense', 'income'] as const;

type CategoryRow = {
  id: string;
  ledger_id: string;
  type: CategoryType;
  name: string;
  sort_order: number;
};

// /ledgers/:ledgerId/categories
export const categories = new Hono<AppEnv>();

categories.use('*', requireDevice);

async function findCategory(db: D1Database, ledgerId: string, id: string): Promise<CategoryRow> {
  const row = await db.prepare('SELECT * FROM categories WHERE id = ? AND ledger_id = ? AND deleted_at IS NULL')
    .bind(id, ledgerId)
    .first<CategoryRow>();
  if (!row) throw notFound('category_not_found', '카테고리를 찾을 수 없어요.');
  return row;
}

/** 같은 화면에 함께 보이는 범위에서 이름이 겹치면 안 된다 (공통은 지출·수입 모두와 겹침) */
async function assertNameFree(db: D1Database, ledgerId: string, type: CategoryType, name: string, exceptId = '') {
  const scope = type === 'common' ? ['common', 'expense', 'income'] : ['common', type];
  const dup = await db.prepare(
    `SELECT 1 FROM categories
     WHERE ledger_id = ? AND name = ? AND deleted_at IS NULL AND id != ?
       AND type IN (${scope.map(() => '?').join(', ')})`,
  )
    .bind(ledgerId, name, exceptId, ...scope)
    .first();
  if (dup) throw conflict('duplicate_category', '같은 이름의 카테고리가 이미 있어요.');
}

categories.get('/', requireMember(BUDGET), async (c) => {
  const { results } = await c.env.DB.prepare(
    `SELECT c.id, c.type, c.name, c.sort_order, c.created_by_member_id, m.nickname AS created_by_nickname
     FROM categories c
     LEFT JOIN ledger_members m ON m.id = c.created_by_member_id
     WHERE c.ledger_id = ? AND c.deleted_at IS NULL
     ORDER BY CASE c.type WHEN 'common' THEN 0 WHEN 'expense' THEN 1 ELSE 2 END, c.sort_order, c.created_at`,
  )
    .bind(c.var.ledger.id)
    .all();
  return c.json({ categories: results });
});

/** 카테고리 추가 (방장·부방장). type: common | expense | income */
categories.post('/', requireMember(BUDGET, MANAGERS), async (c) => {
  const body = await readJson(c);
  const type = oneOf(body.type, CATEGORY_TYPES, 'type');
  const name = reqStr(body, 'name', { min: 1, max: 10 });
  const { ledger, member } = c.var;
  const db = c.env.DB;

  await assertNameFree(db, ledger.id, type, name);
  const max = await db.prepare(
    'SELECT COALESCE(MAX(sort_order), -1) AS m FROM categories WHERE ledger_id = ? AND type = ? AND deleted_at IS NULL',
  )
    .bind(ledger.id, type)
    .first<{ m: number }>();

  const id = newId();
  const sortOrder = (max?.m ?? -1) + 1;
  await db.prepare(
    `INSERT INTO categories (id, ledger_id, type, name, sort_order, created_by_member_id, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
  )
    .bind(id, ledger.id, type, name, sortOrder, member.id, now())
    .run();

  return c.json({ id, type, name, sort_order: sortOrder }, 201);
});

/** 이름·순서 변경 (방장·부방장) */
categories.patch('/:categoryId', requireMember(BUDGET, MANAGERS), async (c) => {
  const body = await readJson(c);
  const db = c.env.DB;
  const category = await findCategory(db, c.var.ledger.id, c.req.param('categoryId'));

  const name = str(body, 'name', { min: 1, max: 10, optional: true });
  const sortOrder = body.sort_order;
  if (sortOrder !== undefined && (typeof sortOrder !== 'number' || !Number.isInteger(sortOrder) || sortOrder < 0)) {
    throw badRequest('invalid_field', 'sort_order 값은 0 이상의 정수여야 해요.');
  }
  if (name !== undefined) await assertNameFree(db, category.ledger_id, category.type, name, category.id);

  const next = { name: name ?? category.name, sort_order: (sortOrder as number | undefined) ?? category.sort_order };
  await db.prepare('UPDATE categories SET name = ?, sort_order = ? WHERE id = ?')
    .bind(next.name, next.sort_order, category.id)
    .run();
  return c.json({ id: category.id, type: category.type, ...next });
});

/** 삭제 (방장·부방장). 기존 내역은 미분류로 남는다 */
categories.delete('/:categoryId', requireMember(BUDGET, MANAGERS), async (c) => {
  const db = c.env.DB;
  const category = await findCategory(db, c.var.ledger.id, c.req.param('categoryId'));
  const ts = now();
  await db.batch([
    db.prepare('UPDATE categories SET deleted_at = ? WHERE id = ?').bind(ts, category.id),
    db
      .prepare('UPDATE transactions SET category_id = NULL, updated_at = ? WHERE category_id = ?')
      .bind(ts, category.id),
  ]);
  return c.json({ ok: true });
});
