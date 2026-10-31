import { Hono } from 'hono';
import type { Context } from 'hono';
import type { AppEnv, MemberRow } from '../types';
import { newId } from '../lib/crypto';
import { ApiError, badRequest, conflict, forbidden, notFound, now, oneOf, readJson } from '../lib/http';
import { merge3, mergeValue } from '../lib/merge';
import { MANAGERS, requireDevice, requireMember } from '../middleware/auth';
import { MEMO } from '../kinds';

const MEMO_KINDS = ['text', 'checklist'] as const;
const MAX_TITLE = 100;
const MAX_BODY = 20_000;
const MAX_ITEM = 200;
const MAX_ITEMS = 300;
const MAX_MEMOS = 1_000;
const KEEP_REVISIONS = 50;
const TRASH_DAYS = 30;
/** 이 시간 안에 신호를 보낸 사람만 "보고 있어요"로 표시 */
const PRESENCE_SECONDS = 30;

type MemoRow = {
  id: string;
  ledger_id: string;
  kind: 'text' | 'checklist';
  title: string;
  body: string;
  version: number;
  pinned: number;
  created_by_member_id: string;
  updated_by_member_id: string;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
  deleted_by_member_id: string | null;
  created_by_nickname: string | null;
  updated_by_nickname: string | null;
};

type ItemRow = {
  id: string;
  memo_id: string;
  text: string;
  checked: number;
  sort_order: number;
  version: number;
  updated_at: string;
  updated_by_member_id: string;
  updated_by_nickname: string | null;
  checked_by_nickname: string | null;
};

const SELECT_MEMO = `
  SELECT x.*, cb.nickname AS created_by_nickname, ub.nickname AS updated_by_nickname
  FROM memos x
  LEFT JOIN ledger_members cb ON cb.id = x.created_by_member_id
  LEFT JOIN ledger_members ub ON ub.id = x.updated_by_member_id`;

const SELECT_ITEM = `
  SELECT i.*, ub.nickname AS updated_by_nickname, kb.nickname AS checked_by_nickname
  FROM memo_items i
  LEFT JOIN ledger_members ub ON ub.id = i.updated_by_member_id
  LEFT JOIN ledger_members kb ON kb.id = i.checked_by_member_id`;

function memoJson(m: MemoRow) {
  return {
    id: m.id,
    kind: m.kind,
    title: m.title,
    body: m.kind === 'text' ? m.body : '',
    version: m.version,
    pinned: m.pinned === 1,
    created_by: { id: m.created_by_member_id, nickname: m.created_by_nickname },
    updated_by: { id: m.updated_by_member_id, nickname: m.updated_by_nickname },
    created_at: m.created_at,
    updated_at: m.updated_at,
    deleted_at: m.deleted_at,
  };
}

function itemJson(i: ItemRow) {
  return {
    id: i.id,
    text: i.text,
    checked: i.checked === 1,
    sort_order: i.sort_order,
    version: i.version,
    updated_at: i.updated_at,
    updated_by: { id: i.updated_by_member_id, nickname: i.updated_by_nickname },
    checked_by: i.checked_by_nickname,
  };
}

/** 메모 본문·제목은 앞뒤 공백을 그대로 둔다 (줄 단위 병합에 필요). 제목만 앞뒤를 자른다 */
function text(body: Record<string, unknown>, key: string, max: number, opts: { trim?: boolean } = {}) {
  const value = body[key];
  if (value === undefined || value === null) return undefined;
  if (typeof value !== 'string') throw badRequest('invalid_field', `${key} 값은 문자열이어야 해요.`);
  const v = (opts.trim ? value.trim() : value).replace(/\r\n?/g, '\n');
  if (v.length > max) throw badRequest('invalid_field', `${key} 값은 ${max}자 이하여야 해요.`);
  return v;
}

function itemText(body: Record<string, unknown>): string {
  const v = text(body, 'text', MAX_ITEM, { trim: true });
  if (v === undefined) throw badRequest('missing_field', 'text 값이 필요해요.');
  if (v.includes('\n')) throw badRequest('invalid_field', '항목은 한 줄로 써 주세요.');
  return v;
}

function positiveInt(value: unknown, key: string): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 1) {
    throw badRequest('invalid_field', `${key} 값은 1 이상의 정수여야 해요.`);
  }
  return value;
}

async function loadMemo(c: Context<AppEnv>, opts: { allowDeleted?: boolean } = {}): Promise<MemoRow> {
  const memo = await c.env.DB.prepare(`${SELECT_MEMO} WHERE x.id = ? AND x.ledger_id = ?`)
    .bind(c.req.param('memoId'), c.var.ledger.id)
    .first<MemoRow>();
  if (!memo) throw notFound('memo_not_found', '메모를 찾을 수 없어요.');
  if (memo.deleted_at && !opts.allowDeleted) {
    throw notFound('memo_deleted', '다른 멤버가 이 메모를 지웠어요.');
  }
  return memo;
}

async function loadItems(db: D1Database, memoId: string): Promise<ItemRow[]> {
  const { results } = await db.prepare(
    `${SELECT_ITEM} WHERE i.memo_id = ? AND i.deleted_at IS NULL ORDER BY i.sort_order, i.created_at`,
  )
    .bind(memoId)
    .all<ItemRow>();
  return results;
}

async function fullMemo(db: D1Database, memo: MemoRow) {
  const json = memoJson(memo);
  if (memo.kind !== 'checklist') return json;
  return { ...json, items: (await loadItems(db, memo.id)).map(itemJson) };
}

async function viewers(db: D1Database, memoId: string, me: MemberRow) {
  const since = new Date(Date.now() - PRESENCE_SECONDS * 1000).toISOString();
  const { results } = await db.prepare(
    `SELECT p.member_id, m.nickname, p.editing
     FROM memo_presence p JOIN ledger_members m ON m.id = p.member_id
     WHERE p.memo_id = ? AND p.seen_at > ? AND p.member_id != ? AND m.status = 'approved'
     ORDER BY p.seen_at DESC`,
  )
    .bind(memoId, since, me.id)
    .all<{ member_id: string; nickname: string; editing: number }>();
  return results.map((r) => ({ member_id: r.member_id, nickname: r.nickname, editing: r.editing === 1 }));
}

/** 체크리스트 항목이 바뀌면 메모의 "마지막 수정"도 바꾼다 (버전은 그대로) */
const touchMemo = (db: D1Database, memoId: string, memberId: string, ts: string) =>
  db.prepare('UPDATE memos SET updated_at = ?, updated_by_member_id = ? WHERE id = ?').bind(ts, memberId, memoId);

const canDelete = (memo: MemoRow, me: MemberRow) => memo.created_by_member_id === me.id || MANAGERS.includes(me.role);

// /notebooks/:ledgerId/memos
export const memos = new Hono<AppEnv>();

memos.use('*', requireDevice, requireMember(MEMO));

/** 메모 목록: 고정한 메모 먼저, 그다음 최근에 바뀐 순 */
memos.get('/', async (c) => {
  const { results } = await c.env.DB.prepare(
    `SELECT x.id, x.kind, x.title, substr(x.body, 1, 200) AS preview, x.version, x.pinned,
       x.created_by_member_id, cb.nickname AS created_by_nickname,
       x.updated_by_member_id, ub.nickname AS updated_by_nickname,
       x.created_at, x.updated_at,
       (SELECT COUNT(*) FROM memo_items i WHERE i.memo_id = x.id AND i.deleted_at IS NULL) AS item_count,
       (SELECT COUNT(*) FROM memo_items i WHERE i.memo_id = x.id AND i.deleted_at IS NULL AND i.checked = 1) AS checked_count,
       (SELECT group_concat(t.text, char(10)) FROM (
          SELECT i.text FROM memo_items i WHERE i.memo_id = x.id AND i.deleted_at IS NULL
          ORDER BY i.checked, i.sort_order LIMIT 3) t) AS item_preview
     FROM memos x
     LEFT JOIN ledger_members cb ON cb.id = x.created_by_member_id
     LEFT JOIN ledger_members ub ON ub.id = x.updated_by_member_id
     WHERE x.ledger_id = ? AND x.deleted_at IS NULL
     ORDER BY x.pinned DESC, x.updated_at DESC
     LIMIT ${MAX_MEMOS}`,
  )
    .bind(c.var.ledger.id)
    .all<Record<string, unknown>>();

  return c.json({
    memos: results.map((r) => ({
      id: r.id,
      kind: r.kind,
      title: r.title,
      preview: r.kind === 'checklist' ? (r.item_preview ?? '') : r.preview,
      version: r.version,
      pinned: r.pinned === 1,
      item_count: r.item_count,
      checked_count: r.checked_count,
      created_by: { id: r.created_by_member_id, nickname: r.created_by_nickname },
      updated_by: { id: r.updated_by_member_id, nickname: r.updated_by_nickname },
      created_at: r.created_at,
      updated_at: r.updated_at,
    })),
  });
});

/** 휴지통: 지운 지 30일 안 된 메모 */
memos.get('/trash', async (c) => {
  const since = new Date(Date.now() - TRASH_DAYS * 86_400_000).toISOString();
  const { results } = await c.env.DB.prepare(
    `SELECT x.id, x.kind, x.title, substr(x.body, 1, 200) AS preview, x.created_by_member_id,
       x.deleted_at, dm.nickname AS deleted_by_nickname
     FROM memos x
     LEFT JOIN ledger_members dm ON dm.id = x.deleted_by_member_id
     WHERE x.ledger_id = ? AND x.deleted_at IS NOT NULL AND x.deleted_at > ?
     ORDER BY x.deleted_at DESC`,
  )
    .bind(c.var.ledger.id, since)
    .all<Record<string, unknown>>();
  const me = c.var.member;
  return c.json({
    trash_days: TRASH_DAYS,
    memos: results.map((r) => ({
      id: r.id,
      kind: r.kind,
      title: r.title,
      preview: r.preview,
      deleted_at: r.deleted_at,
      deleted_by: r.deleted_by_nickname,
      can_restore: r.created_by_member_id === me.id || MANAGERS.includes(me.role),
    })),
  });
});

/** 새 메모. 체크리스트는 items(문자열 배열)로 첫 항목들을 함께 만들 수 있다 */
memos.post('/', async (c) => {
  const body = await readJson(c);
  const kind = oneOf(body.kind, MEMO_KINDS, 'kind');
  const title = text(body, 'title', MAX_TITLE, { trim: true }) ?? '';
  const memoBody = kind === 'text' ? (text(body, 'body', MAX_BODY) ?? '') : '';
  const rawItems = body.items ?? [];
  if (!Array.isArray(rawItems)) throw badRequest('invalid_field', 'items 값은 배열이어야 해요.');
  if (rawItems.length > MAX_ITEMS) throw badRequest('invalid_field', `항목은 ${MAX_ITEMS}개까지 넣을 수 있어요.`);
  const items = kind === 'checklist' ? rawItems.map((v) => itemText({ text: v })).filter(Boolean) : [];

  const { ledger, member } = c.var;
  const db = c.env.DB;
  const count = await db.prepare('SELECT COUNT(*) AS n FROM memos WHERE ledger_id = ? AND deleted_at IS NULL')
    .bind(ledger.id)
    .first<{ n: number }>();
  if ((count?.n ?? 0) >= MAX_MEMOS) throw conflict('memo_limit', `메모집 하나에 메모는 ${MAX_MEMOS}개까지 쓸 수 있어요.`);

  const id = newId();
  const ts = now();
  await db.batch([
    db
      .prepare(
        `INSERT INTO memos (id, ledger_id, kind, title, body, version, created_by_member_id, updated_by_member_id, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?, ?)`,
      )
      .bind(id, ledger.id, kind, title, memoBody, member.id, member.id, ts, ts),
    db
      .prepare('INSERT INTO memo_revisions (memo_id, version, title, body, member_id, created_at) VALUES (?, 1, ?, ?, ?, ?)')
      .bind(id, title, memoBody, member.id, ts),
    ...items.map((t, i) =>
      db
        .prepare(
          `INSERT INTO memo_items (id, memo_id, text, sort_order, created_by_member_id, updated_by_member_id, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        )
        .bind(newId(), id, t, i, member.id, member.id, ts, ts),
    ),
  ]);

  const memo = await db.prepare(`${SELECT_MEMO} WHERE x.id = ?`).bind(id).first<MemoRow>();
  return c.json(await fullMemo(db, memo!), 201);
});

/** 메모 하나 (체크리스트면 항목 포함, 지금 보고 있는 사람 포함) */
memos.get('/:memoId', async (c) => {
  const memo = await loadMemo(c);
  return c.json({ ...(await fullMemo(c.env.DB, memo)), viewers: await viewers(c.env.DB, memo.id, c.var.member) });
});

/**
 * 제목·본문 저장. base_version은 내가 고치기 시작한 버전.
 * - 그사이 아무도 안 고쳤으면 그대로 저장
 * - 누가 먼저 고쳤으면 원본(base_version)과 비교해 서로 다른 줄은 합쳐서 저장하고 merged: true
 * - 같은 줄(제목은 통째로)을 서로 다르게 고쳤으면 409 edit_conflict + 지금 저장된 메모(current)
 */
memos.patch('/:memoId', async (c) => {
  const body = await readJson(c);
  const baseVersion = positiveInt(body.base_version, 'base_version');
  const newTitle = text(body, 'title', MAX_TITLE, { trim: true });
  const newBody = text(body, 'body', MAX_BODY);
  const { member } = c.var;
  const db = c.env.DB;

  for (let attempt = 0; attempt < 3; attempt++) {
    const cur = await loadMemo(c);
    if (baseVersion > cur.version) throw badRequest('invalid_field', 'base_version 값이 올바르지 않아요.');
    const mineBody = cur.kind === 'text' ? newBody : undefined;

    let next: { title: string; body: string };
    let mine: { title: string; body: string };
    if (cur.version === baseVersion) {
      next = { title: newTitle ?? cur.title, body: mineBody ?? cur.body };
      mine = next;
    } else {
      const base = await db.prepare('SELECT title, body FROM memo_revisions WHERE memo_id = ? AND version = ?')
        .bind(cur.id, baseVersion)
        .first<{ title: string; body: string }>();
      mine = { title: newTitle ?? base?.title ?? cur.title, body: mineBody ?? base?.body ?? cur.body };
      const title = base ? mergeValue(base.title, mine.title, cur.title) : { ok: false as const };
      const merged = base ? merge3(base.body, mine.body, cur.body) : { ok: false as const };
      if (!title.ok || !merged.ok) {
        throw new ApiError(409, 'edit_conflict', '다른 멤버가 먼저 고쳤어요.', {
          current: await fullMemo(db, cur),
        });
      }
      next = { title: title.text, body: merged.text };
    }

    const merged = next.title !== mine.title || next.body !== mine.body;
    // 바뀐 게 없으면 버전을 올리지 않는다 (자동 저장이 같은 내용을 다시 보내도 괜찮게)
    if (next.title === cur.title && next.body === cur.body) {
      return c.json({ memo: await fullMemo(db, cur), merged });
    }

    const ts = now();
    const version = cur.version + 1;
    try {
      const [res] = await db.batch([
        db
          .prepare(
            `UPDATE memos SET title = ?, body = ?, version = ?, updated_by_member_id = ?, updated_at = ?
             WHERE id = ? AND version = ? AND deleted_at IS NULL`,
          )
          .bind(next.title, next.body, version, member.id, ts, cur.id, cur.version),
        // 다른 요청이 같은 버전을 먼저 저장했으면 기본키가 겹쳐서 전체가 취소된다 → 다시 읽고 병합
        db
          .prepare('INSERT INTO memo_revisions (memo_id, version, title, body, member_id, created_at) VALUES (?, ?, ?, ?, ?, ?)')
          .bind(cur.id, version, next.title, next.body, member.id, ts),
        db.prepare('DELETE FROM memo_revisions WHERE memo_id = ? AND version <= ?').bind(cur.id, version - KEEP_REVISIONS),
      ]);
      if (!res.meta.changes) continue;
    } catch {
      continue;
    }
    const saved = await loadMemo(c);
    return c.json({ memo: await fullMemo(db, saved), merged });
  }
  throw conflict('busy', '여러 명이 동시에 저장하고 있어요. 잠시 후 다시 시도해 주세요.');
});

/** 고정·해제 (누구나) */
memos.patch('/:memoId/pin', async (c) => {
  const body = await readJson(c);
  if (typeof body.pinned !== 'boolean') throw badRequest('invalid_field', 'pinned 값은 true 또는 false여야 해요.');
  const memo = await loadMemo(c);
  await c.env.DB.prepare('UPDATE memos SET pinned = ? WHERE id = ?').bind(body.pinned ? 1 : 0, memo.id).run();
  return c.json({ id: memo.id, pinned: body.pinned });
});

/** 삭제 → 휴지통 (쓴 사람, 방장·부방장) */
memos.delete('/:memoId', async (c) => {
  const memo = await loadMemo(c);
  if (!canDelete(memo, c.var.member)) {
    throw forbidden('no_permission', '메모는 쓴 사람과 방장·부방장만 지울 수 있어요.');
  }
  const ts = now();
  await c.env.DB.batch([
    c.env.DB.prepare('UPDATE memos SET deleted_at = ?, deleted_by_member_id = ? WHERE id = ?').bind(
      ts,
      c.var.member.id,
      memo.id,
    ),
    c.env.DB.prepare('DELETE FROM memo_presence WHERE memo_id = ?').bind(memo.id),
  ]);
  return c.json({ ok: true, trash_days: TRASH_DAYS });
});

/** 휴지통에서 되살리기 (쓴 사람, 방장·부방장) */
memos.post('/:memoId/restore', async (c) => {
  const memo = await loadMemo(c, { allowDeleted: true });
  if (!memo.deleted_at) return c.json(await fullMemo(c.env.DB, memo));
  if (Date.parse(memo.deleted_at) < Date.now() - TRASH_DAYS * 86_400_000) {
    throw notFound('memo_not_found', '휴지통에서 지워진 메모예요.');
  }
  if (!canDelete(memo, c.var.member)) {
    throw forbidden('no_permission', '메모는 쓴 사람과 방장·부방장만 되살릴 수 있어요.');
  }
  await c.env.DB.prepare('UPDATE memos SET deleted_at = NULL, deleted_by_member_id = NULL WHERE id = ?')
    .bind(memo.id)
    .run();
  return c.json(await fullMemo(c.env.DB, await loadMemo(c)));
});

/**
 * "보고 있어요" 신호. 메모를 연 동안 앱이 15초마다 보낸다.
 * 지금 버전·수정 시각을 함께 돌려줘서, 고치지 않고 보고만 있을 때 새 내용을 다시 불러올지 판단한다.
 */
memos.post('/:memoId/presence', async (c) => {
  const body = await readJson(c).catch(() => ({}) as Record<string, unknown>);
  const editing = body.editing === true ? 1 : 0;
  const memo = await loadMemo(c);
  const { member } = c.var;
  const ts = now();
  await c.env.DB.batch([
    c.env.DB.prepare(
      `INSERT INTO memo_presence (memo_id, member_id, editing, seen_at) VALUES (?, ?, ?, ?)
       ON CONFLICT(memo_id, member_id) DO UPDATE SET editing = excluded.editing, seen_at = excluded.seen_at`,
    ).bind(memo.id, member.id, editing, ts),
    c.env.DB.prepare('DELETE FROM memo_presence WHERE memo_id = ? AND seen_at < ?').bind(
      memo.id,
      new Date(Date.now() - 600_000).toISOString(),
    ),
  ]);
  return c.json({
    version: memo.version,
    updated_at: memo.updated_at,
    viewers: await viewers(c.env.DB, memo.id, member),
  });
});

memos.delete('/:memoId/presence', async (c) => {
  await c.env.DB.prepare('DELETE FROM memo_presence WHERE memo_id = ? AND member_id = ?')
    .bind(c.req.param('memoId'), c.var.member.id)
    .run();
  return c.json({ ok: true });
});

// ── 체크리스트 항목 ─────────────────────────────────────

async function loadChecklist(c: Context<AppEnv>): Promise<MemoRow> {
  const memo = await loadMemo(c);
  if (memo.kind !== 'checklist') throw badRequest('not_checklist', '체크리스트 메모가 아니에요.');
  return memo;
}

async function loadItem(c: Context<AppEnv>, memoId: string): Promise<ItemRow> {
  const item = await c.env.DB.prepare(`${SELECT_ITEM} WHERE i.id = ? AND i.memo_id = ?`)
    .bind(c.req.param('itemId'), memoId)
    .first<ItemRow & { deleted_at: string | null }>();
  if (!item) throw notFound('item_not_found', '항목을 찾을 수 없어요.');
  if (item.deleted_at) throw notFound('item_deleted', '다른 멤버가 이 항목을 지웠어요.');
  return item;
}

async function itemResponse(db: D1Database, itemId: string) {
  return itemJson((await db.prepare(`${SELECT_ITEM} WHERE i.id = ?`).bind(itemId).first<ItemRow>())!);
}

/** 항목 추가 (맨 아래) */
memos.post('/:memoId/items', async (c) => {
  const body = await readJson(c);
  const value = itemText(body);
  if (!value) throw badRequest('missing_field', 'text 값이 필요해요.');
  const memo = await loadChecklist(c);
  const db = c.env.DB;
  const stats = await db.prepare(
    'SELECT COUNT(*) AS n, COALESCE(MAX(sort_order), -1) AS m FROM memo_items WHERE memo_id = ? AND deleted_at IS NULL',
  )
    .bind(memo.id)
    .first<{ n: number; m: number }>();
  if ((stats?.n ?? 0) >= MAX_ITEMS) throw conflict('item_limit', `항목은 ${MAX_ITEMS}개까지 넣을 수 있어요.`);

  const id = newId();
  const ts = now();
  const me = c.var.member.id;
  await db.batch([
    db
      .prepare(
        `INSERT INTO memo_items (id, memo_id, text, sort_order, created_by_member_id, updated_by_member_id, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(id, memo.id, value, (stats?.m ?? -1) + 1, me, me, ts, ts),
    touchMemo(db, memo.id, me, ts),
  ]);
  return c.json(await itemResponse(db, id), 201);
});

/**
 * 항목 글자 수정. base_version이 다르면(누가 먼저 고쳤으면) 409 item_conflict + 지금 항목(current).
 * 같은 글자로 고쳤으면 충돌로 보지 않는다.
 */
memos.patch('/:memoId/items/:itemId', async (c) => {
  const body = await readJson(c);
  const baseVersion = positiveInt(body.base_version, 'base_version');
  const value = itemText(body);
  if (!value) throw badRequest('missing_field', 'text 값이 필요해요.');
  const memo = await loadChecklist(c);
  const item = await loadItem(c, memo.id);
  const db = c.env.DB;

  if (item.text === value) return c.json(itemJson(item));
  if (item.version !== baseVersion) {
    throw new ApiError(409, 'item_conflict', '다른 멤버가 이 항목을 먼저 고쳤어요.', { current: itemJson(item) });
  }
  const ts = now();
  const me = c.var.member.id;
  const [res] = await db.batch([
    db
      .prepare(
        'UPDATE memo_items SET text = ?, version = version + 1, updated_by_member_id = ?, updated_at = ? WHERE id = ? AND version = ?',
      )
      .bind(value, me, ts, item.id, item.version),
    touchMemo(db, memo.id, me, ts),
  ]);
  if (!res.meta.changes) {
    throw new ApiError(409, 'item_conflict', '다른 멤버가 이 항목을 먼저 고쳤어요.', {
      current: await itemResponse(db, item.id),
    });
  }
  return c.json(await itemResponse(db, item.id));
});

/** 체크·해제. 충돌을 따지지 않고 마지막 요청이 이긴다 (오프라인에서 모아 둔 체크도 이 API로 보낸다) */
memos.post('/:memoId/items/:itemId/check', async (c) => {
  const body = await readJson(c);
  if (typeof body.checked !== 'boolean') throw badRequest('invalid_field', 'checked 값은 true 또는 false여야 해요.');
  const memo = await loadChecklist(c);
  const item = await loadItem(c, memo.id);
  const db = c.env.DB;
  const ts = now();
  const me = c.var.member.id;
  if ((item.checked === 1) !== body.checked) {
    await db.batch([
      db
        .prepare('UPDATE memo_items SET checked = ?, checked_by_member_id = ?, updated_at = ? WHERE id = ?')
        .bind(body.checked ? 1 : 0, body.checked ? me : null, ts, item.id),
      touchMemo(db, memo.id, me, ts),
    ]);
  }
  return c.json(await itemResponse(db, item.id));
});

memos.delete('/:memoId/items/:itemId', async (c) => {
  const memo = await loadChecklist(c);
  const db = c.env.DB;
  const ts = now();
  const me = c.var.member.id;
  const [res] = await db.batch([
    db
      .prepare('UPDATE memo_items SET deleted_at = ?, updated_at = ? WHERE id = ? AND memo_id = ? AND deleted_at IS NULL')
      .bind(ts, ts, c.req.param('itemId'), memo.id),
    touchMemo(db, memo.id, me, ts),
  ]);
  if (!res.meta.changes) throw notFound('item_not_found', '항목을 찾을 수 없어요.');
  return c.json({ ok: true });
});

/** 체크한 항목 한꺼번에 지우기 */
memos.post('/:memoId/items/clear-checked', async (c) => {
  const memo = await loadChecklist(c);
  const db = c.env.DB;
  const ts = now();
  const [res] = await db.batch([
    db
      .prepare('UPDATE memo_items SET deleted_at = ?, updated_at = ? WHERE memo_id = ? AND checked = 1 AND deleted_at IS NULL')
      .bind(ts, ts, memo.id),
    touchMemo(db, memo.id, c.var.member.id, ts),
  ]);
  return c.json({ removed: res.meta.changes ?? 0 });
});

/** 순서 바꾸기: ids 순서대로 정렬. 목록에 없는 항목(그사이 다른 사람이 추가한 것)은 뒤에 남는다 */
memos.put('/:memoId/items/order', async (c) => {
  const body = await readJson(c);
  const ids = body.ids;
  if (!Array.isArray(ids) || ids.length > MAX_ITEMS || !ids.every((v) => typeof v === 'string')) {
    throw badRequest('invalid_field', 'ids 값은 항목 ID 배열이어야 해요.');
  }
  const memo = await loadChecklist(c);
  const db = c.env.DB;
  const ts = now();
  await db.batch([
    // 새 순서에 없는 항목은 맨 뒤로
    db
      .prepare('UPDATE memo_items SET sort_order = sort_order + ? WHERE memo_id = ? AND deleted_at IS NULL')
      .bind(MAX_ITEMS * 2, memo.id),
    ...ids.map((id, i) =>
      db.prepare('UPDATE memo_items SET sort_order = ? WHERE id = ? AND memo_id = ?').bind(i, id, memo.id),
    ),
    touchMemo(db, memo.id, c.var.member.id, ts),
  ]);
  return c.json({ items: (await loadItems(db, memo.id)).map(itemJson) });
});
