import type { SpaceKind } from './types';
import { newId } from './lib/crypto';
import { josa } from './lib/josa';

/**
 * 한지붕 시리즈의 공간 종류별 설정.
 * 초대코드·승인·부방장·차단·복구코드·기기 이전은 모든 종류가 같은 코드를 쓰고, 종류마다 다른 부분만 여기에 둔다.
 */
export type KindConfig = {
  kind: SpaceKind;
  /** 화면·오류 문구에 쓰는 이름 */
  noun: string;
  /** 목록 응답의 키 (GET /ledgers → {ledgers}, GET /notebooks → {notebooks}) */
  listKey: string;
  /** 목록 항목에 붙일 종류별 값. sql은 SELECT 절에 붙고 ?2부터 binds를 쓴다 */
  listExtra: () => { sql: string; binds: unknown[]; pick: (row: Record<string, unknown>) => Record<string, unknown> };
  /** 공간을 만들 때 함께 넣을 기본 데이터 */
  onCreate: (db: D1Database, spaceId: string, ts: string) => D1PreparedStatement[];
  /** 복구코드로 방장을 가져올 때: 이 기기가 다른 멤버로 있었다면 그 기록을 방장 쪽으로 합친다 */
  mergeMember: (db: D1Database, fromMemberId: string, toMemberId: string) => D1PreparedStatement[];
  /** 멤버 상세 화면의 통계 */
  memberStats: (db: D1Database, memberId: string) => Promise<Record<string, unknown>>;
};

/** 한국 시간 기준 이번 달 (YYYY-MM) */
export function currentMonthKst(): string {
  return new Date(Date.now() + 9 * 3600_000).toISOString().slice(0, 7);
}

function nextMonth(month: string): string {
  const [y, m] = month.split('-').map(Number);
  return m === 12 ? `${y + 1}-01` : `${y}-${String(m + 1).padStart(2, '0')}`;
}

const DEFAULT_CATEGORIES = ['식비', '생활', '교통', '주거', '의료', '교육', '경조사', '급여', '기타'];

export const BUDGET: KindConfig = {
  kind: 'budget',
  noun: '가계부',
  listKey: 'ledgers',
  listExtra: () => {
    const month = currentMonthKst();
    return {
      sql: `(SELECT COALESCE(SUM(t.amount), 0) FROM transactions t
          WHERE t.ledger_id = l.id AND t.type = 'expense' AND t.deleted_at IS NULL
            AND t.spent_at >= ?2 AND t.spent_at < ?3) AS month_expense`,
      binds: [`${month}-01`, `${nextMonth(month)}-01`],
      pick: (row) => ({ month, month_expense: row.month_expense }),
    };
  },
  onCreate: (db, spaceId, ts) =>
    DEFAULT_CATEGORIES.map((cat, i) =>
      db
        .prepare(
          `INSERT INTO categories (id, ledger_id, type, name, sort_order, created_at)
           VALUES (?, ?, 'common', ?, ?, ?)`,
        )
        .bind(newId(), spaceId, cat, i, ts),
    ),
  mergeMember: (db, from, to) => [
    db.prepare('UPDATE transactions SET member_id = ? WHERE member_id = ?').bind(to, from),
  ],
  memberStats: async (db, memberId) => {
    const month = currentMonthKst();
    const stats = await db
      .prepare(
        `SELECT COUNT(*) AS count,
           COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS expense
         FROM transactions
         WHERE member_id = ? AND deleted_at IS NULL AND substr(spent_at, 1, 7) = ?`,
      )
      .bind(memberId, month)
      .first<{ count: number; expense: number }>();
    return { month, month_count: stats?.count ?? 0, month_expense: stats?.expense ?? 0 };
  },
};

export const MEMO: KindConfig = {
  kind: 'memo',
  noun: '메모집',
  listKey: 'notebooks',
  listExtra: () => ({
    sql: `(SELECT COUNT(*) FROM memos x WHERE x.ledger_id = l.id AND x.deleted_at IS NULL) AS memo_count,
       (SELECT MAX(x.updated_at) FROM memos x WHERE x.ledger_id = l.id AND x.deleted_at IS NULL) AS last_updated_at`,
    binds: [],
    pick: (row) => ({ memo_count: row.memo_count, last_updated_at: row.last_updated_at }),
  }),
  onCreate: () => [],
  mergeMember: (db, from, to) => [
    db.prepare('UPDATE memos SET created_by_member_id = ? WHERE created_by_member_id = ?').bind(to, from),
    db.prepare('UPDATE memos SET updated_by_member_id = ? WHERE updated_by_member_id = ?').bind(to, from),
    db.prepare('UPDATE memos SET deleted_by_member_id = ? WHERE deleted_by_member_id = ?').bind(to, from),
    db.prepare('UPDATE memo_revisions SET member_id = ? WHERE member_id = ?').bind(to, from),
    db.prepare('UPDATE memo_items SET created_by_member_id = ? WHERE created_by_member_id = ?').bind(to, from),
    db.prepare('UPDATE memo_items SET updated_by_member_id = ? WHERE updated_by_member_id = ?').bind(to, from),
    db.prepare('UPDATE memo_items SET checked_by_member_id = ? WHERE checked_by_member_id = ?').bind(to, from),
    db.prepare('DELETE FROM memo_presence WHERE member_id = ?').bind(from),
  ],
  memberStats: async (db, memberId) => {
    const stats = await db
      .prepare(
        `SELECT
           (SELECT COUNT(*) FROM memos WHERE created_by_member_id = ?1 AND deleted_at IS NULL) AS created,
           (SELECT COUNT(*) FROM memo_revisions WHERE member_id = ?1) AS edits`,
      )
      .bind(memberId)
      .first<{ created: number; edits: number }>();
    return { memo_count: stats?.created ?? 0, edit_count: stats?.edits ?? 0 };
  },
};

/** "가계부를" / "메모집을" */
export const obj = (k: KindConfig) => josa(k.noun, '을', '를');
/** "가계부에" / "메모집에" */
export const at = (k: KindConfig) => `${k.noun}에`;
/** "가계부가" / "메모집이" */
export const subj = (k: KindConfig) => josa(k.noun, '이', '가');
