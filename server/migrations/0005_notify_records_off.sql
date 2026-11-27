-- 가족이 쓴 내역 알림은 기본으로 꺼 둔다 (켜는 사람만 받는다).
-- 새 멤버는 INSERT에서 0으로 넣고(src/routes/spaces.ts), 1.1.0 출시 전에 기본 1로 들어간 기존 멤버도 끈다.
UPDATE ledger_members SET notify_records = 0;
