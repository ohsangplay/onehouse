-- 신고 (App Store 1.2: 사용자 콘텐츠 신고). 같은 공간의 승인된 멤버 누구나 보낼 수 있고, 운영자가 확인한다.
CREATE TABLE reports (
  id                 TEXT PRIMARY KEY,
  ledger_id          TEXT NOT NULL REFERENCES ledgers(id),
  reporter_member_id TEXT NOT NULL,
  target_type        TEXT NOT NULL CHECK (target_type IN ('space', 'member', 'transaction', 'memo')),
  target_id          TEXT,
  target_member_id   TEXT,
  reason             TEXT NOT NULL,
  detail             TEXT,
  created_at         TEXT NOT NULL,
  resolved_at        TEXT
);
CREATE INDEX idx_reports_open ON reports(resolved_at, created_at);
CREATE INDEX idx_reports_reporter ON reports(reporter_member_id, created_at);
