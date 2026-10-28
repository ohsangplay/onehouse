-- 한지붕 초기 스키마
-- 코드·키·토큰은 모두 SHA-256 해시로만 저장한다. 초대코드만 다시 보여줘야 해서 평문.

CREATE TABLE devices (
  id               TEXT PRIMARY KEY,
  install_key_hash TEXT NOT NULL UNIQUE,
  token_hash       TEXT NOT NULL UNIQUE,
  created_at       TEXT NOT NULL,
  last_seen_at     TEXT NOT NULL
);

CREATE TABLE device_transfer_codes (
  id         TEXT PRIMARY KEY,
  device_id  TEXT NOT NULL REFERENCES devices(id),
  code_hash  TEXT NOT NULL UNIQUE,
  expires_at TEXT NOT NULL,
  used_at    TEXT
);

CREATE TABLE ledgers (
  id                       TEXT PRIMARY KEY,
  name                     TEXT NOT NULL,
  owner_member_id          TEXT,
  invite_code              TEXT NOT NULL UNIQUE,
  invite_code_updated_at   TEXT NOT NULL,
  recovery_code_hash       TEXT UNIQUE,
  recovery_code_updated_at TEXT,
  created_at               TEXT NOT NULL,
  deleted_at               TEXT
);

CREATE TABLE ledger_members (
  id                   TEXT PRIMARY KEY,
  ledger_id            TEXT NOT NULL REFERENCES ledgers(id),
  device_id            TEXT NOT NULL REFERENCES devices(id),
  nickname             TEXT NOT NULL,
  role                 TEXT NOT NULL DEFAULT 'member'
                       CHECK (role IN ('owner', 'co_owner', 'member')),
  status               TEXT NOT NULL DEFAULT 'pending'
                       CHECK (status IN ('pending', 'approved', 'rejected', 'revoked', 'left')),
  was_revoked          INTEGER NOT NULL DEFAULT 0,
  requested_at         TEXT NOT NULL,
  decided_at           TEXT,
  decided_by_member_id TEXT,
  UNIQUE (ledger_id, device_id)
);
CREATE INDEX idx_members_device ON ledger_members(device_id);
CREATE INDEX idx_members_ledger_status ON ledger_members(ledger_id, status);

-- 관리 이력: approve, reject, link, revoke, role, transfer_owner, recover, invite_code, recovery_code, rename
CREATE TABLE ledger_events (
  id               TEXT PRIMARY KEY,
  ledger_id        TEXT NOT NULL REFERENCES ledgers(id),
  actor_member_id  TEXT,
  type             TEXT NOT NULL,
  target_member_id TEXT,
  created_at       TEXT NOT NULL
);
CREATE INDEX idx_events_ledger ON ledger_events(ledger_id, created_at);

-- type: common(지출·수입 공통) | expense | income
CREATE TABLE categories (
  id                   TEXT PRIMARY KEY,
  ledger_id            TEXT NOT NULL REFERENCES ledgers(id),
  type                 TEXT NOT NULL CHECK (type IN ('common', 'expense', 'income')),
  name                 TEXT NOT NULL,
  sort_order           INTEGER NOT NULL DEFAULT 0,
  created_by_member_id TEXT,
  created_at           TEXT NOT NULL,
  deleted_at           TEXT
);
CREATE INDEX idx_categories_ledger ON categories(ledger_id, type, sort_order);

-- amount: 원 단위 정수, spent_at: YYYY-MM-DD
CREATE TABLE transactions (
  id          TEXT PRIMARY KEY,
  ledger_id   TEXT NOT NULL REFERENCES ledgers(id),
  member_id   TEXT NOT NULL REFERENCES ledger_members(id),
  type        TEXT NOT NULL CHECK (type IN ('income', 'expense')),
  amount      INTEGER NOT NULL CHECK (amount > 0),
  category_id TEXT REFERENCES categories(id),
  memo        TEXT,
  spent_at    TEXT NOT NULL,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL,
  deleted_at  TEXT
);
CREATE INDEX idx_tx_ledger_date ON transactions(ledger_id, spent_at);
CREATE INDEX idx_tx_ledger_updated ON transactions(ledger_id, updated_at);

CREATE TABLE rate_limits (
  key          TEXT PRIMARY KEY,
  count        INTEGER NOT NULL,
  window_start INTEGER NOT NULL
);
