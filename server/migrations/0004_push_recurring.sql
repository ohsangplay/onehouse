-- 푸시 알림 (한지붕 가계부부터): 기기별 FCM 토큰. 한 기기가 토큰을 여러 개 가질 수 있다 (재설치·토큰 갱신)
CREATE TABLE push_tokens (
  token      TEXT PRIMARY KEY,
  device_id  TEXT NOT NULL REFERENCES devices(id),
  platform   TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  updated_at TEXT NOT NULL
);
CREATE INDEX idx_push_tokens_device ON push_tokens(device_id);

-- 가족이 쓴 내역 알림 받기 (공간·멤버별). 참여 요청·승인 알림은 항상 보낸다
ALTER TABLE ledger_members ADD COLUMN notify_records INTEGER NOT NULL DEFAULT 1;

-- 고정 지출·수입(매월)과 할부. 매월 정한 날에 내역(transactions)을 자동으로 만든다 (src/lib/recurring.ts)
--   fixed:       amount = 매월 금액, months = NULL(중지할 때까지)
--   installment: amount = 총 결제 금액, months = 할부 개월 수 (1회차에 나머지 원 단위를 더한다)
CREATE TABLE recurring_rules (
  id          TEXT PRIMARY KEY,
  ledger_id   TEXT NOT NULL REFERENCES ledgers(id),
  member_id   TEXT NOT NULL REFERENCES ledger_members(id),
  kind        TEXT NOT NULL CHECK (kind IN ('fixed', 'installment')),
  type        TEXT NOT NULL CHECK (type IN ('income', 'expense')),
  amount      INTEGER NOT NULL CHECK (amount > 0),
  months      INTEGER CHECK (months IS NULL OR months BETWEEN 2 AND 60),
  category_id TEXT,
  memo        TEXT,
  day         INTEGER NOT NULL CHECK (day BETWEEN 1 AND 31),
  start_date  TEXT NOT NULL,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL,
  deleted_at  TEXT
);
CREATE INDEX idx_recurring_ledger ON recurring_rules(ledger_id, deleted_at);

-- 자동으로 만든 내역: 어느 규칙의 몇 번째(1부터)인지. 같은 회차는 한 번만 만든다
ALTER TABLE transactions ADD COLUMN rule_id TEXT;
ALTER TABLE transactions ADD COLUMN rule_seq INTEGER;
CREATE UNIQUE INDEX idx_tx_rule_seq ON transactions(rule_id, rule_seq) WHERE rule_id IS NOT NULL;
