/**
 * 하루 한 번 (wrangler.toml [triggers]) 지운 지 30일 지난 데이터를 완전히 지운다.
 * - 휴지통의 메모 (항목·버전 기록·보는 중 기록 포함), 지운 가계부 내역
 * - 삭제한 가계부·메모집과 그 안의 모든 내용·멤버·관리 이력
 * - 오래된 "보는 중" 기록, 시도 횟수 기록
 */
export const PURGE_DAYS = 30;

export async function purge(db: D1Database, now = Date.now()): Promise<Record<string, number>> {
  const cutoff = new Date(now - PURGE_DAYS * 86_400_000).toISOString();
  const deletedMemos = 'SELECT id FROM memos WHERE deleted_at IS NOT NULL AND deleted_at < ?1';
  const deletedSpaces = 'SELECT id FROM ledgers WHERE deleted_at IS NOT NULL AND deleted_at < ?1';
  const spaceMemos = `SELECT id FROM memos WHERE ledger_id IN (${deletedSpaces})`;

  const steps: [string, D1PreparedStatement][] = [
    ['memo_items', db.prepare(`DELETE FROM memo_items WHERE memo_id IN (${deletedMemos}) OR memo_id IN (${spaceMemos})`).bind(cutoff)],
    ['memo_revisions', db.prepare(`DELETE FROM memo_revisions WHERE memo_id IN (${deletedMemos}) OR memo_id IN (${spaceMemos})`).bind(cutoff)],
    ['memo_presence', db.prepare(`DELETE FROM memo_presence WHERE memo_id IN (${deletedMemos}) OR memo_id IN (${spaceMemos}) OR seen_at < ?2`).bind(cutoff, new Date(now - 86_400_000).toISOString())],
    ['memos', db.prepare(`DELETE FROM memos WHERE deleted_at IS NOT NULL AND deleted_at < ?1 OR ledger_id IN (${deletedSpaces})`).bind(cutoff)],
    ['transactions', db.prepare(`DELETE FROM transactions WHERE deleted_at IS NOT NULL AND deleted_at < ?1 OR ledger_id IN (${deletedSpaces})`).bind(cutoff)],
    ['categories', db.prepare(`DELETE FROM categories WHERE ledger_id IN (${deletedSpaces})`).bind(cutoff)],
    ['ledger_events', db.prepare(`DELETE FROM ledger_events WHERE ledger_id IN (${deletedSpaces})`).bind(cutoff)],
    ['ledger_members', db.prepare(`DELETE FROM ledger_members WHERE ledger_id IN (${deletedSpaces})`).bind(cutoff)],
    ['ledgers', db.prepare('DELETE FROM ledgers WHERE deleted_at IS NOT NULL AND deleted_at < ?1').bind(cutoff)],
    ['device_transfer_codes', db.prepare('DELETE FROM device_transfer_codes WHERE expires_at < ?1').bind(cutoff)],
    ['rate_limits', db.prepare('DELETE FROM rate_limits WHERE window_start < ?1').bind(Math.floor(now / 1000) - 86_400)],
  ];
  const results = await db.batch(steps.map(([, stmt]) => stmt));
  return Object.fromEntries(steps.map(([name], i) => [name, results[i].meta.changes ?? 0]));
}
