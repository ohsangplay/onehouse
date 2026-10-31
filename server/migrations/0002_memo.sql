-- 한지붕 메모: 가계부와 같은 공간·멤버 테이블을 쓰고, 종류(kind)로 나눈다.
-- 기존 가계부는 모두 budget 으로 남는다.
ALTER TABLE ledgers ADD COLUMN kind TEXT NOT NULL DEFAULT 'budget' CHECK (kind IN ('budget', 'memo'));

-- 메모. kind: text(글 메모) | checklist(체크리스트)
-- version: 제목·본문을 저장할 때마다 1씩 오른다. 고치기 시작한 버전과 다르면 병합하거나 충돌로 돌려준다.
-- updated_at: 내용이 바뀐 시각 (체크리스트 항목 변경 포함)
CREATE TABLE memos (
  id                   TEXT PRIMARY KEY,
  ledger_id            TEXT NOT NULL REFERENCES ledgers(id),
  kind                 TEXT NOT NULL CHECK (kind IN ('text', 'checklist')),
  title                TEXT NOT NULL DEFAULT '',
  body                 TEXT NOT NULL DEFAULT '',
  version              INTEGER NOT NULL DEFAULT 1,
  pinned               INTEGER NOT NULL DEFAULT 0,
  created_by_member_id TEXT NOT NULL,
  updated_by_member_id TEXT NOT NULL,
  created_at           TEXT NOT NULL,
  updated_at           TEXT NOT NULL,
  deleted_at           TEXT,
  deleted_by_member_id TEXT
);
CREATE INDEX idx_memos_ledger ON memos(ledger_id, deleted_at, updated_at);

-- 버전별 제목·본문. 3방향 병합의 원본으로 쓰고, 메모마다 최근 50개만 남긴다.
CREATE TABLE memo_revisions (
  memo_id    TEXT NOT NULL REFERENCES memos(id),
  version    INTEGER NOT NULL,
  title      TEXT NOT NULL,
  body       TEXT NOT NULL,
  member_id  TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (memo_id, version)
);

-- 체크리스트 항목은 한 줄씩 따로 저장해서 서로 다른 항목을 동시에 고쳐도 부딪히지 않는다.
-- 체크 표시는 마지막 저장이 이기고(version 그대로), 글자를 고칠 때만 version을 비교한다.
CREATE TABLE memo_items (
  id                   TEXT PRIMARY KEY,
  memo_id              TEXT NOT NULL REFERENCES memos(id),
  text                 TEXT NOT NULL,
  checked              INTEGER NOT NULL DEFAULT 0,
  sort_order           INTEGER NOT NULL DEFAULT 0,
  version              INTEGER NOT NULL DEFAULT 1,
  created_by_member_id TEXT NOT NULL,
  updated_by_member_id TEXT NOT NULL,
  checked_by_member_id TEXT,
  created_at           TEXT NOT NULL,
  updated_at           TEXT NOT NULL,
  deleted_at           TEXT
);
CREATE INDEX idx_items_memo ON memo_items(memo_id, deleted_at, sort_order);

-- "지금 ○○님이 보고 있어요": 메모를 연 동안 앱이 주기적으로 갱신한다
CREATE TABLE memo_presence (
  memo_id   TEXT NOT NULL,
  member_id TEXT NOT NULL,
  editing   INTEGER NOT NULL DEFAULT 0,
  seen_at   TEXT NOT NULL,
  PRIMARY KEY (memo_id, member_id)
);
